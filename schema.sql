-- MySQL dump 10.13  Distrib 8.0.46, for Win64 (x86_64)
--
-- Host: localhost    Database: harborwing
-- ------------------------------------------------------
-- Server version	8.0.46

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `airport`
--

DROP TABLE IF EXISTS `airport`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `airport` (
  `airport_code` char(3) NOT NULL,
  `airport_name` varchar(100) NOT NULL,
  `location` varchar(100) NOT NULL,
  `other_details` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`airport_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `booking_agent`
--

DROP TABLE IF EXISTS `booking_agent`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `booking_agent` (
  `agent_id` int NOT NULL AUTO_INCREMENT,
  `agent_name` varchar(100) NOT NULL,
  `agent_details` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`agent_id`)
) ENGINE=InnoDB AUTO_INCREMENT=61 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `calendar_date`
--

DROP TABLE IF EXISTS `calendar_date`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calendar_date` (
  `calendar_date` date NOT NULL,
  `day_of_month` tinyint NOT NULL,
  `is_business_day` tinyint(1) NOT NULL,
  PRIMARY KEY (`calendar_date`),
  CONSTRAINT `calendar_date_chk_1` CHECK ((`day_of_month` between 1 and 31))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `flight_cost`
--

DROP TABLE IF EXISTS `flight_cost`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `flight_cost` (
  `flight_number` varchar(10) NOT NULL,
  `aircraft_type_code` varchar(4) NOT NULL,
  `valid_from` date NOT NULL,
  `valid_to` date NOT NULL,
  `cost_amount` decimal(10,2) NOT NULL,
  PRIMARY KEY (`flight_number`,`aircraft_type_code`,`valid_from`),
  KEY `fk_fc_from` (`valid_from`),
  KEY `fk_fc_to` (`valid_to`),
  CONSTRAINT `fk_fc_from` FOREIGN KEY (`valid_from`) REFERENCES `calendar_date` (`calendar_date`) ON DELETE RESTRICT,
  CONSTRAINT `fk_fc_fs` FOREIGN KEY (`flight_number`) REFERENCES `flight_schedule` (`flight_number`) ON DELETE RESTRICT,
  CONSTRAINT `fk_fc_to` FOREIGN KEY (`valid_to`) REFERENCES `calendar_date` (`calendar_date`) ON DELETE RESTRICT,
  CONSTRAINT `chk_fc_cost` CHECK ((`cost_amount` >= 0)),
  CONSTRAINT `chk_fc_dates` CHECK ((`valid_to` >= `valid_from`))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `flight_leg`
--

DROP TABLE IF EXISTS `flight_leg`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `flight_leg` (
  `leg_id` int NOT NULL AUTO_INCREMENT,
  `flight_number` varchar(10) NOT NULL,
  `origin_airport` char(3) NOT NULL,
  `destination_airport` char(3) NOT NULL,
  `actual_departure_utc` datetime DEFAULT NULL,
  `actual_arrival_utc` datetime DEFAULT NULL,
  PRIMARY KEY (`leg_id`),
  KEY `fk_leg_origin` (`origin_airport`),
  KEY `fk_leg_dest` (`destination_airport`),
  KEY `idx_leg_flight` (`flight_number`),
  CONSTRAINT `fk_leg_dest` FOREIGN KEY (`destination_airport`) REFERENCES `airport` (`airport_code`) ON DELETE RESTRICT,
  CONSTRAINT `fk_leg_fs` FOREIGN KEY (`flight_number`) REFERENCES `flight_schedule` (`flight_number`) ON DELETE RESTRICT,
  CONSTRAINT `fk_leg_origin` FOREIGN KEY (`origin_airport`) REFERENCES `airport` (`airport_code`) ON DELETE RESTRICT,
  CONSTRAINT `chk_leg_airports` CHECK ((`origin_airport` <> `destination_airport`)),
  CONSTRAINT `chk_leg_times` CHECK (((`actual_departure_utc` is null) or (`actual_arrival_utc` is null) or (`actual_arrival_utc` > `actual_departure_utc`)))
) ENGINE=InnoDB AUTO_INCREMENT=121 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `flight_schedule`
--

DROP TABLE IF EXISTS `flight_schedule`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `flight_schedule` (
  `flight_number` varchar(10) NOT NULL,
  `airline_code` char(2) NOT NULL,
  `aircraft_type_code` varchar(4) NOT NULL,
  `origin_airport` char(3) NOT NULL,
  `destination_airport` char(3) NOT NULL,
  `sched_departure_utc` datetime NOT NULL,
  `sched_arrival_utc` datetime NOT NULL,
  PRIMARY KEY (`flight_number`),
  KEY `fk_fs_dest` (`destination_airport`),
  KEY `idx_fs_route` (`origin_airport`,`destination_airport`),
  KEY `idx_fs_dep` (`sched_departure_utc`),
  CONSTRAINT `fk_fs_dest` FOREIGN KEY (`destination_airport`) REFERENCES `airport` (`airport_code`) ON DELETE RESTRICT,
  CONSTRAINT `fk_fs_origin` FOREIGN KEY (`origin_airport`) REFERENCES `airport` (`airport_code`) ON DELETE RESTRICT,
  CONSTRAINT `chk_fs_airports` CHECK ((`origin_airport` <> `destination_airport`)),
  CONSTRAINT `chk_fs_times` CHECK ((`sched_arrival_utc` > `sched_departure_utc`))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `passenger`
--

DROP TABLE IF EXISTS `passenger`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `passenger` (
  `passenger_id` int NOT NULL AUTO_INCREMENT,
  `first_name` varchar(50) NOT NULL,
  `second_name` varchar(50) DEFAULT NULL,
  `last_name` varchar(50) NOT NULL,
  `phone` varchar(30) NOT NULL,
  `email` varchar(120) NOT NULL,
  `address_line1` varchar(100) NOT NULL,
  `address_line2` varchar(100) DEFAULT NULL,
  `city` varchar(60) NOT NULL,
  `state_province` varchar(60) DEFAULT NULL,
  `country` varchar(60) NOT NULL,
  `other_details` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`passenger_id`),
  KEY `idx_passenger_name` (`last_name`,`first_name`),
  KEY `idx_passenger_email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=81 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `payment`
--

DROP TABLE IF EXISTS `payment`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `payment` (
  `payment_id` int NOT NULL AUTO_INCREMENT,
  `payment_status_code` varchar(10) NOT NULL,
  `payment_date` date NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  PRIMARY KEY (`payment_id`),
  CONSTRAINT `chk_pay_amount` CHECK ((`amount` > 0))
) ENGINE=InnoDB AUTO_INCREMENT=81 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `reservation`
--

DROP TABLE IF EXISTS `reservation`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reservation` (
  `reservation_id` int NOT NULL AUTO_INCREMENT,
  `passenger_id` int NOT NULL,
  `agent_id` int DEFAULT NULL,
  `status_code` varchar(10) NOT NULL,
  `ticket_type_code` varchar(10) NOT NULL,
  `travel_class_code` varchar(10) NOT NULL,
  `created_at_utc` datetime NOT NULL,
  `party_size` smallint NOT NULL,
  PRIMARY KEY (`reservation_id`),
  KEY `idx_res_passenger` (`passenger_id`),
  KEY `idx_res_agent` (`agent_id`),
  KEY `idx_res_created` (`created_at_utc`),
  CONSTRAINT `fk_res_agent` FOREIGN KEY (`agent_id`) REFERENCES `booking_agent` (`agent_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_res_passenger` FOREIGN KEY (`passenger_id`) REFERENCES `passenger` (`passenger_id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_party` CHECK ((`party_size` > 0))
) ENGINE=InnoDB AUTO_INCREMENT=101 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `reservation_leg`
--

DROP TABLE IF EXISTS `reservation_leg`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reservation_leg` (
  `reservation_id` int NOT NULL,
  `leg_id` int NOT NULL,
  PRIMARY KEY (`reservation_id`,`leg_id`),
  KEY `idx_rl_leg` (`leg_id`),
  CONSTRAINT `fk_rl_leg` FOREIGN KEY (`leg_id`) REFERENCES `flight_leg` (`leg_id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_rl_res` FOREIGN KEY (`reservation_id`) REFERENCES `reservation` (`reservation_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `reservation_payment`
--

DROP TABLE IF EXISTS `reservation_payment`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reservation_payment` (
  `reservation_id` int NOT NULL,
  `payment_id` int NOT NULL,
  PRIMARY KEY (`reservation_id`,`payment_id`),
  KEY `idx_rp_payment` (`payment_id`),
  CONSTRAINT `fk_rp_pay` FOREIGN KEY (`payment_id`) REFERENCES `payment` (`payment_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_rp_res` FOREIGN KEY (`reservation_id`) REFERENCES `reservation` (`reservation_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-10-16 18:16:24
