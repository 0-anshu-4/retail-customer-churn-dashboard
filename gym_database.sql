-- =====================================================================
-- Gym Operations & Business Analytics Database (MySQL)
-- Run in order: schema -> seed data -> procedures/functions/triggers -> views
-- =====================================================================

DROP DATABASE IF EXISTS gym_analytics;
CREATE DATABASE gym_analytics;
USE gym_analytics;

-- ---------------------------------------------------------------------
-- 1. SCHEMA (13 tables, 3NF)
-- ---------------------------------------------------------------------

CREATE TABLE Branch (
    branch_id     INT AUTO_INCREMENT PRIMARY KEY,
    branch_name   VARCHAR(100) NOT NULL,
    city          VARCHAR(100) NOT NULL,
    contact_phone VARCHAR(15)
);

CREATE TABLE Staff (
    staff_id    INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    role        VARCHAR(50)  NOT NULL,
    branch_id   INT NOT NULL,
    hire_date   DATE NOT NULL,
    FOREIGN KEY (branch_id) REFERENCES Branch(branch_id)
);

CREATE TABLE Trainer (
    trainer_id     INT AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(100) NOT NULL,
    specialization VARCHAR(100),
    branch_id      INT NOT NULL,
    FOREIGN KEY (branch_id) REFERENCES Branch(branch_id)
);

CREATE TABLE Member (
    member_id   INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    dob         DATE,
    phone       VARCHAR(15) UNIQUE,
    email       VARCHAR(100) UNIQUE,
    join_date   DATE NOT NULL DEFAULT (CURDATE()),
    branch_id   INT NOT NULL,
    FOREIGN KEY (branch_id) REFERENCES Branch(branch_id)
);

CREATE TABLE MembershipPlan (
    plan_id         INT AUTO_INCREMENT PRIMARY KEY,
    plan_name       VARCHAR(50) NOT NULL,
    duration_months INT NOT NULL CHECK (duration_months > 0),
    price           DECIMAL(10,2) NOT NULL CHECK (price >= 0)
);

CREATE TABLE Membership (
    membership_id INT AUTO_INCREMENT PRIMARY KEY,
    member_id     INT NOT NULL,
    plan_id       INT NOT NULL,
    start_date    DATE NOT NULL,
    end_date      DATE,
    status        VARCHAR(20) NOT NULL DEFAULT 'Pending',  -- Pending / Active / Expired
    FOREIGN KEY (member_id) REFERENCES Member(member_id),
    FOREIGN KEY (plan_id) REFERENCES MembershipPlan(plan_id)
);

CREATE TABLE Payment (
    payment_id    INT AUTO_INCREMENT PRIMARY KEY,
    membership_id INT NOT NULL,
    amount        DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
    payment_date  DATE NOT NULL DEFAULT (CURDATE()),
    method        VARCHAR(20) NOT NULL,  -- Cash / Card / UPI
    FOREIGN KEY (membership_id) REFERENCES Membership(membership_id)
);

CREATE TABLE Attendance (
    attendance_id INT AUTO_INCREMENT PRIMARY KEY,
    member_id     INT NOT NULL,
    check_in      DATETIME NOT NULL,
    check_out     DATETIME,
    FOREIGN KEY (member_id) REFERENCES Member(member_id)
);

CREATE TABLE GymClass (
    class_id      INT AUTO_INCREMENT PRIMARY KEY,
    class_name    VARCHAR(100) NOT NULL,
    trainer_id    INT NOT NULL,
    branch_id     INT NOT NULL,
    schedule_time DATETIME NOT NULL,
    capacity      INT NOT NULL DEFAULT 20,
    FOREIGN KEY (trainer_id) REFERENCES Trainer(trainer_id),
    FOREIGN KEY (branch_id) REFERENCES Branch(branch_id)
);

-- Junction table: resolves the Member <-> GymClass many-to-many relationship
CREATE TABLE ClassBooking (
    member_id    INT NOT NULL,
    class_id     INT NOT NULL,
    booking_date DATE NOT NULL DEFAULT (CURDATE()),
    attended     BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (member_id, class_id, booking_date),   -- composite key
    FOREIGN KEY (member_id) REFERENCES Member(member_id),
    FOREIGN KEY (class_id) REFERENCES GymClass(class_id)
);

CREATE TABLE Equipment (
    equipment_id   INT AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(100) NOT NULL,
    branch_id      INT NOT NULL,
    purchase_date  DATE,
    status         VARCHAR(20) DEFAULT 'Working',   -- Working / Under Maintenance / Retired
    FOREIGN KEY (branch_id) REFERENCES Branch(branch_id)
);

CREATE TABLE EquipmentMaintenance (
    maintenance_id INT AUTO_INCREMENT PRIMARY KEY,
    equipment_id   INT NOT NULL,
    reported_date  DATE NOT NULL,
    resolved_date  DATE,
    notes          VARCHAR(255),
    FOREIGN KEY (equipment_id) REFERENCES Equipment(equipment_id)
);

CREATE TABLE TrainingSession (
    session_id  INT AUTO_INCREMENT PRIMARY KEY,
    trainer_id  INT NOT NULL,
    member_id   INT NOT NULL,
    session_date DATETIME NOT NULL,
    notes       VARCHAR(255),
    FOREIGN KEY (trainer_id) REFERENCES Trainer(trainer_id),
    FOREIGN KEY (member_id) REFERENCES Member(member_id)
);

CREATE TABLE Feedback (
    feedback_id  INT AUTO_INCREMENT PRIMARY KEY,
    member_id    INT NOT NULL,
    branch_id    INT NOT NULL,
    rating       INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comments     VARCHAR(255),
    feedback_date DATE NOT NULL DEFAULT (CURDATE()),
    FOREIGN KEY (member_id) REFERENCES Member(member_id),
    FOREIGN KEY (branch_id) REFERENCES Branch(branch_id)
);

-- Total: Branch, Staff, Trainer, Member, MembershipPlan, Membership, Payment,
-- Attendance, GymClass, ClassBooking, Equipment, EquipmentMaintenance,
-- TrainingSession, Feedback  = 14 tables

-- ---------------------------------------------------------------------
-- 2. SEED DATA (small realistic sample)
-- ---------------------------------------------------------------------

INSERT INTO Branch (branch_name, city, contact_phone) VALUES
('FitZone Central', 'Ludhiana', '9876500001'),
('FitZone North', 'Chandigarh', '9876500002');

INSERT INTO Staff (name, role, branch_id, hire_date) VALUES
('Ramesh Kumar', 'Manager', 1, '2023-01-15'),
('Neha Sharma', 'Receptionist', 1, '2023-03-01'),
('Vikram Singh', 'Manager', 2, '2023-02-10');

INSERT INTO Trainer (name, specialization, branch_id) VALUES
('Arjun Mehta', 'Strength Training', 1),
('Pooja Rani', 'Yoga', 1),
('Suresh Nair', 'CrossFit', 2);

INSERT INTO Member (name, dob, phone, email, join_date, branch_id) VALUES
('Anshu Gupta', '2004-05-12', '9998887771', 'anshu.g@example.com', '2025-07-01', 1),
('Rohit Verma', '1998-11-03', '9998887772', 'rohit.v@example.com', '2025-07-10', 1),
('Simran Kaur', '2000-02-20', '9998887773', 'simran.k@example.com', '2025-08-01', 2);

INSERT INTO MembershipPlan (plan_name, duration_months, price) VALUES
('Monthly', 1, 1500.00),
('Quarterly', 3, 4000.00),
('Annual', 12, 14000.00);

INSERT INTO Membership (member_id, plan_id, start_date, end_date, status) VALUES
(1, 2, '2025-07-01', '2025-10-01', 'Active'),
(2, 1, '2025-07-10', '2025-08-10', 'Expired'),
(3, 3, '2025-08-01', '2026-08-01', 'Active');

INSERT INTO Payment (membership_id, amount, payment_date, method) VALUES
(1, 4000.00, '2025-07-01', 'UPI'),
(2, 1500.00, '2025-07-10', 'Cash'),
(3, 14000.00, '2025-08-01', 'Card');

INSERT INTO GymClass (class_name, trainer_id, branch_id, schedule_time, capacity) VALUES
('Morning Yoga', 2, 1, '2026-08-01 07:00:00', 15),
('CrossFit Blast', 3, 2, '2026-08-01 18:00:00', 12);

INSERT INTO ClassBooking (member_id, class_id, booking_date, attended) VALUES
(1, 1, '2026-07-28', TRUE),
(3, 2, '2026-07-29', FALSE);

-- ---------------------------------------------------------------------
-- 3. STORED PROCEDURE — register a member + first membership + payment atomically
-- ---------------------------------------------------------------------
DELIMITER //
CREATE PROCEDURE RegisterMember(
    IN p_name VARCHAR(100), IN p_phone VARCHAR(15), IN p_email VARCHAR(100),
    IN p_branch_id INT, IN p_plan_id INT, IN p_amount DECIMAL(10,2), IN p_method VARCHAR(20)
)
BEGIN
    DECLARE v_member_id INT;
    DECLARE v_membership_id INT;
    DECLARE v_duration INT;

    START TRANSACTION;

    INSERT INTO Member (name, phone, email, join_date, branch_id)
    VALUES (p_name, p_phone, p_email, CURDATE(), p_branch_id);
    SET v_member_id = LAST_INSERT_ID();

    SELECT duration_months INTO v_duration FROM MembershipPlan WHERE plan_id = p_plan_id;

    INSERT INTO Membership (member_id, plan_id, start_date, end_date, status)
    VALUES (v_member_id, p_plan_id, CURDATE(), DATE_ADD(CURDATE(), INTERVAL v_duration MONTH), 'Active');
    SET v_membership_id = LAST_INSERT_ID();

    INSERT INTO Payment (membership_id, amount, payment_date, method)
    VALUES (v_membership_id, p_amount, CURDATE(), p_method);

    COMMIT;
END //
DELIMITER ;

-- ---------------------------------------------------------------------
-- 4. STORED PROCEDURE — record attendance check-in
-- ---------------------------------------------------------------------
DELIMITER //
CREATE PROCEDURE RecordCheckIn(IN p_member_id INT)
BEGIN
    INSERT INTO Attendance (member_id, check_in) VALUES (p_member_id, NOW());
END //
DELIMITER ;

-- ---------------------------------------------------------------------
-- 5. FUNCTION — membership duration in months (as of today, or end_date if past)
-- ---------------------------------------------------------------------
DELIMITER //
CREATE FUNCTION MembershipDurationMonths(p_membership_id INT)
RETURNS INT DETERMINISTIC
BEGIN
    DECLARE v_months INT;
    SELECT TIMESTAMPDIFF(MONTH, start_date, IFNULL(end_date, CURDATE()))
    INTO v_months FROM Membership WHERE membership_id = p_membership_id;
    RETURN v_months;
END //
DELIMITER ;

-- ---------------------------------------------------------------------
-- 6. FUNCTION — total revenue generated by a single member (all payments, all memberships)
-- ---------------------------------------------------------------------
DELIMITER //
CREATE FUNCTION MemberTotalRevenue(p_member_id INT)
RETURNS DECIMAL(12,2) DETERMINISTIC
BEGIN
    DECLARE v_total DECIMAL(12,2);
    SELECT COALESCE(SUM(p.amount), 0) INTO v_total
    FROM Payment p
    JOIN Membership m ON p.membership_id = m.membership_id
    WHERE m.member_id = p_member_id;
    RETURN v_total;
END //
DELIMITER ;

-- ---------------------------------------------------------------------
-- 7. TRIGGER — auto-activate membership status the moment a payment is recorded
-- ---------------------------------------------------------------------
DELIMITER //
CREATE TRIGGER trg_after_payment_insert
AFTER INSERT ON Payment
FOR EACH ROW
BEGIN
    UPDATE Membership SET status = 'Active' WHERE membership_id = NEW.membership_id;
END //
DELIMITER ;

-- ---------------------------------------------------------------------
-- 8. TRIGGER — prevent negative/zero-capacity class bookings beyond capacity
--    (simple guard: block a booking if the class is already at capacity)
-- ---------------------------------------------------------------------
DELIMITER //
CREATE TRIGGER trg_before_booking_insert
BEFORE INSERT ON ClassBooking
FOR EACH ROW
BEGIN
    DECLARE v_capacity INT;
    DECLARE v_current INT;
    SELECT capacity INTO v_capacity FROM GymClass WHERE class_id = NEW.class_id;
    SELECT COUNT(*) INTO v_current FROM ClassBooking WHERE class_id = NEW.class_id;
    IF v_current >= v_capacity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Class is at full capacity';
    END IF;
END //
DELIMITER ;

-- ---------------------------------------------------------------------
-- 9. VIEWS — reporting layer
-- ---------------------------------------------------------------------

CREATE VIEW MonthlyRevenue AS
SELECT DATE_FORMAT(payment_date, '%Y-%m') AS month, SUM(amount) AS revenue
FROM Payment
GROUP BY month;

CREATE VIEW ActiveMembersByBranch AS
SELECT b.branch_name, COUNT(DISTINCT m.member_id) AS active_members
FROM Member m
JOIN Membership ms ON m.member_id = ms.member_id
JOIN Branch b ON m.branch_id = b.branch_id
WHERE ms.status = 'Active'
GROUP BY b.branch_name;

CREATE VIEW ClassAttendanceRate AS
SELECT gc.class_name,
       COUNT(cb.member_id) AS total_bookings,
       SUM(cb.attended) AS attended_count,
       ROUND(SUM(cb.attended) / COUNT(cb.member_id) * 100, 1) AS attendance_rate_pct
FROM GymClass gc
JOIN ClassBooking cb ON gc.class_id = cb.class_id
GROUP BY gc.class_name;

CREATE VIEW MembersNearExpiry AS
SELECT m.name, ms.end_date, DATEDIFF(ms.end_date, CURDATE()) AS days_to_expiry
FROM Membership ms
JOIN Member m ON ms.member_id = m.member_id
WHERE ms.status = 'Active' AND DATEDIFF(ms.end_date, CURDATE()) BETWEEN 0 AND 15;

-- ---------------------------------------------------------------------
-- 10. Example calls / usage
-- ---------------------------------------------------------------------
-- CALL RegisterMember('Priya Das','9998887774','priya.d@example.com',1,1,1500.00,'UPI');
-- CALL RecordCheckIn(1);
-- SELECT MembershipDurationMonths(1);
-- SELECT MemberTotalRevenue(1);
-- SELECT * FROM MonthlyRevenue;
-- SELECT * FROM ActiveMembersByBranch;
