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
-- ---------------------------------------------------------------------------
-- 3.1  PRODUCTS
-- ---------------------------------------------------------------------------
CREATE TABLE products (
    product_id    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    seller_id     BIGINT UNSIGNED NOT NULL,
    category_id   INT UNSIGNED    NOT NULL,
    sku           VARCHAR(100) NOT NULL COMMENT 'Global catalog SKU',
    product_name  VARCHAR(300) NOT NULL,
    slug          VARCHAR(350) NOT NULL,
    short_desc    VARCHAR(500) NULL,
    description   LONGTEXT     NULL,
    brand         VARCHAR(150) NULL,
    base_price    DECIMAL(14,2) NOT NULL COMMENT 'In Ethiopian Birr (ETB)',
    sale_price    DECIMAL(14,2) NULL,
    cost_price    DECIMAL(14,2) NULL COMMENT 'Seller cost; not shown to buyers',
    currency      CHAR(3)       NOT NULL DEFAULT 'ETB',
    weight_grams  INT UNSIGNED  NULL,
    is_featured   TINYINT(1)    NOT NULL DEFAULT 0,
    is_active     TINYINT(1)    NOT NULL DEFAULT 1,
    requires_shipping TINYINT(1) NOT NULL DEFAULT 1,
    tags          JSON          NULL COMMENT 'Array of tag strings',
    metadata      JSON          NULL,
    rating        DECIMAL(3,2)  NOT NULL DEFAULT 0.00,
    review_count  INT UNSIGNED  NOT NULL DEFAULT 0,
    deleted_at    DATETIME(3)   NULL,
    created_at    DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at    DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

    CONSTRAINT fk_prod_seller   FOREIGN KEY (seller_id)   REFERENCES users(user_id)       ON DELETE RESTRICT,
    CONSTRAINT fk_prod_category FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE RESTRICT,
    CONSTRAINT chk_prod_price   CHECK (base_price >= 0),
    CONSTRAINT chk_sale_price   CHECK (sale_price IS NULL OR sale_price >= 0),

    UNIQUE KEY uq_product_sku       (sku),
    UNIQUE KEY uq_product_slug      (slug),
    KEY        idx_prod_seller      (seller_id),
    KEY        idx_prod_category    (category_id),
    KEY        idx_prod_active      (is_active, deleted_at),
    KEY        idx_prod_featured    (is_featured, is_active),
    -- Covering index for product listing (category + price filter)
    KEY        idx_prod_cat_price   (category_id, base_price, is_active, deleted_at),
    -- Covering index for seller dashboard
    KEY        idx_prod_seller_active (seller_id, is_active, created_at),
    FULLTEXT KEY ft_product_search  (product_name, short_desc, brand)
) ENGINE=InnoDB COMMENT='Master product catalog';

-- ---------------------------------------------------------------------------
-- 3.2  PRODUCT IMAGES
-- ---------------------------------------------------------------------------
CREATE TABLE product_images (
    image_id    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id  BIGINT UNSIGNED NOT NULL,
    variant_id  BIGINT UNSIGNED NULL COMMENT 'Optional: link to specific variant',
    url         VARCHAR(500) NOT NULL,
    alt_text    VARCHAR(300) NULL,
    sort_order  TINYINT UNSIGNED NOT NULL DEFAULT 0,
    is_primary  TINYINT(1) NOT NULL DEFAULT 0,

    CONSTRAINT fk_img_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,

    KEY idx_img_product (product_id, sort_order)
) ENGINE=InnoDB COMMENT='Product and variant images';

-- ---------------------------------------------------------------------------
-- 3.3  PRODUCT ATTRIBUTE TYPES  (size, color, material…)
-- ---------------------------------------------------------------------------
CREATE TABLE attribute_types (
    attr_type_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    attr_name     VARCHAR(100) NOT NULL COMMENT 'Color, Size, Material',
    attr_code     VARCHAR(50)  NOT NULL,
    display_type  ENUM('SWATCH','DROPDOWN','RADIO','TEXT') NOT NULL DEFAULT 'DROPDOWN',
    UNIQUE KEY uq_attr_code (attr_code)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 3.4  PRODUCT ATTRIBUTE VALUES  (Red, XL, Cotton…)
-- ---------------------------------------------------------------------------
CREATE TABLE attribute_values (
    attr_value_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    attr_type_id  INT UNSIGNED NOT NULL,
    value_label   VARCHAR(100) NOT NULL,
    value_code    VARCHAR(100) NOT NULL,
    hex_color     CHAR(7) NULL COMMENT '#RRGGBB for swatch',
    sort_order    TINYINT NOT NULL DEFAULT 0,

    CONSTRAINT fk_attrval_type FOREIGN KEY (attr_type_id)
        REFERENCES attribute_types(attr_type_id) ON DELETE CASCADE,

    UNIQUE KEY uq_attr_value (attr_type_id, value_code),
    KEY idx_attrval_type (attr_type_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 3.5  PRODUCT VARIANTS  (specific sellable combinations)
-- ---------------------------------------------------------------------------
CREATE TABLE product_variants (
    variant_id    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id    BIGINT UNSIGNED NOT NULL,
    variant_sku   VARCHAR(150) NOT NULL,
    variant_name  VARCHAR(200) NULL COMMENT 'e.g. "Red / XL"',
    price_delta   DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'Added to base_price',
    weight_grams  INT UNSIGNED  NULL,
    is_active     TINYINT(1)    NOT NULL DEFAULT 1,
    deleted_at    DATETIME(3)   NULL,
    created_at    DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at    DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

    CONSTRAINT fk_var_product FOREIGN KEY (product_id)
        REFERENCES products(product_id) ON DELETE CASCADE,
    CONSTRAINT chk_price_delta CHECK (price_delta >= -99999),

    UNIQUE KEY uq_variant_sku     (variant_sku),
    KEY        idx_var_product    (product_id, is_active)
) ENGINE=InnoDB COMMENT='Specific product variants (SKU-level)';

-- ---------------------------------------------------------------------------
-- 3.6  VARIANT ATTRIBUTE MAP  (many-to-many)
-- ---------------------------------------------------------------------------
CREATE TABLE variant_attributes (
    variant_id    BIGINT UNSIGNED NOT NULL,
    attr_value_id INT UNSIGNED NOT NULL,

    PRIMARY KEY (variant_id, attr_value_id),
    CONSTRAINT fk_va_variant FOREIGN KEY (variant_id)
        REFERENCES product_variants(variant_id) ON DELETE CASCADE,
    CONSTRAINT fk_va_attrval FOREIGN KEY (attr_value_id)
        REFERENCES attribute_values(attr_value_id) ON DELETE RESTRICT,
    KEY idx_va_attr (attr_value_id)
) ENGINE=InnoDB COMMENT='Links variant to its attribute values';

-- =============================================================================
-- SECTION 4: INVENTORY (multi-warehouse, multi-region)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 4.1  WAREHOUSES
-- ---------------------------------------------------------------------------
CREATE TABLE warehouses (
    warehouse_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    region_id      SMALLINT UNSIGNED NOT NULL,
    warehouse_name VARCHAR(150) NOT NULL,
    address        VARCHAR(500) NOT NULL,
    latitude       DECIMAL(10,7) NULL,
    longitude      DECIMAL(10,7) NULL,
    is_active      TINYINT(1)   NOT NULL DEFAULT 1,
    created_at     DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    CONSTRAINT fk_wh_region FOREIGN KEY (region_id) REFERENCES regions(region_id),

    KEY idx_wh_region (region_id),
    KEY idx_wh_active (is_active)
) ENGINE=InnoDB COMMENT='Physical fulfillment warehouses per region';

-- ---------------------------------------------------------------------------
-- 4.2  INVENTORY  (core — one row per variant per warehouse)
-- ---------------------------------------------------------------------------
CREATE TABLE inventory (
    inventory_id       BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    variant_id         BIGINT UNSIGNED NOT NULL,
    warehouse_id       INT UNSIGNED    NOT NULL,
    quantity_on_hand   INT NOT NULL DEFAULT 0 COMMENT 'Actual physical stock',
    reserved_quantity  INT NOT NULL DEFAULT 0 COMMENT 'Held for pending orders',
    reorder_point      INT NOT NULL DEFAULT 10,
    reorder_quantity   INT NOT NULL DEFAULT 50,
    low_stock_alert    TINYINT(1) NOT NULL DEFAULT 0,
    last_restocked_at  DATETIME(3) NULL,
    updated_at         DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

    CONSTRAINT fk_inv_variant   FOREIGN KEY (variant_id)   REFERENCES product_variants(variant_id) ON DELETE CASCADE,
    CONSTRAINT fk_inv_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
    CONSTRAINT chk_inv_qty      CHECK (quantity_on_hand  >= 0),
    CONSTRAINT chk_inv_reserved CHECK (reserved_quantity >= 0),
    CONSTRAINT chk_inv_available CHECK (quantity_on_hand >= reserved_quantity),

    UNIQUE KEY uq_inv_variant_wh (variant_id, warehouse_id),
    KEY        idx_inv_warehouse (warehouse_id),
    KEY        idx_inv_low_stock (low_stock_alert, quantity_on_hand)
) ENGINE=InnoDB COMMENT='Real-time inventory per variant per warehouse';
