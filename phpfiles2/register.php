<?php
include("template.php");
openHTML("Registro");
?>

<style>
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
        background: rgba(255,255,255,0.05);
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

    input[type="text"],
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

    a { color: #ffcc00; }

    .muted {
        font-size: 13px;
        text-align: center;
        margin-top: 12px;
    }
</style>

<main>
    <div class="card">
        <h2>Crear una cuenta</h2>

        <?php if (!empty($_GET['error'])): ?>
            <div style="color:#f33; margin-bottom:10px; text-align:center;">
                <?= htmlspecialchars($_GET['error']) ?>
            </div>
        <?php endif; ?>

        <form action="register_submit.php" method="POST" accept-charset="UTF-8" autocomplete="off">
            <div class="form-group">
                <label for="username">Nombre de usuario</label>
                <input id="username" name="username" placeholder="Usuario" type="text" required>
            </div>

            <div class="form-group">
                <label for="email">Correo electrónico</label>
                <input id="email" name="email" placeholder="Email" type="email" required>
            </div>

            <div class="form-group">
                <label for="password">Contraseña</label>
                <input id="password" name="password" placeholder="Contraseña" type="password" required>
            </div>

            <input class="alt" value="Registrar" name="submit" type="submit">
        </form>

        <div class="muted">
            <p>¿Ya tienes una cuenta? <a href="login.php">Inicia sesión</a></p>
        </div>
    </div>
</main>

</body>
</html>

