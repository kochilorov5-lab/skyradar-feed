#!/usr/bin/env python3
"""Парсер открытых сводок radar-map.ru и публичных страниц Telegram в RadarFeedPayload."""

from __future__ import annotations

import json
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path

import requests
from bs4 import BeautifulSoup

PAGE_URL = "https://radar-map.ru/"
STATE_PATH = "/api/state"
ROOT = Path(__file__).resolve().parent
OUTPUT_PATH = ROOT / "output" / "feed.json"
TELEGRAM_SOURCES_PATH = ROOT / "config" / "telegram_sources.json"
USER_AGENT = "SkyRadarFeedParser/1.0"
TELEGRAM_USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
)
MSK = timezone(timedelta(hours=3))
ACTIVE_TTL = timedelta(minutes=50)
CLEAR_TTL = timedelta(minutes=20)
DEDUP_WINDOW = timedelta(minutes=15)
LEVEL_RANK = {"danger": 4, "attention": 3, "allClear": 2, "clear": 1}
DANGER_RE = re.compile(r"опасност|тревог|ракет|взрыв|каб|авиаудар|\bпво\b", re.IGNORECASE)
ATTENTION_RE = re.compile(r"вниман|фиксац|прол[её]т|бпла|беспилот|дрон|\bfpv\b", re.IGNORECASE)
UAV_RE = re.compile(r"бпла|беспилот|дрон|\bfpv\b|баражир", re.IGNORECASE)
ALL_CLEAR_RE = re.compile(r"отбой|опасность снята|тревога снята|угроза миновала|\bчисто\b", re.IGNORECASE)
STAMP_RE = re.compile(r"\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2}")
PROMO_RE = re.compile(r"карта опасностей.*$|radar-vrv\.ru|локатор россии.*$", re.IGNORECASE)

# Идентификаторы совпадают с пресетами SkyRadar там, где регион уже есть в приложении.
KNOWN_REGIONS: list[tuple[str, str, tuple[str, ...]]] = [
    ("moscow", "Москва", ("москва", "город москва")),
    ("moscow-oblast", "Московская область", ("московская область", "подмосковье")),
    ("saint-petersburg", "Санкт-Петербург", ("санкт-петербург", "петербург", "спб")),
    ("leningrad-oblast", "Ленинградская область", ("ленинградская область", "ленобласть")),
    ("belgorod-oblast", "Белгородская область", ("белгородская область", "белгород")),
    ("kursk-oblast", "Курская область", ("курская область", "курск")),
    ("bryansk-oblast", "Брянская область", ("брянская область", "брянск")),
    ("voronezh-oblast", "Воронежская область", ("воронежская область", "воронеж")),
    ("rostov-oblast", "Ростовская область", ("ростовская область", "ростов-на-дону", "ростов")),
    ("krasnodar-krai", "Краснодарский край", ("краснодарский край", "краснодар", "кубань")),
    ("tatarstan", "Республика Татарстан", ("республика татарстан", "татарстан", "казань")),
    ("samara-oblast", "Самарская область", ("самарская область", "самара")),
    ("nizhny-novgorod-oblast", "Нижегородская область", ("нижегородская область", "нижний новгород")),
    ("sverdlovsk-oblast", "Свердловская область", ("свердловская область", "екатеринбург")),
    ("crimea", "Республика Крым", ("республика крым", "автономная республика крым", "крым")),
    ("sevastopol", "Севастополь", ("севастополь",)),
    ("dnr", "Донецкая Народная Республика", ("донецкая народная республика", "днр")),
    ("lnr", "Луганская Народная Республика", ("луганская народная республика", "лнр")),
    ("kherson-oblast", "Херсонская область", ("херсонская область", "херсон")),
    ("zaporizhzhia-oblast", "Запорожская область", ("запорожская область", "запорожье")),
    ("lipetsk-oblast", "Липецкая область", ("липецкая область", "липецк")),
    ("smolensk-oblast", "Смоленская область", ("смоленская область", "смоленск")),
    ("oryol-oblast", "Орловская область", ("орловская область", "орёл", "орел")),
    ("kaluga-oblast", "Калужская область", ("калужская область", "калуга")),
    ("tula-oblast", "Тульская область", ("тульская область", "тула")),
    ("ryazan-oblast", "Рязанская область", ("рязанская область", "рязань")),
    ("tambov-oblast", "Тамбовская область", ("тамбовская область", "тамбов")),
]

TRANSLIT = str.maketrans(
    {
        "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "e",
        "ж": "zh", "з": "z", "и": "i", "й": "y", "к": "k", "л": "l", "м": "m",
        "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u",
        "ф": "f", "х": "h", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "sch",
        "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya",
    }
)
SUBJECT_HINT = ("область", "край", "республика", "автоном", "округ", "народная")
FEDERAL_CITIES = {"москва", "санкт-петербург", "севастополь"}


def iso_z(moment: datetime) -> str:
    return moment.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def slugify(name: str) -> str:
    lowered = name.lower().translate(TRANSLIT)
    slug = re.sub(r"[^a-z0-9]+", "-", lowered).strip("-")
    return slug or "region"


def is_russian_subject(name: str) -> bool:
    lowered = name.lower().strip()
    if lowered in FEDERAL_CITIES:
        return True
    return any(hint in lowered for hint in SUBJECT_HINT)


def region_by_id(region_id: str) -> tuple[str, str] | None:
    for known_id, title, _aliases in KNOWN_REGIONS:
        if known_id == region_id:
            return known_id, title
    return None


def known_for(name: str) -> tuple[str, str] | None:
    lowered = name.lower().strip()
    for region_id, title, aliases in KNOWN_REGIONS:
        if lowered == title.lower() or lowered in aliases:
            return region_id, title
    return None


def region_identity(name: str) -> tuple[str, str] | None:
    if not is_russian_subject(name) and known_for(name) is None:
        return None
    found = known_for(name)
    if found:
        return found
    return slugify(name), name.strip()


def alias_catalog() -> list[tuple[str, str, str]]:
    rows: list[tuple[str, str, str]] = []
    for region_id, title, aliases in KNOWN_REGIONS:
        rows.append((title.lower(), region_id, title))
        for alias in aliases:
            rows.append((alias, region_id, title))
    rows.sort(key=lambda item: len(item[0]), reverse=True)
    return rows


ALIASES = alias_catalog()


def mentioned_regions(text: str) -> list[tuple[str, str]]:
    lowered = text.lower()
    occupied = [False] * len(lowered)
    found: list[tuple[str, str]] = []
    seen: set[str] = set()
    for alias, region_id, title in ALIASES:
        start = 0
        while True:
            index = lowered.find(alias, start)
            if index < 0:
                break
            end = index + len(alias)
            before_ok = index == 0 or not lowered[index - 1].isalnum()
            after_ok = end == len(lowered) or not lowered[end].isalnum()
            if before_ok and after_ok and not any(occupied[index:end]):
                for pos in range(index, end):
                    occupied[pos] = True
                if region_id not in seen:
                    seen.add(region_id)
                    found.append((region_id, title))
                break
            start = index + 1
    return found


def latest_block(source_text: str) -> str:
    lines = [line.strip() for line in source_text.splitlines() if line.strip()]
    block: list[str] = []
    stamps = 0
    for line in lines:
        if STAMP_RE.search(line):
            stamps += 1
            if stamps > 1:
                break
            continue
        block.append(line)
    text = " ".join(block) if block else " ".join(lines)
    text = PROMO_RE.sub("", text)
    text = re.sub(r"\s+", " ", text).strip(" -\n")
    return text[:360]


def level_from_text(text: str) -> str | None:
    if ALL_CLEAR_RE.search(text) and not DANGER_RE.search(text):
        return "allClear"
    if DANGER_RE.search(text):
        return "danger"
    if ATTENTION_RE.search(text):
        return "attention"
    return None


def level_from_flags(item: dict) -> str | None:
    if item.get("danger") or item.get("rocket") or item.get("explosionOnRegion") or item.get("uab"):
        return "danger"
    if item.get("attention") or item.get("bpla") or item.get("fpv") or item.get("aviation") or item.get("pvo"):
        return "attention"
    return None


def stronger(left: str | None, right: str | None) -> str | None:
    if left is None:
        return right
    if right is None:
        return left
    if LEVEL_RANK[right] > LEVEL_RANK[left]:
        return right
    return left


def parse_stamp(text: str) -> datetime | None:
    match = STAMP_RE.search(text)
    if not match:
        return None
    return datetime.strptime(match.group(0), "%d.%m.%Y %H:%M").replace(tzinfo=MSK)


def event_time(item: dict, text: str, now: datetime) -> datetime:
    raw = item.get("last_event_ts")
    if isinstance(raw, (int, float)) and raw > 0:
        return datetime.fromtimestamp(raw, timezone.utc)
    stamped = parse_stamp(str(item.get("source_text") or text))
    return stamped or now


def fetch_state() -> dict:
    response = requests.get(
        PAGE_URL.rstrip("/") + STATE_PATH,
        headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
        timeout=40,
    )
    response.raise_for_status()
    payload = response.json()
    if not isinstance(payload, dict):
        raise RuntimeError("Ответ /api/state не является объектом JSON.")
    return payload


def build_alerts(state: dict, now: datetime) -> list[dict]:
    regions = state.get("regions") if isinstance(state.get("regions"), dict) else {}
    cities = state.get("cities") if isinstance(state.get("cities"), list) else []
    city_level: dict[str, str] = {}
    for city in cities:
        if not isinstance(city, dict):
            continue
        parent = str(city.get("region") or "")
        identity = region_identity(parent)
        if identity is None:
            continue
        merged = stronger(city_level.get(identity[0]), level_from_flags(city))
        if merged:
            city_level[identity[0]] = merged

    chosen: dict[str, dict] = {}
    for raw_name, item in regions.items():
        if not isinstance(item, dict):
            continue
        identity = region_identity(str(raw_name))
        if identity is None:
            continue
        summary = latest_block(str(item.get("source_text") or ""))
        if not summary:
            continue
        named = mentioned_regions(summary)
        key_id, key_title = identity
        if named and all(region_id != key_id for region_id, _title in named):
            targets = named
        else:
            targets = [(key_id, key_title)]
        moment = event_time(item, summary, now)
        text_level = level_from_text(summary)
        for region_id, region_name in targets:
            level = text_level or level_from_flags(item)
            if level is None and region_id == key_id:
                level = city_level.get(region_id)
            if level is None:
                continue
            ttl = CLEAR_TTL if level in {"allClear", "clear"} else ACTIVE_TTL
            expires = moment + ttl
            if expires <= now:
                continue
            alert = {
                "id": f"{region_id}-{level}-{int(moment.timestamp())}",
                "regionId": region_id,
                "regionName": region_name,
                "level": level,
                "summary": summary,
                "sourceName": "radar-map.ru",
                "sourceURL": PAGE_URL,
                "timestamp": iso_z(moment),
                "expiresAt": iso_z(expires),
                "_moment": moment,
            }
            previous = chosen.get(region_id)
            if previous is None or LEVEL_RANK[level] > LEVEL_RANK[previous["level"]] or (
                level == previous["level"] and moment > previous["_moment"]
            ):
                chosen[region_id] = alert

    return list(chosen.values())


def load_telegram_sources() -> list[dict]:
    if not TELEGRAM_SOURCES_PATH.exists():
        return []
    raw = json.loads(TELEGRAM_SOURCES_PATH.read_text(encoding="utf-8"))
    rows = raw.get("sources") if isinstance(raw, dict) else raw
    if not isinstance(rows, list):
        raise RuntimeError("config/telegram_sources.json должен быть списком каналов.")
    sources: list[dict] = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        username = str(row.get("username") or "").strip().lstrip("@")
        if not username:
            continue
        default_region = row.get("default_region_id")
        sources.append(
            {
                "username": username,
                "title": str(row.get("title") or username).strip() or username,
                "default_region_id": default_region if isinstance(default_region, str) and default_region else None,
            }
        )
    return sources


def fetch_channel_html(username: str) -> str:
    response = requests.get(
        f"https://t.me/s/{username}",
        headers={
            "User-Agent": TELEGRAM_USER_AGENT,
            "Accept": "text/html,application/xhtml+xml",
            "Accept-Language": "ru,en;q=0.8",
        },
        timeout=25,
    )
    response.raise_for_status()
    return response.text


def parse_telegram_time(raw: str) -> datetime | None:
    try:
        moment = datetime.fromisoformat(raw)
    except ValueError:
        return None
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=timezone.utc)
    return moment.astimezone(timezone.utc)


def channel_targets(text: str, default_region_id: str | None) -> list[tuple[str, str]]:
    mentioned = mentioned_regions(text)
    if mentioned:
        return mentioned
    if not default_region_id:
        return []
    fallback = region_by_id(default_region_id)
    return [fallback] if fallback else []


def alerts_from_channel(source: dict, now: datetime) -> list[dict]:
    username = source["username"]
    soup = BeautifulSoup(fetch_channel_html(username), "html.parser")
    alerts: list[dict] = []
    for node in soup.select(".tgme_widget_message"):
        post = str(node.get("data-post") or "")
        text_node = node.select_one(".tgme_widget_message_text")
        time_node = node.select_one("time")
        if text_node is None or time_node is None or "/" not in post:
            continue
        text = re.sub(r"\s+", " ", text_node.get_text(" ", strip=True)).strip()
        if not text or UAV_RE.search(text) is None:
            continue
        moment = parse_telegram_time(str(time_node.get("datetime") or ""))
        if moment is None or moment < now - ACTIVE_TTL:
            continue
        level = level_from_text(text) or "attention"
        if level == "clear":
            continue
        targets = channel_targets(text, source["default_region_id"])
        if not targets:
            continue
        channel_name, post_id = post.split("/", 1)
        summary = text[:360]
        ttl = CLEAR_TTL if level == "allClear" else ACTIVE_TTL
        expires = moment + ttl
        if expires <= now:
            continue
        for region_id, region_name in targets:
            alerts.append(
                {
                    "id": f"{region_id}-{level}-{int(moment.timestamp())}",
                    "regionId": region_id,
                    "regionName": region_name,
                    "level": level,
                    "summary": summary,
                    "sourceName": source["title"],
                    "sourceURL": f"https://t.me/{channel_name}/{post_id}",
                    "timestamp": iso_z(moment),
                    "expiresAt": iso_z(expires),
                    "_moment": moment,
                }
            )
    return alerts


def fetch_telegram_alerts(now: datetime) -> list[dict]:
    alerts: list[dict] = []
    for source in load_telegram_sources():
        try:
            found = alerts_from_channel(source, now)
        except (requests.RequestException, ValueError) as exc:
            print(f"Telegram @{source['username']}: {exc}")
            continue
        print(f"Telegram @{source['username']}: {len(found)}")
        alerts.extend(found)
    return alerts


def dedupe_region_window(alerts: list[dict]) -> list[dict]:
    grouped: dict[str, list[dict]] = {}
    for alert in alerts:
        grouped.setdefault(alert["regionId"], []).append(alert)
    kept: list[dict] = []
    for region_alerts in grouped.values():
        region_alerts.sort(key=lambda item: item["_moment"])
        cluster: list[dict] = []
        for alert in region_alerts:
            if cluster and alert["_moment"] - cluster[-1]["_moment"] <= DEDUP_WINDOW:
                previous = cluster[-1]
                if LEVEL_RANK[alert["level"]] > LEVEL_RANK[previous["level"]] or (
                    alert["level"] == previous["level"] and alert["_moment"] >= previous["_moment"]
                ):
                    cluster[-1] = alert
                continue
            cluster.append(alert)
        kept.extend(cluster)
    return kept


def finalize_alerts(alerts: list[dict], now: datetime) -> list[dict]:
    fresh = [alert for alert in alerts if alert["_moment"] + (CLEAR_TTL if alert["level"] == "allClear" else ACTIVE_TTL) > now]
    merged = dedupe_region_window(fresh)
    merged.sort(key=lambda item: (-LEVEL_RANK[item["level"]], -item["_moment"].timestamp(), item["regionName"]))
    for alert in merged:
        del alert["_moment"]
    return merged


def build_payload(now: datetime | None = None) -> dict:
    moment = now or datetime.now(timezone.utc)
    state = fetch_state()
    alerts = build_alerts(state, moment)
    alerts.extend(fetch_telegram_alerts(moment))
    return {"updatedAt": iso_z(moment), "alerts": finalize_alerts(alerts, moment)}


def main() -> None:
    payload = build_payload()
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Записан {OUTPUT_PATH}")
    print(f"Сводок: {len(payload['alerts'])}")
    for alert in payload["alerts"]:
        print(f"- {alert['level']}: {alert['regionName']} [{alert['sourceName']}] до {alert['expiresAt']}")


if __name__ == "__main__":
    main()
