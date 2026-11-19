#!/usr/bin/env python3
"""Парсер открытых сводок https://radar-map.ru/ в RadarFeedPayload для SkyRadar."""

from __future__ import annotations

import json
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path

import requests

PAGE_URL = "https://radar-map.ru/"
STATE_PATH = "/api/state"
OUTPUT_PATH = Path(__file__).resolve().parent / "output" / "feed.json"
USER_AGENT = "SkyRadarFeedParser/1.0"
MSK = timezone(timedelta(hours=3))
ACTIVE_TTL = timedelta(minutes=50)
CLEAR_TTL = timedelta(minutes=20)
LEVEL_RANK = {"danger": 4, "attention": 3, "allClear": 2, "clear": 1}
DANGER_RE = re.compile(r"опасност|тревог|ракет|взрыв|каб|авиаудар|\bпво\b", re.IGNORECASE)
ATTENTION_RE = re.compile(r"вниман|фиксац|прол[её]т|бпла|дрон|\bfpv\b", re.IGNORECASE)
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

    alerts = list(chosen.values())
    alerts.sort(key=lambda item: (-LEVEL_RANK[item["level"]], -item["_moment"].timestamp(), item["regionName"]))
    for alert in alerts:
        del alert["_moment"]
    return alerts


def build_payload(now: datetime | None = None) -> dict:
    moment = now or datetime.now(timezone.utc)
    state = fetch_state()
    return {"updatedAt": iso_z(moment), "alerts": build_alerts(state, moment)}


def main() -> None:
    payload = build_payload()
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Записан {OUTPUT_PATH}")
    print(f"Сводок: {len(payload['alerts'])}")
    for alert in payload["alerts"]:
        print(f"- {alert['level']}: {alert['regionName']} до {alert['expiresAt']}")


if __name__ == "__main__":
    main()
