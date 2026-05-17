# Ethiopian E-Commerce Platform
## ADVANCED DATABASE SYSTEMS-GROUP 2 PROJECT

### Entity-Relationship Diagram & Relational Schema

---

## Project Overview

This project presents the database architecture and relational schema design for a scalable Ethiopian E-Commerce Platform.

The system is designed using:

- **3NF / BCNF normalization**
- Modular database subsystems
- Enterprise-level relational modeling
- Security and auditing structures
- Analytics and inventory tracking

---

## Project Statistics

| Category | Details |
|---|---|
| Total Tables | 32 |
| Functional Domains | 9 |
| Diagram Pages | 8 |
| Normalization | 3NF / BCNF |

---

## Supported Ethiopian Cities

- Addis Ababa
- Adama
- Hawassa
- Dire Dawa
- Mekelle
- Bahir Dar

---

# Database Subsystems

The platform database is divided into the following domains:

1. User & Identity
2. Product Catalog
3. Inventory
4. Orders
5. Payments
6. Analytics
7. Security & Audit
8. Social & Promo
9. Lookup / Reference

---

# Technology Focus

- Relational DATABASE Design
- PostgreSQL / MySQL Compatible Schema
- High Scalability
- Data Integrity Enforcement
- Optimized Relationships
- Enterprise Normalization Standards

---

# ER Diagram Structure

The following sections contain:

- Entity definitions
- Primary and foreign keys
- Relationship cardinalities
- Normalized schema design
- Domain-based architecture

---
# 1. User & Identity Domain

```mermaid
erDiagram

    USERS {
        BIGINT user_id PK
        TINYINT role_id FK
        SMALLINT region_id FK
        VARCHAR email
        VARCHAR phone_number
        VARCHAR password_hash
        VARCHAR first_name
        VARCHAR last_name
        DATE date_of_birth
        ENUM gender
        ENUM account_status
        BOOLEAN is_email_verified
        BOOLEAN is_phone_verified
        DATETIME last_login_at
        JSON metadata
        DATETIME created_at
        DATETIME updated_at
    }

    USER_ADDRESSES {
        BIGINT address_id PK
        BIGINT user_id FK
        VARCHAR region_id
        VARCHAR label
        VARCHAR recipient
        VARCHAR phone
        VARCHAR street
        VARCHAR sub_city
        VARCHAR woreda
        VARCHAR landmark
        DECIMAL latitude
        DECIMAL longitude
        BOOLEAN is_default
        DATETIME created_at
        DATETIME updated_at
    }

    SELLER_PROFILES {
        BIGINT seller_id PK
        SMALLINT region_id FK
        VARCHAR business_name
        VARCHAR business_tin
        VARCHAR business_type
        TEXT address
        VARCHAR bank_account_num
        VARCHAR bank_name
        DECIMAL commission_rate
        ENUM verification_status
        DATETIME verified_at
        JSON metadata
        DATETIME created_at
        DATETIME updated_at
    }

    REGIONS {
        SMALLINT region_id PK
        SMALLINT parent_region_id FK
        VARCHAR region_code
        VARCHAR region_name
        VARCHAR timezone
        DECIMAL latitude
        DECIMAL longitude
        BOOLEAN is_active
        DATETIME created_at
        DATETIME updated_at
    }

    USER_ROLES {
        TINYINT role_id PK
        VARCHAR role_code
        VARCHAR role_name
    }

    ORDER_STATUSES {
        TINYINT status_id PK
        VARCHAR status_code
        VARCHAR status_name
        BOOLEAN is_terminal
        TINYINT sort_order
    }

    PAYMENT_METHOD_TYPES {
        TINYINT method_id PK
        VARCHAR method_code
        VARCHAR method_name
        BOOLEAN is_digital
        BOOLEAN is_active
    }

    USERS ||--o{ USER_ADDRESSES : has
    USERS ||--|| SELLER_PROFILES : owns
    REGIONS ||--o{ USERS : contains
    REGIONS ||--o{ SELLER_PROFILES : contains
    USER_ROLES ||--o{ USERS : classifies
```

---

# Domain Description

This domain manages:

- User authentication and identity
- Seller business registration
- Geographic regional hierarchy
- Address management
- Lookup/reference structures
- Order status standardization
- Payment method classification

---

# Design Notes

## User Management
The `USERS` entity acts as the core identity table for customers, admins, and sellers.

## Seller Profiles
The `SELLER_PROFILES` entity extends users with business - specific INFORMATION.

## Regional Structure
The `REGIONS` table supports hierarchical Ethiopian geographic organization.

## Address Handling
Users can store multiple addresses with one default address.

## Lookup Tables
Reference tables improve normalization and enforce consistency across the platform.

---

# Normalization Level

- FULLY NORMALIZED TO **3NF / BCNF**
- Lookup/reference isolation applied
- Redundant data minimized
- Relationship integrity enforced

---
# 2.Product Catalog Subsystem

```mermaid
erDiagram

    CATEGORIES {
        INT category_id PK
        INT parent_id FK
        VARCHAR slug
        VARCHAR category_name
        TEXT description
        VARCHAR image_url
        SMALLINT sort_order
        BOOLEAN is_active
        DATETIME deleted_at
        DATETIME created_at
        DATETIME updated_at
    }

    PRODUCTS {
        BIGINT product_id PK
        BIGINT seller_id FK
        INT category_id FK
        VARCHAR sku
        VARCHAR slug
        VARCHAR product_name
        VARCHAR short_description
        LONGTEXT description
        VARCHAR brand
        DECIMAL base_price
        DECIMAL sale_price
        DECIMAL cost_price
        CHAR currency
        INT weight_grams
        BOOLEAN is_featured
        BOOLEAN is_active
        BOOLEAN requires_shipping
        JSON tags
        JSON metadata
        DECIMAL rating
        INT review_count
        DATETIME deleted_at
        DATETIME created_at
        DATETIME updated_at
    }

    PRODUCT_VARIANTS {
        BIGINT variant_id PK
        BIGINT product_id FK
        VARCHAR variant_sku
        VARCHAR variant_name
        DECIMAL price_delta
        INT weight_grams
        BOOLEAN is_active
        DATETIME deleted_at
        DATETIME created_at
        DATETIME updated_at
    }

    PRODUCT_IMAGES {
        BIGINT image_id PK
        BIGINT product_id FK
        BIGINT variant_id FK
        VARCHAR image_url
        VARCHAR alt_text
        TINYINT sort_order
        BOOLEAN is_primary
    }

    ATTRIBUTE_TYPES {
        INT attribute_type_id PK
        VARCHAR attribute_code
        VARCHAR attribute_name
        ENUM display_type
    }

    ATTRIBUTE_VALUES {
        INT attribute_value_id PK
        INT attribute_type_id FK
        VARCHAR value_label
        VARCHAR value_code
        CHAR hex_color
        TINYINT sort_order
    }

    VARIANT_ATTRIBUTES {
        BIGINT variant_id FK
        INT attribute_value_id FK
    }

    CATEGORIES ||--o{ PRODUCTS : categorizes

    CATEGORIES ||--o{ CATEGORIES : parent_category

    PRODUCTS ||--o{ PRODUCT_VARIANTS : has_variants

    PRODUCTS ||--o{ PRODUCT_IMAGES : has_images

    PRODUCT_VARIANTS ||--o{ PRODUCT_IMAGES : variant_images

    ATTRIBUTE_TYPES ||--o{ ATTRIBUTE_VALUES : defines

    PRODUCT_VARIANTS ||--o{ VARIANT_ATTRIBUTES : maps

    ATTRIBUTE_VALUES ||--o{ VARIANT_ATTRIBUTES : assigned_to
```

---
# Domain Description

This domain manages:

- Product catalog organization
- Hierarchical category structures
- Product and SKU management
- Variant-based inventory modeling
- Product image handling
- Dynamic attribute configuration
- Marketplace-ready merchandising structures
- Flexible catalog extensibility

---

# Design Notes

## Product Management
The `PRODUCTS` entity acts as the core catalog table for all sellable items within the platform.

## Category Hierarchy
The `CATEGORIES` entity supports recursive parent-child relationships for scalable multi-level catalog organization.

## Product Variants
The `PRODUCT_VARIANTS` entity extends products into configurable sellable variations such as size, color, and storage options.

## Attribute System
The combination of `ATTRIBUTE_TYPES`, `ATTRIBUTE_VALUES`, and `VARIANT_ATTRIBUTES` enables dynamic product configuration without schema modification.

## Product Images
The `PRODUCT_IMAGES` entity centralizes media management for both product-level and variant-level image assets.

## Junction Table Architecture
The `VARIANT_ATTRIBUTES` table resolves many-to-many relationships between variants and attribute values using normalized relational mapping.

---

# Normalization Level

- Fully normalized to **3NF / BCNF**
- Variant decomposition applied
- Recursive hierarchy normalization implemented
- Attribute lookup isolation enforced
- Many-to-many relationships resolved through junction tables
- Redundant product attribute storage minimized
- Referential integrity enforced
- Enterprise-scale catalog extensibility maintained

---

# 3.Inventory & Warehouse Domain

```mermaid
erDiagram

    REGIONS {
        SMALLINT region_id PK
        VARCHAR region_code
        VARCHAR region_name
    }

    WAREHOUSES {
        INT warehouse_id PK
        SMALLINT region_id FK
        VARCHAR warehouse_name
        VARCHAR address
        DECIMAL latitude
        DECIMAL longitude
        BOOLEAN is_active
        DATETIME created_at
    }

    PRODUCT_VARIANTS {
        BIGINT variant_id PK
        BIGINT product_id FK
        VARCHAR variant_sku
        VARCHAR variant_name
        DECIMAL price_delta
        BOOLEAN is_active
    }

    INVENTORY {
        BIGINT inventory_id PK
        BIGINT variant_id FK
        INT warehouse_id FK
        INT quantity_on_hand
        INT reserved_quantity
        INT available_quantity
        INT reorder_point
        INT reorder_quantity
        BOOLEAN low_stock_alert
        DATETIME last_restocked_at
        DATETIME updated_at
    }

    INVENTORY_TRANSACTIONS {
        BIGINT transaction_id PK
        BIGINT inventory_id FK
        BIGINT variant_id FK
        INT warehouse_id FK
        ENUM transaction_type
        INT quantity_delta
        INT quantity_after
        VARCHAR reference_type
        BIGINT reference_id
        VARCHAR notes
        BIGINT created_by FK
        DATETIME created_at
    }

    REGIONS ||--o{ WAREHOUSES : contains

    WAREHOUSES ||--o{ INVENTORY : stores

    PRODUCT_VARIANTS ||--o{ INVENTORY : tracked_as

    INVENTORY ||--o{ INVENTORY_TRANSACTIONS : records
```

---

# Domain Description

This domain manages:

- Warehouse management
- Regional inventory distribution
- Product stock tracking
- Multi-warehouse inventory control
- Inventory movement auditing
- Restocking operations
- Stock availability management
- Inventory transaction history

---

# Design Notes

## Warehouse Management
The `WAREHOUSES` entity manages physical storage facilities across different Ethiopian regions.

## Regional Structure
The `REGIONS` entity provides geographic organization for warehouse distribution and logistics management.

## Inventory Tracking
The `INVENTORY` entity tracks stock quantities for each product variant within specific warehouses.

## Product Variant Inventory
The `PRODUCT_VARIANTS` entity enables SKU-level inventory tracking for configurable products.

## Inventory Transactions
The `INVENTORY_TRANSACTIONS` entity records all stock movement activities including:

- Restocking
- Sales deductions
- Returns
- Adjustments
- Transfers

## Stock Control
Inventory quantities support operational stock management through:

- Reserved stock tracking
- Available stock calculations
- Reorder thresholds
- Low stock monitoring

---

# Normalization Level

- Fully normalized to **3NF / BCNF**
- Warehouse-region separation implemented
- Inventory transaction auditing normalized
- SKU-level inventory isolation enforced
- Redundant stock calculations minimized
- Relationship integrity enforced
- Multi-warehouse scalability supported
- Enterprise inventory control architecture maintained
---
# 4.Orders & Checkout Domain

```mermaid
erDiagram

    ORDER_STATUSES {
        TINYINT status_id PK
        VARCHAR status_code
        VARCHAR status_name
        BOOLEAN is_terminal
        TINYINT sort_order
    }

    PAYMENT_METHOD_TYPES {
        SMALLINT method_id PK
        VARCHAR method_code
        VARCHAR method_name
        BOOLEAN is_digital
        BOOLEAN is_active
    }

    USER_ADDRESSES {
        BIGINT address_id PK
        BIGINT user_id FK
        SMALLINT region_id FK
        VARCHAR street
        VARCHAR sub_city
        VARCHAR woreda
        BOOLEAN is_default
    }

    ORDERS {
        BIGINT order_id PK
        VARCHAR order_number
        BIGINT customer_id FK
        BIGINT seller_id FK
        BIGINT shipping_address_id FK
        BIGINT billing_address_id FK
        INT warehouse_id FK
        SMALLINT region_id FK
        TINYINT status_id FK
        SMALLINT payment_method_id FK
        DECIMAL subtotal_amount
        DECIMAL discount_amount
        DECIMAL shipping_fee
        DECIMAL tax_amount
        DECIMAL total_amount
        CHAR currency
        VARCHAR payment_status
        VARCHAR coupon_code
        TEXT notes
        DATETIME placed_at
        DATETIME confirmed_at
        DATETIME shipped_at
        DATETIME delivered_at
        DATETIME cancelled_at
        DATETIME deleted_at
        DATETIME updated_at
    }

    ORDER_ITEMS {
        BIGINT item_id PK
        BIGINT order_id FK
        BIGINT product_id FK
        BIGINT variant_id FK
        INT warehouse_id FK
        INT quantity
        DECIMAL unit_price
        DECIMAL discount_amount
        DECIMAL line_total
        VARCHAR item_status
        DATETIME created_at
        DATETIME updated_at
    }

    ORDER_STATUSES ||--o{ ORDERS : "assigned_to"
    PAYMENT_METHOD_TYPES ||--o{ ORDERS : "paid_via"
    USER_ADDRESSES ||--o{ ORDERS : "shipping_address"
    USER_ADDRESSES ||--o{ ORDERS : "billing_address"
    ORDERS ||--o{ ORDER_ITEMS : "contains"

```

                
---

# Domain Description

This domain manages:

- Customer order processing
- Checkout operations
- Order item management
- Payment method classification
- Order lifecycle tracking
- Shipping and billing addresses
- Regional fulfillment routing
- Multi-seller transaction handling

---

# Design Notes

## Order Management
The `ORDERS` entity acts as the central transactional table for all customer purchases across the platform.

## Order Lifecycle
The `ORDER_STATUSES` entity standardizes order progression stages including:

- Pending
- Confirmed
- Shipped
- Delivered
- Cancelled

## Checkout Processing
The `ORDERS` table manages pricing calculations including:

- Subtotals
- Discounts
- Shipping fees
- Taxes
- Final payable amounts

## Order Items
The `ORDER_ITEMS` entity stores individual purchasable items associated with each order.

This supports:

- Product-level fulfillment
- Warehouse allocation
- SKU-specific pricing
- Item-level status tracking

## Payment Methods
The `PAYMENT_METHOD_TYPES` entity standardizes supported payment channels including digital and traditional payment methods.

## Address Management
The `USER_ADDRESSES` entity supports separate:

- Shipping addresses
- Billing addresses

for flexible checkout workflows.

## Fulfillment Integration
Warehouse and regional references support distributed fulfillment and logistics routing across Ethiopia.

---

# Normalization Level

- Fully normalized to **3NF / BCNF**
- Transactional order decomposition applied
- Payment method lookup normalization enforced
- Order status standardization implemented
- Address reuse normalization supported
- Redundant pricing storage minimized
- Referential integrity enforced
- Enterprise checkout architecture maintained
---

#5.Payments & Refunds Domain

```mermaid
erDiagram
    ORDERS {
        BIGINT order_id PK
        VARCHAR order_number
        BIGINT customer_id FK
        DECIMAL total_amount
        ENUM payment_status
        DATETIME placed_at
    }

    PAYMENTS {
        BIGINT payment_id PK
        BIGINT order_id FK
        BIGINT customer_id FK
        TINYINT method_id FK
        VARCHAR idempotency_key
        DECIMAL amount
        VARCHAR currency
        ENUM status
        VARCHAR gateway_reference
        JSON gateway_response
        DATETIME paid_at
        DECIMAL refunded_amount
        VARCHAR failure_reason
        VARCHAR ip_address
        VARCHAR device_fingerprint
        BOOLEAN is_flagged
        DATETIME created_at
        DATETIME updated_at
    }

    REFUNDS {
        BIGINT refund_id PK
        BIGINT payment_id FK
        BIGINT order_id FK
        BIGINT requested_by FK
        BIGINT approved_by FK
        DECIMAL refund_amount
        VARCHAR reason
        ENUM status
        VARCHAR gateway_ref
        TEXT notes
        DATETIME created_at
        DATETIME updated_at
    }

    PAYMENT_METHOD_TYPES {
        TINYINT method_id PK
        VARCHAR method_code
        VARCHAR method_name
        BOOLEAN is_digital
    }

    USERS {
        BIGINT user_id PK
        VARCHAR email
        VARCHAR first_name
        VARCHAR last_name
    }

    ORDERS ||--o{ PAYMENTS : "generates"
    PAYMENT_METHOD_TYPES ||--o{ PAYMENTS : "uses"
    USERS ||--o{ PAYMENTS : "makes"
    PAYMENTS ||--o{ REFUNDS : "produces"
    ORDERS ||--o{ REFUNDS : "contains"
    USERS ||--o{ REFUNDS : "requests"
    USERS ||--o{ REFUNDS : "approves"

```
---

# Domain Description

This domain manages:

- Customer payment processing
- Payment method integration
- Refund workflows
- Financial transaction tracking
- Fraud monitoring and auditing

---

# Design Notes

## Payment Management
`PAYMENTS` stores all customer payment transactions and gateway responses.

## Refund Processing
`REFUNDS` manages refund requests, approvals, and refund transaction tracking.

## Payment Methods
`PAYMENT_METHOD_TYPES` standardizes supported payment channels.

## Security & Auditing
Fraud detection fields and audit timestamps support secure transaction monitoring.

---

# Normalization Level

- Fully normalized to **3NF / BCNF**
- Referential integrity enforced
- Lookup table normalization applied
- Scalable transactional architecture maintained
- Financial auditing structure implemented
---
# 6. Security & Audit Domain

```mermaid
erDiagram

USERS {
    BIGINT user_id PK
    VARCHAR email
    VARCHAR name
    INT account_status
    INT failed_login_count
    DATETIME lockout_until
    DATETIME last_login_at
}

LOGIN_ATTEMPTS {
    BIGINT attempt_id PK
    BIGINT user_id
    VARCHAR email
    VARCHAR ip_address
    VARCHAR user_agent
    INT status
    VARCHAR failure_reason
    DATETIME attempted_at
}

USER_SESSIONS {
    VARCHAR session_id PK
    BIGINT user_id
    VARCHAR ip_address
    VARCHAR user_agent
    INT device_type
    INT is_active
    DATETIME expires_at
    DATETIME created_at
    DATETIME last_active_at
}

AUDIT_LOGS {
    BIGINT log_id PK
    BIGINT user_id
    VARCHAR session_id
    VARCHAR action
    VARCHAR entity_type
    BIGINT entity_id
    VARCHAR old_values
    VARCHAR new_values
    VARCHAR ip_address
    INT status
    VARCHAR message
    DATETIME created_at
}

FRAUD_LOGS {
    BIGINT fraud_id PK
    BIGINT user_id
    BIGINT order_id
    BIGINT payment_id
    INT fraud_type
    INT risk_score
    VARCHAR details
    INT action_taken
    BIGINT reviewed_by
    DATETIME reviewed_at
    DATETIME created_at
}

USERS ||--o{ LOGIN_ATTEMPTS : generates
USERS ||--o{ USER_SESSIONS : owns
USERS ||--o{ AUDIT_LOGS : triggers
USERS ||--o{ FRAUD_LOGS : flagged
USER_SESSIONS ||--o{ AUDIT_LOGS : tracks

```
