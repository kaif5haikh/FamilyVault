#!/usr/bin/env python3
"""Run real Auth/PostgREST against a disposable, loopback-only Supabase pod."""

import base64
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


def request(url: str, body: dict | None = None, *, token: str | None = None, status: int = 200):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    try:
        with urlopen(Request(url, data=None if body is None else json.dumps(body).encode(), headers=headers), timeout=10) as reply:
            actual, raw = reply.status, reply.read()
    except HTTPError as e:
        actual, raw = e.code, e.read()
    if actual != status:
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

        def rpc(endpoint: str, fields: dict, token: str, status: int = 200):
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
        request(auth_url + '/logout?scope=local', {}, token=member_session, status=204)
        rpc('workspace', member_fields, member_session, status=403)
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
