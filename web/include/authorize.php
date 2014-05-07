<?php
include_once '../include/db_connect.php';
include_once '../include/functions.php';
 
sec_session_start();
$logged = login_check($mysqli);

if (!$logged) { ?>
<!DOCTYPE html>
<html>
	<head>
		<meta charset="UTF-8">
		<title>Unauthorized Access</title>
		<link rel="stylesheet" href="styles/main.css" />
	</head>
	<body>
		<p>
			<span class="error">You are not authorized to access this page.</span> Perhaps you should <a href="<?php echo ROOT ?>/index.php">login</a>?
		</p>
	</body>
</html>
<?php } else {
	$username = htmlentities($_SESSION['username']);
	$user_id = htmlentities($_SESSION['user_id']);
}
?>
