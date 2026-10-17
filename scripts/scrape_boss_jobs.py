"""Boss.az-dan Bakı üzrə real, aktiv vakansiyaları çəkib Supabase 'jobs' cədvəlinə yazır.

Yalnız bu şərtləri ödəyən elanlar əlavə olunur (heç bir məlumat uydurulmur):
  * Boss.az-da bu gün (və ya --max-age-days daxilində) dərc olunub;
  * əlaqə nömrəsi mövcuddur;
  * ünvan Nominatim ilə Bakı daxilində real koordinata çevrilib.

İstifadə:
  pip install requests beautifulsoup4
  $env:SUPABASE_URL = "https://<project>.supabase.co"
  $env:SUPABASE_SERVICE_ROLE_KEY = "<service role key>"   # repoya yazmayın
  python scripts/scrape_boss_jobs.py --limit 50 --dry-run
  python scripts/scrape_boss_jobs.py --limit 50
"""

import argparse
import json
import os
import re
import sys
import time
from datetime import datetime, timedelta, timezone

import requests
from bs4 import BeautifulSoup

BASE = "https://boss.az"
BAKU_TZ = timezone(timedelta(hours=4))
UA = "WorkSpotJobImporter/1.0 (contact: admin@workspot.az)"
# Bakı və ətraf qəsəbələrin təxmini sərhədi (lon_min, lat_max, lon_max, lat_min)
BAKU_VIEWBOX = (49.55, 40.65, 50.25, 40.20)
STOP_MARKERS = ("Kopyala", "Reklam et", "Vakansiyaya müraciət et", "Oxşar elanlar", "Şikayət et")

session = requests.Session()
session.headers.update({"User-Agent": UA, "Accept-Language": "az,en;q=0.8"})


def get(url, **kwargs):
    for attempt in range(3):
        try:
            resp = session.get(url, timeout=30, **kwargs)
            if resp.status_code == 200:
                return resp
            if resp.status_code in (429, 503):
                time.sleep(5 * (attempt + 1))
                continue
            return None
        except requests.RequestException:
            time.sleep(2)
    return None


def list_vacancy_ids(max_pages):
    seen = []
    for page in range(1, max_pages + 1):
        resp = get(f"{BASE}/search/vacancies", params={"sortBy": "DATE", "regionIds": 1, "page": page})
        if not resp:
            break
        ids = re.findall(r'href="/vacancies/(\d+)"', resp.text)
        new = [i for i in dict.fromkeys(ids) if i not in seen]
        if not new:
            break
        seen.extend(new)
        time.sleep(1)
    return seen


def parse_vacancy(vac_id):
    url = f"{BASE}/vacancies/{vac_id}"
    resp = get(url)
    if not resp:
        return None
    soup = BeautifulSoup(resp.text, "html.parser")

    posting = None
    breadcrumbs = []
    for tag in soup.find_all("script", type="application/ld+json"):
        try:
            data = json.loads(tag.string or "")
        except json.JSONDecodeError:
            continue
        if data.get("@type") == "JobPosting":
            posting = data
        elif data.get("@type") == "BreadcrumbList":
            breadcrumbs = [i["name"] for i in data.get("itemListElement", [])]
    if not posting:
        return None

    posted = datetime.fromisoformat(posting["datePosted"]).astimezone(BAKU_TZ)

    phones = []
    for a in soup.select('a[href^="tel:"]'):
        number = a["href"][4:].strip()
        if number and number not in phones:
            phones.append(number)

    for tag in soup(["script", "style"]):
        tag.decompose()
    lines = [l.strip() for l in soup.get_text("\n").split("\n") if l.strip()]

    description = ""
    if "İş barədə məlumat" in lines:
        start = lines.index("İş barədə məlumat") + 1
        end = len(lines)
        for idx in range(start, len(lines)):
            if lines[idx] in STOP_MARKERS:
                end = idx
                break
        description = "\n".join(lines[start:end]).strip()

    address = None
    for line in lines:
        m = re.match(r"İş yeri\s*:\s*(.+)", line)
        if m:
            address = m.group(1).strip()
            break

    salary_val = (posting.get("baseSalary") or {}).get("value") or {}
    values = [v for v in (salary_val.get("minValue"), salary_val.get("maxValue"))
              if isinstance(v, (int, float)) and v > 0]
    salary = round(sum(values) / len(values)) if values else None

    categories = breadcrumbs[2:-2] if len(breadcrumbs) > 4 else []
    return {
        "id": vac_id,
        "url": url,
        "title": (posting.get("title") or "").strip(),
        "company": ((posting.get("hiringOrganization") or {}).get("name") or "").strip(),
        "description": description,
        "salary": salary,
        "phones": phones,
        "address": address,
        "category": categories[0] if categories else "Digər",
        "posted": posted,
    }


def geocode(address):
    # "Azərbaycan/Baki/Nəsimi rayonu/Azadlıq pr. 140" -> "Azadlıq pr. 140, Nəsimi, Bakı"
    parts = [p.strip() for p in re.split(r"[/,]", address) if p.strip()]
    parts = [p for p in parts if p.lower() not in ("azərbaycan", "baki", "bakı")]
    if not parts:
        return None
    parts = [re.sub(r"\s*(rayonu|ray\.)$", "", p, flags=re.I) for p in parts]
    query = ", ".join(reversed(parts)) + ", Bakı, Azərbaycan"
    lon_min, lat_max, lon_max, lat_min = BAKU_VIEWBOX
    try:
        resp = requests.get(
            "https://nominatim.openstreetmap.org/search",
            params={
                "q": query,
                "format": "jsonv2",
                "limit": 1,
                "countrycodes": "az",
                "viewbox": f"{lon_min},{lat_max},{lon_max},{lat_min}",
                "bounded": 1,
            },
            headers={"User-Agent": UA},
            timeout=30,
        )
        results = resp.json() if resp.status_code == 200 else []
    except (requests.RequestException, ValueError):
        results = []
    time.sleep(1.1)  # Nominatim siyasəti: saniyədə maksimum 1 sorğu
    if not results:
        return None
    lat, lng = float(results[0]["lat"]), float(results[0]["lon"])
    if not (lat_min <= lat <= lat_max and lon_min <= lng <= lon_max):
        return None
    return lat, lng


class Supabase:
    def __init__(self, url, key):
        self.endpoint = f"{url.rstrip('/')}/rest/v1/jobs"
        self.headers = {
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal",
        }

    def exists(self, source_url):
        resp = requests.get(
            self.endpoint,
            headers=self.headers,
            params={"select": "id", "description": f"like.*{source_url}*", "limit": 1},
            timeout=30,
        )
        resp.raise_for_status()
        return bool(resp.json())

    def insert(self, row):
        payload = dict(row)
        for _ in range(8):
            resp = requests.post(self.endpoint, headers=self.headers, json=payload, timeout=30)
            if resp.status_code < 300:
                return True
            m = re.search(r"Could not find the '([^']+)' column", resp.text)
            if m and m.group(1) in payload:
                print(f"  ! 'jobs' cədvəlində '{m.group(1)}' sütunu yoxdur, çıxarıldı")
                payload.pop(m.group(1))
                continue
            print(f"  ! insert xətası {resp.status_code}: {resp.text[:300]}")
            return False
        return False


def build_row(item, coords):
    description = item["description"] or item["title"]
    description = f"{description}\n\nMənbə: {item['url']}"
    return {
        "business_name": item["company"] or "Boss.az",
        "title": item["title"],
        "category": item["category"],
        "district": "Bakı",
        "address": item["address"],
        "description": description,
        "salary": item["salary"],
        "phone_whatsapp": item["phones"][0],
        "latitude": coords[0],
        "longitude": coords[1],
        "has_vacancy": True,
        "ad_status": "approved",
        "is_active": True,
        "created_at": item["posted"].isoformat(),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=50)
    ap.add_argument("--max-pages", type=int, default=30)
    ap.add_argument("--max-age-days", type=int, default=0, help="0 = yalnız bu gün dərc olunanlar")
    ap.add_argument("--dry-run", action="store_true", help="Supabase-ə yazmadan nəticəni göstər")
    args = ap.parse_args()

    db = None
    if not args.dry_run:
        url, key = os.environ.get("SUPABASE_URL"), os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        if not url or not key:
            sys.exit("SUPABASE_URL və SUPABASE_SERVICE_ROLE_KEY mühit dəyişənləri tələb olunur.")
        db = Supabase(url, key)

    cutoff = (datetime.now(BAKU_TZ) - timedelta(days=args.max_age_days)).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    ids = list_vacancy_ids(args.max_pages)
    print(f"{len(ids)} elan tapıldı, yoxlanılır...")

    stats = {"saved": 0, "old": 0, "no_phone": 0, "no_address": 0, "no_geo": 0, "dup": 0}
    for vac_id in ids:
        if stats["saved"] >= args.limit:
            break
        item = parse_vacancy(vac_id)
        time.sleep(1)
        if not item or not item["title"]:
            continue
        if item["posted"] < cutoff:
            stats["old"] += 1
            continue
        if not item["phones"]:
            stats["no_phone"] += 1
            continue
        if not item["address"]:
            stats["no_address"] += 1
            continue
        coords = geocode(item["address"])
        if not coords:
            stats["no_geo"] += 1
            continue
        if db and db.exists(item["url"]):
            stats["dup"] += 1
            continue

        row = build_row(item, coords)
        if args.dry_run:
            print(json.dumps(row, ensure_ascii=False, indent=2))
            stats["saved"] += 1
        elif db.insert(row):
            stats["saved"] += 1
            print(f"[{stats['saved']}/{args.limit}] {item['title']} — {item['company']}")

    print("Nəticə:", stats)


if __name__ == "__main__":
    main()
