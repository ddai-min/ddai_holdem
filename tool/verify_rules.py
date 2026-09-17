"""배포된 firestore.rules가 실제로 남의 홀 카드를 막는지 라이브로 확인한다."""
import json, re, sys, urllib.request, urllib.error, pathlib

PROJECT = 'ddai-holdem'
ROOM = 'ZZTST'
BASE = f'https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents'

src = pathlib.Path('lib/firebase_options.dart').read_text()
KEY = re.search(r"static const FirebaseOptions web[\s\S]*?apiKey: '([^']+)'", src).group(1)


def call(url, method='GET', body=None, token=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header('Content-Type', 'application/json')
    if token:
        req.add_header('Authorization', f'Bearer {token}')
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read() or b'{}')
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b'{}')


def sign_in():
    status, out = call(
        f'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={KEY}',
        'POST', {'returnSecureToken': True})
    assert status == 200, out
    return out['localId'], out['idToken']


def s(v):
    return {'stringValue': v}


results = []


def check(label, expected_ok, status, detail=''):
    ok = (status in (200, 204)) == expected_ok
    results.append(ok)
    mark = '✅' if ok else '❌'
    want = '허용' if expected_ok else '거부'
    got = '허용' if status in (200, 204) else f'거부({status})'
    print(f'{mark} {label}\n     기대: {want} / 실제: {got} {detail}')


uid_a, tok_a = sign_in()
uid_b, tok_b = sign_in()
print(f'익명 사용자 둘 확보: A={uid_a[:8]}… B={uid_b[:8]}…\n')

# 1. 방장이 방을 만든다.
st, out = call(f'{BASE}/rooms?documentId={ROOM}', 'POST',
               {'fields': {'hostUid': s(uid_a)}}, tok_a)
check('A가 hostUid=A로 방 생성', True, st, out.get('error', {}).get('message', ''))

# 2. 방장이 각자의 홀 카드를 써 넣는다.
for uid, tok in ((uid_a, tok_a), (uid_b, tok_a)):
    st, _ = call(f'{BASE}/rooms/{ROOM}/private/{uid}', 'PATCH',
                 {'fields': {'cards': s('As,Kd')}}, tok)
    check(f'방장이 {"A" if uid == uid_a else "B"}의 홀 카드 기록', True, st)

# 3. ★ 핵심: B가 A의 홀 카드를 읽으려 한다.
st, _ = call(f'{BASE}/rooms/{ROOM}/private/{uid_a}', 'GET', None, tok_b)
check('B가 A의 홀 카드 읽기', False, st)

# 4. B는 자기 홀 카드는 읽을 수 있다.
st, _ = call(f'{BASE}/rooms/{ROOM}/private/{uid_b}', 'GET', None, tok_b)
check('B가 자기 홀 카드 읽기', True, st)

# 5. B가 방장 전용 비밀 문서(남은 덱 + 모두의 홀 카드)를 읽으려 한다.
st, _ = call(f'{BASE}/rooms/{ROOM}/secret/host', 'PATCH',
             {'fields': {'deck': s('2c,3d')}}, tok_a)
check('방장이 비밀 문서 기록', True, st)
st, _ = call(f'{BASE}/rooms/{ROOM}/secret/host', 'GET', None, tok_b)
check('B가 방장 비밀 문서 읽기', False, st)

# 6. B가 공개 테이블 상태를 직접 고치려 한다.
st, _ = call(f'{BASE}/rooms/{ROOM}?updateMask.fieldPaths=table', 'PATCH',
             {'fields': {'table': s('조작')}}, tok_b)
check('B가 테이블 상태 직접 수정', False, st)

# 7. B는 방을 볼 수는 있어야 한다.
st, _ = call(f'{BASE}/rooms/{ROOM}', 'GET', None, tok_b)
check('B가 방 공개 상태 읽기', True, st)

# 8. B가 자기 이름으로 명령을 보낸다.
st, _ = call(f'{BASE}/rooms/{ROOM}/commands?documentId=cmd1', 'POST',
             {'fields': {'uid': s(uid_b), 'type': s('play')}}, tok_b)
check('B가 자기 uid로 명령 전송', True, st)

# 9. ★ B가 A인 척 명령을 보낸다.
st, _ = call(f'{BASE}/rooms/{ROOM}/commands?documentId=cmd2', 'POST',
             {'fields': {'uid': s(uid_a), 'type': s('play')}}, tok_b)
check('B가 A의 uid를 사칭한 명령', False, st)

# 정리
for path in (f'rooms/{ROOM}/private/{uid_a}', f'rooms/{ROOM}/private/{uid_b}',
             f'rooms/{ROOM}/secret/host', f'rooms/{ROOM}/commands/cmd1',
             f'rooms/{ROOM}'):
    call(f'{BASE}/{path}', 'DELETE', None, tok_a)
for tok in (tok_a, tok_b):
    call(f'https://identitytoolkit.googleapis.com/v1/accounts:delete?key={KEY}',
         'POST', {'idToken': tok})
print('\n정리 완료 (테스트 문서와 임시 계정 삭제)')

print(f'\n{sum(results)}/{len(results)} 통과')
sys.exit(0 if all(results) else 1)
