#!/usr/bin/env python3
"""
Деплой семантичної моделі PharmaSalesGold у Fabric через REST API.

Найнадійніший спосіб без git integration: не залежить від версії Power BI Desktop
чи Tabular Editor, працює однаково для створення й оновлення.

Використання:
    # токен з Azure CLI (найпростіше)
    az login
    python3 deploy_semantic_model.py --workspace 343bb55f-11c8-43a8-acba-3ad333a2d07a

    # або явний токен
    python3 deploy_semantic_model.py --workspace <ws-id> --token <access-token>

    # подивитись, що піде в API, нічого не змінюючи
    python3 deploy_semantic_model.py --workspace <ws-id> --dry-run

Потрібні права: Contributor або вище у воркспейсі.
"""

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request

API = "https://api.fabric.microsoft.com/v1"
HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_FOLDER = os.path.join(HERE, "PharmaSalesGold.SemanticModel")


def get_token_from_az() -> str:
    try:
        out = subprocess.run(
            ["az", "account", "get-access-token",
             "--resource", "https://api.fabric.microsoft.com",
             "--query", "accessToken", "-o", "tsv"],
            capture_output=True, text=True, check=True)
        return out.stdout.strip()
    except FileNotFoundError:
        sys.exit("az CLI не знайдено. Передайте токен через --token або встановіть Azure CLI.")
    except subprocess.CalledProcessError as e:
        sys.exit(f"az не віддав токен: {e.stderr.strip()}\nСпробуйте 'az login'.")


def collect_parts(folder: str) -> list:
    """Усі файли моделі -> parts для API. .platform не надсилаємо: displayName
    передається окремо, а logicalId Fabric призначає сам."""
    parts = []
    for root, _, files in os.walk(folder):
        for f in sorted(files):
            full = os.path.join(root, f)
            rel = os.path.relpath(full, folder).replace(os.sep, "/")
            if rel == ".platform":
                continue
            with open(full, "rb") as fh:
                payload = base64.b64encode(fh.read()).decode("ascii")
            parts.append({"path": rel, "payload": payload, "payloadType": "InlineBase64"})
    return parts


GUID_RE = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-"
                     r"[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")


def check_connection(folder: str) -> None:
    """Підключення до whgold має бути заповнене й синтаксично валідне.
    Найчастіша помилка — item id, скопійований з зайвим або втраченим символом:
    модель створиться, але таблиці будуть порожні."""
    expr = os.path.join(folder, "definition", "expressions.tmdl")
    text = open(expr, encoding="utf-8").read()

    if "<SQL_ENDPOINT>" in text or "<WHGOLD_ITEM_ID>" in text:
        sys.exit("У definition/expressions.tmdl лишились плейсхолдери "
                 "<SQL_ENDPOINT> / <WHGOLD_ITEM_ID> — підставте значення warehouse whgold.")

    m = re.search(r'Sql\.Database\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*\)', text)
    if not m:
        sys.exit("У definition/expressions.tmdl не знайдено виклик "
                 'Sql.Database("<endpoint>", "<item-id>") — перевірте файл.')

    endpoint, item_id = m.group(1), m.group(2)

    if not endpoint.endswith(".fabric.microsoft.com"):
        sys.exit(f"Підозрілий SQL endpoint: {endpoint}\n"
                 "Очікується хост виду <...>.datawarehouse.fabric.microsoft.com")

    if not GUID_RE.match(item_id):
        blocks = "-".join(str(len(b)) for b in item_id.split("-"))
        sys.exit(f"Item id warehouse невалідний: {item_id}\n"
                 f"  довжини блоків: {blocks}, очікується 8-4-4-4-12\n"
                 "  Візьміть id з URL айтема whgold у Fabric: .../warehouses/<id>")

    print(f"Підключення: {endpoint}")
    print(f"Warehouse id: {item_id}")


def request(method: str, url: str, token: str, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read().decode() or "{}"
            return resp.status, dict(resp.headers), json.loads(raw) if raw.strip() else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode()
        sys.exit(f"{method} {url}\nHTTP {e.code}: {detail}")


def wait_for_operation(headers: dict, token: str) -> None:
    loc = headers.get("Location")
    if not loc:
        return
    for _ in range(60):
        time.sleep(3)
        status, _, body = request("GET", loc, token)
        state = body.get("status")
        if state in ("Succeeded", "Completed"):
            return
        if state == "Failed":
            sys.exit(f"Операція Fabric завершилась помилкою: {json.dumps(body, ensure_ascii=False)}")
    print("  ! операція ще виконується — перевірте статус у воркспейсі")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--workspace", required=True, help="ID воркспейса Fabric")
    ap.add_argument("--folder", default=DEFAULT_FOLDER, help="шлях до *.SemanticModel")
    ap.add_argument("--name", default="PharmaSalesGold", help="displayName айтема")
    ap.add_argument("--token", help="access token; без нього береться з az CLI")
    ap.add_argument("--item-id", help="id наявної моделі; тоді пошук за назвою не робиться. "
                                      "Корисно, коли модель створена в UI, а сюди підвантажується "
                                      "лише визначення — так обходиться привʼязка джерела при create")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    check_connection(args.folder)
    parts = collect_parts(args.folder)
    print(f"Файлів у визначенні: {len(parts)}")
    for p in parts:
        print(f"  {p['path']}")

    if args.dry_run:
        print("\n--dry-run: нічого не надіслано")
        return

    token = args.token or get_token_from_az()

    if args.item_id:
        existing = {"id": args.item_id}
    else:
        _, _, listing = request("GET", f"{API}/workspaces/{args.workspace}/semanticModels", token)
        existing = next((i for i in listing.get("value", []) if i.get("displayName") == args.name), None)

    definition = {"parts": parts}
    if existing:
        item_id = existing["id"]
        print(f"\nЗнайдено наявну модель {item_id} — оновлюю визначення")
        status, headers, _ = request(
            "POST",
            # updateMetadata не вмикаємо: .platform у parts не йде, оновлюємо лише визначення
            f"{API}/workspaces/{args.workspace}/semanticModels/{item_id}/updateDefinition",
            token, {"definition": definition})
    else:
        print("\nМоделі з такою назвою немає — створюю")
        status, headers, _ = request(
            "POST", f"{API}/workspaces/{args.workspace}/semanticModels", token,
            {"displayName": args.name,
             "description": "Семантична модель над gold-шаром (whgold.dwh)",
             "definition": definition})

    if status == 202:
        print("  Fabric прийняв запит, чекаю завершення…")
        wait_for_operation(headers, token)
    print("Готово. Перевірте модель у воркспейсі та оновіть облікові дані підключення "
          "(Settings → Data source credentials), якщо Fabric попросить.")


if __name__ == "__main__":
    main()
