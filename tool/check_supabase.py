#!/usr/bin/env python3
"""Run real Auth/PostgREST against a disposable, loopback-only Supabase pod."""

import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import hmac
import json
import os
import re
from pathlib import Path
import secrets
import subprocess
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
from uuid import uuid4

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / '.cache'
OS_ENV = {**os.environ, 'XDG_CONFIG_HOME': str(CACHE / 'config'), 'XDG_CACHE_HOME': str(CACHE / 'xdg')}
PODMAN = [
    'podman', '--root', str(CACHE / 'podman/root'), '--runroot', str(CACHE / 'podman/run'),
    '--storage-driver', 'vfs',
]
# Image versions match the reviewed Supabase self-hosted stack.
DB_IMAGE = 'docker.io/supabase/postgres@sha256:5a4314708484bec672de2c09653a5c01fb1c84a998564ac231b0325e2238ed5b'
AUTH_IMAGE = 'docker.io/supabase/gotrue@sha256:839f529492d116b4e8b7777c953a27c381d34c15a744b1bcefde5eefaa1f9f9f'
REST_IMAGE = 'docker.io/postgrest/postgrest@sha256:c847127074bd26e1b8d3f7c0e6e01e5346f4b85dd34f5d699fd230af960827c0'


def podman(*args: str, source: str | None = None, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run([*PODMAN, *args], input=source, check=check, text=True,
                          capture_output=True, env=OS_ENV, cwd=ROOT, timeout=180)


def env_file(path: Path, values: dict[str, str]) -> str:
    path.write_text(''.join(f'{key}={value}\n' for key, value in values.items()))
    path.chmod(0o600)
    return str(path)


def base64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b'=').decode()


def admin_token(signing_key: str) -> str:
    head = base64url(b'{"alg":"HS256","typ":"JWT"}')
    body = base64url(json.dumps({'role': 'service_role', 'exp': int(time.time()) + 300}).encode())
    signature = hmac.digest(signing_key.encode(), f'{head}.{body}'.encode(), 'sha256')
    return f'{head}.{body}.{base64url(signature)}'


def request(url: str, body: dict | None = None, *, token: str | None = None, status: int | tuple[int, ...] = 200):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    try:
        with urlopen(Request(url, data=None if body is None else json.dumps(body).encode(), headers=headers), timeout=10) as reply:
            actual, raw = reply.status, reply.read()
    except HTTPError as e:
        actual, raw = e.code, e.read()
    if actual not in (status if isinstance(status, tuple) else (status,)):
        # Never print response details from login, MFA or database requests.
        raise AssertionError(f'{url.split("?")[0]} returned HTTP {actual}, expected {status}')
    return json.loads(raw) if raw else None


def wait_for(check, description: str, timeout: float = 75):
    until = time.monotonic() + timeout
    while time.monotonic() < until:
        try:
            if check():
                return
        except (AssertionError, URLError, OSError):
            pass
        time.sleep(0.4)
    raise RuntimeError(f'{description} did not become ready')


def otp(secret: str) -> str:
    key = base64.b32decode(secret + '=' * (-len(secret) % 8))
    mac = hmac.digest(key, (int(time.time()) // 30).to_bytes(8, 'big'), 'sha1')
    offset = mac[-1] & 0x0f
    code = int.from_bytes(mac[offset:offset + 4], 'big') & 0x7fffffff
    return f'{code % 1_000_000:06d}'


def check_ledger(rpc, family: str, owner: dict, owner_session: str, member: dict, member_session: str):
    """Drive competing exact-integer operations through two signed Auth sessions."""
    owner_member = rpc('workspace', owner, owner_session)['member_id']
    member_id = rpc('workspace', member, member_session)['member_id']
    categories = rpc('sync_chart', owner, owner_session)
    opening = next(row['id'] for row in categories if row['subtype'] == 'opening')
    cash, journal = str(uuid4()), str(uuid4())
    provenance = {'family_id': family, 'created_by': owner_member, 'updated_by': owner_member,
                  'created_at_us': 1, 'updated_at_us': 1, 'deleted_at_us': None, 'revision': 1}
    account = {'id': cash, **provenance, 'name': 'Synthetic cash', 'kind': 'asset', 'subtype': 'cash',
               'system_account': False, 'currency': 'INR'}
    maximum = 2**63 - 1
    posted = {'id': journal, **provenance, 'kind': 'opening', 'occurred_on': '2026-11-01',
              'description': 'Synthetic exact opening', 'currency': 'INR', 'status': 'posted',
              'reverses_id': None, 'business_id': None, 'related_entity_id': None,
              'postings': [{'id': str(uuid4()), 'family_id': family, 'journal_id': journal,
                            'account_id': account_id, 'position': position, 'amount_minor': amount}
                           for position, (account_id, amount) in enumerate(((cash, maximum), (opening, -maximum)))]}

    def envelope(record: dict, proof: dict, actor: str, revision: int):
        return {'protocol_version': 1, 'operation_id': str(uuid4()), 'family_id': family,
                'actor_id': actor, 'device_id': proof['p_device'], 'entity_type': 'account',
                'entity_id': record['id'], 'mutation_kind': 'upsert', 'base_revision': revision, 'record': record}

    def push(change: dict, proof: dict, token: str, status=200):
        raw = json.dumps(change, sort_keys=True, separators=(',', ':'))
        return rpc('sync_push', {**proof, 'p_envelope': raw}, token, status=status)

    args = envelope(account, owner, owner_member, 0)
    args['bundle'] = {'journals': [posted]}
    receipt = push(args, owner, owner_session)
    assert receipt['sequence'] == 1
    assert receipt == push(args, owner, owner_session)
    first_page = rpc('sync_pull', {**member, 'p_after': 0, 'p_limit': 1}, member_session)
    event = first_page['changes'][0]
    assert event['payload_digest'] == receipt['payload_digest']
    raw = event['payload_json']
    assert hashlib.sha256(raw.encode()).hexdigest() == receipt['payload_digest']
    assert json.loads(raw)['bundle']['journals'][0]['postings'][0]['amount_minor'] == maximum

    def rename(proof, token, actor, label):
        after = {**account, 'name': label, 'updated_at_us': 2, 'updated_by': actor, 'revision': 2}
        return push(envelope(after, proof, actor, 1), proof, token, status=(200, 409))

    with ThreadPoolExecutor(max_workers=2) as workers:
        futures = [workers.submit(rename, owner, owner_session, owner_member, 'Synthetic owner edit'),
                   workers.submit(rename, member, member_session, member_id, 'Synthetic member edit')]
        results = [future.result() for future in futures]

    assert sum(result.get('sequence') == 2 for result in results) == 1
    assert sum(result.get('code') == 'PT409' for result in results) == 1
    latest = rpc('sync_pull', {**member, 'p_after': 1}, member_session)
    assert latest['watermark'] == 2 and len(latest['changes']) == 1
    assert json.loads(latest['changes'][0]['payload_json'])['record']['created_by'] == owner_member
    print('Real Data API passed exact paise, atomic opening, receipt replay and concurrent revision checks.')


def run(scratch: Path):
    name = 'fv-check-' + uuid4().hex[:10]
    db, auth, rest = (f'{name}-{service}' for service in ('db', 'auth', 'rest'))
    password = secrets.token_hex(32)
    signing_key = secrets.token_hex(48)
    podman('pod', 'create', '--name', name, '-p', '127.0.0.1::9999', '-p', '127.0.0.1::3000')
    try:
        def psql(sql: str, *, user: str = 'postgres') -> str:
            proc = podman('exec', '-i', db, 'psql', '-X', '-qAt', '-U', user, '-v', 'ON_ERROR_STOP=1', source=sql, check=False)
            if proc.returncode:
                # DDL without fixture credentials may be inspected in the ignored cache.
                # Do not include data parameters in diagnostics.
                detail = proc.stderr.strip() or 'No diagnostic output'
                if source_sql := proc.stdout.strip():
                    detail += '\nSQL context: ' + '\n'.join(source_sql.splitlines()[-4:])
                detail = detail.replace(password, '[redacted]').replace(signing_key, '[redacted]')
                detail = re.sub(r'[A-Za-z0-9_+.\-/]{32,}', '[redacted]', detail)
                raise RuntimeError(f'Database command failed (exit {proc.returncode}). {detail[:800]}')
            return proc.stdout.strip()

        podman('run', '-d', '--pull=never', '--pod', name, '--name', db, '--env-file', env_file(scratch / 'db.env', {
            'POSTGRES_HOST': '/var/run/postgresql', 'POSTGRES_PORT': '5432', 'PGPORT': '5432',
            'POSTGRES_DB': 'postgres', 'PGDATABASE': 'postgres', 'POSTGRES_PASSWORD': password, 'PGPASSWORD': password,
        }), DB_IMAGE, 'postgres', '-c', 'config_file=/etc/postgresql/postgresql.conf',
               '-c', 'log_parameter_max_length_on_error=0', '-c', 'log_min_messages=warning',
               '-c', 'log_min_error_statement=panic', '-c', 'log_error_verbosity=terse',
               '-c', 'log_statement=none', '-c', 'log_parameter_max_length=0')
        wait_for(lambda: podman('exec', db, 'pg_isready', '-U', 'postgres', '-h', '127.0.0.1', check=False).returncode == 0,
                 'Supabase PostgreSQL')
        # Same-role passwords used by the official compose setup, scoped to this disposable pod.
        psql(f"ALTER ROLE authenticator PASSWORD '{password}'; ALTER ROLE supabase_auth_admin PASSWORD '{password}';", user='supabase_admin')
        infra = podman('pod', 'inspect', name, '--format', '{{.InfraContainerID}}').stdout.strip()
        psql('SELECT current_user;')
        mapping = podman('port', infra).stdout.splitlines()
        ports = {line.split('/')[0]: line.rsplit(':', 1)[-1] for line in mapping}
        auth_url = f'http://127.0.0.1:{ports["9999"]}'
        rest_url = f'http://127.0.0.1:{ports["3000"]}'
        podman('run', '-d', '--pull=never', '--pod', name, '--name', auth, '--env-file', env_file(scratch / 'auth.env', {
            'GOTRUE_API_HOST': '0.0.0.0', 'GOTRUE_API_PORT': '9999', 'API_EXTERNAL_URL': auth_url,
            'GOTRUE_DB_DRIVER': 'postgres',
            'GOTRUE_DB_DATABASE_URL': f'postgres://supabase_auth_admin:{password}@127.0.0.1:5432/postgres',
            'GOTRUE_SITE_URL': auth_url, 'GOTRUE_DISABLE_SIGNUP': 'true', 'GOTRUE_EXTERNAL_EMAIL_ENABLED': 'true',
            'GOTRUE_MAILER_AUTOCONFIRM': 'true', 'GOTRUE_JWT_SECRET': signing_key, 'GOTRUE_JWT_EXP': '3600',
            'GOTRUE_JWT_ADMIN_ROLES': 'service_role', 'GOTRUE_JWT_AUD': 'authenticated',
            'GOTRUE_JWT_DEFAULT_GROUP_NAME': 'authenticated', 'GOTRUE_MFA_TOTP_ENROLL_ENABLED': 'true',
            'GOTRUE_MFA_TOTP_VERIFY_ENABLED': 'true', 'GOTRUE_LOG_LEVEL': 'warn',
        }), AUTH_IMAGE)
        wait_for(lambda: request(auth_url + '/health') is not None, 'Supabase Auth')
        for migration in sorted((ROOT / 'supabase/migrations').glob('*.sql')):
            psql('\\set ECHO all\n' + migration.read_text())
        podman('run', '-d', '--pull=never', '--pod', name, '--name', rest, '--env-file', env_file(scratch / 'rest.env', {
            'PGRST_DB_URI': f'postgres://authenticator:{password}@127.0.0.1:5432/postgres',
            'PGRST_DB_SCHEMAS': 'public', 'PGRST_DB_ANON_ROLE': 'anon', 'PGRST_JWT_SECRET': signing_key,
            'PGRST_LOG_LEVEL': 'crit',
        }), REST_IMAGE)
        wait_for(lambda: request(rest_url + '/') is not None, 'PostgREST')

        def create_user(email: str, admin: str):
            pw = secrets.token_urlsafe(32)
            user = request(auth_url + '/admin/users', {'email': email, 'password': pw, 'email_confirm': True}, token=admin)
            access = request(auth_url + '/token?grant_type=password', {'email': email, 'password': pw})
            return user['id'], access['access_token']

        def rpc(endpoint: str, fields: dict, token: str, status: int | tuple[int, ...] = 200):
            return request(rest_url + '/rpc/fv_' + endpoint, fields, token=token, status=status)

        admin = admin_token(signing_key)
        owner, owner_session = create_user('owner@example.invalid', admin)
        member, member_session = create_user('member@example.invalid', admin)
        outsider, outsider_session = create_user('outside@example.invalid', admin)
        del member, outsider, admin
        family = psql(f"SELECT fv_internal.bootstrap_family('{owner}', 'Synthetic workspace', 'Synthetic owner');")

        def request_device(session: str):
            device, proof = str(uuid4()), secrets.token_hex(32)
            signing, exchange = secrets.token_hex(32), secrets.token_hex(32)
            result = rpc('request_device', {'p_family': family, 'p_device': device, 'p_proof': proof,
                'p_name': 'Synthetic phone', 'p_signing_public': signing, 'p_exchange_public': exchange}, session)
            assert result == 'pending'
            return {'p_device': device, 'p_proof': proof}, hashlib.sha256(bytes.fromhex(signing + exchange)).hexdigest()

        owner_fields, owner_fingerprint = request_device(owner_session)
        psql(f"SELECT fv_internal.approve_first_device('{owner_fields['p_device']}', '{owner_fingerprint}');")
        rpc('bind_device', owner_fields, owner_session, status=204)
        assert rpc('workspace', owner_fields, owner_session)['role'] == 'administrator'
        rpc('admin_access', owner_fields, owner_session, status=403)
        enrollment = request(auth_url + '/factors', {'factor_type': 'totp', 'friendly_name': 'Synthetic test'}, token=owner_session)
        factor = auth_url + f'/factors/{enrollment["id"]}'
        challenge = request(factor + '/challenge', {}, token=owner_session)
        verified = request(factor + '/verify', {'challenge_id': challenge['id'], 'code': otp(enrollment['totp']['secret'])}, token=owner_session)
        owner_session = verified['access_token']
        invite = rpc('invite_member', {**owner_fields, 'p_email': 'member@example.invalid', 'p_name': 'Synthetic member',
            'p_relationship': 'member'}, owner_session)
        rpc('accept_invite', {'p_invite': invite}, outsider_session, status=403)
        assert rpc('accept_invite', {'p_invite': invite}, member_session) == family
        member_fields, member_fingerprint = request_device(member_session)
        rpc('bind_device', member_fields, member_session, status=403)
        rpc('approve_device', {**owner_fields, 'p_candidate': member_fields['p_device'], 'p_fingerprint': member_fingerprint}, owner_session, status=204)
        rpc('bind_device', member_fields, member_session, status=204)
        assert rpc('workspace', member_fields, member_session)['role'] == 'member'
        rpc('admin_access', member_fields, member_session, status=403)
        rpc('workspace', {**member_fields, 'p_proof': secrets.token_hex(32)}, member_session, status=403)
        check_ledger(rpc, family, owner_fields, owner_session, member_fields, member_session)
        request(auth_url + '/logout?scope=local', {}, token=member_session, status=204)
        rpc('workspace', member_fields, member_session, status=403)
        rpc('sync_pull', {**member_fields, 'p_after': 0}, member_session, status=403)
        print('Real Supabase Auth and PostgREST passed sign-in, MFA, invitation, enrollment and stale-token denial.')
    except Exception:
        for service in (db, auth, rest):
            logs = podman('logs', '--tail', '8', service, check=False)
            if logs.returncode == 0:
                details = (logs.stdout + logs.stderr).replace(password, '[redacted]').replace(signing_key, '[redacted]')
                details = re.sub(r'[A-Za-z0-9_+.\-/]{32,}', '[redacted]', details)
                print(details, flush=True)
        raise
    finally:
        podman('pod', 'rm', '--force', name, check=False)


if __name__ == '__main__':
    CACHE.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='fv-supabase-', dir=CACHE) as scratch_dir:
        run(Path(scratch_dir))
