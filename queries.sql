USE harborwing;

-- =====================================================================
-- Query 1: A reservation with its passenger, agent, payments, and legs.
-- Payments and legs are aggregated in separate subqueries so joining
-- them together cannot multiply rows or inflate total_paid.
-- Change the reservation_id to view another reservation.
-- =====================================================================
SELECT r.reservation_id,
       CONCAT(p.first_name, ' ', p.last_name) AS main_passenger,
       r.party_size,
       r.status_code, r.ticket_type_code, r.travel_class_code,
       COALESCE(a.agent_name, 'Direct booking') AS agent,
       (SELECT COUNT(*)
          FROM reservation_payment rp
         WHERE rp.reservation_id = r.reservation_id)       AS payment_count,
       (SELECT SUM(py.amount)
          FROM reservation_payment rp
          JOIN payment py ON py.payment_id = rp.payment_id
         WHERE rp.reservation_id = r.reservation_id)       AS total_paid,
       (SELECT GROUP_CONCAT(rp.payment_id ORDER BY rp.payment_id)
          FROM reservation_payment rp
         WHERE rp.reservation_id = r.reservation_id)       AS payment_ids,
       (SELECT COUNT(*)
          FROM reservation_leg rl
         WHERE rl.reservation_id = r.reservation_id)       AS leg_count,
       (SELECT GROUP_CONCAT(rl.leg_id ORDER BY rl.leg_id)
          FROM reservation_leg rl
         WHERE rl.reservation_id = r.reservation_id)       AS leg_ids
FROM reservation r
JOIN passenger p          ON p.passenger_id = r.passenger_id
LEFT JOIN booking_agent a ON a.agent_id = r.agent_id
WHERE r.reservation_id = 1;

-- Query 1b: the individual legs of that reservation (one row per leg).
SELECT rl.reservation_id, l.leg_id, l.flight_number,
       l.origin_airport, l.destination_airport,
       fs.sched_departure_utc, l.actual_departure_utc
FROM reservation_leg rl
JOIN flight_leg l       ON l.leg_id = rl.leg_id
JOIN flight_schedule fs ON fs.flight_number = l.flight_number
WHERE rl.reservation_id = 1
ORDER BY fs.sched_departure_utc;

-- Query 1c: the individual payments of that reservation (one row per payment).
SELECT rp.reservation_id, py.payment_id, py.payment_status_code,
       py.payment_date, py.amount
FROM reservation_payment rp
JOIN payment py ON py.payment_id = rp.payment_id
WHERE rp.reservation_id = 1
ORDER BY py.payment_date;

-- =====================================================================
-- Query 2: Reservations that use a particular leg.
-- =====================================================================
SELECT l.leg_id, r.reservation_id,
       CONCAT(p.first_name, ' ', p.last_name) AS main_passenger,
       r.party_size, r.status_code
FROM reservation_leg rl
JOIN flight_leg l   ON l.leg_id = rl.leg_id
JOIN reservation r  ON r.reservation_id = rl.reservation_id
JOIN passenger p    ON p.passenger_id = r.passenger_id
WHERE rl.leg_id = 1;

-- =====================================================================
-- Query 3: Payments linked to a reservation.
-- shared_with_other_reservations shows payments that cover more than
-- one reservation (the exact allocation per reservation is not stored).
-- =====================================================================
SELECT py.payment_id, py.payment_status_code, py.payment_date, py.amount,
       (SELECT COUNT(*) FROM reservation_payment x
         WHERE x.payment_id = py.payment_id) - 1 AS shared_with_other_reservations
FROM reservation_payment rp
JOIN payment py ON py.payment_id = rp.payment_id
WHERE rp.reservation_id = 1;

-- =====================================================================
-- Query 4: Flight cost for a flight, aircraft type, and date.
-- To find real values to test with, run this first:
--   SELECT flight_number, aircraft_type_code, valid_from, valid_to
--   FROM flight_cost LIMIT 5;
-- Then use a date between valid_from and valid_to.
-- =====================================================================
SELECT flight_number, aircraft_type_code, valid_from, valid_to, cost_amount
FROM flight_cost
WHERE flight_number = 'HW127'
  AND aircraft_type_code = 'AT72'
  AND '2026-03-15' BETWEEN valid_from AND valid_to;

-- =====================================================================
-- Extra checks
-- =====================================================================

-- Payments shared by several reservations
SELECT payment_id, COUNT(*) AS reservations_linked
FROM reservation_payment
GROUP BY payment_id
HAVING COUNT(*) > 1
ORDER BY reservations_linked DESC
LIMIT 10;

-- Flights with several cost validity periods
SELECT flight_number, aircraft_type_code, COUNT(*) AS periods
FROM flight_cost
GROUP BY flight_number, aircraft_type_code
HAVING COUNT(*) > 1
LIMIT 10;

-- Overlapping cost periods for the same flight + aircraft (should return no rows)
SELECT a.flight_number, a.aircraft_type_code,
       a.valid_from AS a_from, a.valid_to AS a_to,
       b.valid_from AS b_from, b.valid_to AS b_to
FROM flight_cost a
JOIN flight_cost b
  ON a.flight_number = b.flight_number
 AND a.aircraft_type_code = b.aircraft_type_code
 AND a.valid_from < b.valid_from
 AND b.valid_from <= a.valid_to;

-- Delay in minutes: scheduled vs actual departure (kept separate, so this works)
SELECT l.leg_id, l.flight_number, fs.sched_departure_utc, l.actual_departure_utc,
       TIMESTAMPDIFF(MINUTE, fs.sched_departure_utc, l.actual_departure_utc) AS departure_delay_min
FROM flight_leg l
JOIN flight_schedule fs ON fs.flight_number = l.flight_number
WHERE l.actual_departure_utc IS NOT NULL
LIMIT 10;

-- Validation test: this INSERT must FAIL (check constraint chk_pay_amount)
-- INSERT INTO payment (payment_status_code, payment_date, amount)
-- VALUES ('PAID', '2026-01-01', -50);
