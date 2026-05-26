<?php
include("template.php");
openHTML("Portada");
?>

<style>
    body {
        background-color: #000;
        color: #fff;
        text-align: center;
        font-family: Arial, sans-serif;
    }

    header {
        margin-bottom: 50px;
    }

    nav ul {
        list-style: none;
        padding: 0;
        display: flex;
        justify-content: center;
        gap: 30px;
    }

    nav a {
        color: white;
        text-decoration: none;
        font-size: 18px;
        transition: color 0.3s ease;
    }

    nav a:hover {
        color: #ffcc00;
    }

    main {
        margin-top: 60px;
    }
</style>

<main>
    <h2>Bienvenido a la Portada</h2>
    <p>Este es el inicio de tu sitio web. Usa el menú de navegación para explorar las diferentes secciones.</p>

    <?php if (isset($_SESSION["id_user"])): ?>
        <p>Estás conectado como usuario.</p>
    <?php else: ?>
        <p>No has iniciado sesión. <a href="login.php" style="color: #ffcc00;">Inicia sesión aquí</a>.</p>
    <?php endif; ?>
</main>

</body>
</html>

