-- geography_schema.sql
-- Unified master lookup tables for countries, states, cities, ZIP mapping, and medical conditions.
-- This file contains NO destructive DROP CASCADE statements.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ------------------------------------------------------------
-- countries
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS countries (
    id         SERIAL      PRIMARY KEY,
    iso2       CHAR(2)     NOT NULL UNIQUE,
    iso3       CHAR(3)     NOT NULL UNIQUE,
    name       VARCHAR(100) NOT NULL,
    phone_code VARCHAR(10)
);

-- ------------------------------------------------------------
-- states
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS states (
    id         SERIAL       PRIMARY KEY,
    country_id INTEGER      NOT NULL REFERENCES countries(id),
    code       VARCHAR(10)  NOT NULL,
    name       VARCHAR(100) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_states_country_id ON states(country_id);

-- ------------------------------------------------------------
-- cities
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cities (
    id         SERIAL       PRIMARY KEY,
    state_id   INTEGER      NOT NULL REFERENCES states(id),
    country_id INTEGER      NOT NULL REFERENCES countries(id),
    name       VARCHAR(100) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_cities_state_id   ON cities(state_id);
CREATE INDEX IF NOT EXISTS idx_cities_country_id ON cities(country_id);

-- ------------------------------------------------------------
-- zip_code_mappings
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS zip_code_mappings (
    id         SERIAL      PRIMARY KEY,
    zip_code   VARCHAR(20) NOT NULL,
    city_id    INTEGER     NOT NULL REFERENCES cities(id),
    state_id   INTEGER     NOT NULL REFERENCES states(id),
    country_id INTEGER     NOT NULL REFERENCES countries(id)
);

CREATE INDEX IF NOT EXISTS idx_zip_code_mappings_zip ON zip_code_mappings(zip_code);

-- ------------------------------------------------------------
-- medical_conditions (Static reference checkbox labels)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS medical_conditions (
    id          SERIAL      PRIMARY KEY,
    code        VARCHAR(50) NOT NULL UNIQUE,
    description TEXT        NOT NULL,
    sort_order  INTEGER     NOT NULL DEFAULT 0
);

-- Populate static medical conditions
INSERT INTO medical_conditions (code, description, sort_order) VALUES
    ('BLURRED_VISION',    'Blurred Vision',              1),
    ('VISION_DIFFICULTY', 'Difficulty with Vision',      2),
    ('DOUBLE_VISION',     'Double Vision',               3),
    ('WEARING_CORRECTION','Currently Wearing Correction', 4)
ON CONFLICT (code) DO NOTHING;
