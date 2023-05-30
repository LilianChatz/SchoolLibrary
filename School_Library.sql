DROP DATABASE IF EXISTS SCHOOL_LIBRARY;
CREATE DATABASE SCHOOL_LIBRARY;
USE SCHOOL_LIBRARY;

-- Δημιουργία πίνακα Roles
CREATE TABLE Roles (
  role_id INT PRIMARY KEY,
  role_name VARCHAR(255) NOT NULL
);

-- Εισαγωγή ρόλων
INSERT INTO Roles (role_id, role_name)
VALUES (1, 'Διαχειριστής'), (2, 'Χειριστής'), (3, 'Εκπαιδευτικός'), (4, 'Μαθητής');

CREATE TABLE address (
	address_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	city VARCHAR(100) NOT NULL,
	street VARCHAR(100) NOT NULL,
	street_number SMALLINT NOT NULL,
	postal_code VARCHAR(15) NOT NULL,
	district VARCHAR(200) NOT NULL
);

CREATE TABLE SchoolUnit (
	school_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	school_name VARCHAR(100) NOT NULL,
	address_id INT UNSIGNED NOT NULL,
	phone VARCHAR(20) NOT NULL,
	email VARCHAR(100) NOT NULL,
	principal_name VARCHAR(100) NOT NULL,
	FOREIGN KEY (address_id) REFERENCES address (address_id)
);

CREATE TABLE user_details (
	user_details_id VARCHAR(200) PRIMARY KEY,
	first_name VARCHAR(100) NOT NULL,
	last_name VARCHAR(100) NOT NULL,
	address_id INT UNSIGNED NOT NULL,
	email1 VARCHAR(100) NOT NULL,
	phone1 VARCHAR(100) NOT NULL,
	birth_date DATE
	FOREIGN KEY(address_id) REFERENCES address(address_id)
);

-- Δημιουργία πίνακα Users
CREATE TABLE Users (
	user_id VARCHAR(200) PRIMARY KEY,
	password VARCHAR(255) NOT NULL,
	user_details_id INT NOT NULL,
	role_id INT,
	role_name VARCHAR(255) NOT NULL,
	approval_ac BOOLEAN DEFAULT FALSE
	school_id INT NOT NULL,
	max_books_borrowed INT DEFAULT 0;
	weekly_reservations INT DEFAULT 0;
	FOREIGN KEY (role_id) REFERENCES Roles(role_id),
	FOREIGN KEY (school_id) REFERENCES SchoolUnit(school_id),
	FOREIGN KEY (role_name) REFERENCES Roles(role_name)
);

CREATE TRIGGER SetApprovalAc
BEFORE INSERT ON Users
FOR EACH ROW
BEGIN
	IF NEW.role_name = 'Διαχειριστής' THEN
		SET NEW.approval_ac = TRUE;
	ELSE
		SET NEW.approval_ac = FALSE;
	END IF;
END;


-- Πίνακας: Books
CREATE TABLE Books (
	ISBN CHAR(13) PRIMARY KEY,
	title VARCHAR(100) NOT NULL,
	pages INT(10) NOT NULL,
	editor VARCHAR(100) NOT NULL,
	summary TEXT,
	images BLOB,
	key_words VARCHAR(200) NOT NULL
);

-- Πίνακας: Categories
CREATE TABLE Categories (
	category_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	category_name VARCHAR(50) NOT NULL
);

CREATE TABLE book_category (
	category_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	ISBN CHAR(13) PRIMARY KEY,
	FOREIGN KEY (category_id) REFERENCES Categories(category_id),
	FOREIGN KEY (ISBN) REFERENCES Books(ISBN)
);

-- Πίνακας: Authors
CREATE TABLE Authors (
  author_id INT PRIMARY KEY,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL
);

CREATE TABLE book_author (
	author_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	ISBN CHAR(13) PRIMARY KEY,
	FOREIGN KEY (author_id) REFERENCES Authors(author_id),
	FOREIGN KEY (ISBN) REFERENCES Books(ISBN)
);

CREATE TABLE Languages (
	language_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	language_name VARCHAR(100) NOT NULL
);

CREATE TABLE book_language (
	language_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	ISBN CHAR(13) PRIMARY KEY,
	FOREIGN KEY (language_id) REFERENCES Languages(language_id),
	FOREIGN KEY (ISBN) REFERENCES Books(ISBN)
);

CREATE TABLE Inventory (
	inventory_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	school_id INT NOT NULL,
	ISBN CHAR(13) NOT NULL,
	copies_available INT(20) NOT NULL,
	loaned BOOLEAN NOT NULL DEFAULT FALSE,
	reserved BOOLEAN NOT NULL DEFAULT FALSE,
	FOREIGN KEY (school_id) REFERENCES SchoolUnit(school_id),
	FOREIGN KEY (ISBN) REFERENCES Books(ISBN)
);

-- Έλεγχος ύπαρξης του ISBN στον πίνακα Books πριν γίνει εισαγωγή στον πίνακα Inventory
DELIMITER ;;
CREATE TRIGGER check_book_exists
BEFORE INSERT ON Inventory
FOR EACH ROW
BEGIN
    DECLARE count INT;
    
    SELECT COUNT(*) INTO count
    FROM Books
    WHERE ISBN = NEW.ISBN;
    
    IF count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Το βιβλίο με το συγκεκριμένο ISBN δεν υπάρχει';
    END IF;
END;;
DELIMITER ;


-- Πίνακας: Book_Loan
CREATE TABLE Loans (
	loan_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	user_id INT NOT NULL,
	ISBN CHAR(13) NOT NULL,
	loan_date DATE NOT NULL,
	return_date DATE,
	overdue_returns INT NOT NULL, 
	FOREIGN KEY (user_id) REFERENCES Users(user_id),
	FOREIGN KEY (ISBN) REFERENCES Books(ISBN)
);

-- Πίνακας: Book_Reservations
CREATE TABLE Reservations (
	reservation_id INT PRIMARY KEY,
	user_id INT,
	book_id INT,
	reservation_date DATE,
	reservation_count INT NOT NULL,
	on_hold BOOLEAN DEFAULT FALSE,
	FOREIGN KEY (user_id) REFERENCES Users(user_id),
	FOREIGN KEY (ISBN) REFERENCES Books(ISBN)
);

-- Πίνακας: Book_Reviews
CREATE TABLE Reviews (
  user_id INT,
  book_id INT,
  review_text TEXT,
  likert_rating INT CHECK (likert_rating >= 1 AND likert_rating <= 5),
  FOREIGN KEY (user_id) REFERENCES Users(user_id),
  FOREIGN KEY (ISBN) REFERENCES Books(ISBN)
);

-- Δημιουργία trigger για περιορισμούς δανεισμού και κρατήσεων
DELIMITER ;;
CREATE TRIGGER loan_and_reservations_limits
BEFORE INSERT ON Users
FOR EACH ROW
BEGIN
    DECLARE error_message VARCHAR(255);
    
    IF (NEW.role_name = 'Εκπαιδευτικός' AND (NEW.max_books_borrowed > 1 OR NEW.weekly_reservations > 1)) THEN
        SET error_message = 'Ο εκπαιδευτικός μπορεί να δανειστεί έως και ένα βιβλίο την εβδομάδα ή να κάνει κράτηση εως και για ένα βιβλίο.';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;

    IF (NEW.role_name = 'Χειριστής' AND (NEW.max_books_borrowed > 1 OR NEW.weekly_reservations > 1)) THEN
        SET error_message = 'Ο χειριστής μπορεί να δανειστεί έως και ένα βιβλίο την εβδομάδα ή να κάνει κράτηση εως και για ένα βιβλίο.';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
    
    IF (NEW.role_name = 'Μαθητής' AND (NEW.max_books_borrowed > 2 OR NEW.weekly_reservations > 2)) THEN
        SET error_message = 'Ο μαθητής μπορεί να δανειστεί έως και δύο βιβλία την εβδομάδα ή να κάνει κράτηση εως και για δύο βιβλία.';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_message;
    END IF;
END ;;
DELIMITER ;


DELIMITER ;;

CREATE TRIGGER check_availability
BEFORE INSERT ON Loans
FOR EACH ROW
BEGIN
    DECLARE available_copies INT;
	DECLARE overdue_returns INT;
	DECLARE reservation_count INT;
	
	-- Έλεγχος καθυστερημένων επιστροφών
    SELECT COUNT(*) INTO overdue_returns
    FROM Loans
    WHERE user_id = NEW.user_id
    AND return_date < CURRENT_DATE
    AND returned = TRUE;

    IF overdue_returns > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Έχετε καθυστερημένες επιστροφές.';
    END IF;

	-- Έλεγχος αν υπάρχει κράτηση για το βιβλίο και τον συγκεκριμένο χρήστη
    SELECT COUNT(*) INTO reservation_count
    FROM Reservations
    WHERE user_id = NEW.user_id AND ISBN = NEW.ISBN;
    
    -- Αν υπάρχει κράτηση, αποτροπή της εισαγωγής της εγγραφής δανεισμού
    IF reservation_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Το βιβλίο είναι ήδη σε κράτηση για τον συγκεκριμένο χρήστη'
	END IF;
	
    -- Ελέγχει αν το βιβλίο έχει διαθέσιμα αντίτυπα
    SELECT COUNT(*) INTO available_copies
    FROM Inventory
    WHERE ISBN = NEW.ISBN AND (loaned = FALSE OR reserved=FALSE);

    -- Αν δεν υπάρχουν διαθέσιμα αντίτυπα, ανακόπτει την εισαγωγή
    IF available_copies = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Δεν υπάρχουν διαθέσιμα αντίτυπα για δανεισμό ή κράτηση.';
    END IF;
END ;;

DELIMITER ;;

CREATE TRIGGER cancel_reservation_trigger
AFTER DELETE ON Reservations
FOR EACH ROW
BEGIN
    DECLARE user_id INT;
    DECLARE ISBN INT;
    DECLARE reservation_id INT;
    
    -- Ανάκτηση των user_id και ISBN από τη διαγραφή της κράτησης
    SET user_id = OLD.user_id;
    SET ISBN = OLD.ISBN;
    
    -- Έλεγχος για την ύπαρξη της κράτησης
    SELECT COUNT(*) INTO reservation_id
    FROM Reservations
    WHERE user_id = user_id AND ISBN = ISBN;
    
    -- Αν η κράτηση υπάρχει, εκτελέστε τις ενέργειες ακύρωσης
    IF reservation_id > 0 THEN
        -- Ενημέρωση του πίνακα Inventory για το βιβλίο που ακυρώθηκε η κράτηση
        UPDATE Inventory
        SET available_copies = available_copies + 1
        WHERE ISBN = ISBN;
        
    END IF;
    
END;;

-- Δημιουργία του προγραμματισμένου γεγονότος
DELIMITER ;;
CREATE EVENT check_expired_reservations
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
DO
BEGIN
    -- Εύρεση και ακύρωση των κρατήσεων που έχουν λήξει
    UPDATE Reservations
    SET on_hold = FALSE
    WHERE on_hold = TRUE AND reservation_date < CURRENT_DATE() - INTERVAL 7 DAY;
END;;
DELIMITER ;

CREATE TRIGGER convert_reservation_to_loan
AFTER INSERT ON Reservations
FOR EACH ROW
BEGIN
    DECLARE available_copies INT;
    
    -- Έλεγχος αν το βιβλίο είναι διαθέσιμο
    SELECT COUNT(*) INTO available_copies
    FROM Inventory
    WHERE ISBN = NEW.ISBN;
    
    IF available_copies > 0 THEN
        -- Εισαγωγή νέας εγγραφής στον πίνακα δανεισμένων
        INSERT INTO Loans (user_id, ISBN, loan_date)
        VALUES (NEW.user_id, NEW.ISBN, CURDATE());
        
        -- Μείωση του αριθμού των διαθέσιμων αντιτύπων στον πίνακα inventory
        UPDATE Inventory
        SET available_copies = available_copies - 1
        WHERE ISBN = NEW.ISBN;
        
        -- Διαγραφή της εγγραφής από τον πίνακα κρατήσεων
        DELETE FROM Reservations
        WHERE user_id = NEW.user_id AND ISBN = NEW.ISBN;
    END IF;
END;

CREATE TRIGGER check_reservation 
AFTER INSERT ON Reservations
FOR EACH ROW
BEGIN
    DECLARE reservation_count INT;

    SELECT COUNT(*) INTO reservation_count
    FROM Reservations
    WHERE ISBN = NEW.ISBN;

    IF reservation_count > 0 THEN
        -- Το βιβλίο βρίσκεται σε κράτηση
        SET on_hold = TRUE
    END IF;
END;

CREATE TRIGGER check_and_reserve_book
BEFORE INSERT ON Loans
FOR EACH ROW
BEGIN
    DECLARE available_copies INT;
    SET available_copies = (SELECT available_copies FROM Inventory WHERE ISBN = NEW.ISBN);
    
    IF available_copies > 0 THEN
        UPDATE Inventory SET available_copies = available_copies - 1 WHERE ISBN = NEW.ISBN;
    ELSE
        INSERT INTO Reservations (user_id, ISBN, reservation_date, on_hold)
        VALUES (NEW.user_id, NEW.ISBN, NOW(), TRUE);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Το βιβλίο δεν είναι διαθέσιμο. Έγινε κράτηση';
    END IF;
END;

-- Παραχώρηση δικαιωμάτων στον ρόλο του χειριστή
GRANT ALL PRIVILEGES ON Reviews TO role_name='Χειριστής';
GRANT ALL PRIVILEGES ON Loans TO role_name='Χειριστής';
GRANT ALL PRIVILEGES ON Reservations TO role_name='Χειριστής';
GRANT ALL PRIVILEGES ON Books TO role_name='Χειριστής';
