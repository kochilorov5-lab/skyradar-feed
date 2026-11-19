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

# 89 субъектов. Идентификаторы пресетов SkyRadar не меняются.
# Формат: regionId, regionName, дополнительные имена без официального названия.
REGIONS: list[tuple[str, str, tuple[str, ...]]] = [
    ("adygea", "Республика Адыгея", ("адыгея",)),
    ("altai", "Республика Алтай", ("республика алтай", "горный алтай")),
    ("bashkortostan", "Республика Башкортостан", ("башкортостан", "башкирия")),
    ("buryatia", "Республика Бурятия", ("бурятия",)),
    ("chechnya", "Чеченская Республика", ("чеченская республика", "чечня")),
    ("chuvashia", "Чувашская Республика", ("чувашская республика", "чувашия")),
    ("crimea", "Республика Крым", ("крым", "автономная республика крым")),
    ("dagestan", "Республика Дагестан", ("дагестан",)),
    ("dnr", "Донецкая Народная Республика", ("днр",)),
    ("ingushetia", "Республика Ингушетия", ("ингушетия",)),
    ("kabardino-balkaria", "Кабардино-Балкарская Республика", ("кабардино-балкарская республика", "кабардино-балкария", "кбр")),
    ("kalmykia", "Республика Калмыкия", ("калмыкия",)),
    ("karachay-cherkessia", "Карачаево-Черкесская Республика", ("карачаево-черкесская республика", "карачаево-черкесия", "кчр")),
    ("karelia", "Республика Карелия", ("карелия",)),
    ("khakassia", "Республика Хакасия", ("хакасия",)),
    ("komi", "Республика Коми", ("коми",)),
    ("lnr", "Луганская Народная Республика", ("лнр",)),
    ("mari-el", "Республика Марий Эл", ("марий эл",)),
    ("mordovia", "Республика Мордовия", ("мордовия",)),
    ("north-ossetia", "Республика Северная Осетия — Алания", ("северная осетия", "алания", "северная осетия - алания")),
    ("sakha", "Республика Саха (Якутия)", ("республика саха", "якутия")),
    ("tatarstan", "Республика Татарстан", ("татарстан",)),
    ("tuva", "Республика Тыва", ("тыва", "тува")),
    ("udmurtia", "Удмуртская Республика", ("удмуртская республика", "удмуртия")),
    ("altai-krai", "Алтайский край", ()),
    ("zabaykalsky-krai", "Забайкальский край", ("забайкалье",)),
    ("kamchatka-krai", "Камчатский край", ("камчатка",)),
    ("krasnodar-krai", "Краснодарский край", ("кубань",)),
    ("krasnoyarsk-krai", "Красноярский край", ()),
    ("perm-krai", "Пермский край", ()),
    ("primorsky-krai", "Приморский край", ("приморье",)),
    ("stavropol-krai", "Ставропольский край", ("ставрополье",)),
    ("khabarovsk-krai", "Хабаровский край", ()),
    ("amur-oblast", "Амурская область", ()),
    ("arkhangelsk-oblast", "Архангельская область", ()),
    ("astrakhan-oblast", "Астраханская область", ()),
    ("belgorod-oblast", "Белгородская область", ()),
    ("bryansk-oblast", "Брянская область", ()),
    ("vladimir-oblast", "Владимирская область", ()),
    ("volgograd-oblast", "Волгоградская область", ()),
    ("vologda-oblast", "Вологодская область", ()),
    ("voronezh-oblast", "Воронежская область", ()),
    ("ivanovo-oblast", "Ивановская область", ()),
    ("irkutsk-oblast", "Иркутская область", ()),
    ("kaliningrad-oblast", "Калининградская область", ()),
    ("kaluga-oblast", "Калужская область", ()),
    ("kemerovo-oblast", "Кемеровская область", ("кузбасс", "кемеровская область — кузбасс")),
    ("kirov-oblast", "Кировская область", ()),
    ("kostroma-oblast", "Костромская область", ()),
    ("kurgan-oblast", "Курганская область", ()),
    ("kursk-oblast", "Курская область", ()),
    ("leningrad-oblast", "Ленинградская область", ("ленобласть",)),
    ("lipetsk-oblast", "Липецкая область", ()),
    ("magadan-oblast", "Магаданская область", ()),
    ("moscow-oblast", "Московская область", ("подмосковье",)),
    ("murmansk-oblast", "Мурманская область", ()),
    ("nizhny-novgorod-oblast", "Нижегородская область", ()),
    ("novgorod-oblast", "Новгородская область", ()),
    ("novosibirsk-oblast", "Новосибирская область", ()),
    ("omsk-oblast", "Омская область", ()),
    ("orenburg-oblast", "Оренбургская область", ()),
    ("oryol-oblast", "Орловская область", ()),
    ("penza-oblast", "Пензенская область", ()),
    ("pskov-oblast", "Псковская область", ()),
    ("rostov-oblast", "Ростовская область", ()),
    ("ryazan-oblast", "Рязанская область", ()),
    ("samara-oblast", "Самарская область", ()),
    ("saratov-oblast", "Саратовская область", ()),
    ("sakhalin-oblast", "Сахалинская область", ("сахалин",)),
    ("sverdlovsk-oblast", "Свердловская область", ()),
    ("smolensk-oblast", "Смоленская область", ()),
    ("tambov-oblast", "Тамбовская область", ()),
    ("tver-oblast", "Тверская область", ()),
    ("tomsk-oblast", "Томская область", ()),
    ("tula-oblast", "Тульская область", ()),
    ("tyumen-oblast", "Тюменская область", ()),
    ("ulyanovsk-oblast", "Ульяновская область", ()),
    ("chelyabinsk-oblast", "Челябинская область", ()),
    ("yaroslavl-oblast", "Ярославская область", ()),
    ("kherson-oblast", "Херсонская область", ()),
    ("zaporizhzhia-oblast", "Запорожская область", ("запорожье",)),
    ("moscow", "Москва", ("город москва", "мск")),
    ("saint-petersburg", "Санкт-Петербург", ("петербург", "спб", "санкт петербург")),
    ("sevastopol", "Севастополь", ("город севастополь",)),
    ("jewish-autonomous-oblast", "Еврейская автономная область", ("еао",)),
    ("nenets-ao", "Ненецкий автономный округ", ("нао",)),
    ("khanty-mansi-ao", "Ханты-Мансийский автономный округ — Югра", ("хмао", "югра", "ханты-мансийский автономный округ")),
    ("chukotka-ao", "Чукотский автономный округ", ("чукотка",)),
    ("yamalo-nenets-ao", "Ямало-Ненецкий автономный округ", ("янао", "ямал")),
]

# Крупные города и пункты, которые в сводках называют чаще, чем сам субъект.
CITIES: dict[str, tuple[str, ...]] = {
    "crimea": ("Симферополь", "Ялта", "Керчь", "Евпатория", "Феодосия", "Джанкой", "Алушта", "Бахчисарай", "Судак", "Армянск", "Красноперекопск"),
    "sevastopol": ("Севастополь",),
    "dnr": ("Донецк", "Мариуполь", "Горловка", "Макеевка"),
    "lnr": ("Луганск", "Алчевск", "Северодонецк", "Брянка", "Стаханов"),
    "kherson-oblast": ("Херсон", "Геническ", "Скадовск"),
    "zaporizhzhia-oblast": ("Запорожье", "Мелитополь", "Бердянск", "Энергодар"),
    "krasnodar-krai": ("Краснодар", "Сочи", "Новороссийск", "Туапсе", "Анапа", "Геленджик", "Ейск", "Армавир", "Темрюк", "Крымск", "Тихорецк"),
    "rostov-oblast": ("Ростов-на-Дону", "Таганрог", "Шахты", "Волгодонск", "Морозовск", "Миллерово", "Новочеркасск", "Батайск", "Азов", "Каменск-Шахтинский", "Гуково"),
    "belgorod-oblast": ("Белгород", "Шебекино", "Грайворон", "Валуйки", "Старый Оскол", "Алексеевка"),
    "kursk-oblast": ("Курск", "Суджа", "Рыльск", "Льгов", "Курчатов"),
    "bryansk-oblast": ("Брянск", "Клинцы", "Стародуб", "Дятьково", "Унеча", "Почеп", "Трубчевск", "Суземка", "Севск"),
    "lipetsk-oblast": ("Липецк", "Елец"),
    "saratov-oblast": ("Саратов", "Энгельс", "Балаково", "Балашов", "Вольск"),
    "nizhny-novgorod-oblast": ("Нижний Новгород", "Дзержинск", "Арзамас", "Саров", "Кстово"),
    "tatarstan": ("Казань", "Елабуга", "Нижнекамск", "Альметьевск", "Набережные Челны", "Зеленодольск"),
    "samara-oblast": ("Самара", "Тольятти", "Сызрань", "Новокуйбышевск", "Чапаевск"),
    "moscow": ("Москва",),
    "moscow-oblast": ("Химки", "Подольск", "Мытищи", "Балашиха", "Королёв", "Люберцы", "Одинцово", "Красногорск", "Коломна", "Серпухов", "Электросталь", "Домодедово", "Жуковский", "Дмитров", "Клин"),
    "saint-petersburg": ("Санкт-Петербург",),
    "leningrad-oblast": ("Гатчина", "Выборг", "Тихвин", "Сосновый Бор", "Кингисепп", "Волхов"),
    "voronezh-oblast": ("Воронеж", "Борисоглебск", "Россошь", "Лиски", "Острогожск"),
    "oryol-oblast": ("Орёл", "Ливны", "Мценск"),
    "kaluga-oblast": ("Калуга", "Обнинск"),
    "tula-oblast": ("Тула", "Новомосковск", "Алексин", "Щёкино", "Узловая"),
    "smolensk-oblast": ("Смоленск", "Вязьма", "Рославль", "Ярцево", "Сафоново"),
    "volgograd-oblast": ("Волгоград", "Волжский", "Камышин", "Урюпинск", "Михайловка"),
    "sverdlovsk-oblast": ("Екатеринбург", "Нижний Тагил", "Каменск-Уральский", "Первоуральск"),
    "bashkortostan": ("Уфа", "Стерлитамак", "Салават", "Нефтекамск"),
    "chelyabinsk-oblast": ("Челябинск", "Магнитогорск", "Златоуст", "Миасс"),
    "novosibirsk-oblast": ("Новосибирск", "Бердск"),
    "omsk-oblast": ("Омск",),
    "krasnoyarsk-krai": ("Красноярск", "Норильск", "Ачинск"),
    "irkutsk-oblast": ("Иркутск", "Братск", "Ангарск"),
    "kemerovo-oblast": ("Кемерово", "Новокузнецк", "Прокопьевск"),
    "perm-krai": ("Пермь", "Березники"),
    "stavropol-krai": ("Ставрополь", "Пятигорск", "Кисловодск", "Невинномысск", "Ессентуки", "Минеральные Воды"),
    "dagestan": ("Махачкала", "Дербент", "Хасавюрт", "Каспийск"),
    "chechnya": ("Грозный",),
    "kabardino-balkaria": ("Нальчик",),
    "karachay-cherkessia": ("Черкесск",),
    "north-ossetia": ("Владикавказ",),
    "ingushetia": ("Назрань", "Магас"),
    "kalmykia": ("Элиста",),
    "adygea": ("Майкоп",),
    "astrakhan-oblast": ("Астрахань",),
    "kaliningrad-oblast": ("Калининград",),
    "murmansk-oblast": ("Мурманск",),
    "arkhangelsk-oblast": ("Архангельск", "Северодвинск"),
    "vologda-oblast": ("Вологда", "Череповец"),
    "pskov-oblast": ("Псков", "Великие Луки"),
    "novgorod-oblast": ("Великий Новгород",),
    "tver-oblast": ("Тверь",),
    "yaroslavl-oblast": ("Ярославль", "Рыбинск", "Ростов Великий"),
    "ivanovo-oblast": ("Иваново",),
    "vladimir-oblast": ("Владимир", "Ковров", "Муром"),
    "kostroma-oblast": ("Кострома",),
    "ryazan-oblast": ("Рязань",),
    "tambov-oblast": ("Тамбов", "Мичуринск"),
    "penza-oblast": ("Пенза",),
    "ulyanovsk-oblast": ("Ульяновск", "Димитровград"),
    "kirov-oblast": ("Киров",),
    "orenburg-oblast": ("Оренбург", "Орск"),
    "kurgan-oblast": ("Курган",),
    "tyumen-oblast": ("Тюмень", "Тобольск"),
    "khanty-mansi-ao": ("Сургут", "Нижневартовск", "Нефтеюганск", "Ханты-Мансийск"),
    "yamalo-nenets-ao": ("Салехард", "Новый Уренгой", "Ноябрьск", "Надым"),
    "chukotka-ao": ("Анадырь",),
    "nenets-ao": ("Нарьян-Мар",),
    "jewish-autonomous-oblast": ("Биробиджан",),
    "amur-oblast": ("Благовещенск",),
    "khabarovsk-krai": ("Хабаровск", "Комсомольск-на-Амуре"),
    "primorsky-krai": ("Владивосток", "Находка", "Уссурийск"),
    "kamchatka-krai": ("Петропавловск-Камчатский",),
    "magadan-oblast": ("Магадан",),
    "sakhalin-oblast": ("Южно-Сахалинск",),
    "sakha": ("Якутск",),
    "buryatia": ("Улан-Удэ",),
    "zabaykalsky-krai": ("Чита",),
    "tuva": ("Кызыл",),
    "khakassia": ("Абакан",),
    "altai": ("Горно-Алтайск",),
    "altai-krai": ("Барнаул", "Бийск", "Рубцовск"),
    "mari-el": ("Йошкар-Ола",),
    "mordovia": ("Саранск",),
    "chuvashia": ("Чебоксары",),
    "udmurtia": ("Ижевск",),
    "komi": ("Сыктывкар",),
    "karelia": ("Петрозаводск",),
    "tomsk-oblast": ("Томск",),
}

# Формы, которые нельзя получить простым окончанием.
IRREGULAR_CITY_FORMS: dict[str, tuple[str, ...]] = {
    "Ростов-на-Дону": ("ростов", "ростова", "ростове", "ростовом", "ростова-на-дону", "ростове-на-дону"),
    "Нижний Новгород": ("нижнего новгорода", "нижнем новгороде", "нижнему новгороду"),
    "Старый Оскол": ("старого оскола", "старом осколе", "старому осколу"),
    "Набережные Челны": ("набережных челнов", "набережных челнах"),
    "Великий Новгород": ("великого новгорода", "великом новгороде"),
    "Великие Луки": ("великих лук", "великих луках"),
    "Ростов Великий": ("ростова великого", "ростове великом"),
    "Комсомольск-на-Амуре": ("комсомольска-на-амуре", "комсомольске-на-амуре"),
    "Петропавловск-Камчатский": ("петропавловска-камчатского", "петропавловске-камчатском"),
    "Каменск-Шахтинский": ("каменска-шахтинского", "каменске-шахтинском"),
    "Каменск-Уральский": ("каменска-уральского", "каменске-уральском"),
    "Санкт-Петербург": ("санкт-петербурга", "санкт-петербурге", "петербурга", "петербурге"),
    "Орёл": ("орел", "орла", "орле", "орлом"),
    "Елец": ("ельца", "ельце", "ельцом"),
    "Валуйки": ("валуек", "валуйках", "валуйками"),
    "Щёкино": ("щекино", "щекина", "щекине"),
    "Королёв": ("королев", "королева", "королеве"),
    "Йошкар-Ола": ("йошкар-олы", "йошкар-оле"),
    "Улан-Удэ": ("улан-удэ", "улан-уде"),
    "Минеральные Воды": ("минеральных вод", "минеральных водах"),
    "Сосновый Бор": ("соснового бора", "сосновом бору"),
    "Нарьян-Мар": ("нарьян-мара", "нарьян-маре"),
    "Ханты-Мансийск": ("ханты-мансийска", "ханты-мансийске"),
    "Южно-Сахалинск": ("южно-сахалинска", "южно-сахалинске"),
}

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


def normalize_place(value: str) -> str:
    return value.lower().replace("ё", "е").replace("—", "-")


def inflect_city(display: str) -> set[str]:
    """Грубые падежные формы. Составные названия не склоняются автоматически."""
    base = normalize_place(display)
    forms = {base}
    if any(char in base for char in " -"):
        return forms
    vowels = set("аеёиоуыэюя")
    if base.endswith("а"):
        stem = base[:-1]
        forms.update({stem + end for end in ("ы", "е", "у", "ой", "ою")})
    elif base.endswith("я"):
        stem = base[:-1]
        forms.update({stem + end for end in ("и", "е", "ю", "ей")})
    elif base.endswith("о"):
        stem = base[:-1]
        forms.update({stem + end for end in ("а", "е", "у", "ом")})
    elif base.endswith("ы") or base.endswith(("цы", "ки")):
        stem = base[:-1]
        forms.update({stem + "ах", stem + "ами", stem + "ов", stem})
    elif base.endswith("ь"):
        stem = base[:-1]
        forms.update({stem + end for end in ("и", "ью", "ю")})
    elif base[-1] not in vowels:
        forms.update({base + end for end in ("а", "у", "е", "ом", "ов")})
    return forms


def alias_catalog() -> list[tuple[str, str, str, str | None]]:
    found: dict[str, tuple[str, str, str, str | None]] = {}

    def add(alias: str, region_id: str, title: str, locality: str | None) -> None:
        key = normalize_place(alias)
        if len(key) < 3:
            return
        current = found.get(key)
        row = (key, region_id, title, locality)
        if current is None or (current[3] is not None and locality is None):
            found[key] = row

    titles = {region_id: title for region_id, title, _aliases in REGIONS}
    for region_id, title, aliases in REGIONS:
        add(title, region_id, title, None)
        for alias in aliases:
            add(alias, region_id, title, None)
        for city in CITIES.get(region_id, ()):
            forms = inflect_city(city)
            forms.update(normalize_place(item) for item in IRREGULAR_CITY_FORMS.get(city, ()))
            for form in forms:
                add(form, region_id, titles[region_id], city)
    rows = list(found.values())
    rows.sort(key=lambda item: len(item[0]), reverse=True)
    return rows


ALIASES = alias_catalog()


def region_by_id(region_id: str) -> tuple[str, str] | None:
    for known_id, title, _aliases in REGIONS:
        if known_id == region_id:
            return known_id, title
    return None


def resolve_place(name: str) -> tuple[str, str, str | None] | None:
    lowered = normalize_place(name).strip()
    for alias, region_id, title, locality in ALIASES:
        if alias == lowered:
            return region_id, title, locality
    return None


def region_identity(name: str) -> tuple[str, str, str | None] | None:
    found = resolve_place(name)
    if found:
        return found
    if not is_russian_subject(name):
        return None
    return slugify(name), name.strip(), None


def mentioned_regions(text: str) -> list[tuple[str, str, str | None]]:
    lowered = normalize_place(text)
    occupied = [False] * len(lowered)
    order: list[tuple[str, str]] = []
    localities: dict[str, list[str]] = {}
    seen: set[str] = set()
    for alias, region_id, title, locality in ALIASES:
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
                    order.append((region_id, title))
                if locality and locality not in localities.setdefault(region_id, []):
                    localities[region_id].append(locality)
                break
            start = index + 1
    return [
        (region_id, title, ", ".join(localities[region_id]) if localities.get(region_id) else None)
        for region_id, title in order
    ]


def describe_summary(summary: str, locality: str | None) -> str:
    if not locality:
        return summary
    folded = normalize_place(summary)
    if all(normalize_place(part) in folded for part in locality.split(", ")):
        return summary
    return f"{locality}. {summary}"[:360]


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
            city_name = str(city.get("name") or city.get("title") or "")
            identity = resolve_place(city_name) or (resolve_place(parent) if parent else None)
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
        key_id, key_title, key_locality = identity
        if named and all(region_id != key_id for region_id, _title, _locality in named):
            targets = named
        else:
            locality = key_locality
            for region_id, _title, found_locality in named:
                if region_id == key_id and found_locality:
                    locality = found_locality
                    break
            targets = [(key_id, key_title, locality)]
        moment = event_time(item, summary, now)
        text_level = level_from_text(summary)
        for region_id, region_name, locality in targets:
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
                "summary": describe_summary(summary, locality),
                "sourceName": "radar-map.ru",
                "sourceURL": PAGE_URL,
                "timestamp": iso_z(moment),
                "expiresAt": iso_z(expires),
                "_moment": moment,
            }
            if locality:
                alert["locality"] = locality
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


def channel_targets(text: str, default_region_id: str | None) -> list[tuple[str, str, str | None]]:
    mentioned = mentioned_regions(text)
    if mentioned:
        return mentioned
    if not default_region_id:
        return []
    fallback = region_by_id(default_region_id)
    if fallback is None:
        return []
    return [(fallback[0], fallback[1], None)]


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
        for region_id, region_name, locality in targets:
            alert = {
                "id": f"{region_id}-{level}-{int(moment.timestamp())}",
                "regionId": region_id,
                "regionName": region_name,
                "level": level,
                "summary": describe_summary(summary, locality),
                "sourceName": source["title"],
                "sourceURL": f"https://t.me/{channel_name}/{post_id}",
                "timestamp": iso_z(moment),
                "expiresAt": iso_z(expires),
                "_moment": moment,
            }
            if locality:
                alert["locality"] = locality
            alerts.append(alert)
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
