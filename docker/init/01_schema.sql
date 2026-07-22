-- Sports league schema (Postgres) for docker smoke tests.
CREATE TABLE Person (
    PersonID INTEGER PRIMARY KEY,
    FirstName TEXT NOT NULL,
    LastName TEXT NOT NULL
);

CREATE TABLE Sport (
    SportID INTEGER PRIMARY KEY,
    SportType TEXT NOT NULL,
    SportName TEXT NOT NULL
);

CREATE TABLE History (
    PersonID INTEGER NOT NULL REFERENCES Person (PersonID),
    SportID INTEGER NOT NULL REFERENCES Sport (SportID),
    Timestamp TIMESTAMP NOT NULL,
    Score INTEGER NOT NULL DEFAULT 0
);
