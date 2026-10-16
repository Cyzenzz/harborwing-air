# HarborWing Air Reservation Database

# 

# A MySQL database that replaces HarborWing Air's spreadsheets, with a Python Faker script that fills it with fictional data.

# 

# Setup

# 

# Requires MySQL 8.0.16 or later (earlier versions ignore CHECK constraints) and Python 3.9+.

# 

# 1.Create the database.

# &#x09; Run schema.sql in MySQL Workbench, or mysql -u root -p < schema.sql. It creates harborwing and all 11 tables.

# 2\. Install dependencies

# &#x09; pip install -r requirements.txt (on Windows, py -m pip install -r requirements.txt).

# 3\. Seed the data

# &#x09; Set your password, then run the script (use py instead of python on Windows if needed):



# &#x20; 	bash

# &#x20;  		set DB\_PASSWORD=your\_password        # Windows; use "export" on macOS/Linux

# &#x20; 		 python seed.py

# &#x20;

# 4\. Reset.

# &#x20;	`python seed.py --reset` empties every table and seeds again. The seed is fixed at 42, so every run produces the same data.

# 

# Relationships

# 

# \- A reservation has exactly one main passenger and zero or one booking agent.

# \- A passenger has zero or many reservations. An agent handles zero or many reservations.

# \- Reservation and payment are many-to-many, through the link table reservation\_payment.

# \- Reservation and flight leg are many-to-many, through the link table reservation\_leg. Each link table holds one row per pair, and its composite primary key blocks duplicate pairs.

# \- Every leg belongs to one flight schedule. Every schedule and leg has one origin and one destination airport.

# \- A schedule has zero or many cost records. Both validity dates in a cost record reference calendar\_date.

# 

# Trade-offs

# 

# Advantages: passenger, airport, and payment data are stored once; foreign keys and `CHECK` constraints enforce the rules in the database; planned and actual times, and old flight costs, are kept instead of overwritten.

# 

# Trade-offs and limitations:

# 

# 1\. Shared payment links do not show the amount allocated to each reservation.

# &#x09;If one payment covers three reservations, the database cannot say how much belongs to each, so per-reservation totals count a shared payment in full.

# 2\. Party size does not identify every traveler.

# &#x09;Only the main passenger and a head count are stored.

# 3\. Separating data reduces duplication but requires joins. 

# &#x09;Joining payments and legs together multiplies rows, so the example queries total each side in its own subquery.

# 4\. Cost validity periods need an overlap policy. 

# &#x09;The key stops two rows from starting on the same date, but not from overlapping. For the same flight and aircraft type, periods must not overlap. The seed data follows this and the application must check it on insert.

# 

# Developer usage

# 

# Check the data, then query it:

# 

# \- row\_counts.sql shows the row count of every table (each has 50 or more rows).

# \- queries.sql has four example queries: a reservation with its passenger, agent, payments, and legs; reservations using a given leg; payments linked to a reservation; and the cost for a flight, aircraft type, and date. It also has a query that finds overlapping cost periods.

# 

# Open `harborwing.png` (or harborwing.mwb in MySQL Workbench) to see the diagram.

# 

# Optional environment variables for seed.py: DB\_HOST (default localhost), DB\_PORT (3306), DB\_USER (root), DB\_NAME (harborwing). If DB\_PASSWORD is not set, the script asks for it.

