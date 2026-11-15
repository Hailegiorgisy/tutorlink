-- ============================================================================
-- TutorLink — 01-schema.sql
-- Creates all tables, constraints, and indexes.
--
-- Run with:
--     psql -U postgres -d tutorlink -f 01-schema.sql
--
-- Create the database first (this script does not, because you cannot
-- CREATE DATABASE from inside a connection to that same database):
--     CREATE DATABASE tutorlink;
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Clean slate. Order matters: drop children before parents, or the foreign
-- keys will refuse. CASCADE handles it either way, but the explicit order
-- shows which table depends on which.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS subjects CASCADE;
DROP TABLE IF EXISTS users    CASCADE;


-- ============================================================================
-- TABLE: users
-- One row per person with an account.
-- ============================================================================
CREATE TABLE users (
    id            SERIAL       PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(150) UNIQUE NOT NULL,

    -- The column is named password_hash, not password, on purpose:
    -- the name itself documents that a plain password must never go here.
    -- A bcrypt hash is always 60 chars; 255 leaves room to change algorithm.
    password_hash VARCHAR(255) NOT NULL,

    -- CHECK stops a typo like 'studnet' from being stored. Without it, that
    -- user would fail every checkRole(['student']) test forever, with no
    -- obvious cause.
    role          VARCHAR(20)  NOT NULL DEFAULT 'student'
                  CHECK (role IN ('student', 'tutor', 'admin')),

    created_at    TIMESTAMP    NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  users IS 'Students, tutors, and administrators.';
COMMENT ON COLUMN users.password_hash IS 'bcrypt hash, cost 10. NEVER a plain password.';


-- ============================================================================
-- TABLE: subjects
-- Lookup table. A session belongs to exactly one subject.
-- ============================================================================
CREATE TABLE subjects (
    id          SERIAL      PRIMARY KEY,
    name        VARCHAR(80) UNIQUE NOT NULL,

    -- Nullable on purpose: a description is genuinely optional, and that is
    -- exactly what NULL means.
    description TEXT
);


-- ============================================================================
-- TABLE: sessions
-- One tutoring session offered by one tutor.
--
-- NOTE: "session" here means a TUTORING session. It has nothing to do with
-- login sessions — our authentication is stateless with JWT, so there is no
-- table for those.
-- ============================================================================
CREATE TABLE sessions (
    id           SERIAL        PRIMARY KEY,
    title        VARCHAR(150)  NOT NULL,
    description  TEXT,

    -- CASCADE: delete the tutor's account and their sessions go too.
    -- A session with no tutor has no meaning.
    tutor_id     INTEGER       NOT NULL
                 REFERENCES users(id) ON DELETE CASCADE,

    -- RESTRICT: refuse to delete a subject while sessions still reference it.
    -- This protects real data from a careless admin click.
    -- Two different rules, two different reasons — be ready to explain both.
    subject_id   INTEGER       NOT NULL
                 REFERENCES subjects(id) ON DELETE RESTRICT,

    scheduled_at TIMESTAMP     NOT NULL,
    location     VARCHAR(120)  NOT NULL DEFAULT 'Online',

    capacity     INTEGER       NOT NULL CHECK (capacity > 0),

    -- Controlled denormalization: seats_left could be calculated as
    -- capacity - COUNT(confirmed bookings), but storing it lets the browse
    -- page show seat counts without a COUNT per row, AND lets the database
    -- make overbooking impossible via the CHECK below.
    -- The cost: it must be kept in step with bookings, which is why booking
    -- runs inside a transaction.
    seats_left   INTEGER       NOT NULL CHECK (seats_left >= 0),

    -- DECIMAL, never FLOAT. Floating point cannot represent every decimal
    -- exactly, and money must be exact.
    -- Gotcha: the pg driver returns DECIMAL as a STRING in JavaScript.
    -- "50.00" + "25.00" is "50.0025.00". Always wrap in Number().
    price        DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (price >= 0),

    status       VARCHAR(20)   NOT NULL DEFAULT 'open'
                 CHECK (status IN ('open', 'closed', 'cancelled')),

    created_at   TIMESTAMP     NOT NULL DEFAULT NOW(),

    -- A named table-level CHECK, because it spans two columns.
    -- Naming it means the error message tells you which rule failed.
    CONSTRAINT seats_within_capacity CHECK (seats_left <= capacity)
);


-- ============================================================================
-- TABLE: bookings
-- The JUNCTION TABLE resolving the many-to-many relationship between
-- users and sessions: a student attends many sessions, a session is
-- attended by many students.
--
-- It carries its own data (status, booked_at), which is why it gets its own
-- SERIAL primary key rather than only a composite key.
-- ============================================================================
CREATE TABLE bookings (
    id         SERIAL      PRIMARY KEY,

    student_id INTEGER     NOT NULL
               REFERENCES users(id) ON DELETE CASCADE,

    session_id INTEGER     NOT NULL
               REFERENCES sessions(id) ON DELETE CASCADE,

    status     VARCHAR(20) NOT NULL DEFAULT 'confirmed'
               CHECK (status IN ('confirmed', 'cancelled')),

    booked_at  TIMESTAMP   NOT NULL DEFAULT NOW(),

    -- The heart of this table. Double-booking becomes impossible.
    -- Your API should ALSO check first and return a friendly 409 — but if
    -- two requests arrive in the same millisecond, only the database can
    -- reliably stop the second one.
    --
    -- The lesson: the API check is for the USER's benefit; the database
    -- constraint is for the DATA's safety. You need both.
    CONSTRAINT one_booking_per_student_per_session UNIQUE (student_id, session_id)
);


-- ============================================================================
-- INDEXES
--
-- Five, each serving a query the application actually runs.
--
-- NOT created here, because PostgreSQL already made them:
--   users.email     — UNIQUE creates an index automatically
--   subjects.name   — same
--   every id column — PRIMARY KEY creates one automatically
--
-- Every index speeds reads but slows writes and costs disk. Adding one
-- "just in case" is a cost with no benefit.
-- ============================================================================

-- Browse page: filter by subject
CREATE INDEX idx_sessions_subject_id   ON sessions(subject_id);

-- "My sessions" for a tutor
CREATE INDEX idx_sessions_tutor_id     ON sessions(tutor_id);

-- Default sort: upcoming sessions first
CREATE INDEX idx_sessions_scheduled_at ON sessions(scheduled_at);

-- "My bookings" page
CREATE INDEX idx_bookings_student_id   ON bookings(student_id);

-- Attendee roster, and counting bookings per session
CREATE INDEX idx_bookings_session_id   ON bookings(session_id);


-- ============================================================================
-- VERIFY
-- ============================================================================
-- \dt                                    -- should list 4 tables
-- \d sessions                            -- inspect columns and constraints
-- SELECT tablename, indexname FROM pg_indexes WHERE schemaname = 'public';
