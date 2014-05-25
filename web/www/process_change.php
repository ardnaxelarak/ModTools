<?php
include_once '../include/db_connect.php';
include_once '../include/functions.php';
 
sec_session_start();
if (!(isset($_SESSION['salt'], $_SESSION['user_id'], $_SESSION['temp'])))
{
	header('Location: ../error.php');
}
else
{
	$user_id = htmlentities($_SESSION['user_id']);
	$salt = htmlentities($_SESSION['salt']);
	 
	if (isset($_POST['password']))
	{
		// Sanitize and validate the data passed in
		$password = filter_input(INPUT_POST, 'password', FILTER_SANITIZE_STRING);
		$password = hash('sha512', $password);
		$password = hash('sha512', $password . $salt);
	 
		if ($update_stmt = $mysqli->prepare("UPDATE players SET password = ? WHERE pid = ?"))
		{
			$update_stmt->bind_param('si', $password, $user_id);
			if (!$update_stmt->execute())
			{
				header('Location: ../error.php');
			}
			else
			{
				$_SESSION['temp'] = null;
				header('Location: ../index.php');
			}
		}
		else
		{
			header('Location: ../error.php');
		}
	}
	else
	{
		header('Location: ../error.php');
	}
}
?>
