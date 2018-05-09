CREATE DATABASE nti310;
CREATE USER db_srv WITH PASSWORD '';
ALTER ROLE db_srv SET client_encoding TO 'utf8';
ALTER ROLE db_srv SET default_transaction_isolation TO 'read committed';
ALTER ROLE db_srv SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE nti310 TO db_srv;
