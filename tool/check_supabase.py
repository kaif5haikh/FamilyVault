#!/usr/bin/env python3
"""Run real Auth/PostgREST against a disposable, loopback-only Supabase pod."""

import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import hmac
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import re
from pathlib import Path
import secrets
import subprocess
import tempfile
from threading import Thread
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

    def envelope(record: dict, proof: dict, actor: str, revision: int, entity: str = 'account'):
        return {'protocol_version': 1, 'operation_id': str(uuid4()), 'family_id': family,
                'actor_id': actor, 'device_id': proof['p_device'], 'entity_type': entity,
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

    member_provenance = {**provenance, 'created_by': member_id, 'updated_by': member_id,
                         'created_at_us': 3, 'updated_at_us': 3}
    grocery = next(row['id'] for row in categories if row['subtype'] == 'groceries')
    budget = {'id': str(uuid4()), **member_provenance, 'account_id': grocery,
              'month': '2026-11', 'amount_minor': 150000}
    assert push(envelope(budget, member, member_id, 0, 'budget'), member, member_session)['sequence'] == 3
    duplicate = {**budget, 'id': str(uuid4())}
    assert push(envelope(duplicate, member, member_id, 0, 'budget'), member, member_session, status=409)['code'] == 'PT409'

    check_id, adjustment_id = str(uuid4()), str(uuid4())
    statement = {'id': check_id, **member_provenance, 'account_id': cash, 'statement_date': '2026-11-01',
                 'statement_minor': maximum - 1, 'ledger_minor': maximum, 'notes': 'Synthetic statement'}
    stale = {**statement, 'ledger_minor': maximum - 1}
    assert push(envelope(stale, member, member_id, 0, 'reconciliation'), member, member_session, status=409)['code'] == 'PT409'
    equity = next(row['id'] for row in categories if row['subtype'] == 'reconciliation')
    adjustment = {**posted, **member_provenance, 'id': adjustment_id, 'kind': 'adjustment',
                  'description': 'Synthetic reconciliation', 'related_entity_id': check_id,
                  'postings': [{'id': str(uuid4()), 'family_id': family, 'journal_id': adjustment_id,
                                'account_id': account_id, 'position': position, 'amount_minor': amount}
                               for position, (account_id, amount) in enumerate(((cash, -1), (equity, 1)))]}
    args = envelope(statement, member, member_id, 0, 'reconciliation')
    args['bundle'] = {'adjustment': adjustment}
    receipt = push(args, member, member_session)
    assert receipt['sequence'] == 4 and receipt == push(args, member, member_session)
    latest = rpc('sync_pull', {**owner, 'p_after': 2}, owner_session)
    assert [event['sequence'] for event in latest['changes']] == [3, 4]
    assert json.loads(latest['changes'][1]['payload_json']) == args
    print('Real Data API passed shared budgets, stale statement refusal and atomic reconciliation.')


def check_document_access(rpc, family: str, owner: dict, owner_token: str, member: dict, member_token: str, worker: str):
    """Drive document RPCs with genuine Auth. The dedicated gateway test measures bytes."""
    owner_id = rpc('workspace', owner, owner_token)['member_id']
    member_id = rpc('workspace', member, member_token)['member_id']
    operation, doc, version = (str(uuid4()) for _ in range(3))
    fixture_digest = hashlib.sha256(b'Synthetic stored object for the RPC receipt fixture').hexdigest()
    reserved = rpc('document_reserve', {**member, 'p_operation': operation, 'p_document': doc,
        'p_version': version, 'p_owner': owner_id, 'p_base': 0, 'p_mime': 'application/pdf',
        'p_bytes': 100, 'p_digest': fixture_digest, 'p_metadata': base64.b64encode(secrets.token_bytes(72)).decode()}, member_token)
    assert reserved == operation
    readback = {'p_family': family, 'p_reservation': operation, 'p_size': 148, 'p_digest': fixture_digest}
    rpc('document_mark_bytes', readback, member_token, status=403)
    args = {**member, 'p_reservation': operation, 'p_grants': []}
    rpc('document_finalize', args, member_token, status=409)
    rpc('document_mark_bytes', readback, worker, status=204)
    assert rpc('document_list', owner, owner_token) == []
    args['p_grants'] = [{'version': 1, 'sender_device_id': member['p_device'], 'recipient_device_id': device['p_device'],
                        'ephemeral_public': secrets.token_hex(32),
                        'wrapped_key': base64.b64encode(secrets.token_bytes(72)).decode(),
                        'signature': secrets.token_hex(64)} for device in (owner, member)]
    receipt = rpc('document_finalize', args, member_token)
    assert receipt['version_id'] == version and receipt == rpc('document_finalize', args, member_token)
    summary = rpc('document_list', owner, owner_token)[0]
    assert (summary['owner_id'], summary['created_by']) == (owner_id, member_id)
    assert summary['key_grant']['recipient_device_id'] == owner['p_device']
    assert rpc('document_download_plan', {**owner, 'p_version': version}, owner_token)['ciphertext_digest'] == fixture_digest
    print('Real Data API passed document membership, worker-only verification and addressed key grants with a receipt fixture.')


def check_mobile(scratch: Path, auth_url: str, rest_url: str, family: str, users: list[dict]):
    """Expose the two isolated services under the normal Supabase client paths."""
    class FixtureProxy(BaseHTTPRequestHandler):
        def forward(self):
            target = None
            for prefix, upstream in (('/auth/v1/', auth_url), ('/rest/v1/', rest_url)):
                if self.path.startswith(prefix):
                    target = upstream + '/' + self.path[len(prefix):]
                    break
            if target is None:
                self.send_error(404)
                return
            length = int(self.headers.get('Content-Length', '0'))
            if length > 2 * 1024 * 1024:
                self.send_error(413)
                return
            body = self.rfile.read(length) if length else None
            headers = {key: self.headers[key] for key in ('Authorization', 'Content-Type', 'Accept', 'Prefer')
                       if key in self.headers}
            try:
                response = urlopen(Request(target, data=body, headers=headers, method=self.command), timeout=10)
            except HTTPError as error:
                response = error
            except (URLError, TimeoutError):
                self.send_error(502)
                return
            with response:
                raw = response.read()
                self.send_response(response.code)
                self.send_header('Content-Type', response.headers.get('Content-Type', 'application/json'))
                self.send_header('Content-Length', str(len(raw)))
                self.end_headers()
                self.wfile.write(raw)

        do_POST = do_GET = forward

        def log_message(self, *_):
            pass

    with ThreadingHTTPServer(('127.0.0.1', 0), FixtureProxy) as proxy:
        config = scratch / 'mobile-fixture.json'
        config.write_text(json.dumps({'url': f'http://127.0.0.1:{proxy.server_port}', 'family': family, 'users': users}))
        config.chmod(0o600)
        thread = Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        try:
            subprocess.run(['flutter', 'test', '--no-pub', 'test/features/supabase_ledger_round_trip_test.dart'],
                           env={**os.environ, 'FAMILYVAULT_TEST_SUPABASE_FIXTURE': str(config)},
                           cwd=ROOT, timeout=180, check=True)
        finally:
            proxy.shutdown()
            thread.join(timeout=5)


def run(scratch: Path, *, mobile: bool):
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
            return user['id'], access['access_token'], pw

        def rpc(endpoint: str, fields: dict, token: str, status: int | tuple[int, ...] = 200):
            return request(rest_url + '/rpc/fv_' + endpoint, fields, token=token, status=status)

        admin = admin_token(signing_key)
        owner, owner_session, owner_password = create_user('owner@example.invalid', admin)
        member, member_session, member_password = create_user('member@example.invalid', admin)
        outsider, outsider_session, _ = create_user('outside@example.invalid', admin)
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
        check_document_access(rpc, family, owner_fields, owner_session, member_fields, member_session, admin_token(signing_key))
        if mobile:
            check_mobile(scratch, auth_url, rest_url, family, [
                {'email': 'owner@example.invalid', 'password': owner_password, **owner_fields},
                {'email': 'member@example.invalid', 'password': member_password, **member_fields},
            ])
        request(auth_url + '/logout?scope=local', {}, token=member_session, status=204)
        rpc('workspace', member_fields, member_session, status=403)
        rpc('sync_pull', {**member_fields, 'p_after': 0}, member_session, status=403)
        rpc('document_list', member_fields, member_session, status=403)
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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mobile', action='store_true', help='run the Dart transport against the same provider pod')
    args = parser.parse_args()
    CACHE.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='fv-supabase-', dir=CACHE) as scratch_dir:
        run(Path(scratch_dir), mobile=args.mobile)
