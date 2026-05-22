DROP DATABASE IF EXISTS registros;
CREATE DATABASE registros;
USE registros;

DROP TABLE IF EXISTS users;
CREATE TABLE users (
    id_user INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
    username varchar(24) NOT NULL,
    email varchar(50) NOT NULL,
    password varchar(24) NOT NULL,
    money INT DEFAULT 1000
);
ALTER TABLE users MODIFY password VARCHAR(255);
DROP USER IF EXISTS 'web';
CREATE USER 'web' IDENTIFIED by 'web';
GRANT ALL PRIVILEGES on registros.* TO 'web';

