-- Healthcare scheduling schema (Postgres) for docker smoke tests.
CREATE TABLE accounts (
    account_id INTEGER PRIMARY KEY,
    account_created_date DATE NOT NULL,
    pcah_eligible BOOLEAN NOT NULL
);

CREATE TABLE pcah_reg (
    account_id INTEGER PRIMARY KEY REFERENCES accounts (account_id),
    pcah_reg_date DATE NOT NULL
);
