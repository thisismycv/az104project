<?php
<?php
// Content-Security-Policy (already added)
header("Content-Security-Policy: ...");

// ── Session cookie hardening ──────────────────────────────────────
ini_set('session.cookie_httponly', 1);   // JS cannot read the cookie (blocks XSS theft)
ini_set('session.cookie_secure', 1);     // Cookie only sent over HTTPS, never HTTP
ini_set('session.cookie_samesite', 'Strict'); // Cookie never sent on cross-site requests
ini_set('session.use_strict_mode', 1);   // Reject unrecognised session IDs from client
ini_set('session.cookie_lifetime', 0);   // Cookie dies when browser closes (no persistence)

session_start();

function openHTML($title)
{
    $login_url = "login.php";
    $login_text = "Login";

    if (isset($_SESSION["id_user"])) {
        $login_url = "logout.php";
        $login_text = "Logout";
    }

    echo <<<EOD
<!DOCTYPE html>
<html>
<head>
<title>{$title}</title>
<link rel="stylesheet" type="text/css" href="styles.css">
</head>
<body>

<header>
    <h1>{$title}</h1>
    <nav>
        <ul>
            <li><a href="index.php">Portada</a></li>
            <li><a href="about.php">Sobre Masao</a></li>
            <li><a href="contact.php">Contacto</a></li>
            <li><a href="{$login_url}">{$login_text}</a></li>
        </ul>
    </nav>
</header>

<main>
EOD;

    if (isset($_SESSION["id_user"])) {
        $id_user = $_SESSION["id_user"];
        $conn = mysqli_connect("localhost", "masao", "masao", "swagmasaoweb");

//PARA VER SI ME DETECTA QUE SOY ADMIN
 	$sql = "SELECT COUNT(*) AS total FROM user_admins WHERE id_user = $id_user";
    	$result = mysqli_query($conn, $sql);
    	$row = mysqli_fetch_assoc($result);
    	$is_admin = $row["total"] > 0;
    	if ($is_admin) {
        echo "<p>HOLA ADMIN</p>";
    }


        $sql = "SELECT name FROM users WHERE id_user = $id_user";
        $result = mysqli_query($conn, $sql);
        $row = mysqli_fetch_assoc($result);
        $user_name = $row["name"];
        mysqli_close($conn);
        echo "<p>Hola {$user_name}</p>";
    }
}

function closeHTML()
{
    echo <<<EOD
</main>

<footer>

</footer>

</body>
</html>
EOD;
}
?>
