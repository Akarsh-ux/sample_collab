-- patient_schema.sql
-- Table structures for patient registrations and medical intake questionnaires.
-- Depends on geography_schema.sql (cities, states, countries)

-- ------------------------------------------------------------
-- camps
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS camps (
    id        SERIAL       PRIMARY KEY,
    name      VARCHAR(100) NOT NULL,
    location  VARCHAR(255),
    camp_date DATE,
    is_active BOOLEAN      NOT NULL DEFAULT TRUE
);

-- Seed camps dummy data so dropdown lists work
INSERT INTO camps (name, location, camp_date, is_active) VALUES
    ('Spring Camp 2025',  'Los Angeles, CA',  '2025-04-15', TRUE),
    ('Summer Camp 2025',  'Chicago, IL',       '2025-07-20', TRUE),
    ('Fall Camp 2025',    'New York, NY',      '2025-10-05', TRUE),
    ('Winter Camp 2024',  'Houston, TX',       '2024-12-10', FALSE)
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------
-- patients
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS patients (
    id           UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    first_name   VARCHAR(100) NOT NULL,
    last_name    VARCHAR(100) NOT NULL,
    gender       VARCHAR(20),
    dob          DATE         NOT NULL CHECK (dob <= CURRENT_DATE),
    phone_number VARCHAR(20),
    photo_url    TEXT,
    address_line VARCHAR(255),
    zip_code     VARCHAR(20),
    city_id      INTEGER      REFERENCES cities(id),
    state_id     INTEGER      REFERENCES states(id),
    country_id   INTEGER      REFERENCES countries(id),
    camp_id      INTEGER      REFERENCES camps(id),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    deleted_at   TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_patients_first_name  ON patients USING GIN (first_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_patients_last_name   ON patients USING GIN (last_name  gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_patients_camp_id     ON patients(camp_id);
CREATE INDEX IF NOT EXISTS idx_patients_deleted_at  ON patients(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_patients_zip_code    ON patients(zip_code);

-- ------------------------------------------------------------
-- medical_questionnaire
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS medical_questionnaire (
    patient_id           UUID        PRIMARY KEY REFERENCES patients(id) ON DELETE CASCADE,
    IsBlurredVision      SMALLINT    NOT NULL DEFAULT 0,
    IsVisionDifficulty   SMALLINT    NOT NULL DEFAULT 0,
    IsDoubleVision       SMALLINT    NOT NULL DEFAULT 0,
    IsWearingCorrection  SMALLINT    NOT NULL DEFAULT 0,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Triggers for setting updated_at on patient records
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_patients_updated_at ON patients;
CREATE TRIGGER trg_patients_updated_at
    BEFORE UPDATE ON patients
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_mq_updated_at ON medical_questionnaire;
CREATE TRIGGER trg_mq_updated_at
    BEFORE UPDATE ON medical_questionnaire
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
