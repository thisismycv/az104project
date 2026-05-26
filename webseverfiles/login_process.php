<?php
// login_process.php
session_start();

ini_set('display_errors', 1);
error_reporting(E_ALL);

// --- DB credentials (adjust if needed) ---
$host = "localhost";
$db_name = "registros";
$username = "web";
$dbpassword = "web";

try {
    $pdo = new PDO("mysql:host={$host};dbname={$db_name};charset=utf8", $username, $dbpassword, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
    ]);
} catch (PDOException $e) {
    // Fatal DB error
    header("Location: login.php?error=" . urlencode("Error de conexión a la base de datos"));
    exit;
}

// Validate input presence
if (empty($_POST['email']) || empty($_POST['password'])) {
    header("Location: login.php?error=" . urlencode("Introduce email y contraseña"));
    exit;
}

$email = trim($_POST['email']);
$password = $_POST['password'];

// Fetch user
$stmt = $pdo->prepare("SELECT * FROM users WHERE email = :email LIMIT 1");
$stmt->execute([':email' => $email]);
$user = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$user) {
    // user not found
    header("Location: login.php?error=" . urlencode("Credenciales incorrectas"));
    exit;
}

// if DB stores hashed passwords (recommended), verify using password_verify()
if (!empty($user['password']) && password_verify($password, $user['password'])) {
    // success with hashed password
    $_SESSION['id_user'] = $user['id_user'];
    // optionally store more info in session:
    // $_SESSION['email'] = $user['email'];
    header("Location: index.php");
    exit;
}

// Fallback: plaintext comparison (only if your DB currently has unhashed passwords)
if (isset($user['password']) && $user['password'] === $password) {
    $_SESSION['id_user'] = $user['id_user'];
    header("Location: template.php");
    exit;
}

// otherwise: invalid credentials
header("Location: login.php?error=" . urlencode("Credenciales incorrectas"));
exit;

