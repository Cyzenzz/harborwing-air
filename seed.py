#!/usr/bin/env python3
"""
HarborWing Air - synthetic data generator.

Fills all 11 tables (parents first, then children) with fictional data.
Repeatable: a fixed seed (42) gives the same dataset on every run.

Usage:
    pip install -r requirements.txt
    python seed.py            # seed an EMPTY database
    python seed.py --reset    # wipe all rows, then seed again

Connection settings come from environment variables (never hard-code a
password in a file you push to GitHub):
    DB_HOST (default localhost)   DB_PORT (default 3306)
    DB_USER (default root)        DB_PASSWORD (prompted if not set)
    DB_NAME (default harborwing)
"""
import argparse
import getpass
import os
import random
import string
import sys
from datetime import date, datetime, timedelta
from decimal import Decimal

import mysql.connector
from faker import Faker

# ---------------------------------------------------------------- settings
SEED = 42
random.seed(SEED)
Faker.seed(SEED)
fake = Faker("en_US")

N_AGENTS = 60
N_PASSENGERS = 80
N_AIRPORTS = 55
N_SCHEDULES = 60
N_LEGS = 120
N_RESERVATIONS = 100
N_PAYMENTS = 80

CAL_START = date(2026, 1, 1)
CAL_END = date(2027, 12, 31)
REFERENCE_NOW = datetime(2026, 10, 16)   # flights before this date "have operated"

# Reference codes: externally managed, NOT enforced by foreign keys.
AIRLINE_CODE = "HW"
AIRCRAFT_TYPES = ["AT72", "DH8D", "E145", "B190"]
RES_STATUS = ["CONF", "PEND", "CANC"]
TICKET_TYPES = ["ONEWAY", "RETURN", "MULTI"]
TRAVEL_CLASSES = ["ECON", "PREM", "BUS"]
PAY_STATUS = ["PAID", "PEND", "FAIL", "RFND"]

# Child tables first (used for the reset and the row counts)
TABLES_CHILD_FIRST = [
    "reservation_leg", "reservation_payment", "flight_cost", "flight_leg",
    "reservation", "payment", "flight_schedule", "calendar_date",
    "airport", "passenger", "booking_agent",
]


# ---------------------------------------------------------------- helpers
def money(low_cents, high_cents):
    """Random positive Decimal with 2 decimal places."""
    return (Decimal(random.randint(low_cents, high_cents)) / 100).quantize(Decimal("0.01"))


def rand_datetime(start, end):
    seconds = int((end - start).total_seconds())
    return start + timedelta(seconds=random.randint(0, seconds))


def connect(args):
    password = os.environ.get("DB_PASSWORD") or getpass.getpass("MySQL password: ")
    return mysql.connector.connect(
        host=args.host, port=args.port, user=args.user,
        password=password, database=args.database,
    )


def table_counts(cur):
    counts = {}
    for t in TABLES_CHILD_FIRST:
        cur.execute(f"SELECT COUNT(*) FROM {t}")
        counts[t] = cur.fetchone()[0]
    return counts


def reset_tables(cur):
    """Documented reset: empty every table and restart AUTO_INCREMENT at 1."""
    cur.execute("SET FOREIGN_KEY_CHECKS = 0")
    for t in TABLES_CHILD_FIRST:
        cur.execute(f"TRUNCATE TABLE {t}")
    cur.execute("SET FOREIGN_KEY_CHECKS = 1")


# ---------------------------------------------------------------- seeders
def seed_agents(cur):
    ids = []
    for _ in range(N_AGENTS):
        cur.execute(
            "INSERT INTO booking_agent (agent_name, agent_details) VALUES (%s, %s)",
            (fake.company()[:100], fake.catch_phrase()[:255]),
        )
        ids.append(cur.lastrowid)
    return ids


def seed_passengers(cur):
    ids = []
    for _ in range(N_PASSENGERS):
        cur.execute(
            """INSERT INTO passenger
               (first_name, second_name, last_name, phone, email,
                address_line1, address_line2, city, state_province,
                country, other_details)
               VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
            (
                fake.first_name()[:50],
                fake.first_name()[:50] if random.random() < 0.4 else None,
                fake.last_name()[:50],
                fake.phone_number()[:30],
                fake.unique.email()[:120],
                fake.street_address()[:100],
                fake.secondary_address()[:100] if random.random() < 0.3 else None,
                fake.city()[:60],
                fake.state()[:60] if random.random() < 0.8 else None,
                fake.country()[:60],
                "Synthetic passenger" if random.random() < 0.2 else None,
            ),
        )
        ids.append(cur.lastrowid)
    return ids


def seed_airports(cur):
    """Fictional 3-letter codes. Labelled as demonstration data."""
    codes = set()
    while len(codes) < N_AIRPORTS:
        codes.add("".join(random.choices(string.ascii_uppercase, k=3)))
    codes = sorted(codes)
    for code in codes:
        city = fake.city()
        cur.execute(
            """INSERT INTO airport (airport_code, airport_name, location, other_details)
               VALUES (%s,%s,%s,%s)""",
            (code, f"{city} Regional Airport"[:100],
             f"{city}, {fake.country()}"[:100],
             "DEMONSTRATION DATA - fictional airport code"),
        )
    return codes


def seed_calendar(cur):
    rows, d = [], CAL_START
    while d <= CAL_END:
        rows.append((d, d.day, 1 if d.weekday() < 5 else 0))   # Mon-Fri = business day
        d += timedelta(days=1)
    cur.executemany(
        "INSERT INTO calendar_date (calendar_date, day_of_month, is_business_day) VALUES (%s,%s,%s)",
        rows,
    )
    return len(rows)


def seed_schedules(cur, airports):
    numbers = random.sample(range(100, 1000), N_SCHEDULES)   # unique flight numbers
    schedules = []   # (flight_number, aircraft, origin, dest, dep, arr)
    for n in numbers:
        fn = f"{AIRLINE_CODE}{n}"
        aircraft = random.choice(AIRCRAFT_TYPES)
        origin, dest = random.sample(airports, 2)             # always different
        dep = (datetime(2026, 1, 1) + timedelta(days=random.randint(0, 540),
               hours=random.randint(5, 22), minutes=random.choice([0, 15, 30, 45])))
        arr = dep + timedelta(minutes=random.randint(45, 240))  # always after departure
        cur.execute(
            """INSERT INTO flight_schedule
               (flight_number, airline_code, aircraft_type_code, origin_airport,
                destination_airport, sched_departure_utc, sched_arrival_utc)
               VALUES (%s,%s,%s,%s,%s,%s,%s)""",
            (fn, AIRLINE_CODE, aircraft, origin, dest, dep, arr),
        )
        schedules.append((fn, aircraft, origin, dest, dep, arr))
    return schedules


def seed_legs(cur, schedules):
    """Every schedule gets at least one leg; the rest are random (so some have several)."""
    picks = list(range(len(schedules))) + [
        random.randrange(len(schedules)) for _ in range(N_LEGS - len(schedules))
    ]
    ids = []
    for i in picks:
        fn, _, origin, dest, s_dep, s_arr = schedules[i]
        planned = s_arr - s_dep
        if s_dep < REFERENCE_NOW and random.random() > 0.08:
            a_dep = s_dep + timedelta(minutes=random.randint(-5, 45))
            a_arr = a_dep + planned + timedelta(minutes=random.randint(-10, 30))
            if a_arr <= a_dep:
                a_arr = a_dep + timedelta(minutes=30)
        else:
            a_dep = a_arr = None          # not operated yet (or unknown)
        cur.execute(
            """INSERT INTO flight_leg
               (flight_number, origin_airport, destination_airport,
                actual_departure_utc, actual_arrival_utc)
               VALUES (%s,%s,%s,%s,%s)""",
            (fn, origin, dest, a_dep, a_arr),
        )
        ids.append(cur.lastrowid)
    return ids


def seed_costs(cur, schedules):
    """Several non-overlapping validity periods per flight + aircraft type."""
    rows, seen = [], set()

    def add_periods(fn, aircraft, n_periods):
        start = CAL_START + timedelta(days=random.randint(0, 60))
        amount = money(400_000, 1_200_000)
        for _ in range(n_periods):
            if start > CAL_END:
                break
            end = min(start + timedelta(days=random.randint(60, 200) - 1), CAL_END)
            amount = (amount * Decimal(str(round(random.uniform(0.95, 1.15), 3)))).quantize(Decimal("0.01"))
            key = (fn, aircraft, start)
            if key not in seen:                      # composite key never repeats
                seen.add(key)
                rows.append((fn, aircraft, start, end, amount))
            start = end + timedelta(days=1)          # next period starts the day after

    for fn, aircraft, *_ in schedules:
        add_periods(fn, aircraft, random.choice([1, 2, 2, 3]))
        if random.random() < 0.25:                   # occasional substitute aircraft
            other = random.choice([a for a in AIRCRAFT_TYPES if a != aircraft])
            add_periods(fn, other, 1)

    cur.executemany(
        """INSERT INTO flight_cost
           (flight_number, aircraft_type_code, valid_from, valid_to, cost_amount)
           VALUES (%s,%s,%s,%s,%s)""",
        rows,
    )
    return len(rows)


def seed_reservations(cur, passenger_ids, agent_ids):
    ids = []
    for _ in range(N_RESERVATIONS):
        cur.execute(
            """INSERT INTO reservation
               (passenger_id, agent_id, status_code, ticket_type_code,
                travel_class_code, created_at_utc, party_size)
               VALUES (%s,%s,%s,%s,%s,%s,%s)""",
            (
                random.choice(passenger_ids),
                random.choice(agent_ids) if random.random() < 0.6 else None,  # ~40% direct
                random.choice(RES_STATUS),
                random.choice(TICKET_TYPES),
                random.choice(TRAVEL_CLASSES),
                rand_datetime(datetime(2026, 1, 1), REFERENCE_NOW),
                random.choice([1, 1, 1, 2, 2, 3, 4, 5, 6]),
            ),
        )
        ids.append(cur.lastrowid)
    return ids


def seed_payments(cur):
    ids = []
    for _ in range(N_PAYMENTS):
        cur.execute(
            """INSERT INTO payment (payment_status_code, payment_date, amount)
               VALUES (%s,%s,%s)""",
            (
                random.choice(PAY_STATUS),
                CAL_START + timedelta(days=random.randint(0, 288)),
                money(5_000, 300_000),               # always positive
            ),
        )
        ids.append(cur.lastrowid)
    return ids


def seed_reservation_payments(cur, res_ids, pay_ids):
    pairs = set()                                    # set = no duplicate pairs
    for pid in pay_ids:                              # every payment has a home reservation
        pairs.add((random.choice(res_ids), pid))
    for pid in pay_ids[:12]:                         # 12 payments shared by 2-3 reservations
        for rid in random.sample(res_ids, random.randint(2, 3)):
            pairs.add((rid, pid))
    for pid in pay_ids[:4]:                          # reservation #1 has 4 payments
        pairs.add((res_ids[0], pid))
    cur.executemany(
        "INSERT INTO reservation_payment (reservation_id, payment_id) VALUES (%s,%s)",
        sorted(pairs),
    )
    return len(pairs)


def seed_reservation_legs(cur, res_ids, leg_ids):
    pairs = set()
    for rid in res_ids:
        if random.random() < 0.9:                    # ~10% have no legs yet
            k = random.choice([1, 1, 2, 2, 3, 4])
            for lid in random.sample(leg_ids, k):
                pairs.add((rid, lid))
    for lid in random.sample(leg_ids, 4):            # reservation #1 has 4 legs
        pairs.add((res_ids[0], lid))
    cur.executemany(
        "INSERT INTO reservation_leg (reservation_id, leg_id) VALUES (%s,%s)",
        sorted(pairs),
    )
    return len(pairs)


# ---------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(description="Seed the HarborWing Air database.")
    ap.add_argument("--reset", action="store_true", help="empty all tables first")
    ap.add_argument("--host", default=os.environ.get("DB_HOST", "localhost"))
    ap.add_argument("--port", type=int, default=int(os.environ.get("DB_PORT", 3306)))
    ap.add_argument("--user", default=os.environ.get("DB_USER", "root"))
    ap.add_argument("--database", default=os.environ.get("DB_NAME", "harborwing"))
    args = ap.parse_args()

    conn = connect(args)
    cur = conn.cursor()
    try:
        if args.reset:
            reset_tables(cur)
            conn.commit()
            print("Tables emptied.")
        elif any(table_counts(cur).values()):
            print("Database already has data. Run again with --reset to wipe and reseed.")
            sys.exit(1)

        # Parent tables first, then children
        agent_ids = seed_agents(cur)
        passenger_ids = seed_passengers(cur)
        airports = seed_airports(cur)
        seed_calendar(cur)
        schedules = seed_schedules(cur, airports)
        leg_ids = seed_legs(cur, schedules)
        seed_costs(cur, schedules)
        res_ids = seed_reservations(cur, passenger_ids, agent_ids)
        pay_ids = seed_payments(cur)
        seed_reservation_payments(cur, res_ids, pay_ids)
        seed_reservation_legs(cur, res_ids, leg_ids)
        conn.commit()

        print("\nRow counts:")
        counts = table_counts(cur)
        for t in reversed(TABLES_CHILD_FIRST):
            flag = "" if counts[t] >= 50 else "   <-- UNDER 50!"
            print(f"  {t:<22}{counts[t]:>6}{flag}")

        cur.execute("SELECT SUM(agent_id IS NULL), SUM(agent_id IS NOT NULL) FROM reservation")
        direct, agent = cur.fetchone()
        print(f"\nDirect reservations: {direct}   Agent-assisted: {agent}")
    except Exception:
        conn.rollback()
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()
