<?php
include_once '../include/db_connect.php';
include_once '../include/functions.php';
include_once '../include/header.php';
 
sec_session_start();

$logged = isset($_SESSION['user_id']);

if ($logged)
	$user_id = $_SESSION['user_id'];
else
	$user_id = -1;

if (isset($_POST['gid']))
	$gid = $_POST['gid'];
else if (isset($_GET['gid']))
	$gid = $_GET['gid'];
else
	$gid = null;

$closed = false;

if (!is_null($gid)) {
	$stmt = $mysqli->prepare("SELECT tid, type_short, sid, status_name, game_index, game_name, thread_id, max_players, signup, show_rooms, roles_change FROM game_view WHERE gid = ?");
	$stmt->bind_param('i', $gid);
	$stmt->execute();
	$stmt->store_result();
	$stmt->bind_result($tid, $type_short, $sid, $status_name, $game_index, $game_name, $thread_id, $max_players, $can_signup, $show_rooms, $change);
	$can_signup = $can_signup > 0;
	$show_rooms = $show_rooms > 0;
	$change = $change > 0;
	if (!($stmt->fetch()))
		$gid = null;
	if ($sid == '5')
		$closed = true;
	$stmt->close();
}

$player = false;
$moderator = false;

if (!is_null($gid)) {
	$stmt = $mysqli->prepare("SELECT m.pid, p.username FROM moderators m JOIN players p ON m.pid = p.pid WHERE gid = ?");
	$stmt->bind_param('i', $gid);
	$stmt->execute();
	$stmt->store_result();
	$stmt->bind_result($p_id, $p_name);
	$mods = [];
	while ($stmt->fetch()) {
		$mods[] = $p_name;
		if ($logged && $user_id == $p_id)
			$moderator = true;
	}
	$stmt->close();

	$stmt = $mysqli->prepare("SELECT g.pid, p.username FROM game_players g JOIN players p ON g.pid = p.pid WHERE gid = ?");
	$stmt->bind_param('i', $gid);
	$stmt->execute();
	$stmt->store_result();
	$stmt->bind_result($p_id, $p_name);
	$p_list = [];
	while ($stmt->fetch()) {
		$p_list[] = $p_name;
		if ($logged && $user_id == $p_id)
			$player = true;
	}
	$stmt->close();
}

$message = "";

/* print_r($_POST); */

if (!is_null($gid) && isset($_POST['action']))
	$action = $_POST['action'];
else if (!is_null($gid) && isset($_GET['action']))
	$action = $_GET['action'];
else
	$action = null;

if (!is_null($action) && !$logged) {
	$message .= "<p>You must be logged in to perform that action.</p>";
	$action = null;
} else if ($action == "modify") {
	if ($moderator) {
		$ps = $mysqli->prepare("SELECT rp.pid, p.username, r.rid, r.name FROM room_players rp JOIN current_rooms r ON rp.rid = r.rid JOIN players p ON rp.pid = p.pid WHERE r.gid = ?");
		$ps->bind_param('i', $gid);
		$ps->execute();
		$ps->store_result();
		$ps->bind_result($pid, $pname, $rid, $roomname);
		while ($ps->fetch()) {
			if (!isset($_POST["pid_$pid"]))
				continue;
			$action = $_POST["pid_$pid"];
			if ($action == "appoint") {
				$mysqli->query("UPDATE rooms SET leader = $pid, modified = TRUE WHERE rid = $rid");
				$mysqli->query("INSERT INTO room_messages (rid, message) VALUES ($rid, '$pname has become leader!')");
				$message .= "<p>$pname has been appointed leader of $roomname</p>";
			}
		}
		$ps->close();
	} else {
		$message .= "<p>You do not have permission to take that action.</p>";
	}
} else if ($action == "next-round" || $action == "end-2r1b") {
	if ($moderator)
	{
		$rs = $mysqli->prepare("SELECT rid, name, leader FROM current_rooms WHERE gid = ?");
		$rs->bind_param('i', $gid);
		$rs->execute();
		$rs->store_result();
		$rs->bind_result($rid, $room_name, $leader);
		$thread_id = [];
		$players = [];
		$leaders = [];
		$room_names = [];
		while ($rs->fetch()) {
			if ($action == "next-round")
				$thread_id[$rid] = $_POST["thread_$rid"];
			else
				$thread_id[$rid] = "";
			$players[$rid] = [];
			$room_names[$rid] = $room_name;
			$leaders[$rid] = $leader;
		}
		$rs->close();

		$ps = $mysqli->prepare("SELECT DISTINCT pid FROM room_players p JOIN current_rooms r ON p.rid = r.rid WHERE r.gid = ?");
		$ps->bind_param('i', $gid);
		$ps->execute();
		$ps->store_result();
		$ps->bind_result($pid);
		while ($ps->fetch()) {
			$rid = $_POST["pid_$pid"];
			if (isset($players[$rid]))
				$players[$rid][] = $pid;
		}
		$ps->close();

		$gs = $mysqli->prepare("SELECT round_num FROM games WHERE gid = ?");
		$gs->bind_param('i', $gid);
		$gs->execute();
		$gs->bind_result($rn);
		$gs->fetch();
		$gs->close();

		$nrid = 1;
		$thread = "";

		$rn += 1;

		$rs = $mysqli->prepare("INSERT INTO rooms (gid, thread_id, round_num, name, leader) VALUES (?, ?, ?, ?, ?)");
		$rs->bind_param('isisi', $gid, $thread, $rn, $room_name, $leader);
		$ps = $mysqli->prepare("INSERT INTO room_players (rid, pid) VALUES (?, ?)");
		$ps->bind_param('ii', $nrid, $pid);
		foreach ($players as $rid => $pl) {
			$thread = $thread_id[$rid];
			$room_name = $room_names[$rid];
			$leader = $leaders[$rid];
			$rs->execute();
			$nrid = $mysqli->insert_id;
			foreach ($pl as $pid) {
				$ps->execute();
			}
		}
		$rs->close();
		$ps->close();

		if ($action == "next-round")
		{
			$mysqli->query("UPDATE games SET round_num = $rn WHERE gid = $gid");
			$message .= "<p>New round successfully created.</p>";
		}
		else
		{
			$mysqli->query("UPDATE games SET status = 4, round_num = $rn WHERE gid = $gid");
			$message .= "<p>Game successfully ended.</p>";
		}
	} else {
		$message .= "<p>You do not have permission to take that action.</p>";
	}
} else if ($action == "signup") {
	if ($player) {
		$message .= "<p>You are already signed up!";
	} else if (!$can_signup) {
		$message .= "<p>This game is not open for signups at the moment.</p>";
	} else if (!is_null($max_players) && count($p_list) >= $max_players) {
		$message .= "<p>This game is already full.";
	} else {
		$ps = $mysqli->prepare("INSERT INTO game_players (gid, pid) VALUES (?, ?)");
		$ps->bind_param('ii', $gid, $user_id);
		$ps->execute();
		$mysqli->query("UPDATE games SET signup_modified = TRUE WHERE gid = $gid");
		$message .= "<p>You have successfuly signed up.</p>";
	}
} else if ($action == "unsignup") {
	if (!$player) {
		$message .= "<p>You are already not signed up!";
	} else if (!$can_signup) {
		$message .= "<p>This game is not open for signups at the moment.</p>";
	} else {
		$ps = $mysqli->prepare("DELETE FROM game_players WHERE gid = ? AND pid = ?");
		$ps->bind_param('ii', $gid, $user_id);
		$ps->execute();
		$mysqli->query("UPDATE games SET signup_modified = TRUE WHERE gid = $gid");
		$message .= "<p>You have successfuly been removed from the game.</p>";
	}
}

$moderator = false;
$player = false;

if (!is_null($gid)) {
	$stmt = $mysqli->prepare("SELECT m.pid, p.username FROM moderators m JOIN players p ON m.pid = p.pid WHERE gid = ?");
	$stmt->bind_param('i', $gid);
	$stmt->execute();
	$stmt->store_result();
	$stmt->bind_result($p_id, $p_name);
	$mods = [];
	while ($stmt->fetch()) {
		$mods[] = $p_name;
		if ($logged && $user_id == $p_id)
			$moderator = true;
	}
	$stmt->close();

	$stmt = $mysqli->prepare("SELECT g.pid, p.username FROM game_players g JOIN players p ON g.pid = p.pid WHERE gid = ?");
	$stmt->bind_param('i', $gid);
	$stmt->execute();
	$stmt->store_result();
	$stmt->bind_result($p_id, $p_name);
	$p_list = [];
	while ($stmt->fetch()) {
		$p_list[] = $p_name;
		if ($logged && $user_id == $p_id)
			$player = true;
	}
	$stmt->close();
}

if (!is_null($gid) && $show_rooms) {
	$stmt = $mysqli->prepare("SELECT rid, name FROM current_rooms WHERE gid = ?");
	$stmt->bind_param('i', $gid);
	$stmt->execute();
	$stmt->store_result();
	$stmt->bind_result($rid, $room_name);
	$rooms = [];
	while ($stmt->fetch()) {
		$rooms[$rid] = $room_name;
	}
	$stmt->close();

	if ($moderator) {
		$options = [];
		foreach ($rooms as $rid => $room_name)
		{
			$text = "<option value='none'>No Action</option>";
			foreach ($rooms as $rid2 => $room_name2)
			{
				if ($rid != $rid2)
					$text .= "<option value='move_$rid2'>Send to $room_name2</option>";
			}
			$text .= "<option value='remove'>Remove from Game</option>";
			$text .= "<option value='appoint'>Appoint Leader</option>";
			$options[$rid] = $text;
		}
	}
}
?>
