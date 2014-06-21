<?php
include_once '../include/db_connect.php';
include_once '../include/functions.php';
 
sec_session_start();
  
if (isset($_POST['username'], $_POST['password']))
{
	$username = $_POST['username'];
	$password = $_POST['password'];

	$res = login($username, $password, $mysqli);
	switch ($res)
	{
		case 1:
			// login succeeded
			header('Location: ../');
			break;
		case 2:
			// login used temp password
			header('Location: ../change_password.php');
			break;
		default:
			// login failed
			header('Location: ../login_error');
	}
}
else
{
	// The correct POST variables were not sent to this page. 
	echo 'Invalid Request';
}

?>
