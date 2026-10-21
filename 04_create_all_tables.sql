-- 1. vehicle_types
CREATE TABLE vehicle_types (
    vehicle_type_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name             VARCHAR(50)  NOT NULL UNIQUE,
    max_weight_kg    NUMERIC(8,2) NOT NULL CHECK (max_weight_kg > 0),
    max_volume_cft   NUMERIC(8,2) NOT NULL CHECK (max_volume_cft > 0)
);

-- 2. drivers
CREATE TABLE drivers (
    driver_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    phone           VARCHAR(15)  NOT NULL UNIQUE,
    license_number  VARCHAR(30)  NOT NULL UNIQUE,
    is_active       BOOLEAN      NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- 3. users (staff: dispatcher, manager, admin)
CREATE TABLE users (
    user_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    email       VARCHAR(100) NOT NULL UNIQUE,
    role        VARCHAR(20)  NOT NULL CHECK (role IN ('dispatcher', 'manager', 'admin')),
    is_active   BOOLEAN      NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- 4. vehicles
CREATE TABLE vehicles (
    vehicle_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vehicle_number   VARCHAR(20) NOT NULL UNIQUE,
    vehicle_type_id  INT NOT NULL REFERENCES vehicle_types(vehicle_type_id),
    owner_driver_id  INT REFERENCES drivers(driver_id),
    is_active        BOOLEAN NOT NULL DEFAULT true
);

-- 5. pricing_rules
CREATE TABLE pricing_rules (
    rule_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vehicle_type_id  INT NOT NULL REFERENCES vehicle_types(vehicle_type_id),
    base_fare        NUMERIC(10,2) NOT NULL CHECK (base_fare >= 0),
    per_km_rate      NUMERIC(10,2) NOT NULL CHECK (per_km_rate >= 0),
    valid_from       DATE NOT NULL,
    valid_to         DATE,
    created_by       INT NOT NULL REFERENCES users(user_id),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

-- 6. bookings
CREATE TABLE bookings (
    booking_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id      INT NOT NULL REFERENCES customers(customer_id),
    vehicle_type_id  INT NOT NULL REFERENCES vehicle_types(vehicle_type_id),
    pickup_address   TEXT NOT NULL,
    drop_address     TEXT NOT NULL,
    distance_km      NUMERIC(8,2) CHECK (distance_km > 0),
    requested_time   TIMESTAMPTZ NOT NULL,
    status           VARCHAR(20) NOT NULL DEFAULT 'requested'
                     CHECK (status IN ('requested', 'confirmed', 'in_progress', 'completed', 'cancelled')),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. booking_items (deleted together with their booking)
CREATE TABLE booking_items (
    item_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id  INT NOT NULL REFERENCES bookings(booking_id) ON DELETE CASCADE,
    item_name   VARCHAR(100) NOT NULL,
    quantity    INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
    weight_kg   NUMERIC(8,2) CHECK (weight_kg > 0),
    notes       TEXT
);

-- 8. driver_assignments
CREATE TABLE driver_assignments (
    assignment_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id     INT NOT NULL REFERENCES bookings(booking_id),
    driver_id      INT NOT NULL REFERENCES drivers(driver_id),
    vehicle_id     INT NOT NULL REFERENCES vehicles(vehicle_id),
    assigned_by    INT NOT NULL REFERENCES users(user_id),
    start_time     TIMESTAMPTZ NOT NULL,
    end_time       TIMESTAMPTZ NOT NULL,
    assigned_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_active      BOOLEAN NOT NULL DEFAULT true,
    CHECK (end_time > start_time)
);

-- 9. booking_status_history
CREATE TABLE booking_status_history (
    history_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id   INT NOT NULL REFERENCES bookings(booking_id),
    from_status  VARCHAR(20),
    to_status    VARCHAR(20) NOT NULL,
    changed_by   INT REFERENCES users(user_id),
    changed_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 10. booking_price_breakdowns (the price lock)
CREATE TABLE booking_price_breakdowns (
    breakdown_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id       INT NOT NULL UNIQUE REFERENCES bookings(booking_id),
    rule_id          INT NOT NULL REFERENCES pricing_rules(rule_id),
    distance_km      NUMERIC(8,2)  NOT NULL CHECK (distance_km > 0),
    base_amount      NUMERIC(10,2) NOT NULL CHECK (base_amount >= 0),
    distance_amount  NUMERIC(10,2) NOT NULL CHECK (distance_amount >= 0),
    total_amount     NUMERIC(10,2) NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (total_amount = base_amount + distance_amount)
);

-- 11. payments (simulated)
CREATE TABLE payments (
    payment_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id       INT NOT NULL REFERENCES bookings(booking_id),
    amount           NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    method           VARCHAR(10) NOT NULL CHECK (method IN ('upi', 'cash', 'card')),
    status           VARCHAR(10) NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending', 'success', 'failed', 'refunded')),
    idempotency_key  VARCHAR(100) NOT NULL UNIQUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 12. reviews
CREATE TABLE reviews (
    review_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id  INT NOT NULL UNIQUE REFERENCES bookings(booking_id),
    rating      SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);