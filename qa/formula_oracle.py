"""Đối chiếu công thức sức khỏe (docs/11) bằng một bộ tính độc lập với backend.

Bộ tính ở đây dùng phân số chính xác (fractions.Fraction) và làm tròn HALF_UP ở bước cuối, viết lại từ
docs/11 §3–§4 chứ không dịch từ HealthCalculator.java. Mỗi ca: PUT /health-profile/me trên backend đang
chạy rồi so từng trường của `targets` và `profile.age`.

Chạy (gốc repo): python -I -X utf8 qa/formula_oracle.py [base_url] [số ca ngẫu nhiên] [seed]
Mặc định staging http://127.0.0.1:18080, 300 ca, seed 16. Tạo một tài khoản oracle.<thời điểm>@staging.viegym.vn.
"""
import json
import random
import sys
import urllib.error
import urllib.request
from datetime import date, datetime, timedelta, timezone
from decimal import ROUND_HALF_UP, Decimal
from fractions import Fraction as F

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:18080") + "/api/v1"
N = int(sys.argv[2]) if len(sys.argv) > 2 else 300
SEED = int(sys.argv[3]) if len(sys.argv) > 3 else 16
TODAY = datetime.now(timezone(timedelta(hours=7))).date()

ACTIVITY = {"SEDENTARY": F(12, 10), "LIGHT": F(1375, 1000), "MODERATE": F(155, 100),
            "ACTIVE": F(1725, 1000), "VERY_ACTIVE": F(19, 10)}
DELTA = {"LOSE_WEIGHT": -500, "MAINTAIN": 0, "GAIN_MUSCLE": 300}
PROTEIN_PER_KG = {"LOSE_WEIGHT": F(2), "MAINTAIN": F(16, 10), "GAIN_MUSCLE": F(18, 10)}


def call(method, path, body=None, token=None):
    req = urllib.request.Request(BASE + path, method=method, headers={"Accept": "application/json"})
    data = json.dumps(body).encode() if body is not None else None
    if data:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, data, timeout=20) as r:
            t = r.read().decode()
            return r.status, json.loads(t) if t else None
    except urllib.error.HTTPError as e:
        t = e.read().decode()
        return e.code, json.loads(t) if t else None


def half_up(x: F, places: int) -> Decimal:
    q = Decimal(1).scaleb(-places)
    # Fraction → Decimal chính xác đủ 40 chữ số rồi mới làm tròn (không qua float).
    d = (Decimal(x.numerator) / Decimal(x.denominator)) if x.denominator != 1 else Decimal(x.numerator)
    return d.quantize(q, rounding=ROUND_HALF_UP)


def age_on(dob: date, today: date) -> int:
    years = today.year - dob.year
    # Sinh 29/2: năm không nhuận đủ tuổi từ 1/3 (docs/11 §3).
    if (today.month, today.day) < (dob.month, dob.day):
        years -= 1
    return years


def expected(sex, dob, height, weight, activity, goal):
    age = age_on(dob, TODAY)
    h, w = F(height), F(weight)
    bmi = w / (h / 100) ** 2
    bmr = 10 * w + F(625, 100) * h - 5 * age + (5 if sex == "MALE" else -161)
    tdee = bmr * ACTIVITY[activity]
    target = tdee + DELTA[goal]
    floor = max(bmr, F(1500 if sex == "MALE" else 1200))
    applied = target < floor
    if applied:
        target = floor
    protein = min(PROTEIN_PER_KG[goal] * w, F(35, 100) * target / 4)
    fat = F(25, 100) * target / 9
    carbs = (target - 4 * protein - F(25, 100) * target) / 4
    return age, {"bmi": half_up(bmi, 2), "bmrKcal": half_up(bmr, 1), "tdeeKcal": half_up(tdee, 1),
                 "targetKcal": half_up(target, 1), "proteinG": half_up(protein, 1),
                 "carbsG": half_up(carbs, 1), "fatG": half_up(fat, 1), "kcalFloorApplied": applied}


def dec1(x):
    return Decimal(str(x)).quantize(Decimal("0.1"))


def years_ago(n, extra_days=0):
    try:
        d = TODAY.replace(year=TODAY.year - n)
    except ValueError:  # hôm nay 29/2
        d = TODAY.replace(year=TODAY.year - n, day=28)
    return d - timedelta(days=extra_days)


def cases():
    fixed = [
        ("plan ngày 16", "MALE", years_ago(25), "175", "70", "SEDENTARY", "MAINTAIN"),
        ("demo docs/04 ca 1", "MALE", years_ago(22, 30), "170", "65", "MODERATE", "GAIN_MUSCLE"),
        ("trần protein", "FEMALE", years_ago(80, 10), "100", "300", "SEDENTARY", "LOSE_WEIGHT"),
        ("ngưỡng nữ", "FEMALE", years_ago(80, 10), "150", "40", "SEDENTARY", "LOSE_WEIGHT"),
        ("ngưỡng nam", "MALE", years_ago(30, 10), "160", "50", "SEDENTARY", "LOSE_WEIGHT"),
        ("sinh nhật 18 hôm nay", "FEMALE", years_ago(18), "160", "50", "LIGHT", "MAINTAIN"),
        ("sinh nhật 80 hôm nay", "MALE", years_ago(80), "170", "60", "VERY_ACTIVE", "GAIN_MUSCLE"),
        ("cận trên", "MALE", years_ago(40, 100), "250.0", "300.0", "VERY_ACTIVE", "GAIN_MUSCLE"),
        ("cận dưới", "FEMALE", years_ago(50, 100), "100.0", "30.0", "SEDENTARY", "LOSE_WEIGHT"),
    ]
    yield from fixed
    rnd = random.Random(SEED)
    for i in range(N):
        age = rnd.randint(18, 79)
        yield (f"ngẫu nhiên {i + 1}", rnd.choice(["MALE", "FEMALE"]), years_ago(age, rnd.randint(1, 364)),
               f"{rnd.randint(1000, 2500) / 10:.1f}", f"{rnd.randint(300, 3000) / 10:.1f}",
               rnd.choice(list(ACTIVITY)), rnd.choice(list(DELTA)))


def main():
    email = f"oracle.{datetime.now():%m%d%H%M%S}@staging.viegym.vn"
    call("POST", "/auth/register", {"email": email, "password": "Matkhau123", "fullName": "Oracle"})
    s, login = call("POST", "/auth/login", {"email": email, "password": "Matkhau123"})
    assert s == 200, (s, login)
    token = login["accessToken"]
    total = failed = 0
    for name, sex, dob, h, w, act, goal in cases():
        age, exp = expected(sex, dob, h, w, act, goal)
        s, body = call("PUT", "/health-profile/me", {"sex": sex, "dateOfBirth": dob.isoformat(), "heightCm": float(h),
                                                     "weightKg": float(w), "activityLevel": act, "goal": goal}, token)
        total += 1
        if s != 200:
            failed += 1
            print(f"FAIL {name}: HTTP {s} {body}")
            continue
        t = body["targets"]
        diffs = []
        if body["profile"]["age"] != age:
            diffs.append(f"age {body['profile']['age']} != {age}")
        for k, v in exp.items():
            got = t[k] if k == "kcalFloorApplied" else Decimal(str(t[k])).quantize(v)
            if got != v:
                diffs.append(f"{k} {t[k]} != {v}")
        if t.get("formulaVersion") != "MSJ-v1":
            diffs.append(f"formulaVersion {t.get('formulaVersion')}")
        if diffs:
            failed += 1
            print(f"FAIL {name} ({sex} {dob} {h}cm {w}kg {act} {goal}): " + "; ".join(diffs))
        elif not name.startswith("ngẫu nhiên"):
            print(f"PASS {name}: BMI {t['bmi']}, BMR {t['bmrKcal']}, TDEE {t['tdeeKcal']}, mục tiêu {t['targetKcal']}, "
                  f"P/C/F {t['proteinG']}/{t['carbsG']}/{t['fatG']}, ngưỡng {t['kcalFloorApplied']}")
    print(f"\n{total - failed}/{total} PASS (ngày {TODAY}, seed {SEED}, tài khoản {email})")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
