"""Ma trận truy cập (plan ngày 17 §1) trên STAGING: chưa login / B (chủ) / A (người khác) / ADMIN với mọi tài nguyên
cá nhân của B, cả đọc lẫn ghi. Kiểm tra thêm: lỗi của A với ID của B giống hệt lỗi với một UUID ngẫu nhiên
(không lộ sự tồn tại), và dữ liệu B không đổi sau các lần A/ADMIN thử ghi.
Chạy (gốc repo): python -I -X utf8 qa/access_matrix.py [base_url]   (ADMIN_* đọc từ infra/staging/.env)
"""
import json
import sys
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:18080") + "/api/v1"
ENV = dict(line.split("=", 1) for line in
           (Path(__file__).resolve().parent.parent / "infra/staging/.env").read_text(encoding="utf-8").splitlines()
           if "=" in line and not line.startswith("#"))
TODAY = datetime.now(timezone(timedelta(hours=7))).date().isoformat()
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
        with urllib.request.urlopen(req, data, timeout=40) as r:
            t = r.read().decode()
            return r.status, json.loads(t) if t else None
    except urllib.error.HTTPError as e:
        t = e.read().decode()
        return e.code, json.loads(t) if t else None


def check(cid, name, cond, detail=""):
    results.append((cid, bool(cond)))
    print(f"{'PASS' if cond else 'FAIL'} {cid} {name}" + (f"  [{detail}]" if not cond else ""))


def user(prefix):
    email = f"{prefix}.{RUN}@staging.viegym.vn"
    call("POST", "/auth/register", {"email": email, "password": "Matkhau123", "fullName": prefix.upper()})
    return call("POST", "/auth/login", {"email": email, "password": "Matkhau123"})[1]


def strip(b):
    """Bỏ các trường thay đổi theo request để so hai body lỗi."""
    return {k: v for k, v in (b or {}).items() if k not in ("timestamp", "path")}


A, B = user("acl-a"), user("acl-b")
ta, tb = A["accessToken"], B["accessToken"]
tad = call("POST", "/auth/login", {"email": ENV["ADMIN_EMAIL"], "password": ENV["ADMIN_PASSWORD"]})[1]["accessToken"]

# ---- Dữ liệu của B
call("PUT", "/health-profile/me", {"sex": "FEMALE", "dateOfBirth": "1995-03-03", "heightCm": 158, "weightKg": 52,
                                   "activityLevel": "LIGHT", "goal": "LOSE_WEIGHT"}, tb)
tpl = call("GET", "/workout-programs?scope=templates", token=tb)[1]
tpl = tpl.get("items", tpl) if isinstance(tpl, dict) else tpl
ex_id = call("GET", "/exercises?size=1", token=tb)[1]["items"][0]["id"]
prog = call("POST", "/workout-programs", {"name": "Giáo án riêng của B", "description": "bí mật B", "activate": True,
                                          "days": [{"name": "Ngày B", "exercises": [{"exerciseId": ex_id, "targetSets": 3,
                                                                                     "targetReps": 10, "restSeconds": 60}]}]}, tb)[1]
day_id = prog["days"][0]["id"]
sch = call("POST", "/workout-schedules", {"workoutDayId": day_id, "scheduledDate": TODAY}, tb)[1]
sch2 = call("POST", "/workout-schedules", {"workoutDayId": day_id, "scheduledDate": TODAY}, tb)[1]
log = call("POST", "/workout-logs", {"scheduleId": sch["id"], "note": "log B",
                                     "exercises": [{"exerciseId": ex_id, "sets": [{"reps": 8, "weightKg": 15}]}]}, tb)[1]
food = call("GET", "/foods?size=1", token=tb)[1]["items"][0]
meal = call("POST", "/meal-plans/entries", {"date": TODAY, "mealType": "DINNER", "foodId": food["id"], "servings": 2}, tb)[1]
entry_id = meal["meals"]["DINNER"][0]["id"]
wl = call("POST", "/weight-logs", {"logDate": TODAY, "weightKg": 51.5, "note": "cân B"}, tb)[1]
crid = str(uuid.uuid4())
chat = call("POST", "/ai/coach/chat", {"clientRequestId": crid, "message": "Mục tiêu calo của tôi là bao nhiêu?"}, tb)[1]
conv_id = chat["conversation"]["id"]

R = str(uuid.uuid4())  # ID không tồn tại, để so lỗi
put_prog = {"name": "A sửa", "description": None, "activate": True, "version": prog.get("version", 0),
            "days": [{"name": "x", "exercises": [{"exerciseId": ex_id, "targetSets": 1, "targetReps": 1, "restSeconds": 0}]}]}
ops = [
    # (id ca, mô tả, method, path theo id, body, status khi B làm, path ngẫu nhiên)
    ("M01", "xem giáo án", "GET", f"/workout-programs/{prog['id']}", None, 200),
    ("M02", "sửa giáo án", "PUT", f"/workout-programs/{prog['id']}", put_prog, 200),
    ("M03", "kích hoạt giáo án", "POST", f"/workout-programs/{prog['id']}/activate", None, 200),
    ("M04", "sao chép giáo án riêng như template", "POST", "/workout-programs", {"templateId": prog["id"], "activate": False}, None),
    ("M05", "xếp lịch từ buổi (dayId) của B", "POST", "/workout-schedules", {"workoutDayId": day_id, "scheduledDate": TODAY}, 201),
    ("M06", "xem lịch", "GET", f"/workout-schedules/{sch['id']}", None, 200),
    ("M07", "đổi/hủy lịch", "PUT", f"/workout-schedules/{sch2['id']}", {"scheduledDate": TODAY, "status": "CANCELLED"}, 200),
    ("M08", "ghi log vào lịch của B", "POST", "/workout-logs", {"scheduleId": sch2["id"], "exercises": [
        {"exerciseId": ex_id, "sets": [{"reps": 1, "weightKg": 1}]}]}, None),
    ("M09", "xem log", "GET", f"/workout-logs/{log['id']}", None, 200),
    ("M10", "sửa mục thực đơn", "PUT", f"/meal-plans/entries/{entry_id}", {"servings": 9}, 200),
    ("M11", "xóa mục thực đơn", "DELETE", f"/meal-plans/entries/{entry_id}", None, None),
    ("M12", "xóa cân nặng", "DELETE", f"/weight-logs/{wl['id']}", None, None),
    ("M13", "đọc tin nhắn hội thoại", "GET", f"/ai/conversations/{conv_id}/messages", None, 200),
    ("M14", "gửi câu hỏi vào hội thoại của B", "POST", "/ai/coach/chat",
     {"clientRequestId": str(uuid.uuid4()), "conversationId": conv_id, "message": "Tôi vừa hỏi gì?"}, None),
]


def random_path(path):
    for real in (prog["id"], sch["id"], sch2["id"], log["id"], entry_id, wl["id"], conv_id):
        path = path.replace(real, R)
    return path


def random_body(body):
    if body is None:
        return None
    text = json.dumps(body)
    for real in (prog["id"], day_id, sch2["id"], conv_id):
        text = text.replace(real, R)
    return json.loads(text)


def snapshot_b():
    return {
        "prog": call("GET", f"/workout-programs/{prog['id']}", token=tb)[1],
        "sch2": call("GET", f"/workout-schedules/{sch2['id']}", token=tb)[1]["status"],
        "meal": call("GET", f"/meal-plans?date={TODAY}", token=tb)[1]["totals"],
        "weight": call("GET", f"/weight-logs?from={TODAY}&to={TODAY}", token=tb)[1]["items"],
        "msgs": len(call("GET", f"/ai/conversations/{conv_id}/messages", token=tb)[1]["items"]),
        "logs": len(call("GET", "/workout-logs", token=tb)[1]["items"]),
        "schedules": len(call("GET", f"/workout-schedules?from={TODAY}&to={TODAY}", token=tb)[1]["items"]),
    }


before = snapshot_b()
for cid, name, method, path, body, _ in ops:
    s0, b0 = call(method, path, body)
    check(f"{cid}.0", f"chưa login: {name} → 401", s0 == 401 and b0.get("code") == "UNAUTHORIZED", (s0, b0))
    for role, tok in (("A", ta), ("ADMIN", tad)):
        s, b = call(method, path, body, tok)
        sr, br = call(method, random_path(path), random_body(body), tok)
        # Ca đặc biệt: M04 — template không phải của user → 404 như template không tồn tại.
        check(f"{cid}.{role}", f"{role}: {name} → 404, giống hệt ID không tồn tại",
              s == 404 and s == sr and strip(b) == strip(br), (s, b, sr, br))
after = snapshot_b()
check("M15", "dữ liệu B không đổi sau mọi lần A/ADMIN thử ghi", before == after,
      {k: (before[k], after[k]) for k in before if before[k] != after[k]})

# B (chủ) vẫn làm được các thao tác đọc
for cid, name, method, path, body, ok in ops:
    if method == "GET":
        s, _ = call(method, path, None, tb)
        check(f"{cid}.B", f"B: {name} → {ok}", s == ok, s)

# ---- Chat: dùng lại clientRequestId của B
s, b = call("POST", "/ai/coach/chat", {"clientRequestId": crid, "message": "Mục tiêu calo của tôi là bao nhiêu?"}, ta)
check("M16", "A dùng lại clientRequestId của B: không nhận câu trả lời/hội thoại của B",
      not (isinstance(b, dict) and (b.get("requestId") == chat["requestId"] or
                                    (b.get("conversation") or {}).get("id") == conv_id)), (s, b and b.get("requestId")))
# ---- Danh sách: không lẫn dữ liệu B
lists = {
    "workout-programs?scope=mine": lambda b: all(p["id"] != prog["id"] for p in (b.get("items", b) if isinstance(b, dict) else b)),
    f"workout-schedules?from={TODAY}&to={TODAY}": lambda b: all(x["id"] not in (sch["id"], sch2["id"]) for x in b["items"]),
    "workout-logs": lambda b: all(x["id"] != log["id"] for x in b["items"]),
    f"meal-plans?date={TODAY}": lambda b: b["entryCount"] == 0,
    f"weight-logs?from={TODAY}&to={TODAY}": lambda b: b["items"] == [],
    "ai/conversations": lambda b: all(c["id"] != conv_id for c in b["items"]),
    f"dashboard?date={TODAY}": lambda b: b["nutrition"]["entryCount"] == 0 and b["training"]["today"] == [],
}
for i, (path, ok) in enumerate(lists.items(), 1):
    for role, tok in (("A", ta), ("ADMIN", tad)):
        s, b = call("GET", "/" + path, token=tok)
        check(f"L{i:02d}.{role}", f"{role}: danh sách /{path.split('?')[0]} không có dữ liệu B", s == 200 and ok(b), s)
s, hp = call("GET", "/health-profile/me", token=ta)
check("L08", "A: /health-profile/me không trả hồ sơ B", s == 404, s)

# ---- Admin không có đường đọc dữ liệu cá nhân (BR-AD02)
s, users = call("GET", "/admin/users?keyword=" + B["user"]["email"], token=tad)
row = users["items"][0] if s == 200 and users["items"] else {}
check("D01", "admin users chỉ có id/email/fullName/role/status/createdAt",
      set(row) <= {"id", "email", "fullName", "role", "status", "createdAt"} and row, row)
for path in (f"/admin/users/{B['user']['id']}", f"/admin/users/{B['user']['id']}/health-profile",
             f"/admin/users/{B['user']['id']}/meal-plans", f"/admin/users/{B['user']['id']}/conversations",
             f"/health-profile/{B['user']['id']}", f"/users/{B['user']['id']}"):
    s, b = call("GET", path, token=tad)
    check("D02", f"admin GET {path.replace(B['user']['id'], '{B}')} → không có dữ liệu B", s in (404, 405) and "weightKg" not in json.dumps(b or {}), (s, b))
# ---- USER tự nâng quyền
s, b = call("PUT", f"/admin/users/{A['user']['id']}/status", {"status": "ACTIVE", "reason": "x"}, ta)
check("D03", "USER gọi PUT admin → 403", s == 403, s)
s, me = call("GET", "/users/me", token=ta)
check("D04", "role A vẫn USER", me["role"] == "USER", me)

ok = sum(1 for _, p in results if p)
print(f"\n{ok}/{len(results)} PASS (chạy {RUN})")
sys.exit(0 if ok == len(results) else 1)
