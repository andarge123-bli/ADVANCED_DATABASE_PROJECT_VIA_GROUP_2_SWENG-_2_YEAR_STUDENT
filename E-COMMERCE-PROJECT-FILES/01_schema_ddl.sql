=============================================================================
-- ETHIOPIA E-COMMERCE PLATFORM — PRODUCTION-GRADE MySQL 8 DATABASE
-- =============================================================================
-- Author  : group 2 students 
-- Version : 1.0.0
-- Date    : 2026-04-07
-- Target  : MySQL 8.0+  (InnoDB, utf8mb4, ROW_FORMAT=DYNAMIC)
-- Scale   : Designed for millions of users, multi-city Ethiopia operations
-- Cities  : Addis Ababa, Adama, Hawassa, Dire Dawa, Mekele, Bahir Dar, ...
-- =============================================================================
-- EXECUTION ORDER:
--   01_schema_ddl.sql      → Core schema, constraints, indexes
--   02_security_rbac.sql   → Roles, users, grants
--   03_triggers.sql        → Triggers (anti-oversell, audit, totals)
--   04_stored_procedures.sql → Stored procedures & functions
--   05_views.sql           → Analytical views
--   06_events.sql          → MySQL Event Scheduler jobs
--   07_sample_data.sql     → Realistic seed data
--   08_queries_explain.sql → Optimized queries & EXPLAIN examples
--   09_distributed_arch.sql→ Partitioning, sharding notes & helpers
-- =============================================================================

SET NAMES utf8mb4;
SET time_zone = '+03:00';  -- East Africa Time (EAT)

-- Strict SQL mode — no silent truncation, no zero dates
SET sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- ---------------------------------------------------------------------------
-- DATABASE
-- ---------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS eth_ecommerce
    CHARACTER SET utf8mb4
    COLLATE      utf8mb4_unicode_ci;

USE eth_ecommerce;

-- Enable event scheduler (done at server level; reminder here)
-- SET GLOBAL event_scheduler = ON;

-- =============================================================================
-- SECTION 1: LOOKUP / REFERENCE TABLES
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1.1  REGIONS (Ethiopian cities / zones)
-- ---------------------------------------------------------------------------
CREATE TABLE regions (
    region_id        SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    region_code      VARCHAR(10)  NOT NULL,
    region_name      VARCHAR(100) NOT NULL,
    parent_region_id SMALLINT UNSIGNED NULL COMMENT 'For sub-city / woreda hierarchy',
    timezone         VARCHAR(50)  NOT NULL DEFAULT 'Africa/Addis_Ababa',
    latitude         DECIMAL(10,7) NULL,
    longitude        DECIMAL(10,7) NULL,
    is_active        TINYINT(1) NOT NULL DEFAULT 1,
    created_at       DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at       DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

    CONSTRAINT fk_region_parent FOREIGN KEY (parent_region_id)
        REFERENCES regions(region_id) ON DELETE RESTRICT ON UPDATE CASCADE,

    UNIQUE KEY uq_region_code (region_code),
    KEY idx_region_parent     (parent_region_id),
    KEY idx_region_active     (is_active)
) ENGINE=InnoDB COMMENT='Ethiopian administrative regions and cities';

-- ---------------------------------------------------------------------------
-- 1.2  CATEGORIES  (hierarchical / recursive, unlimited depth)
-- ---------------------------------------------------------------------------
CREATE TABLE categories (
    category_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    parent_id     INT UNSIGNED NULL COMMENT 'NULL = root category',
    category_name VARCHAR(150) NOT NULL,
    slug          VARCHAR(200) NOT NULL,
    description   TEXT NULL,
    image_url     VARCHAR(500) NULL,
    sort_order    SMALLINT     NOT NULL DEFAULT 0,
    is_active     TINYINT(1)   NOT NULL DEFAULT 1,
    deleted_at    DATETIME(3)  NULL COMMENT 'Soft delete',
    created_at    DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at    DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

    CONSTRAINT fk_cat_parent FOREIGN KEY (parent_id)
        REFERENCES categories(category_id) ON DELETE RESTRICT ON UPDATE CASCADE,

    UNIQUE KEY uq_category_slug      (slug),
    KEY        idx_cat_parent        (parent_id),
    KEY        idx_cat_active_sort   (is_active, sort_order),
    FULLTEXT KEY ft_category_name    (category_name, description)
) ENGINE=InnoDB COMMENT='Recursive product category tree';

-- ---------------------------------------------------------------------------
-- 1.3  PAYMENT METHOD TYPES  (lookup table instead of ENUM for extensibility)
-- ---------------------------------------------------------------------------
CREATE TABLE payment_method_types (
    method_id    TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    method_code  VARCHAR(50)  NOT NULL,
    method_name  VARCHAR(100) NOT NULL,
    is_digital   TINYINT(1)   NOT NULL DEFAULT 1,
    is_active    TINYINT(1)   NOT NULL DEFAULT 1,
    UNIQUE KEY uq_method_code (method_code)
) ENGINE=InnoDB COMMENT='Telebirr, bank transfer, cash on delivery, etc.';

-- ---------------------------------------------------------------------------
-- 1.4  ORDER STATUS LOOKUP  (state-machine)
-- ---------------------------------------------------------------------------
