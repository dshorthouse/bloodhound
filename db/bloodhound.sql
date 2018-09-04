-- phpMyAdmin SQL Dump
-- version 4.8.0.1
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Generation Time: Sep 04, 2018 at 12:40 PM
-- Server version: 5.7.22
-- PHP Version: 5.6.36

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET AUTOCOMMIT = 0;
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `bloodhound`
--
CREATE DATABASE IF NOT EXISTS `bloodhound` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
USE `bloodhound`;

-- --------------------------------------------------------

--
-- Table structure for table `agents`
--

DROP TABLE IF EXISTS `agents`;
CREATE TABLE `agents` (
  `id` int(11) NOT NULL,
  `canonical_id` int(11) DEFAULT NULL,
  `family` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `given` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `agent_descriptions`
--

DROP TABLE IF EXISTS `agent_descriptions`;
CREATE TABLE `agent_descriptions` (
  `id` int(11) NOT NULL,
  `agent_id` int(11) NOT NULL,
  `description_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `descriptions`
--

DROP TABLE IF EXISTS `descriptions`;
CREATE TABLE `descriptions` (
  `id` int(11) NOT NULL,
  `scientificName` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `year` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `occurrences`
--

DROP TABLE IF EXISTS `occurrences`;
CREATE TABLE `occurrences` (
  `id` int(11) NOT NULL,
  `gbifID` int(11) NOT NULL,
  `dateIdentified` text COLLATE utf8_unicode_ci,
  `decimalLatitude` text COLLATE utf8_unicode_ci,
  `decimalLongitude` text COLLATE utf8_unicode_ci,
  `eventDate` text COLLATE utf8_unicode_ci,
  `family` text CHARACTER SET utf8 COLLATE utf8_bin,
  `identifiedBy` text CHARACTER SET utf8 COLLATE utf8_bin,
  `institutionCode` text CHARACTER SET utf8 COLLATE utf8_bin,
  `catalogNumber` text CHARACTER SET utf8 COLLATE utf8_bin,
  `recordedBy` text CHARACTER SET utf8 COLLATE utf8_bin,
  `scientificName` text CHARACTER SET utf8 COLLATE utf8_bin,
  `typeStatus` text CHARACTER SET utf8 COLLATE utf8_bin,
  `lastChecked` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `occurrence_determiners`
--

DROP TABLE IF EXISTS `occurrence_determiners`;
CREATE TABLE `occurrence_determiners` (
  `id` int(11) NOT NULL,
  `occurrence_id` int(11) NOT NULL,
  `agent_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `occurrence_recorders`
--

DROP TABLE IF EXISTS `occurrence_recorders`;
CREATE TABLE `occurrence_recorders` (
  `id` int(11) NOT NULL,
  `occurrence_id` int(11) NOT NULL,
  `agent_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `schema_migrations`
--

DROP TABLE IF EXISTS `schema_migrations`;
CREATE TABLE `schema_migrations` (
  `version` varchar(255) COLLATE utf8_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `taxa`
--

DROP TABLE IF EXISTS `taxa`;
CREATE TABLE `taxa` (
  `id` int(11) NOT NULL,
  `kingdom` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `family` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `taxon_determiners`
--

DROP TABLE IF EXISTS `taxon_determiners`;
CREATE TABLE `taxon_determiners` (
  `id` int(11) NOT NULL,
  `agent_id` int(11) NOT NULL,
  `taxon_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `taxon_occurrences`
--

DROP TABLE IF EXISTS `taxon_occurrences`;
CREATE TABLE `taxon_occurrences` (
  `id` int(11) NOT NULL,
  `occurrence_id` int(11) NOT NULL,
  `taxon_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `id` int(11) NOT NULL,
  `family` varchar(255) DEFAULT NULL,
  `given` varchar(255) DEFAULT NULL,
  `orcid` varchar(25) NOT NULL,
  `email` varchar(255) DEFAULT NULL,
  `is_public` tinyint(1) DEFAULT NULL,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `user_occurrences`
--

DROP TABLE IF EXISTS `user_occurrences`;
CREATE TABLE `user_occurrences` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `occurrence_id` int(11) NOT NULL,
  `action` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `agents`
--
ALTER TABLE `agents`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `full_name` (`family`,`given`) USING BTREE,
  ADD KEY `canonical_idx` (`canonical_id`);

--
-- Indexes for table `agent_descriptions`
--
ALTER TABLE `agent_descriptions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `agent_idx` (`agent_id`),
  ADD KEY `description_idx` (`description_id`);

--
-- Indexes for table `descriptions`
--
ALTER TABLE `descriptions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `idx_scientific_name` (`scientificName`);

--
-- Indexes for table `occurrences`
--
ALTER TABLE `occurrences`
  ADD PRIMARY KEY (`id`),
  ADD KEY `gbif_idx` (`gbifID`);

--
-- Indexes for table `occurrence_determiners`
--
ALTER TABLE `occurrence_determiners`
  ADD PRIMARY KEY (`id`),
  ADD KEY `occurrence_idx` (`occurrence_id`),
  ADD KEY `agent_idx` (`agent_id`);

--
-- Indexes for table `occurrence_recorders`
--
ALTER TABLE `occurrence_recorders`
  ADD PRIMARY KEY (`id`),
  ADD KEY `occurrence_idx` (`occurrence_id`),
  ADD KEY `agent_idx` (`agent_id`);

--
-- Indexes for table `schema_migrations`
--
ALTER TABLE `schema_migrations`
  ADD UNIQUE KEY `unique_schema_migrations` (`version`);

--
-- Indexes for table `taxa`
--
ALTER TABLE `taxa`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `family_idx` (`family`);

--
-- Indexes for table `taxon_determiners`
--
ALTER TABLE `taxon_determiners`
  ADD PRIMARY KEY (`id`),
  ADD KEY `agent_idx` (`agent_id`),
  ADD KEY `taxon_idx` (`taxon_id`);

--
-- Indexes for table `taxon_occurrences`
--
ALTER TABLE `taxon_occurrences`
  ADD PRIMARY KEY (`id`),
  ADD KEY `occurrence_idx` (`occurrence_id`),
  ADD KEY `taxon_idx` (`taxon_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `orcid_idx` (`orcid`);

--
-- Indexes for table `user_occurrences`
--
ALTER TABLE `user_occurrences`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id_idx` (`user_id`),
  ADD KEY `occurrence_id_idx` (`occurrence_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `agents`
--
ALTER TABLE `agents`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=496149;

--
-- AUTO_INCREMENT for table `agent_descriptions`
--
ALTER TABLE `agent_descriptions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=80950;

--
-- AUTO_INCREMENT for table `descriptions`
--
ALTER TABLE `descriptions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=66213;

--
-- AUTO_INCREMENT for table `occurrences`
--
ALTER TABLE `occurrences`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=88441181;

--
-- AUTO_INCREMENT for table `occurrence_determiners`
--
ALTER TABLE `occurrence_determiners`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=38141371;

--
-- AUTO_INCREMENT for table `occurrence_recorders`
--
ALTER TABLE `occurrence_recorders`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=67501051;

--
-- AUTO_INCREMENT for table `taxa`
--
ALTER TABLE `taxa`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8674;

--
-- AUTO_INCREMENT for table `taxon_determiners`
--
ALTER TABLE `taxon_determiners`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=27721306;

--
-- AUTO_INCREMENT for table `taxon_occurrences`
--
ALTER TABLE `taxon_occurrences`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=33226246;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `user_occurrences`
--
ALTER TABLE `user_occurrences`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=76;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
