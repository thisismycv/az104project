<?php
session_start();

// Elimina todas las variables de sesión
$_SESSION = array();

// Destruye la sesión
session_destroy();

// Redirige al inicio o página principal
header("Location: index.php");
exit;
?>

