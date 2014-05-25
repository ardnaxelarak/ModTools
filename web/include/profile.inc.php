<?php
include_once '../include/db_connect.php';
include_once '../include/functions.php';
 
sec_session_start();
$message = "";
if (!(isset($_SESSION['user_id'], $_SESSION['username'])))
{
	header('Location: ../login');
}
else
{
	$user_id = htmlentities($_SESSION['user_id']);
	 
	if (isset($_POST['password'], $_POST['oldpwd']))
	{
		// Sanitize and validate the data passed in
		$password = filter_input(INPUT_POST, 'password', FILTER_SANITIZE_STRING);
		$oldpwd = filter_input(INPUT_POST, 'oldpwd', FILTER_SANITIZE_STRING);

		$stmt = $mysqli->prepare("SELECT password, salt FROM players WHERE pid = ?");
		$stmt->bind_param('i', $user_id);
		$stmt->execute();
		$stmt->store_result();
		$stmt->bind_result($db_password, $salt);
		$stmt->fetch();
		$num = $stmt->num_rows();
		$stmt->close();

		$oldpwd = hash('sha512', $oldpwd);
		$oldpwd = hash('sha512', $oldpwd . $salt);

		if ($oldpwd != $db_password)
		{
			$message .= "Please enter the correct password.";
		}
		else
		{
			$password = hash('sha512', $password);
			$password = hash('sha512', $password . $salt);
		 
			if ($update_stmt = $mysqli->prepare("UPDATE players SET password = ? WHERE pid = ?"))
			{
				$update_stmt->bind_param('si', $password, $user_id);
				if (!$update_stmt->execute())
				{
					$message .= "Database error occurred while updating password.";
				}
				else
				{
					$message .= "Password changed successfully.";
				}
			}
			else
			{
				$message .= "Database error";
			}
		}
	}
}
?>
