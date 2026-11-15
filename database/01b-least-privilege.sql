-- Run as postgres: psql -U postgres -d tutorlink -f database/01b-least-privilege.sql
CREATE ROLE tutorlink_app LOGIN PASSWORD 'your_strong_local_password';

GRANT CONNECT ON DATABASE tutorlink TO tutorlink_app;
GRANT USAGE ON SCHEMA public TO tutorlink_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON users, subjects, sessions, bookings TO tutorlink_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO tutorlink_app;