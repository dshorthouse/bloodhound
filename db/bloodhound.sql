-- phpMyAdmin SQL Dump
-- version 4.8.0.1
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Generation Time: Sep 28, 2018 at 04:12 AM
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

-- --------------------------------------------------------

--
-- Table structure for table `agents`
--

CREATE TABLE `agents` (
  `id` int(11) NOT NULL,
  `canonical_id` int(11) DEFAULT NULL,
  `family` varchar(255) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `given` varchar(255) COLLATE utf8mb4_bin NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- --------------------------------------------------------

--
-- Table structure for table `occurrences`
--

CREATE TABLE `occurrences` (
  `id` int(11) NOT NULL COMMENT 'This is gbifID.',
  `occurrenceID` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `dateIdentified` text COLLATE utf8mb4_bin,
  `decimalLatitude` text COLLATE utf8mb4_bin,
  `decimalLongitude` text COLLATE utf8mb4_bin,
  `eventDate` text COLLATE utf8mb4_bin,
  `family` text COLLATE utf8mb4_bin,
  `identifiedBy` text COLLATE utf8mb4_bin,
  `institutionCode` text COLLATE utf8mb4_bin,
  `collectionCode` text COLLATE utf8mb4_bin,
  `catalogNumber` text COLLATE utf8mb4_bin,
  `recordedBy` text COLLATE utf8mb4_bin,
  `scientificName` text COLLATE utf8mb4_bin,
  `typeStatus` text COLLATE utf8mb4_bin,
  `lastChecked` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- --------------------------------------------------------

--
-- Table structure for table `occurrence_determiners`
--

CREATE TABLE `occurrence_determiners` (
  `occurrence_id` int(11) NOT NULL,
  `agent_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- --------------------------------------------------------

--
-- Table structure for table `occurrence_recorders`
--

CREATE TABLE `occurrence_recorders` (
  `occurrence_id` int(11) NOT NULL,
  `agent_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- --------------------------------------------------------

--
-- Table structure for table `schema_migrations`
--

CREATE TABLE `schema_migrations` (
  `version` varchar(255) COLLATE utf8mb4_bin NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- --------------------------------------------------------

--
-- Table structure for table `taxa`
--

CREATE TABLE `taxa` (
  `id` int(11) NOT NULL,
  `kingdom` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `family` varchar(255) COLLATE utf8mb4_bin NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- --------------------------------------------------------

--
-- Table structure for table `taxon_determiners`
--

CREATE TABLE `taxon_determiners` (
  `id` int(11) NOT NULL,
  `agent_id` int(11) NOT NULL,
  `taxon_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- --------------------------------------------------------

--
-- Table structure for table `taxon_occurrences`
--

CREATE TABLE `taxon_occurrences` (
  `occurrence_id` int(11) NOT NULL,
  `taxon_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` int(11) NOT NULL,
  `family` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `given` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `orcid` varchar(25) COLLATE utf8mb4_bin NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `other_names` mediumtext COLLATE utf8mb4_bin,
  `is_public` tinyint(1) DEFAULT '0',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- --------------------------------------------------------

--
-- Table structure for table `user_occurrences`
--

CREATE TABLE `user_occurrences` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `occurrence_id` int(11) NOT NULL,
  `action` varchar(100) COLLATE utf8mb4_bin DEFAULT NULL,
  `visible` tinyint(1) NOT NULL DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

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
-- Indexes for table `occurrences`
--
ALTER TABLE `occurrences`
  ADD PRIMARY KEY (`id`) USING BTREE;

--
-- Indexes for table `occurrence_determiners`
--
ALTER TABLE `occurrence_determiners`
  ADD KEY `occurrence_id_idx` (`occurrence_id`) USING BTREE,
  ADD KEY `agent_id_idx` (`agent_id`) USING BTREE;

--
-- Indexes for table `occurrence_recorders`
--
ALTER TABLE `occurrence_recorders`
  ADD KEY `occurrence_id_idx` (`occurrence_id`),
  ADD KEY `agent_id_idx` (`agent_id`) USING BTREE;

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
  ADD UNIQUE KEY `occurrence_id_idx` (`occurrence_id`),
  ADD KEY `taxon_id_idx` (`taxon_id`);

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
ALTER TABLE `user_occurrences` ADD FULLTEXT KEY `action_idx` (`action`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `agents`
--
ALTER TABLE `agents`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=963838;

--
-- AUTO_INCREMENT for table `taxa`
--
ALTER TABLE `taxa`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20827;

--
-- AUTO_INCREMENT for table `taxon_determiners`
--
ALTER TABLE `taxon_determiners`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=31850011;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=74;

--
-- AUTO_INCREMENT for table `user_occurrences`
--
ALTER TABLE `user_occurrences`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=34897;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
