# HarborWing Air Reservation Database

A relational MySQL database that replaces HarborWing Air's spreadsheets. It stores passengers, booking agents, reservations, payments, airports, flight schedules, flight legs, daily calendar dates, and flight costs, with a Python Faker script that fills it with fictional data.

**Author:** _Your Name_  |  **Course:** IT8 Midterm Drill

## Repository contents

| File | Purpose |
|---|---|
| `harborwing.mwb` | MySQL Workbench model (EER diagram source) |
| `harborwing_diagram.png` / `.pdf` | Exported EER diagram |
| `schema.sql` | Creates all 11 tables, keys, constraints, and indexes |
| `seed.py` | Faker-based data generator (fixed seed 42) |
| `requirements.txt` | Python dependencies |
| `row_counts.sql` | Row count of every table |
| `queries.sql` | Example queries |
| `README.md` | This file |

## How the spreadsheet problems were solved

| Spreadsheet problem | Fix in this design |
|---|---|
| Passenger information repeated | One `passenger` row, referenced by `reservation` |
| Inconsistent airport names | `airport` table; other tables store only the airport code |
| Connecting legs hard to track | `flight_leg` table plus the `reservation_leg` link table |
| Payments covering several reservations duplicated | One `payment` row linked through `reservation_payment` |
| Actual times overwrite scheduled times | Separate scheduled columns (`flight_schedule`) and actual columns (`flight_leg`) |
| Cost updates remove old costs | `flight_cost` rows with validity dates; old rows are kept |

---

## Setup (create, seed, query)

### Requirements

- MySQL Server **8.0.16 or later** (earlier versions ignore `CHECK` constraints)
- MySQL Workbench (to open the `.mwb` model)
- Python 3.9+ 

### 1. Create the database

In MySQL Workbench (or the `mysql` command line), run:

```sql
CREATE DATABASE harborwing CHARACTER SET utf8mb4;
```

Then run `schema.sql`, which begins with `USE harborwing;` and creates all 11 tables. Check with:

```sql
SHOW TABLES;   -- 11 tables
```

### 2. Install the Python dependencies

```bash
pip install -r requirements.txt
```

On Windows, if `pip` is not recognized, use `py -m pip install -r requirements.txt`.

### 3. Seed the database

Set your MySQL password as an environment variable so it is never stored in the repository (or leave it unset and the script will prompt for it):

```bash
# Windows (Command Prompt)
set DB_PASSWORD=your_password
# macOS / Linux
export DB_PASSWORD=your_password

python seed.py          # use "py seed.py" on Windows if "python" is not found
```

Optional settings: `DB_HOST` (default `localhost`), `DB_PORT` (`3306`), `DB_USER` (`root`), `DB_NAME` (`harborwing`).

### 4. Reset and re-seed

`seed.py` refuses to run on a database that already has data. To wipe every table and generate the data again:

```bash
python seed.py --reset
```

The reset truncates every table (with foreign key checks switched off for that step only) and restarts the auto-increment counters. Because the random seed is fixed at **42**, every run produces the same dataset.

### 5. Verify and query

Run `row_counts.sql` to see the row count of every table (all should be 50 or more), then try the queries in `queries.sql`.

Expected counts from the default seed:

| Table | Rows |
|---|---|
| booking_agent | 60 |
| passenger | 80 |
| airport | 55 |
| calendar_date | 730 |
| flight_schedule | 60 |
| flight_leg | 120 |
| flight_cost | 143 |
| reservation | 100 |
| payment | 80 |
| reservation_payment | 114 |
| reservation_leg | 195 |

---

## The tables and their purpose

| Table | Purpose |
|---|---|
| `booking_agent` | Agents who book on behalf of customers (ID, name, details) |
| `passenger` | One row per person who is a main passenger (name, contact, address) |
| `reservation` | A booking: main passenger, optional agent, status, ticket type, travel class, creation time, party size |
| `payment` | A payment: status, date, amount |
| `airport` | Airport code, name, location, other details |
| `calendar_date` | One row per date, with day of month and a business-day flag |
| `flight_schedule` | A planned flight: number, airline, usual aircraft, origin, destination, scheduled departure and arrival |
| `flight_leg` | One operated flight segment of a schedule, with actual departure and arrival times |
| `flight_cost` | The cost of a flight for an aircraft type over a validity period |
| `reservation_payment` | Link table: which payments belong to which reservations |
| `reservation_leg` | Link table: which flight legs belong to which reservations |

## How the tables relate

```
booking_agent 0..1 ──< reservation >── 1 passenger
                          │
            ┌─────────────┴──────────────┐
   reservation_payment            reservation_leg
            │                            │
         payment                     flight_leg >── flight_schedule >── airport (origin, destination)
                                          │               │
                                          └── airport     └──< flight_cost >── calendar_date (valid_from, valid_to)
                                      (origin, destination)
```

- A reservation has exactly one main passenger and zero or one booking agent.
- A passenger has zero or many reservations. An agent handles zero or many reservations.
- A reservation links to zero or many payments, and a payment links to zero or many reservations (many-to-many, through `reservation_payment`).
- A reservation links to zero or many legs, and a leg links to zero or many reservations (many-to-many, through `reservation_leg`).
- Every leg belongs to exactly one flight schedule; a schedule has zero or many legs.
- Every schedule and every leg has one origin airport and one destination airport. An airport can be used by many schedules and legs.
- A schedule has zero or many cost records. Each cost record's validity dates both reference `calendar_date`.

## Why the two linking tables are necessary

Both relationships are many-to-many:

- **Reservation and payment.** One payment can cover several reservations, and one reservation can be paid in several instalments.
- **Reservation and leg.** One reservation can contain several connecting legs, and one leg carries many reservations.

A single column cannot hold several IDs without breaking first normal form, and repeating a reservation row for every payment or leg would copy all its data. A link table holds one row per pair. Its composite primary key `(reservation_id, payment_id)` or `(reservation_id, leg_id)` also **prevents duplicate pairs**, as the business rules require. An extra index on the second column makes the reverse lookup fast (for example, "which reservations use this leg?").

## Why scheduled and actual times are separate

The schedule is the plan; the leg records what happened. If actual times overwrote scheduled times, the original plan would be lost and delays could not be measured. Keeping both lets you compute `actual_departure_utc - sched_departure_utc` and report on punctuality. The actual columns are nullable because they are unknown before a flight operates. **All timestamps are stored in UTC.**

## Why flight costs use a composite key

`flight_cost` is identified by `(flight_number, aircraft_type_code, valid_from)`. The same flight can have several costs over time, and the same flight can be operated by different aircraft types with different costs. Including `valid_from` in the key lets each price change be a new row instead of an update, so earlier costs are kept. Both validity dates reference `calendar_date`, and a check constraint makes sure `valid_to >= valid_from`.

---

## Constraints, indexes, and deletion rules

### Validation constraints (CHECK)

| Rule | Constraint |
|---|---|
| Party size greater than zero | `party_size > 0` on `reservation` |
| Payment amount positive | `amount > 0` on `payment` |
| Origin differs from destination | on `flight_schedule` and `flight_leg` |
| Scheduled arrival after departure | on `flight_schedule` |
| Actual arrival after departure (when both known) | on `flight_leg` |
| Valid-to not before valid-from | on `flight_cost` |
| Cost not negative | `cost_amount >= 0` on `flight_cost` |

### Indexes

| Index | Supports |
|---|---|
| `idx_passenger_name (last_name, first_name)` | Finding a passenger by name |
| `idx_passenger_email (email)` | Finding a passenger by email |
| `idx_fs_route (origin_airport, destination_airport)` | Searching schedules by route |
| `idx_fs_dep (sched_departure_utc)` | Searching schedules by departure time |
| `idx_leg_flight (flight_number)` | Listing the legs of a schedule |
| `idx_res_created (created_at_utc)` | Reservations by creation date |
| `idx_rp_payment (payment_id)` | Which reservations a payment covers |
| `idx_rl_leg (leg_id)` | Which reservations use a leg |

Primary keys and foreign keys are indexed automatically by InnoDB.

### Deletion rules

| Relationship | Rule | Reason |
|---|---|---|
| reservation → passenger | `RESTRICT` | A passenger with reservations cannot be deleted |
| reservation → booking_agent | `SET NULL` | Removing an agent keeps the reservation, which becomes direct |
| schedule, leg, cost → airport | `RESTRICT` | Airports in use cannot be deleted |
| leg → schedule | `RESTRICT` | A schedule with legs cannot be deleted |
| cost → schedule | `RESTRICT` | Cost history is protected |
| cost → calendar_date | `RESTRICT` | Referenced dates cannot be deleted |
| reservation_payment → reservation, payment | `CASCADE` | Deleting a reservation or payment removes only the connection rows |
| reservation_leg → reservation | `CASCADE` | Deleting a reservation removes its leg connections |
| reservation_leg → flight_leg | `RESTRICT` | A leg used by a reservation cannot be deleted |

All tables use **InnoDB** for foreign-key and transaction support.

### Reference codes (externally managed)

Airline, aircraft type, reservation status, ticket type, travel class, and payment status are stored as plain codes. They are **managed outside this database**, and no foreign keys are declared to them locally. The seed script uses these demonstration values:

| Code type | Values used |
|---|---|
| Airline | `HW` |
| Aircraft type | `AT72`, `DH8D`, `E145`, `B190` |
| Reservation status | `CONF`, `PEND`, `CANC` |
| Ticket type | `ONEWAY`, `RETURN`, `MULTI` |
| Travel class | `ECON`, `PREM`, `BUS` |
| Payment status | `PAID`, `PEND`, `FAIL`, `RFND` |

Airport codes in the seed data are **fictional demonstration data** and are labelled as such in `airport.other_details`.

### Simplifying assumption: flight number identifies a schedule

This design treats `flight_number` as a unique schedule identifier. A production airline system would need a more detailed identifier, because the same flight number (for example `HW101`) operates on many different dates, and a given date's flight can have its own aircraft, gate, delay, and cost. Real systems identify a flight by flight number **plus operating date**, or by a separate schedule-instance ID. Here, `flight_leg` records stand in for those individual operations.

---

## Advantages and trade-offs

**Advantages**

- No repeated passenger, airport, or payment data; each fact is stored once.
- Relationships are enforced by foreign keys, so orphan records cannot appear.
- Business rules are enforced by the database (checks, composite keys), not only by the application.
- History is preserved: planned vs actual times, and old flight costs.
- Another developer can rebuild the whole database from `schema.sql` and `seed.py`.

**Trade-offs**

- Data is split across many tables, so common questions need joins.
- Link tables add two more tables to maintain.
- Several columns (status, class, ticket type) are unchecked codes, so a typo in an unmanaged code is not caught by the database.

## Limitations

1. **Shared payment links do not reveal the exact amount allocated to each reservation.** `reservation_payment` stores only the pairing. If one payment of 500.00 covers three reservations, the database cannot say how much belongs to each. Summing payments per reservation therefore counts a shared payment in full for every reservation it is linked to, and such totals must not be added across reservations. Fixing this would need an allocation amount column in the link table, which the assignment excludes.
2. **Party size does not identify every traveler.** Only the main passenger and a head count are stored. The names of the other travelers are unknown, which would matter for check-in or manifests. A `party_member` table would be needed.
3. **Separating data reduces duplication but requires joins.** Reading a complete reservation touches `reservation`, `passenger`, `booking_agent`, two link tables, `payment`, and `flight_leg`. Joining payments and legs in one query multiplies rows, so `queries.sql` aggregates each side separately.
4. **Cost validity periods require a policy for overlapping periods.** The key `(flight_number, aircraft_type_code, valid_from)` stops two rows starting on the same date, but it does not stop periods from overlapping (for example 1 Jan to 31 Mar and 15 Feb to 30 Jun). 

   **Policy:** for the same flight number and aircraft type, validity periods must not overlap. The seed script follows this rule. The database does not enforce it, so the application (or a trigger) must check before inserting. This query finds violations:

   ```sql
   SELECT a.flight_number, a.aircraft_type_code,
          a.valid_from AS a_from, a.valid_to AS a_to,
          b.valid_from AS b_from, b.valid_to AS b_to
   FROM flight_cost a
   JOIN flight_cost b
     ON a.flight_number = b.flight_number
    AND a.aircraft_type_code = b.aircraft_type_code
    AND a.valid_from < b.valid_from
    AND b.valid_from <= a.valid_to;
   ```

   An empty result means no overlaps.

---

## Example queries

The full versions are in `queries.sql`.

1. **A reservation with passenger, agent, payments, and legs.** Payments and legs are aggregated in separate subqueries so neither multiplies the other or inflates `total_paid`.
2. **Reservations using a particular leg**, through `reservation_leg`.
3. **Payments linked to a reservation**, through `reservation_payment`.
4. **Flight cost for a flight, aircraft type, and date**, using `BETWEEN valid_from AND valid_to`.

## Synthetic data notes

- All data is fictional and produced by Faker with seed 42.
- Parents are inserted before children, and foreign keys use IDs that were just inserted.
- Link-table pairs are tracked in a Python `set`, so no pair repeats.
- The data includes direct and agent-assisted reservations, a reservation with several payments and legs (reservation 1), payments shared by several reservations, and flights with several cost validity periods.
- Flights dated before 16 October 2026 have actual times; later flights have `NULL` actual times.
