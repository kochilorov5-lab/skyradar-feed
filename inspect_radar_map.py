#!/usr/bin/env python3
"""Диагностика https://radar-map.ru/: статический HTML, затем JSON API, затем Playwright."""

from __future__ import annotations

import json
import re
from pathlib import Path

import requests
from bs4 import BeautifulSoup

PAGE_URL = "https://radar-map.ru/"
DEBUG_DIR = Path(__file__).resolve().parent / "debug"
USER_AGENT = "SkyRadarFeedInspect/1.0"
EVENT_WORDS = ("бпла", "опасность", "тревога", "фиксация", "отбой", "внимание", "ракет")
API_RE = re.compile(r"/api/[a-zA-Z0-9_./?-]+")


def save_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def fetch_html() -> tuple[str, str]:
    response = requests.get(
        PAGE_URL,
        headers={"User-Agent": USER_AGENT, "Accept": "text/html"},
        timeout=30,
    )
    response.raise_for_status()
    return response.url, response.text


def static_report(html: str) -> dict:
    soup = BeautifulSoup(html, "html.parser")
    summary = soup.select_one("#threatSummary")
    summary_text = summary.get_text(" ", strip=True) if summary else ""
    scripts = [tag.get("src") for tag in soup.select("script[src]") if tag.get("src")]
    endpoints = sorted(set(API_RE.findall(html)))
    visible = soup.get_text("\n", strip=True)
    hits = [word for word in EVENT_WORDS if word in visible.lower() or word in summary_text.lower()]
    return {
        "summary_text": summary_text,
        "scripts": scripts,
        "endpoints": endpoints,
        "event_words": hits,
        "has_events": bool(hits) or bool(summary_text),
    }


def fetch_json(path: str) -> tuple[int, object | None, str]:
    response = requests.get(
        PAGE_URL.rstrip("/") + path,
        headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
        timeout=40,
    )
    text = response.text
    payload = None
    if response.ok:
        try:
            payload = response.json()
        except json.JSONDecodeError:
            payload = None
    return response.status_code, payload, text


def describe_state(payload: object) -> dict:
    if not isinstance(payload, dict):
        return {"regions": [], "samples": [], "messages": 0}
    regions = payload.get("regions") if isinstance(payload.get("regions"), dict) else {}
    samples = []
    for name, item in list(regions.items())[:12]:
        text = str(item.get("source_text") or "").replace("\n", " | ")
        samples.append(f"{name}: {text[:180]}")
    messages = payload.get("recent_messages")
    return {
        "regions": list(regions.keys()),
        "samples": samples,
        "messages": len(messages) if isinstance(messages, list) else 0,
    }


def playwright_capture() -> tuple[str, list[tuple[str, str]]]:
    from playwright.sync_api import sync_playwright

    captured: list[tuple[str, str]] = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        page = browser.new_page(user_agent=USER_AGENT)
        def on_response(response) -> None:
            if "/api/" not in response.url or response.status != 200:
                return
            try:
                captured.append((response.url, response.text()))
            except Exception:
                return
        page.on("response", on_response)
        page.goto(PAGE_URL, wait_until="networkidle", timeout=45000)
        html = page.content()
        browser.close()
    return html, captured


def main() -> None:
    DEBUG_DIR.mkdir(parents=True, exist_ok=True)
    final_url, html = fetch_html()
    save_text(DEBUG_DIR / "page.html", html)
    report = static_report(html)
    method = "requests+BeautifulSoup, статический HTML без событий"
    state_info = {"regions": [], "samples": [], "messages": 0}
    endpoint = ""

    if not report["has_events"]:
        candidates = report["endpoints"] or ["/api/state"]
        for path in candidates:
            status, payload, raw = fetch_json(path)
            save_text(DEBUG_DIR / (path.strip("/").replace("/", "_") + ".json"), raw[:500000])
            if isinstance(payload, dict) and isinstance(payload.get("regions"), dict) and payload["regions"]:
                method = f"requests, JSON {path} (HTTP {status})"
                endpoint = path
                state_info = describe_state(payload)
                break
        if not state_info["regions"]:
            try:
                rendered, captured = playwright_capture()
            except Exception as error:
                method = f"Playwright недоступен ({error.__class__.__name__}: {error})"
                rendered = ""
                captured = []
            if rendered:
                save_text(DEBUG_DIR / "playwright.html", rendered)
                method = "Playwright, страница после скриптов"
            for url, body in captured:
                name = re.sub(r"[^a-zA-Z0-9._-]+", "_", url)[-80:]
                save_text(DEBUG_DIR / f"playwright_{name}.json", body[:500000])
                try:
                    payload = json.loads(body)
                except json.JSONDecodeError:
                    continue
                info = describe_state(payload)
                if info["regions"]:
                    method = f"Playwright, перехват {url}"
                    endpoint = url
                    state_info = info
                    break

    print("Источник: https://radar-map.ru/")
    print(f"Итоговый URL: {final_url}")
    print(f"Способ: {method}")
    if endpoint:
        print(f"Эндпоинт: {endpoint}")
    print(f"Селектор #threatSummary: {report['summary_text'] or 'пустой, события в HTML нет'}")
    print("Скрипты:", ", ".join(report["scripts"]) or "нет")
    print("Эндпоинты в разметке:", ", ".join(report["endpoints"]) or "нет")
    print("Слова событий в статическом тексте:", ", ".join(report["event_words"]) or "нет")
    print(f"Регионы в данных ({len(state_info['regions'])}): {', '.join(state_info['regions']) or 'нет'}")
    print(f"Недавних сообщений: {state_info['messages']}")
    if state_info["samples"]:
        print("Фрагменты сводок:")
        for line in state_info["samples"]:
            print(f"- {line}")
    print(f"Файлы диагностики: {DEBUG_DIR}")


if __name__ == "__main__":
    main()
