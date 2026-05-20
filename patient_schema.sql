-- campaign_schema.sql
-- Table structures for campaigns scheduling and staff assignments.
-- Depends on user_schema.sql (users, roles) and geography_schema.sql (cities)

-- ------------------------------------------------------------
-- campaigns
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS campaigns (
    id             SERIAL       PRIMARY KEY,
    camp_name      VARCHAR(150) NOT NULL,
    city_id        INT          NOT NULL REFERENCES cities(id),
    camp_date      DATE         NOT NULL,
    status         VARCHAR(20)  NOT NULL DEFAULT 'Scheduled',
    coordinator_id INT          NOT NULL REFERENCES users(id),
    is_deleted     BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_campaign_status
        CHECK (status IN ('Active', 'Scheduled', 'Completed', 'Waiting'))
);

-- ------------------------------------------------------------
-- campaign_staff (junction table)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS campaign_staff (
    id          SERIAL PRIMARY KEY,
    campaign_id INT NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    user_id     INT NOT NULL REFERENCES users(id),
    role_id     INT NOT NULL REFERENCES roles(id),
    assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_staff_role
        CHECK (role_id IN (3, 4)),            -- only Volunteers or Optometrists
    CONSTRAINT uq_campaign_user
        UNIQUE (campaign_id, user_id)         -- no duplicate assignments
);

-- Trigger for campaigns updated_at
CREATE OR REPLACE FUNCTION trg_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS campaigns_set_updated_at ON campaigns;
CREATE TRIGGER campaigns_set_updated_at
BEFORE UPDATE ON campaigns
FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
