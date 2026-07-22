-- Deterministic seed for sports Q1–Q3 smoke assertions.
INSERT INTO Person (PersonID, FirstName, LastName) VALUES
    (1, 'Ada', 'Lovelace'),
    (2, 'Alan', 'Turing'),
    (3, 'Grace', 'Hopper');

INSERT INTO Sport (SportID, SportType, SportName) VALUES
    (10, 'soccer', 'Soccer'),
    (20, 'baseball', 'Baseball'),
    (30, 'racket', 'Tennis'),
    (40, 'water', 'UnusedSwim');  -- never appears in History

INSERT INTO History (PersonID, SportID, Timestamp, Score) VALUES
    (1, 10, '2010-03-01 10:00:00', 2),
    (1, 20, '2010-04-01 10:00:00', 3),  -- Ada: 2 different SportTypes in 2010
    (2, 10, '2010-05-01 10:00:00', 1),
    (2, 10, '2010-06-01 10:00:00', 1),  -- Alan: 2 history rows in 2010 (same sport)
    (3, 30, '2011-01-01 10:00:00', 5);  -- Grace: not in 2010 multi-sport set
