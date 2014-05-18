<?php
include_once '../include/db_connect.php';
include_once '../include/functions.php';
include_once '../include/header.php';
 
sec_session_start();
 
$logged = login_check($mysqli);
?>
<!DOCTYPE html>
<html>
	<?php if (!$logged) { ?>
	<head>
		<title>ModKiwi Login Page</title>
		<link rel="stylesheet" href="styles/main.css" />
		<script type="text/JavaScript" src="js/sha512.js"></script> 
		<script type="text/JavaScript" src="js/forms.js"></script> 
	</head>
	<body>
		<center>
		<h1>Login Required</h1>
		<?php
		if (isset($_GET['error'])) {
			echo '<p class="error">Error Logging In!</p>';
		}
		?> 
		<form action="process_login.php" method="post" name="login_form">					  
		<table border='0'>
		<tr><td>Username:</td><td><input type='text' name="username" /></td></tr>
		<tr><td>Password:</td><td><input type='password' name='password' id="password" /></td></tr>
		<tr><td colspan='2' align='center'><input type='submit' value='Login' onclick="formhash(this.form, this.form.password);" /></td></tr>
		</table>
		</form>
		<p>To reset your password or create an account, please <a href=http://boardgamegeek.com/geekmail/compose?touser=modkiwi&subject=reset%20password>geekmail modkiwi</a> with "reset password" in the subject line.</p>
		</center>
	</body>
	<?php } else { ?>
	<head>
		<title>Modkiwi</title>
	</head>
		You are already logged in.
</html>
