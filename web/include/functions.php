<?php
include_once 'psl-config.php';

ini_set('display_errors', 'On');
error_reporting(-1);

function sec_session_start()
{
	$session_name = 'sec_session_id';   // Set a custom session name
	$secure = SECURE;
	// This stops JavaScript being able to access the session id.
	$httponly = true;
	// Forces sessions to only use cookies.
	if (ini_set('session.use_only_cookies', 1) === FALSE)
	{
		header("Location: ../error.php?err=Could not initiate a safe session (ini_set)");
		exit();
	}
	// Gets current cookies params.
	$cookieParams = session_get_cookie_params();
	session_set_cookie_params($cookieParams["lifetime"],
		$cookieParams["path"], 
		$cookieParams["domain"], 
		$secure,
		$httponly);
	// Sets the session name to the one set above.
	session_name($session_name);
	session_start();			// Start the PHP session 
	session_regenerate_id();	// regenerated the session, delete the old one. 
}

function login($username, $password, $mysqli)
{
	// Using prepared statements means that SQL injection is not possible. 
	if (!($stmt = $mysqli->prepare("SELECT pid, username, password, salt FROM players WHERE username = ? LIMIT 1")))
		return -3; // No user exists.
	$stmt->bind_param('s', $username);
	$stmt->execute();
	$stmt->store_result();
	$stmt->bind_result($user_id, $username, $db_password, $salt);
	$stmt->fetch();
	$num = $stmt->num_rows();
	$stmt->close();

	if ($num < 1)
		return -4;

	$password = hash('sha512', $password);
	$password = hash('sha512', $password . $salt);

	if (checkbrute($user_id, $mysqli))
	{
		// Account is locked 
		// Send an email to user saying their account is locked
		return -1;
	}

	if ($db_password == $password)
	{
		// Password is correct!
		// XSS protection as we might print this value
		$user_id = preg_replace("/[^0-9]+/", "", $user_id);
		$_SESSION['user_id'] = $user_id;
		// XSS protection as we might print this value
		$username = preg_replace("/[^a-zA-Z0-9_\-]+/", "", $username);
		$_SESSION['username'] = $username;
		$_SESSION['salt'] = $salt;
		// Login successful.
		return 1;
	}

	// Password is not correct
	// Check for temporary passwords less than a day old
	if (!($stmt = $mysqli->prepare("SELECT temp_id, pass FROM temppass WHERE pid = ? AND TIME_TO_SEC(TIMEDIFF(NOW(), time)) < 86400")))
		return -3;
	$stmt->bind_param('i', $user_id);
	$stmt->execute();
	$stmt->store_result();
	$stmt->bind_result($temp_id, $db_temp);

	while ($stmt->fetch())
	{
		if ($db_temp == $password)
		{
			$user_id = preg_replace("/[^0-9]+/", "", $user_id);
			$_SESSION['user_id'] = $user_id;
			$username = preg_replace("/[^a-zA-Z0-9_\-]+/", "", $username);
			$_SESSION['username'] = $username;
			$_SESSION['temp'] = true;
			$_SESSION['salt'] = $salt;

			// remove temp password
			$mysqli->query("DELETE FROM temppass WHERE temp_id = $temp_id");

			// Login with temp successful; prompt to change password
			$stmt->close();
			return 2;
		}
	}
	$stmt->close();

	// Password is incorrect
	// We record this attempt in the database
	$mysqli->query("INSERT INTO login_attempts(user_id, time) VALUES ('$user_id', NOW())");
	return -2;
}

function checkbrute($user_id, $mysqli)
{
	// All login attempts are counted from the past 2 hours. 
	if ($stmt = $mysqli->prepare("SELECT time FROM login_attempts WHERE user_id = ? AND TIME_TO_SEC(TIMEDIFF(NOW(), time)) < 7200"))
	{
		$stmt->bind_param('i', $user_id);
		$stmt->execute();
		$stmt->store_result();
 
		if ($stmt->num_rows > 50)
			return true;
		else
			return false;
	}
}

function login_check($mysqli)
{
	// Check if all session variables are set 
	return (isset($_SESSION['user_id'], $_SESSION['username']));
}

function game_link($gid)
{
	return ROOT . "/game/$gid";
}

function username_link($uname)
{
	return "<a href='" . ROOT . "/user/$uname'>$uname</a>";
}

function esc_url($url)
{
	if ($url == '')
	{
		return $url;
	}
 
	$url = preg_replace('|[^a-z0-9-~+_.?#=!&;,/:%@$\|*\'()\\x80-\\xff]|i', '', $url);
 
	$strip = array('%0d', '%0a', '%0D', '%0A');
	$url = (string) $url;
 
	$count = 1;
	while ($count)
	{
		$url = str_replace($strip, '', $url, $count);
	}
 
	$url = str_replace(';//', '://', $url);
 
	$url = htmlentities($url);
 
	$url = str_replace('&amp;', '&#038;', $url);
	$url = str_replace("'", '&#039;', $url);
 
	if ($url[0] !== '/')
	{
		// We're only interested in relative links from $_SERVER['PHP_SELF']
		return '';
	}
	else
	{
		return $url;
	}
}

?>
