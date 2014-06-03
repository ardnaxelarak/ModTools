<?php
include_once '../include/db_connect.php';
include_once '../include/functions.php';
include_once '../include/header.php';
 
sec_session_start();

print_r($_POST);
$logged = isset($_SESSION['user_id']);

if ($logged)
	$user_id = $_SESSION['user_id'];
else
	$user_id = -1;

$message = "";

if (isset($_POST['action']) && $_POST['action'] == 'Create') {
	if (!$logged) {
		$message .= "<p>You must be logged in to create a game.</p>";
	} else if (!isset($_POST['game_index']) || is_null($_POST['game_index']) || $_POST['game_index'] == "") {
		$message .= "<p>Game Index must be specified.</p>";
	} else if (!isset($_POST['game_name']) || is_null($_POST['game_name']) || $_POST['game_name'] == "") {
		$message .= "<p>Game Name must be specified.</p>";
	} else if (!isset($_POST['game_type']) || is_null($_POST['game_type']) || $_POST['game_type'] == "") {
		$message .= "<p>Game Type must be specified.</p>";
	} else if (isset($_POST['limit_players']) && (!isset($_POST['max_players']) || is_null($_POST['max_players']) || $_POST['max_players'] == "")) {
		$message .= "<p>Max Players must be specified.</p>";
	} else {
		if ($stmt = $mysqli->prepare("INSERT INTO games (tid, status, thread_id, game_index, name, max_players) VALUES (?, ?, ?, ?, ?, ?)")) {
			$tid = $_POST['game_type'];
			if (isset($_POST['signups']))
				$status = 2;
			else
				$status = 1;
			if (isset($_POST['thread_id']) && $_POST['thread_id'] != "")
				$thread_id = $_POST['thread_id'];
			else
				$thread_id = null;
			$game_index = $_POST['game_index'];
			$game_name = $_POST['game_name'];
			if (isset($_POST['limit_players']))
				$max_players = $_POST['max_players'];
			else
				$max_players = null;
			$stmt->bind_param('iisssi', $tid, $status, $thread_id, $game_index, $game_name, $max_players);
			$stmt->execute();
			$gid = $mysqli->insert_id;
			$stmt->close();
			$stmt = $mysqli->prepare("INSERT INTO moderators (gid, pid) VALUES (?, ?)");
			$stmt->bind_param('ii', $gid, $user_id);
			$stmt->execute();
			$stmt->close();
			if (isset($_POST['signuplist'])) {
				$stmt = $mysqli->prepare("INSERT INTO actions (gid, action) VALUES (?, 'postsignup')");
				$stmt->bind_param('i', $gid);
				$stmt->execute();
				$stmt->close();
			}
			header("Location: ../game/$gid");
		} else {
			$message .= "<p>Error creating sql query</p>";
		}
	}
}

$stmt = $mysqli->prepare("SELECT tid, name FROM game_types");
$stmt->execute();
$stmt->store_result();
$stmt->bind_result($tid, $type_name);
$options = "";
while ($stmt->fetch()) {
	if (isset($_POST['game_type']) && $tid == $_POST['game_type'])
		$options .= "<option value='$tid' selected='selected'>$type_name</option>";
	else
		$options .= "<option value='$tid'>$type_name</option>";
}
$stmt->close();
?>
