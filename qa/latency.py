"""Đo latency có kiểm soát (plan ngày 16 §4). KHÔNG phải load test sản xuất.

Chuẩn bị 1 tài khoản có dữ liệu (hồ sơ, 7 ngày thực đơn × 6 mục, 5 buổi tập), warm-up, rồi đo từng endpoint ở
mức đồng thời 1 và 10. In p50/p95/max, tỷ lệ lỗi, throughput. AI không đo ở đây (phụ thuộc provider, có giới hạn
5 câu/phút).
Chạy (gốc repo): python -I -X utf8 qa/latency.py [base_url] [số request mỗi mức]
"""
import json
import statistics
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:18080") + "/api/v1"
N = int(sys.argv[2]) if len(sys.argv) > 2 else 200
TODAY = datetime.now(timezone(timedelta(hours=7))).date()


def call(method, path, body=None, token=None):
    req = urllib.request.Request(BASE + path, method=method, headers={"Accept": "application/json"})
    data = json.dumps(body).encode() if body is not None else None
    if data:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    t0 = time.perf_counter()
    try:
        with urllib.request.urlopen(req, data, timeout=30) as r:
            text = r.read().decode()
            status = r.status
    except urllib.error.HTTPError as e:
        text, status = e.read().decode(), e.code
    return status, (json.loads(text) if text else None), (time.perf_counter() - t0) * 1000


def pct(values, p):
    s = sorted(values)
    return s[min(len(s) - 1, int(round(p / 100 * len(s) + 0.5)) - 1)]


def setup():
    email = f"perf.{datetime.now():%m%d%H%M%S}@staging.viegym.vn"
    call("POST", "/auth/register", {"email": email, "password": "Matkhau123", "fullName": "Perf"})
    tok = call("POST", "/auth/login", {"email": email, "password": "Matkhau123"})[1]["accessToken"]
    call("PUT", "/health-profile/me", {"sex": "MALE", "dateOfBirth": "2000-01-01", "heightCm": 170, "weightKg": 65,
                                       "activityLevel": "MODERATE", "goal": "MAINTAIN"}, tok)
    foods = call("GET", "/foods?size=20", token=tok)[1]["items"]
    for d in range(7):
        for i, meal in enumerate(["BREAKFAST", "LUNCH", "DINNER", "SNACK", "LUNCH", "DINNER"]):
            call("POST", "/meal-plans/entries", {"date": (TODAY - timedelta(days=d)).isoformat(), "mealType": meal,
                                                 "foodId": foods[(d + i) % len(foods)]["id"], "servings": 1}, tok)
    tpl = call("GET", "/workout-programs?scope=templates", token=tok)[1]
    tpl = tpl.get("items", tpl) if isinstance(tpl, dict) else tpl
    prog = call("POST", "/workout-programs", {"templateId": tpl[0]["id"], "activate": True}, tok)[1]
    for k in range(5):
        day = prog["days"][k % len(prog["days"])]
        sch = call("POST", "/workout-schedules", {"workoutDayId": day["id"], "scheduledDate": TODAY.isoformat()}, tok)[1]
        if "id" not in sch:
            break
        exs = call("GET", f"/workout-schedules/{sch['id']}", token=tok)[1]["exercises"]
        call("POST", "/workout-logs", {"scheduleId": sch["id"], "exercises": [
            {"exerciseId": e["exerciseId"], "sets": [{"reps": 10, "weightKg": 20}] * 3} for e in exs]}, tok)
    return email, tok, foods[0]["id"]


def run(name, fn, concurrency, n):
    for _ in range(10):  # warm-up
        fn()
    t0 = time.perf_counter()
    with ThreadPoolExecutor(concurrency) as pool:
        out = list(pool.map(lambda _: fn(), range(n)))
    wall = time.perf_counter() - t0
    lat = [ms for _, ms in out]
    errors = sum(1 for ok, _ in out if not ok)
    print(f"| {name} | {concurrency} | {n} | {statistics.median(lat):.0f} | {pct(lat, 95):.0f} | {max(lat):.0f} | "
          f"{errors / n:.1%} | {n / wall:.0f} |")


def main():
    email, tok, food_id = setup()
    def ok(expected):
        return lambda r: (r[0] == expected, r[2])
    endpoints = [
        ("POST /auth/login (BCrypt)", lambda: ok(200)(call("POST", "/auth/login", {"email": email, "password": "Matkhau123"}))),
        ("GET /foods?keyword=com", lambda: ok(200)(call("GET", "/foods?keyword=com&size=20", token=tok))),
        ("GET /dashboard", lambda: ok(200)(call("GET", f"/dashboard?date={TODAY}", token=tok))),
        ("GET /workout-logs", lambda: ok(200)(call("GET", "/workout-logs?size=20", token=tok))),
        ("GET /meal-plans", lambda: ok(200)(call("GET", f"/meal-plans?date={TODAY}", token=tok))),
        ("POST /weight-logs (ghi, upsert)", lambda: ok(200)(call("POST", "/weight-logs",
                                                                 {"logDate": TODAY.isoformat(), "weightKg": 65}, tok))),
    ]
    print(f"Dữ liệu: 1 user, 42 mục thực đơn/7 ngày, 5 buổi tập; {N} request mỗi dòng, warm-up 10.\n")
    print("| Endpoint | Đồng thời | Request | p50 ms | p95 ms | max ms | Lỗi | req/s |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|")
    call("POST", "/weight-logs", {"logDate": TODAY.isoformat(), "weightKg": 65}, tok)
    for name, fn in endpoints:
        for c in (1, 10):
            run(name, fn, c, N if "login" not in name else N // 4)


if __name__ == "__main__":
    main()
