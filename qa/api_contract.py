"""Quét hợp đồng API (plan ngày 16 §3) trên backend đang chạy, mặc định STAGING.

Mỗi ca: request → so status, `code`, cấu trúc lỗi chuẩn (docs/05 §1.1), kiểu dữ liệu; với input sai thì kiểm tra
thêm là không có dữ liệu bị ghi một phần. Không hardcode token: tự đăng ký tài khoản contract.<thời điểm>.
Chạy (gốc repo): python -I -X utf8 qa/api_contract.py [base_url]
"""
import json
import re
import sys
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:18080") + "/api/v1"
VN = timezone(timedelta(hours=7))
NOW = datetime.now(VN)
TODAY = NOW.date()
RUN = f"{datetime.now():%m%d%H%M%S}"
UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
ISO_INSTANT = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$")
results = []


def call(method, path, body=None, token=None, raw=None):
    req = urllib.request.Request(BASE + path, method=method, headers={"Accept": "application/json"})
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, data, timeout=20) as r:
            t = r.read().decode()
            return r.status, json.loads(t) if t else None
    except urllib.error.HTTPError as e:
        t = e.read().decode()
        try:
            return e.code, json.loads(t) if t else None
        except json.JSONDecodeError:
            return e.code, {"_raw": t[:200]}


def check(cid, name, cond, detail=""):
    results.append((cid, bool(cond)))
    print(f"{'PASS' if cond else 'FAIL'} {cid} {name}" + (f"  [{detail}]" if not cond else ""))


def std_error(body, code, field=None):
    """Lỗi chuẩn: code, message, timestamp ISO UTC, path; fieldErrors chỉ khi VALIDATION_ERROR."""
    if not isinstance(body, dict):
        return False
    ok = body.get("code") == code and isinstance(body.get("message"), str) and body.get("path", "").startswith("/api/v1")
    ok = ok and ISO_INSTANT.match(body.get("timestamp", "")) is not None
    if field:
        ok = ok and field in (body.get("fieldErrors") or {})
    if code != "VALIDATION_ERROR":
        ok = ok and "fieldErrors" not in body
    # Không rò chi tiết nội bộ.
    text = json.dumps(body)
    return ok and not any(s in text for s in ("Exception", "org.", "java.", "SQL", "stack"))


def expect_error(cid, name, resp, status, code, field=None):
    s, b = resp
    check(cid, name, s == status and std_error(b, code, field), f"{s} {json.dumps(b, ensure_ascii=False)[:250]}")


def login_new(prefix):
    email = f"{prefix}.{RUN}@staging.viegym.vn"
    s, reg = call("POST", "/auth/register", {"email": email, "password": "Matkhau123", "fullName": prefix,
                                              "role": "ADMIN", "id": str(uuid.uuid4())})
    s2, lg = call("POST", "/auth/login", {"email": email, "password": "Matkhau123"})
    return reg, lg


# ---- Auth
reg, lg = login_new("contract")
check("C01", "đăng ký bỏ qua role/id client gửi → role USER, id server sinh", reg["role"] == "USER" and UUID_RE.match(reg["id"]))
tok = lg["accessToken"]
check("C02", "login: kiểu dữ liệu token", isinstance(lg["accessTokenExpiresIn"], int) and lg["tokenType"] == "Bearer")
expect_error("C03", "đăng ký thiếu password", call("POST", "/auth/register", {"email": f"x{RUN}@a.vn", "fullName": "x"}),
             400, "VALIDATION_ERROR", "password")
expect_error("C04", "đăng ký fullName 101 ký tự", call("POST", "/auth/register", {"email": f"y{RUN}@a.vn",
             "password": "Matkhau123", "fullName": "a" * 101}), 400, "VALIDATION_ERROR", "fullName")
expect_error("C05", "JSON hỏng", call("POST", "/auth/login", raw=b'{"email":'), 400, "MALFORMED_JSON")
expect_error("C06", "không token → 401", call("GET", "/users/me"), 401, "UNAUTHORIZED")
expect_error("C07", "token rác → 401", call("GET", "/users/me", token="abc.def.ghi"), 401, "UNAUTHORIZED")
expect_error("C08", "USER gọi admin → 403", call("GET", "/admin/users", token=tok), 403, "FORBIDDEN")
s, me = call("GET", "/users/me", token=tok)
check("C09", "/users/me không có passwordHash/secret", s == 200 and not any(k.lower().startswith("password") for k in me), me)

# ---- Health profile
good = {"sex": "MALE", "dateOfBirth": "2000-01-15", "heightCm": 170, "weightKg": 65, "activityLevel": "MODERATE",
        "goal": "MAINTAIN"}
expect_error("C10", "hồ sơ chưa có → 404 HEALTH_PROFILE_REQUIRED", call("GET", "/health-profile/me", token=tok),
             404, "HEALTH_PROFILE_REQUIRED")
for cid, field, bad in [("C11", "heightCm", 99.9), ("C12", "weightKg", 300.1), ("C13", "activityLevel", "HIGH"),
                        ("C14", "dateOfBirth", "2026-13-01"), ("C15", "sex", "UNSPECIFIED"),
                        ("C16", "dateOfBirth", (TODAY + timedelta(days=1)).isoformat()), ("C17", "heightCm", -170),
                        ("C18", "goal", None)]:
    expect_error(cid, f"hồ sơ {field}={bad!r} → 400", call("PUT", "/health-profile/me", dict(good, **{field: bad}), tok),
                 400, "VALIDATION_ERROR", field)
expect_error("C19", "sau các lần sai vẫn chưa có hồ sơ (không ghi dở)", call("GET", "/health-profile/me", token=tok),
             404, "HEALTH_PROFILE_REQUIRED")
s, hp = call("PUT", "/health-profile/me", dict(good, userId=str(uuid.uuid4()), targetKcal=9999, bmi=1), tok)
check("C20", "field lạ userId/targetKcal/bmi bị bỏ qua", s == 200 and hp["targets"]["targetKcal"] != 9999, s)
check("C21", "kiểu: số là number, ngày YYYY-MM-DD, calculatedAt ISO UTC",
      isinstance(hp["targets"]["bmi"], (int, float)) and hp["profile"]["dateOfBirth"] == "2000-01-15"
      and ISO_INSTANT.match(hp["targets"]["calculatedAt"]), hp)

# ---- Foods: phân trang
s, p0 = call("GET", "/foods?size=100", token=tok)
check("C22", "trang foods đủ field phân trang",
      s == 200 and all(k in p0 for k in ("items", "page", "size", "totalItems", "totalPages", "hasNext")), p0.keys())
last = p0["totalPages"] - 1
s, pl = call("GET", f"/foods?size=100&page={last}", token=tok)
s2, pb = call("GET", f"/foods?size=100&page={last + 1}", token=tok)
check("C23", "trang cuối hasNext=false; quá trang cuối → items rỗng",
      pl["hasNext"] is False and len(pl["items"]) == p0["totalItems"] - 100 * last and pb["items"] == [], (last, len(pl["items"])))
ids = set()
for page in range(p0["totalPages"]):
    ids |= {f["id"] for f in call("GET", f"/foods?size=100&page={page}", token=tok)[1]["items"]}
check("C24", "đi hết các trang: không trùng, không thiếu", len(ids) == p0["totalItems"], (len(ids), p0["totalItems"]))
expect_error("C25", "size=101 → 400", call("GET", "/foods?size=101", token=tok), 400, "VALIDATION_ERROR")
expect_error("C26", "page=-1 → 400", call("GET", "/foods?page=-1", token=tok), 400, "VALIDATION_ERROR")
expect_error("C27", "keyword 101 ký tự → 400", call("GET", "/foods?keyword=" + "a" * 101, token=tok), 400, "VALIDATION_ERROR")
s, b = call("GET", "/foods/not-a-uuid", token=tok)
check("C28", "id món sai định dạng → 400/404 có mã chuẩn", s in (400, 404) and std_error(b, b.get("code")), (s, b))
food = p0["items"][0]

# ---- Meal plan
def meal_count():
    return call("GET", f"/meal-plans?date={TODAY}", token=tok)[1]["entryCount"]

entry = {"date": TODAY.isoformat(), "mealType": "LUNCH", "foodId": food["id"], "servings": 1.5}
for cid, field, bad in [("C29", "servings", 0), ("C30", "servings", 21), ("C31", "mealType", "BRUNCH"),
                        ("C32", "date", (TODAY + timedelta(days=8)).isoformat()), ("C33", "date", "1999-12-31"),
                        ("C34", "servings", "abc")]:
    expect_error(cid, f"thêm món {field}={bad!r} → 400", call("POST", "/meal-plans/entries", dict(entry, **{field: bad}), tok),
                 400, "VALIDATION_ERROR" if cid != "C34" else ("VALIDATION_ERROR"), field if cid != "C34" else None)
expect_error("C35", "món không tồn tại → 404", call("POST", "/meal-plans/entries", dict(entry, foodId=str(uuid.uuid4())), tok),
             404, "NOT_FOUND")
check("C36", "sau các lần sai thực đơn vẫn 0 mục", meal_count() == 0)
s, mp = call("POST", "/meal-plans/entries", dict(entry, kcal=1, proteinG=1, userId=str(uuid.uuid4())), tok)
check("C37", "kcal/macro client gửi bị bỏ qua (BR-N04)",
      s == 201 and abs(mp["totals"]["kcal"] - round(float(food["kcalPerServing"]) * 1.5, 2)) < 0.01, s)
check("C38", "4 bữa luôn có mặt, tổng là number", set(mp["meals"]) == {"BREAKFAST", "LUNCH", "DINNER", "SNACK"}
      and all(isinstance(v, (int, float)) for v in mp["totals"].values()), mp["meals"].keys())

# ---- Workout: input sai không ghi dở
s, tpl = call("GET", "/workout-programs?scope=templates", token=tok)
tpl = tpl.get("items", tpl) if isinstance(tpl, dict) else tpl
s, prog = call("POST", "/workout-programs", {"templateId": tpl[0]["id"], "activate": True}, tok)
s, sch = call("POST", "/workout-schedules", {"workoutDayId": prog["days"][0]["id"], "scheduledDate": TODAY.isoformat()}, tok)
ex = call("GET", f"/workout-schedules/{sch['id']}", token=tok)[1]["exercises"][0]["exerciseId"]
log = {"scheduleId": sch["id"], "exercises": [{"exerciseId": ex, "sets": [{"reps": 10, "weightKg": 20}]}]}
future = (datetime.now(timezone.utc) + timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ")
bad_logs = [
    ("C39", "reps thập phân 10.5", {"exercises": [{"exerciseId": ex, "sets": [{"reps": 10.5, "weightKg": 20}]}]}),
    ("C40", "weightKg 1000", {"exercises": [{"exerciseId": ex, "sets": [{"reps": 10, "weightKg": 1000}]}]}),
    ("C41", "weightKg 3 số lẻ", {"exercises": [{"exerciseId": ex, "sets": [{"reps": 10, "weightKg": 20.125}]}]}),
    ("C42", "startedAt tương lai", {"startedAt": future}),
    ("C43", "không có set", {"exercises": [{"exerciseId": ex, "sets": []}]}),
    ("C44", "bài lặp trong log", {"exercises": [{"exerciseId": ex, "sets": [{"reps": 1, "weightKg": 0}]}] * 2}),
    ("C45", "thiếu weightKg (trống ≠ 0)", {"exercises": [{"exerciseId": ex, "sets": [{"reps": 10}]}]}),
]
for cid, name, patch in bad_logs:
    expect_error(cid, f"log {name} → 400", call("POST", "/workout-logs", dict(log, **patch), tok), 400, "VALIDATION_ERROR")
s, sd = call("GET", f"/workout-schedules/{sch['id']}", token=tok)
s2, hist = call("GET", "/workout-logs", token=tok)
check("C46", "sau các log sai: lịch vẫn SCHEDULED, không có log", sd["status"] == "SCHEDULED" and sd["workoutLogId"] is None
      and hist["items"] == [], (sd["status"], len(hist["items"])))
s, lg1 = call("POST", "/workout-logs", log, tok)
s2, lg2 = call("POST", "/workout-logs", dict(log, note="khác nội dung"), tok)
check("C47", "replay khác payload → 409 WORKOUT_ALREADY_LOGGED, log cũ giữ nguyên",
      s == 201 and s2 == 409 and lg2.get("workoutLogId") == lg1["id"]
      and call("GET", f"/workout-logs/{lg1['id']}", token=tok)[1].get("note") is None, (s, s2, lg2))
expect_error("C48", "đổi lịch đã COMPLETED sang COMPLETED → 400",
             call("PUT", f"/workout-schedules/{sch['id']}", {"scheduledDate": TODAY.isoformat(), "status": "COMPLETED"}, tok),
             400, "VALIDATION_ERROR")
expect_error("C49", "hủy lịch đã COMPLETED → 409 INVALID_STATE",
             call("PUT", f"/workout-schedules/{sch['id']}", {"scheduledDate": TODAY.isoformat(), "status": "CANCELLED"}, tok),
             409, "INVALID_STATE")
expect_error("C50", "lịch ngày đã qua → 400", call("POST", "/workout-schedules", {"workoutDayId": prog["days"][0]["id"],
             "scheduledDate": (TODAY - timedelta(days=1)).isoformat()}, tok), 400, "VALIDATION_ERROR")

# ---- Weight / dashboard / AI
expect_error("C51", "cân ngày tương lai → 400", call("POST", "/weight-logs", {"logDate": (TODAY + timedelta(days=1)).isoformat(),
             "weightKg": 65}, tok), 400, "VALIDATION_ERROR", "logDate")
expect_error("C52", "cân 2 số lẻ → 400", call("POST", "/weight-logs", {"logDate": TODAY.isoformat(), "weightKg": 65.25}, tok),
             400, "VALIDATION_ERROR", "weightKg")
# Lần chạy đầu C53 kỳ vọng "chỉ gửi from → 400" (nhầm với /workout-schedules); docs/05 §4 chỉ quy định from > to.
expect_error("C53", "weight-logs from > to → 400", call("GET", f"/weight-logs?from={TODAY}&to={TODAY - timedelta(days=1)}",
             token=tok), 400, "VALIDATION_ERROR", "from")
expect_error("C54", "dashboard ngày 1999 → 400", call("GET", "/dashboard?date=1999-12-31", token=tok), 400, "VALIDATION_ERROR")
s, db = call("GET", f"/dashboard?date={TODAY}&userId={uuid.uuid4()}", token=tok)
check("C55", "dashboard bỏ qua userId trên query, trả dữ liệu chính chủ", s == 200 and db["nutrition"]["entryCount"] == 1, s)
expect_error("C56", "AI message 2.001 ký tự → 400", call("POST", "/ai/coach/chat", {"clientRequestId": str(uuid.uuid4()),
             "message": "a" * 2001}, tok), 400, "VALIDATION_ERROR")
expect_error("C57", "AI clientRequestId không phải UUID → 400", call("POST", "/ai/coach/chat",
             {"clientRequestId": "abc", "message": "xin chào"}, tok), 400, "VALIDATION_ERROR")
s, cv = call("GET", "/ai/conversations", token=tok)
check("C58", "AI input sai không tạo hội thoại", s == 200 and cv["items"] == [], cv)

ok = sum(1 for _, p in results if p)
print(f"\n{ok}/{len(results)} PASS (ngày {TODAY}, chạy {RUN})")
sys.exit(0 if ok == len(results) else 1)
