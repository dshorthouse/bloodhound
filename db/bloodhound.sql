SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;


CREATE TABLE `agents` (
  `id` int(11) NOT NULL,
  `family` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `given` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `articles` (
  `id` int(11) NOT NULL,
  `doi` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `citation` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `abstract` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `gbif_dois` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `gbif_downloadkeys` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `processed` tinyint(1) DEFAULT NULL,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `article_occurrences` (
  `id` bigint(11) UNSIGNED NOT NULL,
  `article_id` int(11) NOT NULL,
  `occurrence_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `occurrences` (
  `gbifID` int(11) NOT NULL,
  `occurrenceID` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `dateIdentified` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `decimalLatitude` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `decimalLongitude` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `country` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `countryCode` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `eventDate` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `year` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `family` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `identifiedBy` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `institutionCode` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `collectionCode` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `catalogNumber` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `recordedBy` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `scientificName` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `typeStatus` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `occurrence_determiners` (
  `occurrence_id` int(11) NOT NULL,
  `agent_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `occurrence_recorders` (
  `occurrence_id` int(11) NOT NULL,
  `agent_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `organizations` (
  `id` int(11) NOT NULL,
  `isni` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `ringgold` int(11) DEFAULT NULL,
  `grid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `address` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `institution_codes` text COLLATE utf8mb4_bin
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `schema_migrations` (
  `version` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `taxa` (
  `id` int(11) NOT NULL,
  `family` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `taxon_determiners` (
  `agent_id` int(11) NOT NULL,
  `taxon_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `taxon_occurrences` (
  `occurrence_id` int(11) NOT NULL,
  `taxon_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `users` (
  `id` int(11) NOT NULL,
  `family` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `given` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `orcid` varchar(25) DEFAULT NULL,
  `wikidata` varchar(50) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `other_names` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `country` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `country_code` varchar(50) DEFAULT NULL,
  `keywords` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `date_born` date DEFAULT NULL,
  `date_died` date DEFAULT NULL,
  `is_public` tinyint(1) DEFAULT '0',
  `can_comment` tinyint(1) NOT NULL DEFAULT '1',
  `made_public` timestamp NULL DEFAULT NULL,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated` timestamp NULL DEFAULT NULL,
  `visited` timestamp NULL DEFAULT NULL,
  `is_admin` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `user_occurrences` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `occurrence_id` int(11) NOT NULL,
  `action` varchar(100) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `visible` tinyint(1) NOT NULL DEFAULT '1',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated` timestamp NULL DEFAULT NULL,
  `created_by` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `user_organizations` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `organization_id` int(11) NOT NULL,
  `start_year` int(11) DEFAULT NULL,
  `start_month` int(11) DEFAULT NULL,
  `start_day` int(11) DEFAULT NULL,
  `end_year` int(11) DEFAULT NULL,
  `end_month` int(11) DEFAULT NULL,
  `end_day` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


ALTER TABLE `agents`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `full_name` (`family`,`given`) USING BTREE;

ALTER TABLE `articles`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `doi_idx` (`doi`);

ALTER TABLE `article_occurrences`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `article_occurrence_idx` (`article_id`,`occurrence_id`),
  ADD KEY `article_idx` (`article_id`),
  ADD KEY `occurrence_idx` (`occurrence_id`);

ALTER TABLE `occurrences`
  ADD PRIMARY KEY (`gbifID`) USING BTREE,
  ADD KEY `typeStatus_idx` (`typeStatus`(256));

ALTER TABLE `occurrence_determiners`
  ADD KEY `agent_idx` (`agent_id`);

ALTER TABLE `occurrence_recorders`
  ADD KEY `agent_idx` (`agent_id`);

ALTER TABLE `organizations`
  ADD PRIMARY KEY (`id`),
  ADD KEY `ringgold_idx` (`ringgold`),
  ADD KEY `grid_idx` (`grid`),
  ADD KEY `isni_idx` (`isni`);

ALTER TABLE `schema_migrations`
  ADD UNIQUE KEY `unique_schema_migrations` (`version`);

ALTER TABLE `taxa`
  ADD PRIMARY KEY (`id`);

ALTER TABLE `taxon_determiners`
  ADD KEY `agent_idx` (`agent_id`);

ALTER TABLE `taxon_occurrences`
  ADD UNIQUE KEY `occurrence_id_idx` (`occurrence_id`),
  ADD KEY `taxon_id_idx` (`taxon_id`);

ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD KEY `orcid_idx` (`orcid`) USING BTREE,
  ADD KEY `wikidata_idx` (`wikidata`) USING BTREE,
  ADD KEY `country_code` (`country_code`);

ALTER TABLE `user_occurrences`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `user_occurrence_idx` (`occurrence_id`,`user_id`),
  ADD KEY `action_idx` (`action`) USING BTREE,
  ADD KEY `created_by_idx` (`created_by`),
  ADD KEY `user_idx` (`user_id`);

ALTER TABLE `user_organizations`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_idx` (`user_id`),
  ADD KEY `organization_idx` (`organization_id`);


ALTER TABLE `agents`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `articles`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `article_occurrences`
  MODIFY `id` bigint(11) UNSIGNED NOT NULL AUTO_INCREMENT;

ALTER TABLE `organizations`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `taxa`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `user_occurrences`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `user_organizations`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
