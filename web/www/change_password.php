<?php
include_once '../include/db_connect.php';
include_once '../include/functions.php';
include_once '../include/header.php';
 
sec_session_start();
 
if (!isset($_SESSION['user_id'], $_SESSION['temp']))
{
	header('Location: ../error.php');
}
else
{
?>
<!DOCTYPE html>
<html>
	<head>
		<title>Password Change | ModKiwi</title>
		<link rel="stylesheet" href="styles/main.css" />
		<script type="text/JavaScript" src="js/forms.js"></script> 
		<script type="text/JavaScript">
function validate_pass(form, password, conf)
{
	// Check that the password is sufficiently long (min 6 chars)
	// The check is duplicated below, but this is included to give more
	// specific guidance to the user
	if (password.value.length < 6) {
		alert('Passwords must be at least 6 characters long.  Please try again');
		form.password.focus();
		return false;
	}
 
	// Check password and confirmation are the same
	if (password.value != conf.value) {
		alert('Your password and confirmation do not match. Please try again');
		form.password.focus();
		return false;
	}
 
	form.submit();
	return true;
}
</script>
	</head>
	<body>
		<center>
		<h1>Change Password</h1>
		You have logged in using a temporary password. Please enter a new password.<br>Passwords must be at least six characters long.
		<form action="process_change.php" method="post" name="change_form">					  
			<table border='0'>
				<tr><td>New Password:</td><td><input type="password" name="password" id="password"/></td></tr>
				<tr><td>Confirm password:</td><td><input type="password" name="confirmpwd" id="confirmpwd" /></td></tr>
				<tr><td colspan='2' align='center'><input type="submit" value="Change" onclick="return validate_pass(this.form, this.form.password, this.form.confirmpwd);" /> </td></tr>
			</table>
		</form>
		</center>
	</body>
</html>
<?php } ?>
