#!/usr/bin/env python3
"""
Generate referentially-consistent sample data for the Pharma Sales sample star schema.

Outputs (into ../data by default):
  * one CSV per table  (<Table>.csv)               - for bulk load / inspection
  * insert_sample_data.sql                          - T-SQL INSERT script for the [dwh] schema

The generator builds dimensions first, then facts that only reference durable keys
(SK*KeyID) that actually exist, so the result loads cleanly against the DDL in ../ddl.

Deterministic: uses a fixed RANDOM_SEED so re-runs produce identical data.
Pure standard library - no third-party dependencies.

Usage:
    python generate_sample_data.py                 # default volumes, output to ../data
    python generate_sample_data.py --out ./out --sales-rows 5000 --seed 7
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import os
import random

# --------------------------------------------------------------------------------------
# Configuration defaults
# --------------------------------------------------------------------------------------
RANDOM_SEED = 42
DATE_START = dt.date(2025, 1, 1)
DATE_END = dt.date(2025, 12, 31)
N_EMPLOYEES = 25
N_CLIENTS = 200
N_PRODUCTS = 30
LOADED_BY = "sample_data_generator"
LOAD_TS = "2026-01-05 08:00:00.000"
CURRENCY = "UAH"

# --------------------------------------------------------------------------------------
# Reference value pools (kept small & realistic for a pharma CRM/sales model)
# --------------------------------------------------------------------------------------
COUNTRY = "Ukraine"
REGIONS = ["Kyiv", "Lviv", "Kharkiv", "Odesa", "Dnipro", "Vinnytsia", "Zaporizhzhia", "Poltava"]
CITIES = {
    "Kyiv": ["Kyiv", "Bila Tserkva", "Brovary"],
    "Lviv": ["Lviv", "Drohobych", "Chervonohrad"],
    "Kharkiv": ["Kharkiv", "Lozova", "Izium"],
    "Odesa": ["Odesa", "Izmail", "Chornomorsk"],
    "Dnipro": ["Dnipro", "Kryvyi Rih", "Kamianske"],
    "Vinnytsia": ["Vinnytsia", "Zhmerynka"],
    "Zaporizhzhia": ["Zaporizhzhia", "Melitopol"],
    "Poltava": ["Poltava", "Kremenchuk"],
}
FIRST_NAMES = ["Oleksandr", "Iryna", "Andriy", "Olena", "Dmytro", "Kateryna", "Serhiy",
               "Nataliia", "Volodymyr", "Yuliia", "Taras", "Mariia", "Ihor", "Anna",
               "Mykola", "Sofiia", "Roman", "Viktoriia", "Pavlo", "Oksana"]
LAST_NAMES = ["Shevchenko", "Melnyk", "Kovalenko", "Bondarenko", "Tkachenko", "Kravchuk",
              "Oliynyk", "Shevchuk", "Polishchuk", "Boyko", "Marchenko", "Lysenko",
              "Rudenko", "Moroz", "Savchenko", "Petrenko", "Kovalchuk", "Palamarchuk"]
PROFILES = ["Medical Representative", "Key Account Manager", "District Manager", "Regional Manager"]
DIRECTIONS = ["Cardio", "Neuro", "Respiratory", "Gastro", "Consumer Health"]
DIVISIONS = ["Rx Franchise", "OTC Franchise", "Hospital Franchise"]

ACCOUNT_TYPES = ["HCP", "Pharmacy", "Hospital", "Distributor"]
SPECIALTIES = ["Cardiology", "Neurology", "Pulmonology", "Gastroenterology", "General Practice",
               "Pediatrics", "Endocrinology", "N/A"]
CATEGORIES = ["A", "B", "C"]

BRANDS = ["Cardioton", "Neurovit", "Respirex", "Gastrocalm", "Immunoboost", "Dermacare"]
PRODUCT_CATEGORIES = ["Rx", "OTC", "FMCG"]
THERAPEUTIC_AREAS = ["Cardiovascular", "Neurology", "Respiratory", "Gastroenterology",
                     "Immunology", "Dermatology"]
PACK_SIZES = ["10 tab", "20 tab", "30 tab", "50 ml", "100 ml", "14 caps", "28 caps"]

# Activity types (fixed small dimension). Tuple: (name, category, channel, segment_type)
ACTIVITY_TYPES = [
    ("1:1 Visit", "Visit", "F2F", "Contact"),
    ("Office Visit", "Visit", "F2F", "Account"),
    ("Pharmacy Visit", "Visit", "F2F", "Account"),
    ("Remote Detailing", "Call", "Remote", "Contact"),
    ("Phone Call", "Call", "Phone", "Contact"),
    ("Group Event", "Event", "F2F", "Account"),
]

VISIT_STATUS = ["Completed", "Completed", "Completed", "Planned", "Cancelled"]
SALES_CHANNELS = ["Direct", "Distributor", "Pharmacy"]


# --------------------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------------------
def sf_id(prefix: str, n: int) -> str:
    """Fabricate a Salesforce-like 18-char business id."""
    return f"{prefix}{n:015d}"[:18].ljust(18, "0")


def date_key(d: dt.date) -> int:
    return d.year * 10000 + d.month * 100 + d.day


def daterange(start: dt.date, end: dt.date):
    cur = start
    while cur <= end:
        yield cur
        cur += dt.timedelta(days=1)


def month_firsts(start: dt.date, end: dt.date):
    d = dt.date(start.year, start.month, 1)
    while d <= end:
        yield d
        d = dt.date(d.year + (d.month // 12), (d.month % 12) + 1, 1)


# --------------------------------------------------------------------------------------
# Dimension builders  (each returns list-of-dict rows; row 0 is the -1 Unknown member)
# --------------------------------------------------------------------------------------
def build_dim_date(start: dt.date, end: dt.date):
    rows = [dict(SKDateID=-1, SKDateKeyID=-1, DateValue=None, DayOfMonth=None, DayOfWeek=None,
                 DayName="N/A", WeekOfYear=None, MonthNumber=None, MonthName="N/A",
                 Quarter=None, Year=None, YearMonth=None, IsWeekend=None,
                 CreatedBy="init_insert", CreatedAt="2000-01-01 00:00:00.000")]
    for d in daterange(start, end):
        dk = date_key(d)
        iso_dow = d.isoweekday()  # 1=Mon..7=Sun
        rows.append(dict(
            SKDateID=dk, SKDateKeyID=dk, DateValue=d.isoformat(),
            DayOfMonth=d.day, DayOfWeek=iso_dow, DayName=d.strftime("%A"),
            WeekOfYear=int(d.strftime("%V")), MonthNumber=d.month, MonthName=d.strftime("%B"),
            Quarter=(d.month - 1) // 3 + 1, Year=d.year, YearMonth=d.year * 100 + d.month,
            IsWeekend=1 if iso_dow >= 6 else 0,
            CreatedBy=LOADED_BY, CreatedAt=LOAD_TS))
    return rows


def build_dim_employee(rng: random.Random, n: int):
    rows = [dict(SKEmployeeID=-1, SKEmployeeKeyID=-1, StartDate="2000-01-01 00:00:00.000",
                 EndDate=None, IsDeleted=0, CreatedBy="init_insert", ModifiedBy=None,
                 CreatedAt="2000-01-01 00:00:00.000", ModifiedAt=None, Id="N/A", Name="N/A",
                 FirstName="N/A", LastName="N/A", Email="N/A", MobilePhone="N/A",
                 ProfileName="N/A", ManagerId="N/A", Direction="N/A", Division="N/A",
                 Territory="N/A", RegionName="N/A", CountryName="N/A", IsActive=0)]
    sk = 0
    key = 0
    managers = []  # (key business id) of managers to reference
    for i in range(1, n + 1):
        key += 1
        sk += 1
        fn = rng.choice(FIRST_NAMES)
        ln = rng.choice(LAST_NAMES)
        region = rng.choice(REGIONS)
        biz_id = sf_id("005", i)
        profile = rng.choices(PROFILES, weights=[60, 15, 15, 10])[0]
        mgr = rng.choice(managers) if managers and profile == "Medical Representative" else "N/A"
        rows.append(dict(
            SKEmployeeID=sk, SKEmployeeKeyID=key, StartDate="2025-01-01 00:00:00.000",
            EndDate=None, IsDeleted=0, CreatedBy=LOADED_BY, ModifiedBy=None, CreatedAt=LOAD_TS,
            ModifiedAt=None, Id=biz_id, Name=f"{fn} {ln}", FirstName=fn, LastName=ln,
            Email=f"{fn.lower()}.{ln.lower()}@example-pharma.com",
            MobilePhone=f"+3806{rng.randint(10000000, 99999999)}",
            ProfileName=profile, ManagerId=mgr, Direction=rng.choice(DIRECTIONS),
            Division=rng.choice(DIVISIONS), Territory=f"T-{region[:3].upper()}-{rng.randint(1, 9)}",
            RegionName=region, CountryName=COUNTRY, IsActive=1))
        if profile in ("District Manager", "Regional Manager"):
            managers.append(biz_id)

        # Demonstrate SCD2: ~15% of reps changed territory mid-year -> add an expired version.
        if profile == "Medical Representative" and rng.random() < 0.15:
            rows[-1]["EndDate"] = "2025-06-30 23:59:59.000"  # close the first version
            rows[-1]["StartDate"] = "2025-01-01 00:00:00.000"
            sk += 1
            new_region = rng.choice([r for r in REGIONS if r != region])
            rows.append(dict(
                SKEmployeeID=sk, SKEmployeeKeyID=key, StartDate="2025-07-01 00:00:00.000",
                EndDate=None, IsDeleted=0, CreatedBy=LOADED_BY, ModifiedBy=LOADED_BY,
                CreatedAt=LOAD_TS, ModifiedAt=LOAD_TS, Id=biz_id, Name=f"{fn} {ln}",
                FirstName=fn, LastName=ln,
                Email=f"{fn.lower()}.{ln.lower()}@example-pharma.com",
                MobilePhone=f"+3806{rng.randint(10000000, 99999999)}",
                ProfileName=profile, ManagerId=mgr, Direction=rng.choice(DIRECTIONS),
                Division=rng.choice(DIVISIONS),
                Territory=f"T-{new_region[:3].upper()}-{rng.randint(1, 9)}",
                RegionName=new_region, CountryName=COUNTRY, IsActive=1))
    return rows, list(range(1, n + 1))  # durable keys 1..n


def build_dim_client(rng: random.Random, n: int):
    rows = [dict(SKClientAccountID=-1, SKClientAccountKeyID=-1, StartDate="2000-01-01 00:00:00.000",
                 EndDate=None, IsDeleted=0, CreatedBy="init_insert", ModifiedBy=None,
                 CreatedAt="2000-01-01 00:00:00.000", ModifiedAt=None, Id="N/A", Name="N/A",
                 AccountType="N/A", RecordType="N/A", Specialty="N/A", Category="N/A",
                 Address="N/A", City="N/A", RegionName="N/A", CountryName="N/A",
                 PostalCode="N/A", IsActive=0)]
    sk = 0
    for i in range(1, n + 1):
        sk += 1
        atype = rng.choices(ACCOUNT_TYPES, weights=[55, 30, 10, 5])[0]
        region = rng.choice(REGIONS)
        city = rng.choice(CITIES[region])
        specialty = rng.choice(SPECIALTIES) if atype == "HCP" else "N/A"
        name = {
            "HCP": f"Dr. {rng.choice(FIRST_NAMES)} {rng.choice(LAST_NAMES)}",
            "Pharmacy": f"Pharmacy #{rng.randint(1, 999)} {city}",
            "Hospital": f"{city} Clinical Hospital #{rng.randint(1, 20)}",
            "Distributor": f"{rng.choice(['Pharma', 'Medi', 'Health'])}Dist LLC",
        }[atype]
        rows.append(dict(
            SKClientAccountID=sk, SKClientAccountKeyID=i, StartDate="2025-01-01 00:00:00.000",
            EndDate=None, IsDeleted=0, CreatedBy=LOADED_BY, ModifiedBy=None, CreatedAt=LOAD_TS,
            ModifiedAt=None, Id=sf_id("001", i), Name=name, AccountType=atype,
            RecordType=atype, Specialty=specialty, Category=rng.choices(CATEGORIES, weights=[25, 45, 30])[0],
            Address=f"{rng.randint(1, 200)} {rng.choice(['Shevchenka', 'Franka', 'Lesi Ukrainky', 'Sadova'])} St.",
            City=city, RegionName=region, CountryName=COUNTRY,
            PostalCode=f"{rng.randint(1, 99):02d}{rng.randint(100, 999)}", IsActive=1))
    return rows, list(range(1, n + 1))


def build_dim_product(rng: random.Random, n: int):
    rows = [dict(SKProductID=-1, SKProductKeyID=-1, StartDate="2000-01-01 00:00:00.000",
                 EndDate=None, IsDeleted=0, CreatedBy="init_insert", ModifiedBy=None,
                 CreatedAt="2000-01-01 00:00:00.000", ModifiedAt=None, Id="N/A", Name="N/A",
                 Brand="N/A", ProductCategory="N/A", TherapeuticArea="N/A", ATCCode="N/A",
                 PackSize="N/A", UnitPrice=0.00, Currency="N/A", IsActive=0, ExternalId="N/A")]
    for i in range(1, n + 1):
        idx = (i - 1) % len(BRANDS)
        brand = BRANDS[idx]
        rows.append(dict(
            SKProductID=i, SKProductKeyID=i, StartDate="2025-01-01 00:00:00.000", EndDate=None,
            IsDeleted=0, CreatedBy=LOADED_BY, ModifiedBy=None, CreatedAt=LOAD_TS, ModifiedAt=None,
            Id=sf_id("01t", i), Name=f"{brand} {rng.choice(PACK_SIZES)}", Brand=brand,
            ProductCategory=rng.choices(PRODUCT_CATEGORIES, weights=[50, 35, 15])[0],
            TherapeuticArea=THERAPEUTIC_AREAS[idx],
            ATCCode=f"{rng.choice('ABCGJLMNR')}{rng.randint(1, 9):02d}{rng.choice('ABCDX')}{rng.randint(1, 9):02d}",
            PackSize=rng.choice(PACK_SIZES), UnitPrice=round(rng.uniform(35, 850), 2),
            Currency=CURRENCY, IsActive=1, ExternalId=f"EXT-{i:05d}"))
    return rows, list(range(1, n + 1))


def build_dim_activity_type():
    rows = [dict(SKActivityTypeID=-1, SKActivityTypeKeyID=-1, StartDate="2000-01-01 00:00:00.000",
                 EndDate=None, IsDeleted=0, CreatedBy="init_insert", ModifiedBy=None,
                 CreatedAt="2000-01-01 00:00:00.000", ModifiedAt=None, Id="N/A", Name="N/A",
                 Category="N/A", Channel="N/A", SegmentType="N/A", IsActive=0)]
    for i, (name, cat, chan, seg) in enumerate(ACTIVITY_TYPES, start=1):
        rows.append(dict(
            SKActivityTypeID=i, SKActivityTypeKeyID=i, StartDate="2025-01-01 00:00:00.000",
            EndDate=None, IsDeleted=0, CreatedBy=LOADED_BY, ModifiedBy=None, CreatedAt=LOAD_TS,
            ModifiedAt=None, Id=sf_id("012", i), Name=name, Category=cat, Channel=chan,
            SegmentType=seg, IsActive=1))
    return rows, list(range(1, len(ACTIVITY_TYPES) + 1))


# --------------------------------------------------------------------------------------
# Fact builders
# --------------------------------------------------------------------------------------
def build_fct_sales(rng, n_rows, day_keys, emp_keys, client_keys, product_keys, product_price):
    rows = []
    for i in range(1, n_rows + 1):
        qty = rng.randint(1, 60)
        pk = rng.choice(product_keys)
        gross = round(qty * product_price[pk], 2)
        disc = round(gross * rng.choice([0, 0, 0.05, 0.1, 0.15]), 2)
        rows.append(dict(
            SKFctSalesID=i, SKDateKeyID=rng.choice(day_keys), SKEmployeeKeyID=rng.choice(emp_keys),
            SKClientAccountKeyID=rng.choice(client_keys), SKProductKeyID=pk,
            InvoiceNumber=f"INV-2025-{i:07d}", SalesChannel=rng.choice(SALES_CHANNELS),
            QuantityUnits=qty, GrossAmount=gross, DiscountAmount=disc,
            NetAmount=round(gross - disc, 2), Currency=CURRENCY,
            CreatedBy=LOADED_BY, CreatedAt=LOAD_TS))
    return rows


def build_fct_sales_plan(rng, months, emp_keys, product_keys, product_price):
    rows = []
    i = 0
    for m in months:
        dk = date_key(m)
        for ek in emp_keys:
            # each rep plans a random basket of 3-6 products per month
            for pk in rng.sample(product_keys, k=rng.randint(3, 6)):
                i += 1
                units = rng.randint(50, 500)
                rows.append(dict(
                    SKFctSalesPlanID=i, SKDateKeyID=dk, SKEmployeeKeyID=ek, SKProductKeyID=pk,
                    Period=m.isoformat(), PlanVersion="V1",
                    PlannedUnits=units, PlannedAmount=round(units * product_price[pk], 2),
                    Currency=CURRENCY, CreatedBy=LOADED_BY, CreatedAt=LOAD_TS))
    return rows


def build_fct_visit(rng, n_rows, day_keys, emp_keys, client_keys, activity_keys):
    rows = []
    for i in range(1, n_rows + 1):
        status = rng.choice(VISIT_STATUS)
        completed = 1 if status == "Completed" else 0
        rows.append(dict(
            SKFctVisitID=i, SKDateKeyID=rng.choice(day_keys), SKEmployeeKeyID=rng.choice(emp_keys),
            SKClientAccountKeyID=rng.choice(client_keys), SKActivityTypeKeyID=rng.choice(activity_keys),
            ActivityId=sf_id("00T", i), VisitStatus=status, VisitCount=1,
            DurationMinutes=rng.choice([15, 20, 30, 45, 60]) if completed else None,
            DetailedProductsCount=rng.randint(1, 4) if completed else 0,
            IsCompleted=completed, CreatedBy=LOADED_BY, CreatedAt=LOAD_TS))
    return rows


def build_fct_target_frequency(rng, months, emp_keys, client_keys, activity_keys):
    rows = []
    i = 0
    for m in months:
        dk = date_key(m)
        for ek in emp_keys:
            # each rep has a call plan for a subset of clients
            for ck in rng.sample(client_keys, k=min(len(client_keys), rng.randint(8, 15))):
                i += 1
                seg_activity = rng.choice(activity_keys)
                rows.append(dict(
                    SKFctTargetFrequencyID=i, SKDateKeyID=dk, SKEmployeeKeyID=ek,
                    SKClientAccountKeyID=ck, SKActivityTypeKeyID=seg_activity,
                    Period=m.isoformat(),
                    TargetFrequencyStatus=rng.choices(["Active", "Draft", "Closed"], weights=[70, 15, 15])[0],
                    SegmentType=rng.choice(["Contact", "Account"]),
                    QuantityVisitsPlanned=rng.randint(1, 4),
                    CreatedBy=LOADED_BY, CreatedAt=LOAD_TS))
    return rows


def build_fct_inventory(rng, months, client_keys, product_keys, product_price):
    """Monthly stock snapshot for pharmacy/distributor accounts (subset of clients)."""
    rows = []
    i = 0
    stock_clients = rng.sample(client_keys, k=max(1, len(client_keys) // 3))
    for m in months:
        # snapshot taken on the last day of the month
        nxt = dt.date(m.year + (m.month // 12), (m.month % 12) + 1, 1)
        snap = nxt - dt.timedelta(days=1)
        dk = date_key(snap)
        for ck in stock_clients:
            for pk in rng.sample(product_keys, k=rng.randint(2, 5)):
                i += 1
                on_hand = rng.randint(0, 300)
                sold = rng.randint(0, 150)
                received = rng.randint(0, 200)
                rows.append(dict(
                    SKFctInventorySnapshotID=i, SKDateKeyID=dk, SKClientAccountKeyID=ck,
                    SKProductKeyID=pk, QuantityOnHand=on_hand, QuantityReceived=received,
                    QuantitySold=sold, StockValue=round(on_hand * product_price[pk], 2),
                    Currency=CURRENCY, CreatedBy=LOADED_BY, CreatedAt=LOAD_TS))
    return rows


# --------------------------------------------------------------------------------------
# Output writers
# --------------------------------------------------------------------------------------
def write_csv(path: str, rows: list[dict]):
    if not rows:
        return
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        for r in rows:
            w.writerow({k: ("" if v is None else v) for k, v in r.items()})


def sql_literal(v) -> str:
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, (int, float)):
        return str(v)
    return "N'" + str(v).replace("'", "''") + "'"


def write_sql(path: str, table: str, rows: list[dict], batch: int = 500):
    """Emit multi-row INSERT statements (Fabric/T-SQL friendly, batched)."""
    if not rows:
        return
    cols = list(rows[0].keys())
    col_list = ", ".join(f"[{c}]" for c in cols)
    with open(path, "a", encoding="utf-8") as f:
        f.write(f"\n-- ---------- {table} ({len(rows)} rows) ----------\n")
        for start in range(0, len(rows), batch):
            chunk = rows[start:start + batch]
            f.write(f"INSERT INTO [dwh].[{table}] ({col_list}) VALUES\n")
            values = ",\n".join(
                "(" + ", ".join(sql_literal(r[c]) for c in cols) + ")" for r in chunk
            )
            f.write(values + ";\nGO\n")


# --------------------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Generate sample data for the pharma sales star schema.")
    default_out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")
    parser.add_argument("--out", default=default_out, help="output directory")
    parser.add_argument("--seed", type=int, default=RANDOM_SEED)
    parser.add_argument("--employees", type=int, default=N_EMPLOYEES)
    parser.add_argument("--clients", type=int, default=N_CLIENTS)
    parser.add_argument("--products", type=int, default=N_PRODUCTS)
    parser.add_argument("--sales-rows", type=int, default=4000)
    parser.add_argument("--visit-rows", type=int, default=3000)
    args = parser.parse_args()

    rng = random.Random(args.seed)
    out = os.path.abspath(args.out)
    os.makedirs(out, exist_ok=True)

    # ---- dimensions ----
    dim_date = build_dim_date(DATE_START, DATE_END)
    dim_emp, emp_keys = build_dim_employee(rng, args.employees)
    dim_client, client_keys = build_dim_client(rng, args.clients)
    dim_product, product_keys = build_dim_product(rng, args.products)
    dim_activity, activity_keys = build_dim_activity_type()

    day_keys = [r["SKDateKeyID"] for r in dim_date if r["SKDateKeyID"] != -1]
    months = list(month_firsts(DATE_START, DATE_END))
    product_price = {r["SKProductKeyID"]: float(r["UnitPrice"]) for r in dim_product if r["SKProductKeyID"] != -1}

    # ---- facts ----
    fct_sales = build_fct_sales(rng, args.sales_rows, day_keys, emp_keys, client_keys, product_keys, product_price)
    fct_plan = build_fct_sales_plan(rng, months, emp_keys, product_keys, product_price)
    fct_visit = build_fct_visit(rng, args.visit_rows, day_keys, emp_keys, client_keys, activity_keys)
    fct_target = build_fct_target_frequency(rng, months, emp_keys, client_keys, activity_keys)
    fct_inv = build_fct_inventory(rng, months, client_keys, product_keys, product_price)

    tables = [
        ("DimDate", dim_date), ("DimEmployee", dim_emp), ("DimClientAccount", dim_client),
        ("DimProduct", dim_product), ("DimActivityType", dim_activity),
        ("FctSales", fct_sales), ("FctSalesPlan", fct_plan), ("FctVisit", fct_visit),
        ("FctTargetFrequency", fct_target), ("FctInventorySnapshot", fct_inv),
    ]

    # CSVs
    for name, rows in tables:
        write_csv(os.path.join(out, f"{name}.csv"), rows)

    # Single SQL insert script (dimensions first, then facts - matches FK order)
    sql_path = os.path.join(out, "insert_sample_data.sql")
    header = (
        "/* Auto-generated sample data for [dwh] pharma sales star schema.\n"
        f"   Generated by generate_sample_data.py (seed={args.seed}).\n"
        "   Run AFTER ../ddl/build_all.sql has created the tables.\n"
        "   Load order below respects dimension -> fact dependencies. */\n"
        "SET NOCOUNT ON;\nGO\n"
    )
    with open(sql_path, "w", encoding="utf-8") as f:
        f.write(header)
    for name, rows in tables:
        write_sql(sql_path, name, rows)

    # Summary
    print(f"Output directory: {out}")
    print(f"{'TABLE':<24}{'ROWS':>10}")
    print("-" * 34)
    total = 0
    for name, rows in tables:
        total += len(rows)
        print(f"{name:<24}{len(rows):>10}")
    print("-" * 34)
    print(f"{'TOTAL':<24}{total:>10}")
    print(f"\nWrote {len(tables)} CSV files + insert_sample_data.sql")


if __name__ == "__main__":
    main()
