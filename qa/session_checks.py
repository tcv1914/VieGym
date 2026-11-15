"""Session/token (plan ngày 17 §2) trên STAGING.

Ký JWT bằng khóa staging (infra/staging/secrets/jwt-private.pem, chỉ có trên máy dev) để mỗi ca chỉ sai đúng
một yếu tố: hết hạn, issuer, audience, typ, thiếu sid, sid lạ, chữ ký khóa khác, alg none/HS256. Sau đó kiểm
tra logout, khóa user, đặt lại mật khẩu làm access token cũ mất hiệu lực; refresh xoay vòng; giới hạn login.
Chạy (gốc repo): python -I -X utf8 qa/session_checks.py [base_url]
"""
import base64
import hashlib
import hmac
import json
import re
import sys
import time
import urllib.error
import urllib.request
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:18080") + "/api/v1"
ROOT = Path(__file__).resolve().parent.parent
ENV = dict(line.split("=", 1) for line in (ROOT / "infra/staging/.env").read_text(encoding="utf-8").splitlines()
           if "=" in line and not line.startswith("#"))
KEY = serialization.load_pem_private_key((ROOT / "infra/staging/secrets/jwt-private.pem").read_bytes(), None)
OTHER_KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)
RUN = f"{datetime.now():%m%d%H%M%S}"
results = []


def call(method, path, body=None, token=None):
    req = urllib.request.Request(BASE + path, method=method, headers={"Accept": "application/json"})
    data = json.dumps(body).encode() if body is not None else None
    if data is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, data, timeout=20) as r:
            t = r.read().decode()
            return r.status, json.loads(t) if t else None, dict(r.headers)
    except urllib.error.HTTPError as e:
        t = e.read().decode()
        return e.code, json.loads(t) if t else None, dict(e.headers)


def check(cid, name, cond, detail=""):
    results.append((cid, bool(cond)))
    print(f"{'PASS' if cond else 'FAIL'} {cid} {name}" + (f"  [{detail}]" if not cond else ""))


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def jwt(claims, key=KEY, alg="RS256", typ="JWT"):
    header = {"alg": alg} | ({"typ": typ} if typ else {})
    signing = f"{b64(json.dumps(header).encode())}.{b64(json.dumps(claims).encode())}"
    if alg == "RS256":
        sig = key.sign(signing.encode(), padding.PKCS1v15(), hashes.SHA256())
    elif alg == "HS256":  # tấn công nhầm thuật toán: dùng public key làm khóa HMAC
        pub = KEY.public_key().public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo)
        sig = hmac.new(pub, signing.encode(), hashlib.sha256).digest()
    else:
        sig = b""
    return f"{signing}.{b64(sig)}"


def claims_of(token):
    part = token.split(".")[1]
    return json.loads(base64.urlsafe_b64decode(part + "=" * (-len(part) % 4)))


def new_user(prefix):
    email = f"{prefix}.{RUN}@staging.viegym.vn"
    call("POST", "/auth/register", {"email": email, "password": "Matkhau123", "fullName": prefix})
    return email, call("POST", "/auth/login", {"email": email, "password": "Matkhau123"})[1]


def me(token):
    return call("GET", "/users/me", token=token)[0]


email, lg = new_user("sess")
real = claims_of(lg["accessToken"])
check("S00", "token thật: chỉ có iss/aud/sub/sid/iat/exp, không role/email",
      set(real) == {"iss", "aud", "sub", "sid", "iat", "exp"} and me(lg["accessToken"]) == 200, real)
now = int(time.time())
base = dict(real, iat=now, exp=now + 600)
forged = {
    "S01 hết hạn (exp quá 2 phút)": jwt(dict(base, exp=now - 120, iat=now - 1000)),
    "S02 issuer sai": jwt(dict(base, iss="evil")),
    "S03 audience sai": jwt(dict(base, aud=["viegym-admin"])),
    "S04 typ khác JWT": jwt(base, typ="at+jwt"),
    "S05 thiếu sid": jwt({k: v for k, v in base.items() if k != "sid"}),
    "S06 sid không tồn tại": jwt(dict(base, sid=str(uuid.uuid4()))),
    "S07 sub của user khác, sid thật": jwt(dict(base, sub=str(uuid.uuid4()))),
    "S08 ký bằng khóa khác": jwt(base, key=OTHER_KEY),
    "S09 alg none": jwt(base, alg="none"),
    "S10 alg HS256 với public key": jwt(base, alg="HS256"),
    "S11 chữ ký bị cắt": lg["accessToken"][:-10],
}
check("S12", "đối chứng: token tự ký đúng mọi claim được chấp nhận", me(jwt(base)) == 200)
for name, tok in forged.items():
    s, b, _ = call("GET", "/users/me", token=tok)
    check(name[:3], name[4:] + " → 401", s == 401 and b and b.get("code") == "UNAUTHORIZED", (s, b))

# Logout → access token cũ chết (kiểm tra session, không chờ hết hạn)
_, lg2 = new_user("sess-logout")
call("POST", "/auth/logout", {"refreshToken": lg2["refreshToken"]})
check("S13", "logout: access token cũ → 401 ngay", me(lg2["accessToken"]) == 401)

# Refresh xoay vòng; dùng lại token cũ thu hồi phiên; hai refresh đồng thời chỉ một thành công
_, lg3 = new_user("sess-refresh")
s1, r1, _ = call("POST", "/auth/refresh", {"refreshToken": lg3["refreshToken"]})
s2, _, _ = call("POST", "/auth/refresh", {"refreshToken": lg3["refreshToken"]})
check("S14", "refresh mới → 200, dùng lại refresh cũ → 401", s1 == 200 and s2 == 401, (s1, s2))
check("S15", "dùng lại refresh cũ thu hồi cả phiên (token mới cũng chết)",
      me(r1["accessToken"]) == 401 and call("POST", "/auth/refresh", {"refreshToken": r1["refreshToken"]})[0] == 401)
_, lg4 = new_user("sess-race")
with ThreadPoolExecutor(5) as pool:
    codes = list(pool.map(lambda _: call("POST", "/auth/refresh", {"refreshToken": lg4["refreshToken"]})[0], range(5)))
check("S16", "5 refresh đồng thời cùng token: tối đa 1 lần 200", codes.count(200) <= 1, codes)

# Khóa user → token cũ chết, login 403; mở khóa phải đăng nhập lại
tad = call("POST", "/auth/login", {"email": ENV["ADMIN_EMAIL"], "password": ENV["ADMIN_PASSWORD"]})[1]["accessToken"]
email5, lg5 = new_user("sess-lock")
call("PUT", f"/admin/users/{lg5['user']['id']}/status", {"status": "LOCKED", "reason": "kiểm thử ngày 17"}, tad)
s_login = call("POST", "/auth/login", {"email": email5, "password": "Matkhau123"})[0]
check("S17", "khóa: access cũ 401, refresh 401, login 403",
      me(lg5["accessToken"]) == 401 and call("POST", "/auth/refresh", {"refreshToken": lg5["refreshToken"]})[0] == 401
      and s_login == 403, s_login)
s_wrong = call("POST", "/auth/login", {"email": email5, "password": "SaiMatkhau1"})
check("S18", "tài khoản khóa + sai mật khẩu → 401 như thường (không lộ trạng thái khóa)", s_wrong[0] == 401, s_wrong[:2])
call("PUT", f"/admin/users/{lg5['user']['id']}/status", {"status": "ACTIVE"}, tad)
check("S19", "mở khóa: token cũ vẫn 401, đăng nhập lại được",
      me(lg5["accessToken"]) == 401 and call("POST", "/auth/login", {"email": email5, "password": "Matkhau123"})[0] == 200)

# Đặt lại mật khẩu (mã lấy từ Mailpit staging) → mọi phiên cũ chết
email6, lg6 = new_user("sess-reset")
call("POST", "/auth/forgot-password", {"email": email6})
code = None
for _ in range(20):
    time.sleep(0.5)
    with urllib.request.urlopen(f"http://127.0.0.1:18025/api/v1/search?query=to:{email6}", timeout=5) as r:
        msgs = json.loads(r.read())["messages"]
    if msgs:
        with urllib.request.urlopen(f"http://127.0.0.1:18025/api/v1/message/{msgs[0]['ID']}", timeout=5) as r:
            code = re.search(r"\b(\d{6})\b", json.loads(r.read())["Text"]).group(1)
        break
check("S20", "Mailpit staging nhận mã 6 số", code is not None)
s_reset = call("POST", "/auth/reset-password", {"email": email6, "code": code, "newPassword": "Matkhaumoi456"})[0]
s_again = call("POST", "/auth/reset-password", {"email": email6, "code": code, "newPassword": "Matkhaukhac789"})
check("S21", "reset → 204; mã dùng lần 2 → 400 INVALID_RESET_CODE",
      s_reset == 204 and s_again[0] == 400 and s_again[1]["code"] == "INVALID_RESET_CODE", (s_reset, s_again[:2]))
check("S22", "sau reset: access token cũ 401, refresh cũ 401",
      me(lg6["accessToken"]) == 401 and call("POST", "/auth/refresh", {"refreshToken": lg6["refreshToken"]})[0] == 401)
s, b, _ = call("POST", "/auth/forgot-password", {"email": f"khongco.{RUN}@staging.viegym.vn"})
check("S23", "quên mật khẩu email không tồn tại → 204 như email có thật", s == 204, s)

# BR-A09: giới hạn đăng nhập sai
email7, _ = new_user("sess-limit")
codes = [call("POST", "/auth/login", {"email": email7, "password": "SaiMatkhau1"})[0] for _ in range(5)]
s, b, h = call("POST", "/auth/login", {"email": email7, "password": "Matkhau123"})
check("S24", "5 lần sai → lần 6 (đúng mật khẩu) 429 RATE_LIMITED + Retry-After",
      codes == [401] * 5 and s == 429 and b["code"] == "RATE_LIMITED" and int(h.get("Retry-After", 0)) > 0, (codes, s, b))
ghost = f"ghost.{RUN}@staging.viegym.vn"
gcodes = [call("POST", "/auth/login", {"email": ghost, "password": "SaiMatkhau1"})[0] for _ in range(6)]
check("S25", "email không tồn tại bị chặn y hệt (không dò được tài khoản)", gcodes == [401] * 5 + [429], gcodes)

ok = sum(1 for _, p in results if p)
print(f"\n{ok}/{len(results)} PASS (chạy {RUN})")
sys.exit(0 if ok == len(results) else 1)
