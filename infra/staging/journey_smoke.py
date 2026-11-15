"""Hành trình 7 bước (plan ngày 15 §1) chạy bằng API trên STAGING. In PASS/FAIL từng kiểm tra.
Chạy (từ gốc repo): python -I -X utf8 infra/staging/journey_smoke.py [base_url]
Tài khoản admin đọc từ ADMIN_EMAIL/ADMIN_PASSWORD trong infra/staging/.env (không ghi trong file này).
Mỗi lần chạy tạo 2 tài khoản smoke.a/b.<thời điểm>@staging.viegym.vn; món/bài bị ẩn ở bước 6 được hiện lại.
"""
import json
import sys
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:18080") + "/api/v1"
ENV = dict(line.split("=", 1) for line in (Path(__file__).parent / ".env").read_text(encoding="utf-8").splitlines()
           if "=" in line and not line.startswith("#"))
ADMIN_EMAIL = ENV["ADMIN_EMAIL"]
ADMIN_PASSWORD = ENV["ADMIN_PASSWORD"]
VN = timezone(timedelta(hours=7))
TODAY = datetime.now(VN).date().isoformat()
RUN = datetime.now().strftime("%m%d%H%M%S")

results = []


def call(method, path, body=None, token=None):
    req = urllib.request.Request(BASE + path, method=method)
    req.add_header("Accept", "application/json")
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, data, timeout=40) as r:
            text = r.read().decode()
            return r.status, (json.loads(text) if text else None)
    except urllib.error.HTTPError as e:
        text = e.read().decode()
        return e.code, (json.loads(text) if text else None)


def check(name, cond, detail=""):
    results.append((name, bool(cond)))
    print(("PASS " if cond else "FAIL ") + name + (f"  [{detail}]" if detail and not cond else ""))


def food_body(d, active):
    b = dict(d)
    b["categoryCode"] = d["category"]["code"]
    b["region"] = d["region"]["code"] if d.get("region") else None
    b["active"] = active
    return b


def login(email, password):
    s, b = call("POST", "/auth/login", {"email": email, "password": password})
    return s, b


# 1. Đăng ký → đăng nhập → hồ sơ → mục tiêu
email_a = f"smoke.a.{RUN}@staging.viegym.vn"
email_b = f"smoke.b.{RUN}@staging.viegym.vn"
pw = "Matkhau123"
s, _ = call("POST", "/auth/register", {"email": email_a, "password": pw, "fullName": "Người thử A"})
check("1.1 đăng ký A → 201", s == 201, s)
s, la = login(email_a, pw)
check("1.2 đăng nhập A → 200, chưa có hồ sơ", s == 200 and la["user"]["hasHealthProfile"] is False, s)
ta = la["accessToken"]
s, hp = call("PUT", "/health-profile/me", {"sex": "MALE", "dateOfBirth": "2003-05-10", "heightCm": 170,
                                           "weightKg": 65, "activityLevel": "MODERATE", "goal": "GAIN_MUSCLE"}, ta)
check("1.3 lưu hồ sơ → 200", s == 200, s)
s, hp = call("GET", "/health-profile/me", token=ta)
tk = (hp or {}).get("targets") or {}
check("1.4 có mục tiêu kcal/macro", s == 200 and (tk.get("targetKcal") or tk.get("kcal")), json.dumps(hp)[:300])

# 2. Giáo án → lịch → ghi buổi → lịch sử
s, tpl = call("GET", "/workout-programs?scope=templates", token=ta)
tpl_items = tpl.get("items", tpl) if isinstance(tpl, dict) else tpl
check("2.1 có giáo án mẫu", s == 200 and len(tpl_items) > 0, s)
s, prog = call("POST", "/workout-programs", {"templateId": tpl_items[0]["id"], "activate": True}, ta)
check("2.2 tạo giáo án từ mẫu → 201", s == 201, s)
day = prog["days"][0]
s, sch = call("POST", "/workout-schedules", {"workoutDayId": day["id"], "scheduledDate": TODAY,
                                             "startTime": None, "note": None}, ta)
check("2.3 tạo lịch hôm nay → 201", s == 201, f"{s} {sch}")
s, schd = call("GET", f"/workout-schedules/{sch['id']}", token=ta)
ex_ids = [e["exerciseId"] for e in schd["exercises"]]
check("2.4 mở buổi tập có bài", s == 200 and len(ex_ids) > 0, s)
log_body = {"scheduleId": sch["id"], "note": "smoke", "exercises": [
    {"exerciseId": x, "sets": [{"reps": 10, "weightKg": 20}, {"reps": 8, "weightKg": 22.5}]} for x in ex_ids]}
s, log = call("POST", "/workout-logs", log_body, ta)
check("2.5 ghi kết quả → 201", s == 201, f"{s} {log}")
s, dup = call("POST", "/workout-logs", log_body, ta)
check("2.6 gửi lặp → 409 WORKOUT_ALREADY_LOGGED cùng id",
      s == 409 and dup.get("code") == "WORKOUT_ALREADY_LOGGED" and dup.get("workoutLogId") == log["id"], f"{s} {dup}")
s, hist = call("GET", "/workout-logs", token=ta)
check("2.7 lịch sử có 1 buổi", s == 200 and len(hist["items"]) == 1, s)

# 3. Món → khẩu phần → bữa → tổng
s, foods = call("GET", "/foods?keyword=pho&size=5", token=ta)
check("3.1 tìm 'pho' (không dấu) có kết quả", s == 200 and len(foods["items"]) > 0, s)
food = foods["items"][0]
s, mp = call("POST", "/meal-plans/entries", {"date": TODAY, "mealType": "LUNCH", "foodId": food["id"],
                                             "servings": 1.5}, ta)
exp_kcal = round(float(food["kcalPerServing"]) * 1.5, 2)
check("3.2 thêm 1,5 phần → tổng = 1,5 × kcal", s == 201 and abs(mp["totals"]["kcal"] - exp_kcal) < 0.01,
      f"{s} {mp and mp.get('totals')} vs {exp_kcal}")
check("3.3 thực đơn có targets/remaining", mp["targets"] is not None and mp["remaining"] is not None)

# 4. Dashboard → chatbot
s, db = call("GET", f"/dashboard?date={TODAY}", token=ta)
check("4.1 dashboard tổng kcal khớp thực đơn", s == 200 and abs(db["nutrition"]["totals"]["kcal"] - exp_kcal) < 0.01, s)
today_items = db["training"]["today"] if s == 200 else []
check("4.2 dashboard: buổi hôm nay COMPLETED, tuần completed=1",
      any(t["status"] == "COMPLETED" for t in today_items) and db["training"]["week"]["completed"] == 1, today_items)
crid = str(uuid.uuid4())
q = "Hôm nay tôi đã ăn món gì vào bữa trưa và còn thiếu bao nhiêu kcal so với mục tiêu?"
t0 = time.time()
s, chat = call("POST", "/ai/coach/chat", {"clientRequestId": crid, "conversationId": None, "message": q}, ta)
answer = (chat or {}).get("assistantMessage", {}).get("content", "") if s == 200 else ""
check(f"4.3 chatbot trả lời ({time.time() - t0:.1f}s)", s == 200 and chat["status"] == "SUCCEEDED", f"{s} {chat}")
print("     câu trả lời:", answer[:400].replace("\n", " "))
check("4.4 câu trả lời nhắc tới món trong thực đơn", food["name"].split()[0].lower() in answer.lower(), food["name"])
s, chat2 = call("POST", "/ai/coach/chat", {"clientRequestId": crid, "conversationId": None, "message": q}, ta)
check("4.5 gửi lặp cùng clientRequestId → 200 cùng requestId (không gọi AI lần 2)",
      s == 200 and chat2.get("requestId") == chat.get("requestId"), s)

# 5. Cân nặng
s, wl = call("POST", "/weight-logs", {"logDate": TODAY, "weightKg": 64.6, "note": None}, ta)
check("5.1 ghi cân → 201", s == 201, f"{s} {wl}")
s, db2 = call("GET", f"/dashboard?date={TODAY}", token=ta)
lw = db2["health"]["latestWeightLog"]
check("5.2 dashboard latestWeightLog = 64,6; hồ sơ vẫn 65 (BR-H02)",
      lw and float(lw["weightKg"]) == 64.6 and float(db2["health"]["weightKg"]) == 65.0, db2["health"])
s, wls = call("GET", f"/weight-logs?from={TODAY}&to={TODAY}", token=ta)
check("5.3 danh sách cân (dữ liệu biểu đồ) có bản ghi", s == 200 and len(wls.get("items", [])) == 1, f"{s} {wls}")

# 6. Admin ẩn món + bài → thư viện, lịch sử của user
s, ad = login(ADMIN_EMAIL, ADMIN_PASSWORD)
check("6.1 admin đăng nhập", s == 200 and ad["user"]["role"] == "ADMIN", s)
tad = ad["accessToken"]
s, fa = call("GET", f"/admin/foods/{food['id']}", token=tad)
s, fa2 = call("PUT", f"/admin/foods/{food['id']}", food_body(fa, False), tad)
check("6.2 admin ẩn món → 200", s == 200 and fa2["active"] is False, f"{s} {fa2}")
s, _ = call("GET", f"/foods/{food['id']}", token=ta)
check("6.3 user mở món đã ẩn → 404", s == 404, s)
s, foods2 = call("GET", f"/foods?keyword={food['code']}", token=ta)
s2, mp2 = call("GET", f"/meal-plans?date={TODAY}", token=ta)
check("6.4 thực đơn cũ vẫn giữ mục + tổng (snapshot)", s2 == 200 and abs(mp2["totals"]["kcal"] - exp_kcal) < 0.01, s2)
s, _ = call("POST", "/meal-plans/entries", {"date": TODAY, "mealType": "DINNER", "foodId": food["id"], "servings": 1}, ta)
check("6.5 thêm món đã ẩn → 422 FOOD_INACTIVE", s == 422, s)
ex_id = ex_ids[0]
s, ea = call("GET", f"/admin/exercises/{ex_id}", token=tad)
ex_name = ea["name"]
body = dict(ea); body["active"] = False
s, ea2 = call("PUT", f"/admin/exercises/{ex_id}", body, tad)
check("6.6 admin ẩn bài → 200", s == 200, f"{s} {ea2}")
s, _ = call("GET", f"/exercises/{ex_id}", token=ta)
check("6.7 thư viện: bài đã ẩn → 404", s == 404, s)
s, ld = call("GET", f"/workout-logs/{log['id']}", token=ta)
names = json.dumps(ld, ensure_ascii=False)
check("6.8 lịch sử buổi tập vẫn hiện tên bài đã ẩn", s == 200 and ex_name in names, s)
# trả lại trạng thái cho catalog staging
s, fa3 = call("GET", f"/admin/foods/{food['id']}", token=tad)
s1, _ = call("PUT", f"/admin/foods/{food['id']}", food_body(fa3, True), tad)
s, ea3 = call("GET", f"/admin/exercises/{ex_id}", token=tad); ea3["active"] = True
s2, _ = call("PUT", f"/admin/exercises/{ex_id}", ea3, tad)
check("6.9 hiện lại món + bài", s1 == 200 and s2 == 200, (s1, s2))

# 7. Đăng xuất A → B không thấy dữ liệu A
s, _ = call("POST", "/auth/logout", {"refreshToken": la["refreshToken"]})
check("7.1 đăng xuất A", s in (200, 204), s)
s, _ = call("POST", "/auth/refresh", {"refreshToken": la["refreshToken"]})
check("7.2 refresh token A sau đăng xuất → 401", s == 401, s)
s, _ = call("GET", "/users/me", token=ta)
print(f"     (thông tin) access token A sau đăng xuất: GET /users/me → {s}")
call("POST", "/auth/register", {"email": email_b, "password": pw, "fullName": "Người thử B"})
s, lb = login(email_b, pw)
tb = lb["accessToken"]
check("7.3 đăng nhập B", s == 200 and lb["user"]["email"] == email_b, s)
s, mb = call("GET", f"/meal-plans?date={TODAY}", token=tb)
check("7.4 B: thực đơn hôm nay rỗng", s == 200 and mb["entryCount"] == 0, s)
s, dbb = call("GET", f"/dashboard?date={TODAY}", token=tb)
check("7.5 B: dashboard không có dữ liệu A",
      s == 200 and dbb["health"]["hasProfile"] is False and dbb["training"]["today"] == [] and dbb["nutrition"]["entryCount"] == 0, s)
s, _ = call("GET", f"/workout-logs/{log['id']}", token=tb)
check("7.6 B mở log của A → 404", s == 404, s)
s, _ = call("GET", f"/ai/conversations/{chat['conversation']['id']}/messages", token=tb)
check("7.7 B mở hội thoại của A → 404", s == 404, s)
s, hb = call("GET", "/workout-logs", token=tb)
check("7.8 B: lịch sử rỗng", s == 200 and hb["items"] == [], s)

ok = sum(1 for _, p in results if p)
print(f"\n{ok}/{len(results)} PASS  (tài khoản: {email_a}, {email_b}; ngày {TODAY})")
sys.exit(0 if ok == len(results) else 1)
