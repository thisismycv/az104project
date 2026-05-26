
<?php
// login.php (form page)
include("template.php");
openHTML("Login");
?>

<style>
    /* simple page-level styles; you can move to styles.css */
    body {
        background-color: #000;
        color: #fff;
        font-family: Arial, sans-serif;
        margin: 0;
        padding: 0;
    }

    main {
        display: flex;
        align-items: center;
        justify-content: center;
        min-height: 60vh;
    }

    .card {
        width: 320px;
        padding: 24px;
        border-radius: 8px;
        background: rgba(255,255,255,0.03);
        box-shadow: 0 6px 18px rgba(0,0,0,0.6);
    }

    .card h2 {
        margin-top: 0;
        margin-bottom: 16px;
        font-size: 20px;
        text-align: center;
    }

    .form-group {
        margin-bottom: 12px;
        text-align: left;
    }

    label {
        display: block;
        margin-bottom: 6px;
        font-size: 13px;
    }

    input[type="email"],
    input[type="password"] {
        width: 100%;
        padding: 8px 10px;
        border-radius: 4px;
        border: 1px solid #333;
        background: #111;
        color: #fff;
        box-sizing: border-box;
    }

    input[type="submit"] {
        width: 100%;
        padding: 10px;
        border-radius: 6px;
        border: none;
        cursor: pointer;
        font-weight: bold;
        margin-top: 6px;
    }

    .muted {
        font-size: 13px;
        text-align: center;
        margin-top: 12px;
    }

    a { color: #ffcc00; }
</style>

<main>
    <div class="card">
        <?php if (isset($_SESSION["id_user"])): ?>
            <h2>Ya estás conectado</h2>
            <p style="text-align:center;">Ya estás conectado. <a href="index.php">Volver a la portada</a></p>
        <?php else: ?>
            <h2>Iniciar sesión</h2>

            <!-- show optional error message -->
            <?php if (!empty($_GET['error'])): ?>
                <div style="color:#f33; margin-bottom:10px; text-align:center;">
                    <?= htmlspecialchars($_GET['error']) ?>
                </div>
            <?php endif; ?>

            <form action="login_process.php" method="POST" autocomplete="off">
                <div class="form-group">
                    <label for="email">Correo electrónico</label>
                    <input id="email" type="email" name="email" required>
                </div>
                <div class="form-group">
                    <label for="password">Contraseña</label>
                    <input id="password" type="password" name="password" required>
                </div>
                <input type="submit" value="Acceder">
            </form>

            <div class="muted">
           <p>No tienes cuenta? <a href="register.php">Regístrate</a></p>
            </div>
        <?php endif; ?>
    </div>
</main>

</body>
</html>

