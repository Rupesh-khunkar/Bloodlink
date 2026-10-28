-- BloodLink: Blood Bank Management System (SQLite dialect)
PRAGMA foreign_keys = ON;

CREATE TABLE blood_group (
  blood_group_id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE CHECK (name IN ('A+','A-','B+','B-','O+','O-','AB+','AB-'))
);
CREATE TABLE stock (
  blood_group_id  INTEGER PRIMARY KEY REFERENCES blood_group(blood_group_id) ON DELETE CASCADE,
  units_available INTEGER NOT NULL DEFAULT 0 CHECK (units_available >= 0)
);
CREATE TABLE donor (
  donor_id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT NOT NULL UNIQUE,
  age INTEGER NOT NULL CHECK (age BETWEEN 18 AND 65),
  blood_group_id INTEGER NOT NULL REFERENCES blood_group(blood_group_id) ON DELETE RESTRICT,
  city TEXT,
  last_donation_date TEXT
);
CREATE TABLE hospital (
  hospital_id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  city TEXT NOT NULL,
  phone TEXT NOT NULL UNIQUE
);
CREATE TABLE donation (
  donation_id INTEGER PRIMARY KEY AUTOINCREMENT,
  donor_id INTEGER NOT NULL REFERENCES donor(donor_id) ON DELETE RESTRICT,
  donation_date TEXT NOT NULL DEFAULT (date('now')),
  units INTEGER NOT NULL DEFAULT 1 CHECK (units BETWEEN 1 AND 2)
);
CREATE TABLE blood_request (
  blood_request_id INTEGER PRIMARY KEY AUTOINCREMENT,
  hospital_id INTEGER NOT NULL REFERENCES hospital(hospital_id) ON DELETE RESTRICT,
  blood_group_id INTEGER NOT NULL REFERENCES blood_group(blood_group_id) ON DELETE RESTRICT,
  units INTEGER NOT NULL CHECK (units > 0),
  request_date TEXT NOT NULL DEFAULT (date('now')),
  status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending','Fulfilled','Rejected'))
);

-- TRIGGERS ------------------------------------------------
CREATE TRIGGER trg_stock_row AFTER INSERT ON blood_group
BEGIN INSERT INTO stock(blood_group_id) VALUES (NEW.blood_group_id); END;

CREATE TRIGGER trg_donor_eligibility BEFORE INSERT ON donation
WHEN (SELECT last_donation_date FROM donor WHERE donor_id = NEW.donor_id) IS NOT NULL
 AND julianday(NEW.donation_date) - julianday((SELECT last_donation_date FROM donor WHERE donor_id = NEW.donor_id)) < 90
BEGIN SELECT RAISE(ABORT, 'Donor not eligible: 90-day gap required between donations'); END;

CREATE TRIGGER trg_donation_stock AFTER INSERT ON donation
BEGIN
  UPDATE stock SET units_available = units_available + NEW.units
   WHERE blood_group_id = (SELECT blood_group_id FROM donor WHERE donor_id = NEW.donor_id);
  UPDATE donor SET last_donation_date = NEW.donation_date WHERE donor_id = NEW.donor_id;
END;

CREATE TRIGGER trg_check_stock BEFORE UPDATE OF status ON blood_request
WHEN OLD.status = 'Pending' AND NEW.status = 'Fulfilled'
 AND (SELECT units_available FROM stock WHERE blood_group_id = NEW.blood_group_id) < NEW.units
BEGIN SELECT RAISE(ABORT, 'Insufficient stock to fulfil this request'); END;

CREATE TRIGGER trg_issue_stock AFTER UPDATE OF status ON blood_request
WHEN OLD.status = 'Pending' AND NEW.status = 'Fulfilled'
BEGIN UPDATE stock SET units_available = units_available - NEW.units WHERE blood_group_id = NEW.blood_group_id; END;

-- VIEWS ---------------------------------------------------
CREATE VIEW v_stock AS
SELECT bg.name AS blood_group, s.units_available
FROM stock s JOIN blood_group bg USING (blood_group_id);

CREATE VIEW v_donor_details AS
SELECT d.donor_id, d.name, bg.name AS blood_group, d.age, d.city, d.phone, d.last_donation_date
FROM donor d JOIN blood_group bg USING (blood_group_id);

CREATE VIEW v_request_details AS
SELECT r.blood_request_id, h.name AS hospital, bg.name AS blood_group, r.units, r.request_date, r.status
FROM blood_request r JOIN hospital h USING (hospital_id) JOIN blood_group bg USING (blood_group_id);

-- SAMPLE DATA ---------------------------------------------
INSERT INTO blood_group(name) VALUES ('A+'),('A-'),('B+'),('B-'),('O+'),('O-'),('AB+'),('AB-');
INSERT INTO donor(name,phone,age,blood_group_id,city) VALUES
('Aarav Sharma','9876500001',28,1,'Nagpur'),('Priya Deshmukh','9876500002',24,3,'Nagpur'),
('Rohan Patil','9876500003',31,5,'Wardha'),('Sneha Kulkarni','9876500004',26,6,'Nagpur'),
('Imran Khan','9876500005',35,1,'Amravati'),('Neha Joshi','9876500006',22,3,'Nagpur'),
('Karan Mehta','9876500007',40,7,'Nagpur'),('Divya Nair',  '9876500008',29,5,'Wardha'),
('Meera Rao','9876500009',33,8,'Nagpur');
INSERT INTO hospital(name,city,phone) VALUES
('City Care Hospital','Nagpur','0712-111111'),('Lifeline Hospital','Nagpur','0712-222222'),('Sunrise Medical Centre','Wardha','07152-333333');
INSERT INTO donation(donor_id,donation_date,units) VALUES
(1,'2026-06-10',1),(1,'2026-10-05',1),(2,'2026-10-01',1),(3,'2026-09-15',1),(4,'2026-10-03',1),
(5,'2026-09-20',1),(6,'2026-08-25',1),(7,'2026-09-28',1),(8,'2026-10-07',1);
INSERT INTO blood_request(hospital_id,blood_group_id,units,request_date) VALUES
(1,1,2,'2026-10-08'),(2,5,1,'2026-10-09'),(3,6,2,'2026-10-10');
UPDATE blood_request SET status='Fulfilled' WHERE blood_request_id=1;
