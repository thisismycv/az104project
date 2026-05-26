<?php
header('Content-Type: text/html; charset=UTF-8');
session_start();

// Database connection
$host = "localhost";
$db_name = "registros";
$username = "web";
$password = "web";

try {
    $pdo = new PDO("mysql:host={$host};dbname={$db_name};charset=utf8", $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
    ]);
} catch (PDOException $e) {
    header("Location: register.php?error=" . urlencode("Error de conexión a la base de datos."));
    exit;
}

if (isset($_POST['submit'])) {
    $username = trim($_POST['username']);
    $email = trim($_POST['email']);
    $password = trim($_POST['password']);

    // Basic validation
    if (empty($username) || empty($email) || empty($password)) {
        header("Location: register.php?error=" . urlencode("Todos los campos son obligatorios."));
        exit;
    }

    // Check if email already exists
    $stmt = $pdo->prepare("SELECT COUNT(*) FROM users WHERE email = :email");
    $stmt->execute([':email' => $email]);
    if ($stmt->fetchColumn() > 0) {
        header("Location: register.php?error=" . urlencode("El correo ya está registrado."));
        exit;
    }

    // Hash password securely
    $hashed_password = password_hash($password, PASSWORD_DEFAULT);

    // Insert into DB
    $query = "INSERT INTO users (username, email, password) VALUES (:username, :email, :password)";
    $stmt = $pdo->prepare($query);

    $success = $stmt->execute([
        ':username' => htmlspecialchars($username),
        ':email' => htmlspecialchars($email),
        ':password' => $hashed_password
    ]);

    if ($success) {
        // Redirect to login page after successful registration
        header("Location: login.php");
        exit;
    } else {
        header("Location: register.php?error=" . urlencode("No se pudo registrar el usuario."));
        exit;
    }
} else {
    header("Location: register.php");
    exit;
}

