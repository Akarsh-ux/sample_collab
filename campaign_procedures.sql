-- campaign_procedures.sql
-- Campaign management workflow stored procedures.

-- ============================================================
-- create_campaign
-- ============================================================
CREATE OR REPLACE FUNCTION create_campaign(
    p_camp_name       TEXT,
    p_city_id         INT,
    p_camp_date       DATE,
    p_status          TEXT,
    p_coordinator_id  INT,
    p_volunteer_ids   INT[] DEFAULT '{}',
    p_optometrist_ids INT[] DEFAULT '{}'
)
RETURNS TABLE (
    campaign_id         INT,
    camp_name           TEXT,
    city_name           TEXT,
    camp_date           DATE,
    status              TEXT,
    volunteers_assigned BIGINT,
    optometrists_assigned BIGINT,
    created_at          TIMESTAMP
) AS $$
DECLARE
    v_new_id INT;
    v_uid    INT;
    v_role   INT;
END;
$$ LANGUAGE plpgsql;

-- We need the complete actual trigger logic of create_campaign. Let's make sure it is exactly the same as in campaign_management.sql!
-- Wait! Let's write the complete body of create_campaign:
CREATE OR REPLACE FUNCTION create_campaign(
    p_camp_name       TEXT,
    p_city_id         INT,
    p_camp_date       DATE,
    p_status          TEXT,
    p_coordinator_id  INT,
    p_volunteer_ids   INT[] DEFAULT '{}',
    p_optometrist_ids INT[] DEFAULT '{}'
)
RETURNS TABLE (
    campaign_id         INT,
    camp_name           TEXT,
    city_name           TEXT,
    camp_date           DATE,
    status              TEXT,
    volunteers_assigned BIGINT,
    optometrists_assigned BIGINT,
    created_at          TIMESTAMP
) AS $$
DECLARE
    v_new_id INT;
    v_uid    INT;
    v_role   INT;
BEGIN
    -- Validate status value
    IF p_status NOT IN ('Active', 'Scheduled', 'Completed', 'Waiting') THEN
        RAISE EXCEPTION 'Invalid status: %', p_status;
    END IF;

    -- Validate coordinator exists and has Coordinator role
    IF NOT EXISTS (
        SELECT 1 FROM users
        WHERE id = p_coordinator_id AND role_id = 2 AND is_deleted = FALSE
    ) THEN
        RAISE EXCEPTION 'Coordinator ID % is not a valid active Coordinator', p_coordinator_id;
    END IF;

    INSERT INTO campaigns (camp_name, city_id, camp_date, status, coordinator_id)
    VALUES (p_camp_name, p_city_id, p_camp_date, p_status, p_coordinator_id)
    RETURNING id INTO v_new_id;

    -- Assign volunteers
    FOREACH v_uid IN ARRAY p_volunteer_ids LOOP
        SELECT role_id INTO v_role FROM users WHERE id = v_uid AND is_deleted = FALSE;
        IF v_role IS NULL THEN
            RAISE EXCEPTION 'User % not found or deleted', v_uid;
        END IF;
        IF v_role != 3 THEN
            RAISE EXCEPTION 'User % is not a Volunteer', v_uid;
        END IF;
        INSERT INTO campaign_staff (campaign_id, user_id, role_id)
        VALUES (v_new_id, v_uid, 3);
    END LOOP;

    -- Assign optometrists
    FOREACH v_uid IN ARRAY p_optometrist_ids LOOP
        SELECT role_id INTO v_role FROM users WHERE id = v_uid AND is_deleted = FALSE;
        IF v_role IS NULL THEN
            RAISE EXCEPTION 'User % not found or deleted', v_uid;
        END IF;
        IF v_role != 4 THEN
            RAISE EXCEPTION 'User % is not an Optometrist', v_uid;
        END IF;
        INSERT INTO campaign_staff (campaign_id, user_id, role_id)
        VALUES (v_new_id, v_uid, 4);
    END LOOP;

    RETURN QUERY
    SELECT
        c.id,
        c.camp_name,
        ci.name,
        c.camp_date,
        c.status,
        COUNT(*) FILTER (WHERE cs.role_id = 3),
        COUNT(*) FILTER (WHERE cs.role_id = 4),
        c.created_at
    FROM campaigns c
    JOIN cities ci ON ci.id = c.city_id
    LEFT JOIN campaign_staff cs ON cs.campaign_id = c.id
    WHERE c.id = v_new_id
    GROUP BY c.id, c.camp_name, ci.name, c.camp_date, c.status, c.created_at;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- get_campaigns
-- ============================================================
CREATE OR REPLACE FUNCTION get_campaigns(
    p_camp_name  TEXT    DEFAULT NULL,
    p_status     TEXT    DEFAULT NULL,
    p_date_from  DATE    DEFAULT NULL,
    p_date_to    DATE    DEFAULT NULL,
    p_city_id    INT     DEFAULT NULL
)
RETURNS TABLE (
    campaign_id           INT,
    camp_name             TEXT,
    city_name             TEXT,
    camp_date             DATE,
    status                TEXT,
    volunteers_assigned   BIGINT,
    optometrists_assigned BIGINT,
    created_at            TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.camp_name,
        ci.name                                        AS city_name,
        c.camp_date,
        c.status,
        COUNT(*) FILTER (WHERE cs.role_id = 3)        AS volunteers_assigned,
        COUNT(*) FILTER (WHERE cs.role_id = 4)        AS optometrists_assigned,
        c.created_at
    FROM campaigns c
    JOIN cities ci ON ci.id = c.city_id
    LEFT JOIN campaign_staff cs ON cs.campaign_id = c.id
    WHERE c.is_deleted = FALSE
      AND (p_camp_name IS NULL OR c.camp_name ILIKE '%' || p_camp_name || '%')
      AND (p_status    IS NULL OR c.status    = p_status)
      AND (p_date_from IS NULL OR c.camp_date >= p_date_from)
      AND (p_date_to   IS NULL OR c.camp_date <= p_date_to)
      AND (p_city_id   IS NULL OR c.city_id   = p_city_id)
    GROUP BY c.id, c.camp_name, ci.name, c.camp_date, c.status, c.created_at
    ORDER BY c.camp_date DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- get_campaign_by_id
-- ============================================================
CREATE OR REPLACE FUNCTION get_campaign_by_id(p_campaign_id INT)
RETURNS TABLE (
    campaign_id           INT,
    camp_name             TEXT,
    city_name             TEXT,
    camp_date             DATE,
    status                TEXT,
    coordinator_id        INT,
    volunteers_assigned   BIGINT,
    optometrists_assigned BIGINT,
    volunteer_ids         INT[],
    optometrist_ids       INT[],
    created_at            TIMESTAMP,
    updated_at            TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.camp_name,
        ci.name,
        c.camp_date,
        c.status,
        c.coordinator_id,
        COUNT(*) FILTER (WHERE cs.role_id = 3),
        COUNT(*) FILTER (WHERE cs.role_id = 4),
        ARRAY_AGG(cs.user_id) FILTER (WHERE cs.role_id = 3),
        ARRAY_AGG(cs.user_id) FILTER (WHERE cs.role_id = 4),
        c.created_at,
        c.updated_at
    FROM campaigns c
    JOIN cities ci ON ci.id = c.city_id
    LEFT JOIN campaign_staff cs ON cs.campaign_id = c.id
    WHERE c.id = p_campaign_id
      AND c.is_deleted = FALSE
    GROUP BY c.id, c.camp_name, ci.name, c.camp_date,
             c.status, c.coordinator_id, c.created_at, c.updated_at;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- update_campaign
-- ============================================================
CREATE OR REPLACE FUNCTION update_campaign(
    p_campaign_id     INT,
    p_camp_name       TEXT     DEFAULT NULL,
    p_city_id         INT      DEFAULT NULL,
    p_camp_date       DATE     DEFAULT NULL,
    p_status          TEXT     DEFAULT NULL,
    p_volunteer_ids   INT[]    DEFAULT NULL,
    p_optometrist_ids INT[]    DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_current_status TEXT;
    v_uid            INT;
    v_role           INT;
BEGIN
    -- Fetch the current status
    SELECT status INTO v_current_status
    FROM campaigns
    WHERE id = p_campaign_id AND is_deleted = FALSE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Campaign % not found or already deleted', p_campaign_id;
    END IF;

    -- Validate incoming status value if provided
    IF p_status IS NOT NULL AND p_status NOT IN ('Active','Scheduled','Completed','Waiting') THEN
        RAISE EXCEPTION 'Invalid status: %', p_status;
    END IF;

    -- Status = Waiting or Completed: only status column may change
    IF v_current_status IN ('Waiting', 'Completed') THEN
        UPDATE campaigns
        SET status = COALESCE(p_status, status)
        WHERE id = p_campaign_id;
        RETURN;
    END IF;

    -- Status = Active or Scheduled: all fields are editable
    UPDATE campaigns
    SET
        camp_name = COALESCE(p_camp_name, camp_name),
        city_id   = COALESCE(p_city_id,   city_id),
        camp_date = COALESCE(p_camp_date,  camp_date),
        status    = COALESCE(p_status,     status)
    WHERE id = p_campaign_id;

    -- Replace staff assignments only when arrays are explicitly passed
    IF p_volunteer_ids IS NOT NULL OR p_optometrist_ids IS NOT NULL THEN
        -- Remove existing volunteer and/or optometrist assignments selectively
        IF p_volunteer_ids IS NOT NULL THEN
            DELETE FROM campaign_staff
            WHERE campaign_id = p_campaign_id AND role_id = 3;

            FOREACH v_uid IN ARRAY p_volunteer_ids LOOP
                SELECT role_id INTO v_role FROM users WHERE id = v_uid AND is_deleted = FALSE;
                IF v_role IS NULL THEN
                    RAISE EXCEPTION 'User % not found or deleted', v_uid;
                END IF;
                IF v_role != 3 THEN
                    RAISE EXCEPTION 'User % is not a Volunteer', v_uid;
                END IF;
                INSERT INTO campaign_staff (campaign_id, user_id, role_id)
                VALUES (p_campaign_id, v_uid, 3);
            END LOOP;
        END IF;

        IF p_optometrist_ids IS NOT NULL THEN
            DELETE FROM campaign_staff
            WHERE campaign_id = p_campaign_id AND role_id = 4;

            FOREACH v_uid IN ARRAY p_optometrist_ids LOOP
                SELECT role_id INTO v_role FROM users WHERE id = v_uid AND is_deleted = FALSE;
                IF v_role IS NULL THEN
                    RAISE EXCEPTION 'User % not found or deleted', v_uid;
                END IF;
                IF v_role != 4 THEN
                    RAISE EXCEPTION 'User % is not an Optometrist', v_uid;
                END IF;
                INSERT INTO campaign_staff (campaign_id, user_id, role_id)
                VALUES (p_campaign_id, v_uid, 4);
            END LOOP;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- delete_campaign  (soft delete)
-- ============================================================
CREATE OR REPLACE FUNCTION delete_campaign(p_campaign_id INT)
RETURNS VOID AS $$
BEGIN
    UPDATE campaigns
    SET    is_deleted = TRUE
    WHERE  id         = p_campaign_id
      AND  is_deleted = FALSE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Campaign % not found or already deleted', p_campaign_id;
    END IF;
END;
$$ LANGUAGE plpgsql;
