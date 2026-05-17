# 6. Security & Audit Domain

```mermaid
erDiagram

USERS {
    BIGINT user_id PK
    VARCHAR email
    VARCHAR name
    ENUM account_status
    TINYINT failed_login_count
    DATETIME lockout_until
    DATETIME last_login_at
}

LOGIN_ATTEMPTS {
    BIGINT attempt_id PK
    BIGINT user_id
    VARCHAR email
    VARBINARY ip_address
    VARCHAR user_agent
    ENUM status
    VARCHAR failure_reason
    DATETIME attempted_at
}

USER_SESSIONS {
    VARCHAR session_id PK
    BIGINT user_id
    VARBINARY ip_address
    VARCHAR user_agent
    ENUM device_type
    BOOLEAN is_active
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
    JSON old_values
    JSON new_values
    VARBINARY ip_address
    ENUM status
    VARCHAR message
    DATETIME created_at
}

FRAUD_LOGS {
    BIGINT fraud_id PK
    BIGINT user_id
    BIGINT order_id
    BIGINT payment_id
    ENUM fraud_type
    TINYINT risk_score
    JSON details
    ENUM action_taken
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

---

# Domain Description

This domain manages:

- User authentication and login security  
- Session lifecycle tracking across devices  
- Audit logging for system activity and compliance  
- Fraud detection and risk analysis  
- Security event monitoring and reporting  
- Login attempt tracking and abuse prevention  

---

# Design Notes

## Authentication Security
Tracks user login attempts, failed logins, and account lockouts to prevent brute-force attacks.

## Session Management
Handles active sessions, device tracking, and session expiration for secure access control.

## Audit Logging
Stores immutable logs of user and system actions for compliance, debugging, and traceability.

## Fraud Monitoring
Detects suspicious transactions using risk scoring and stores investigation results.

## Security Monitoring
Combines login activity, session behavior, and audit trails for full security observability.

---

# Normalization Level

- Fully normalized to **3NF / BCNF**
- Login, session, audit, and fraud concerns separated
- No redundant data duplication
- Referential integrity maintained across all relations
- Event-driven security tracking structure
- Scalable audit and monitoring architecture

# 7. Analytics, Promotions & Distributed Architecture Domain

```mermaid
erDiagram

DAILY_SALES_SUMMARY {
    DATE summary_date PK
    SMALLINT region_id PK
    BIGINT seller_id PK
    INT total_orders
    DECIMAL total_revenue
    INT total_items_sold
    DECIMAL total_refunds
    DECIMAL avg_order_value
    DATETIME updated_at
}

PRODUCT_SALES_STATS {
    BIGINT product_id PK
    DATE period_date PK
    INT units_sold
    DECIMAL revenue
    INT return_count
    INT views
    DATETIME updated_at
}

CUSTOMER_LTV {
    BIGINT customer_id PK
    DATE first_order_date
    DATE last_order_date
    INT total_orders
    DECIMAL total_spent
    DECIMAL total_refunds
    DECIMAL avg_order_value
    DECIMAL ltv_score
    ENUM vip_score_segment
    DATETIME updated_at
}

PRODUCT_REVIEWS {
    BIGINT review_id PK
    BIGINT product_id PK
    BIGINT customer_id
    BIGINT order_id
    TINYINT rating
    VARCHAR title
    TEXT body
    BOOLEAN is_verified
    BOOLEAN is_approved
    INT helpful_votes
    DATETIME deleted_at
    DATETIME created_at
}

COUPONS {
    BIGINT coupon_id PK
    VARCHAR coupon_code
    BIGINT created_by
    ENUM discount_type
    DECIMAL discount_value
    DECIMAL min_order_amount
    DECIMAL max_discount
    INT usage_limit
    INT usage_count
    INT per_user_limit
    DATETIME valid_from
    DATETIME valid_until
    BOOLEAN is_active
    DATETIME created_at
}

NOTIFICATIONS {
    BIGINT notification_id PK
    BIGINT user_id
    VARCHAR type
    ENUM channel
    VARCHAR title
    TEXT body
    JSON data
    BOOLEAN is_read
    DATETIME sent_at
    DATETIME read_at
    DATETIME created_at
}

SHARD_MAP {
    TINYINT shard_id PK
    VARCHAR shard_name
    VARCHAR primary_dsn
    VARCHAR replica_dsn
    JSON region_ids
    BOOLEAN is_active
    BIGINT max_user_id
    BIGINT min_user_id
}

COUPONS ||--o{ NOTIFICATIONS : triggers

```

---

# Domain Description

This domain manages:

- Business intelligence and reporting metrics  
- Product performance analytics  
- Customer lifetime value calculations  
- Product reviews and feedback system  
- Promotional coupon management  
- Notification delivery system  
- Distributed database shard configuration  

---

# Design Notes

## Analytics Layer
Aggregated tables like `DAILY_SALES_SUMMARY`, `PRODUCT_SALES_STATS`, and `CUSTOMER_LTV` are used for reporting and BI dashboards.

## Review System
`PRODUCT_REVIEWS` captures customer feedback and supports moderation workflows.

## Promotion Engine
`COUPONS` handles discount rules, usage limits, and campaign configuration.

## Notification System
`NOTIFICATIONS` manages multi-channel user communication (email, SMS, in-app).

## Distributed Architecture
`SHARD_MAP` defines database partitioning strategy across regions and scaling layers.

## Event Flow (Light Coupling)
Coupons can trigger notifications for promotional campaigns.

---

# Normalization Level

- Fully normalized to **3NF / BCNF**
- Analytical tables separated from transactional data
- Event-driven promotion flow (coupons → notifications)
- Review system decoupled from analytics
- Sharding configuration isolated from business logic
- Designed for horizontal scalability
- 
-- =============== -- END OF ER DIAGRAM --==============================================
