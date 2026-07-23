-- Healthcare scheduling schema (Postgres) for docker smoke tests.
CREATE TABLE accounts (
    account_id INTEGER PRIMARY KEY,
    account_created_date DATE NOT NULL,
    telehealth_eligible BOOLEAN NOT NULL
);

CREATE TABLE telehealth_reg (
    account_id INTEGER PRIMARY KEY REFERENCES accounts (account_id),
    telehealth_reg_date DATE NOT NULL
);
