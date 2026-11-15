"""Input, cấu hình và log (plan ngày 17 §3) trên STAGING. Vài payload không chứng minh miễn nhiễm; xem docs/37.
Chạy (gốc repo): python -I -X utf8 qa/input_config.py [base_url]
"""
import json
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path

HOST = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:18080"
BASE = HOST + "/api/v1"
ROOT = Path(__file__).resolve().parent.parent
RUN = f"{datetime.now():%m%d%H%M%S}"
results = []


def call(method, url, body=None, token=None, headers=None, raw=None):
    req = urllib.request.Request(url if url.startswith("http") else BASE + url, method=method,
                                 headers={"Accept": "application/json", **(headers or {})})
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, data, timeout=30) as r:
            return r.status, r.read().decode(errors="replace"), dict(r.headers)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(errors="replace"), dict(e.headers)
    except (urllib.error.URLError, ConnectionError) as e:
        return None, str(e), {}


def check(cid, name, cond, detail=""):
    results.append((cid, bool(cond)))
    print(f"{'PASS' if cond else 'FAIL'} {cid} {name}" + (f"  [{str(detail)[:300]}]" if not cond else ""))


LEAK = ("Exception", "org.springframework", "java.", "SQLState", "PSQL", "at com.", "Traceback", "hibernate")

email = f"input.{RUN}@staging.viegym.vn"
xss = "<script>alert(1)</script><img src=x onerror=alert(2)> O'Brien \"; DROP TABLE users;--"
s, body, _ = call("POST", "/auth/register", {"email": email, "password": "Matkhau123", "fullName": xss[:100]})
check("I01", "tên có HTML/SQL được lưu nguyên văn (là dữ liệu, không chạy)", s == 201 and json.loads(body)["fullName"] == xss[:100], (s, body))
tok = json.loads(call("POST", "/auth/login", {"email": email, "password": "Matkhau123"})[1])["accessToken"]
s, body, _ = call("GET", "/users/me", token=tok)
check("I02", "đọc lại tên y hệt; bảng users vẫn còn", s == 200 and json.loads(body)["fullName"] == xss[:100], s)

total = json.loads(call("GET", "/foods?size=1", token=tok)[1])["totalItems"]
for cid, kw in [("I03", "' OR '1'='1"), ("I04", "%"), ("I05", "_"), ("I06", "\\"), ("I07", "phở'; DROP TABLE foods;--"),
                ("I08", "<script>"), ("I09", "%' UNION SELECT email FROM users --")]:
    s, body, _ = call("GET", "/foods?size=5&keyword=" + urllib.request.quote(kw), token=tok)
    b = json.loads(body) if s == 200 else {}
    check(cid, f"tìm {kw!r}: 200, không trả toàn bộ {total} món, không lỗi SQL",
          s == 200 and b["totalItems"] < total and not any(x in body for x in LEAK), (s, b.get("totalItems"), body[:200]))
check("I10", "bảng foods còn nguyên sau các chuỗi DROP", json.loads(call("GET", "/foods?size=1", token=tok)[1])["totalItems"] == total)

# Payload lớn
big = json.dumps({"email": email, "password": "x", "fullName": "a" * 5_000_000}).encode()
s, body, _ = call("POST", "/auth/register", raw=big)
check("I11", "body 5 MB → 4xx có mã, không 500/treo", s is not None and 400 <= s < 500 and not any(x in body for x in LEAK), (s, body[:200]))
s, body, _ = call("POST", "/auth/login", raw=b'{"email":' + b'[' * 50000 + b']}')
check("I12", "JSON lồng 50.000 cấp → 400, không 500", s == 400 and not any(x in body for x in LEAK), (s, body[:200]))

# CORS: không có origin nào được phép (admin cùng origin qua proxy, mobile không phải trình duyệt)
s, body, h = call("OPTIONS", "/auth/login", headers={"Origin": "https://evil.example",
                                                     "Access-Control-Request-Method": "POST"})
check("I13", "preflight từ origin lạ: không có Access-Control-Allow-Origin",
      "Access-Control-Allow-Origin" not in h and s in (401, 403, 200, 204), (s, h.get("Access-Control-Allow-Origin")))
s, body, h = call("GET", "/users/me", token=tok, headers={"Origin": "https://evil.example"})
check("I14", "GET kèm Origin lạ: không có ACAO; app không dùng cookie nên không có CSRF qua cookie",
      "Access-Control-Allow-Origin" not in h and "Set-Cookie" not in h, h.get("Access-Control-Allow-Origin"))
s, body, h = call("POST", "/auth/login", {"email": email, "password": "Matkhau123"})
check("I15", "login không đặt cookie, có Cache-Control no-store", "Set-Cookie" not in h and "no-store" in h.get("Cache-Control", ""), h)
check("I16", "header bảo mật: X-Content-Type-Options nosniff, X-Frame-Options",
      h.get("X-Content-Type-Options") == "nosniff" and "X-Frame-Options" in h, h)

# Endpoint lộ cấu hình
s, body, _ = call("GET", "/system/health")
check("I17", "health public chỉ có status/service/database/message",
      s == 200 and set(json.loads(body)) == {"status", "service", "database", "message"}, body)
for cid, path in [("I18", "/actuator"), ("I19", "/actuator/env"), ("I20", "/v3/api-docs"), ("I21", "/swagger-ui.html"),
                  ("I23", "/api/v1/khong-ton-tai"), ("I24", "/media/../application.yaml"),
                  ("I25", "/media/exercises/..%2f..%2fapplication.yaml")]:
    s, body, _ = call("GET", HOST + path)
    check(cid, f"GET {path}: không lộ cấu hình/stack", s in (400, 401, 403, 404) and not any(x in body for x in LEAK)
          and "password" not in body.lower() and "jdbc" not in body.lower(), (s, body[:200]))
# I22: gọi thẳng /error trả 500 {"status":999,"error":"None"} (BasicErrorController khi không có lỗi nào được
# forward). Đã chấp nhận P3 (docs/37 §6): không lộ dữ liệu; chỉ kiểm tra không lộ.
s, body, _ = call("GET", HOST + "/error")
check("I22", "GET /error: không lộ cấu hình/stack (status 500/999 đã chấp nhận P3)",
      not any(x in body for x in LEAK) and "jdbc" not in body.lower(), (s, body[:200]))
s, body, _ = call("GET", "/users/me", token=tok, raw=None, headers={"Accept": "text/html"})
check("I26", "Accept text/html không làm lộ trang lỗi mặc định", not any(x in body for x in LEAK), body[:200])

# ai-service không publish ra host ở staging
s, body, _ = call("GET", "http://127.0.0.1:8000/health")
dev_running = s is not None
s2, _, _ = call("GET", "http://127.0.0.1:18000/health")
check("I27", "ai-service staging không có cổng trên host", s2 is None, s2)
r = subprocess.run(["docker", "compose", "-f", str(ROOT / "infra/staging/compose.yaml"), "exec", "-T", "backend", "bash",
                    "-c", "exec 3<>/dev/tcp/ai-service/8000 && printf 'POST /internal/chat HTTP/1.0\\r\\nContent-Type: application/json\\r\\nContent-Length: 2\\r\\n\\r\\n{}' >&3 && head -n1 <&3"],
                   capture_output=True, text=True, timeout=30)
check("I28", "gọi /internal/chat trong mạng nội bộ không có X-Internal-Key → 401", " 401" in r.stdout, r.stdout + r.stderr)
r = subprocess.run(["docker", "compose", "-f", str(ROOT / "infra/staging/compose.yaml"), "exec", "-T", "backend", "bash",
                    "-c", "exec 3<>/dev/tcp/ai-service/8000 && printf 'GET /docs HTTP/1.0\\r\\n\\r\\n' >&3 && head -n1 <&3; "
                          "exec 4<>/dev/tcp/ai-service/8000 && printf 'GET /openapi.json HTTP/1.0\\r\\n\\r\\n' >&4 && head -n1 <&4"],
                   capture_output=True, text=True, timeout=30)
check("I29", "ai-service tắt /docs và /openapi.json", r.stdout.count(" 404") == 2, r.stdout)

# Log staging: không có token, mật khẩu, mã reset, khóa
r = subprocess.run(["docker", "compose", "-f", str(ROOT / "infra/staging/compose.yaml"), "logs", "--no-color"],
                   capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60)
logs = r.stdout
env = dict(line.split("=", 1) for line in (ROOT / "infra/staging/.env").read_text(encoding="utf-8").splitlines()
           if "=" in line and not line.startswith("#"))
secrets = [env[k] for k in ("STAGING_DB_PASSWORD", "AI_INTERNAL_KEY", "GEMINI_API_KEY", "ADMIN_PASSWORD") if env.get(k)]
check("I30", "log không chứa secret của .env", not any(sct in logs for sct in secrets))
check("I31", "log không chứa JWT, mật khẩu test, refreshToken",
      "eyJ" not in logs and "Matkhau123" not in logs and "refreshToken" not in logs)
mail_lines = [l for l in logs.splitlines() if l.startswith("backend") and "đặt lại" in l]
check("I32", "log reset chỉ có userId, không có mã 6 số", not any(any(t.isdigit() and len(t) == 6 for t in l.split()) for l in mail_lines),
      mail_lines[:3])

ok = sum(1 for _, p in results if p)
print(f"\n{ok}/{len(results)} PASS (chạy {RUN}; ai-service DEV {'đang chạy' if dev_running else 'không chạy'})")
sys.exit(0 if ok == len(results) else 1)
