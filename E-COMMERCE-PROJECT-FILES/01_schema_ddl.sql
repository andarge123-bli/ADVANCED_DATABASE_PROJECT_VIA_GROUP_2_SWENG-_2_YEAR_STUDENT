--=============================================================================
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
CREATE TABLE order_statuses (
    status_id    TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    status_code  VARCHAR(50)  NOT NULL,
    status_name  VARCHAR(100) NOT NULL,
    is_terminal  TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '1 = no further transitions allowed',
    sort_order   TINYINT      NOT NULL DEFAULT 0,
    UNIQUE KEY uq_order_status_code (status_code)
) ENGINE=InnoDB COMMENT='Order lifecycle states';

-- ---------------------------------------------------------------------------
-- 1.5  USER ROLES  (RBAC lookup)
-- ---------------------------------------------------------------------------
CREATE TABLE user_roles (
    role_id   TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    role_code VARCHAR(50)  NOT NULL,
    role_name VARCHAR(100) NOT NULL,
    UNIQUE KEY uq_role_code (role_code)
) ENGINE=InnoDB COMMENT='admin, seller, customer, support, etc.';

-- =============================================================================
-- SECTION 2: USERS (Customers & Sellers share this base table — common pattern)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 2.1  USERS  (base identity table)
-- ---------------------------------------------------------------------------
CREATE TABLE users (
    user_id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    role_id          TINYINT UNSIGNED NOT NULL,
    email            VARCHAR(255) NOT NULL,
    phone_number     VARBINARY(512) NOT NULL COMMENT 'AES-encrypted E.164 phone',
    password_hash    VARCHAR(255) NOT NULL COMMENT 'bcrypt $2b$ hash, cost>=12',
    first_name       VARCHAR(100) NOT NULL,
    last_name        VARCHAR(100) NOT NULL,
    display_name     VARCHAR(150) AS (CONCAT(first_name, ' ', last_name)) STORED,
    date_of_birth    DATE NULL,
    gender           ENUM('M','F','OTHER','PREFER_NOT') NULL,
    profile_image    VARCHAR(500) NULL,
    preferred_lang   CHAR(5)      NOT NULL DEFAULT 'am' COMMENT 'BCP-47: am=Amharic',
    region_id        SMALLINT UNSIGNED NULL COMMENT 'Home city/region',
    is_email_verified TINYINT(1)  NOT NULL DEFAULT 0,
    is_phone_verified TINYINT(1)  NOT NULL DEFAULT 0,
    account_status   ENUM('ACTIVE','SUSPENDED','BANNED','PENDING_VERIFICATION')
                     NOT NULL DEFAULT 'PENDING_VERIFICATION',
    last_login_at    DATETIME(3)  NULL,
    failed_login_cnt TINYINT UNSIGNED NOT NULL DEFAULT 0,
    lockout_until    DATETIME(3)  NULL,
    metadata         JSON         NULL COMMENT 'Extensible attributes',
    deleted_at       DATETIME(3)  NULL COMMENT 'Soft delete',
    created_at       DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at       DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

    CONSTRAINT fk_user_role   FOREIGN KEY (role_id)   REFERENCES user_roles(role_id),
    CONSTRAINT fk_user_region FOREIGN KEY (region_id) REFERENCES regions(region_id),

    UNIQUE KEY uq_user_email        (email),
    KEY        idx_user_phone       (phone_number(64)),
    KEY        idx_user_role        (role_id),
    KEY        idx_user_region      (region_id),
    KEY        idx_user_status      (account_status),
    KEY        idx_user_deleted     (deleted_at),
    KEY        idx_user_created     (created_at)
) ENGINE=InnoDB COMMENT='All platform users: customers, sellers, admins';

-- ---------------------------------------------------------------------------
-- 2.2  USER ADDRESSES
-- ---------------------------------------------------------------------------
CREATE TABLE user_addresses (
    address_id   BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id      BIGINT UNSIGNED NOT NULL,
    region_id    SMALLINT UNSIGNED NOT NULL,
    label        VARCHAR(50)  NOT NULL DEFAULT 'Home' COMMENT 'Home, Office, Other',
    recipient    VARCHAR(200) NOT NULL,
    phone        VARBINARY(512) NOT NULL,
    street       VARCHAR(300) NOT NULL,
    sub_city     VARCHAR(100) NULL,
    woreda       VARCHAR(100) NULL,
    landmark     VARCHAR(300) NULL,
    postal_code  VARCHAR(20)  NULL,
    latitude     DECIMAL(10,7) NULL,
    longitude    DECIMAL(10,7) NULL,
    is_default   TINYINT(1)   NOT NULL DEFAULT 0,
    deleted_at   DATETIME(3)  NULL,
    created_at   DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at   DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

    CONSTRAINT fk_addr_user   FOREIGN KEY (user_id)   REFERENCES users(user_id)   ON DELETE CASCADE,
    CONSTRAINT fk_addr_region FOREIGN KEY (region_id) REFERENCES regions(region_id),
UNIQUE (user_id, is_default) WHERE is_default = 1,
    KEY idx_addr_user    (user_id),
    KEY idx_addr_region  (region_id),
    KEY idx_addr_default (user_id, is_default)
) ENGINE=InnoDB COMMENT='Shipping / billing addresses';

-- ---------------------------------------------------------------------------
-- 2.3  SELLER PROFILES
-- ---------------------------------------------------------------------------
CREATE TABLE seller_profiles (
    seller_id          BIGINT UNSIGNED PRIMARY KEY COMMENT 'Same as users.user_id',
    business_name      VARCHAR(200) NOT NULL,
    business_tin       VARCHAR(50)  NULL COMMENT 'Tax Identification Number',
    business_type      ENUM('INDIVIDUAL','COMPANY','COOPERATIVE') NOT NULL DEFAULT 'INDIVIDUAL',
    region_id          SMALLINT UNSIGNED NOT NULL,
    address            VARCHAR(500) NOT NULL,
    bank_account_name  VARBINARY(512) NULL COMMENT 'Encrypted',
    bank_account_num   VARBINARY(512) NULL COMMENT 'Encrypted',
    bank_name          VARCHAR(100) NULL,
    telebirr_account   VARBINARY(512) NULL COMMENT 'Encrypted',
    commission_rate    DECIMAL(5,4) NOT NULL DEFAULT 0.0800 COMMENT '8% default',
    rating             DECIMAL(3,2) NOT NULL DEFAULT 0.00,
    total_reviews      INT UNSIGNED NOT NULL DEFAULT 0,
    verification_status ENUM('PENDING','VERIFIED','REJECTED','SUSPENDED')
                        NOT NULL DEFAULT 'PENDING',
    verified_at        DATETIME(3) NULL,
    metadata           JSON NULL,
    created_at         DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at         DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

    CONSTRAINT fk_seller_user   FOREIGN KEY (seller_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_seller_region FOREIGN KEY (region_id) REFERENCES regions(region_id),

    KEY idx_seller_region  (region_id),
    KEY idx_seller_status  (verification_status),
    KEY idx_seller_rating  (rating DESC)
) ENGINE=InnoDB COMMENT='Extended profile for seller users';

-- =============================================================================
-- SECTION 3: PRODUCT CATALOG
-- =============================================================================
