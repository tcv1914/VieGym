"""Tra lỗ hổng đã biết cho dependency Maven (backend) và Pub (mobile) qua OSV (api.osv.dev).

Chỉ gửi tên gói + phiên bản (thông tin công khai), không gửi mã nguồn hay dữ liệu dự án.
Chạy (gốc repo):
  backend> .\\mvnw.cmd -q dependency:list -DoutputFile=<file>
  python -I -X utf8 qa/osv_scan.py <file dependency:list> mobile/pubspec.lock
"""
import json
import re
import sys
import urllib.request


def maven(path):
    out = []
    for line in open(path, encoding="utf-8"):
        m = re.match(r"\s*([\w.\-]+):([\w.\-]+):jar:([\w.\-]+):(\w+)", line)
        if m:
            out.append(("Maven", f"{m[1]}:{m[2]}", m[3], m[4]))
    return out


def pub(path):
    out, name, dev = [], None, None
    for line in open(path, encoding="utf-8"):
        if re.match(r"^  [a-z0-9_]+:$", line):
            name = line.strip()[:-1]
        elif name and line.strip().startswith("dependency:"):
            dev = line.split(":", 1)[1].strip().strip('"')
        elif name and line.strip().startswith("version:"):
            out.append(("Pub", name, line.split(":", 1)[1].strip().strip('"'), dev))
            name = None
    return out


def query(pkgs):
    body = {"queries": [{"package": {"ecosystem": eco, "name": n}, "version": v} for eco, n, v, _ in pkgs]}
    req = urllib.request.Request("https://api.osv.dev/v1/querybatch", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "dependency-audit"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())["results"]


def detail(vid):
    with urllib.request.urlopen(f"https://api.osv.dev/v1/vulns/{vid}", timeout=30) as r:
        v = json.loads(r.read())
    fixed = sorted({e["fixed"] for a in v.get("affected", []) for rg in a.get("ranges", [])
                    for e in rg.get("events", []) if "fixed" in e})
    sev = (v.get("database_specific") or {}).get("severity", "?")
    return sev, v.get("summary", "")[:110], fixed


def main():
    pkgs = maven(sys.argv[1]) + pub(sys.argv[2])
    print(f"{len(pkgs)} gói ({sum(p[0] == 'Maven' for p in pkgs)} Maven, {sum(p[0] == 'Pub' for p in pkgs)} Pub)\n")
    found = 0
    for (eco, name, ver, scope), res in zip(pkgs, query(pkgs)):
        for v in res.get("vulns", []):
            found += 1
            sev, summary, fixed = detail(v["id"])
            print(f"| {eco} | {name} {ver} ({scope}) | {v['id']} | {sev} | {summary} | {', '.join(fixed[-3:])} |")
    print(f"\n{found} lỗ hổng đã biết")


if __name__ == "__main__":
    main()
