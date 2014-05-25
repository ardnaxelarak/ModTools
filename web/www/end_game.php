<?php
include_once '../include/db_connect.php';
include_once '../include/functions.php';
include_once '../include/header.php';
 
sec_session_start();

if (!isset($_SESSION['user_id']))
	header('Location: ' . ROOT . '/login');

$user_id = $_SESSION['user_id'];

if (isset($_POST['gid']))
	$gid = $_POST['gid'];
else if (isset($_GET['gid']))
	$gid = $_GET['gid'];
else
	$gid = null;

if (!is_null($gid)) {
	$stmt = $mysqli->prepare("SELECT tid, type_short, sid, status_name, game_index, game_name FROM game_view WHERE gid = ?");
	$stmt->bind_param('i', $gid);
	$stmt->execute();
	$stmt->store_result();
	$stmt->bind_result($tid, $type_short, $sid, $status_name, $game_index, $game_name);
	if (!($stmt->fetch()))
		$gid = null;
	$stmt->close();
}

if (!is_null($gid)) {
	$stmt = $mysqli->prepare("SELECT pid FROM moderators WHERE gid = ? AND pid = ?");
	$stmt->bind_param('ii', $gid, $user_id);
	$stmt->execute();
	$stmt->store_result();
	$allowed = ($stmt->num_rows() > 0);
	$stmt->close();
}

$message = "";

if (!is_null($gid) && $allowed) {
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

	$options = [];
	foreach ($rooms as $rid => $room_name)
	{
		$text = "<option value='$rid'>Stay in $room_name</option>";
		foreach ($rooms as $rid2 => $room_name2)
		{
			if ($rid != $rid2)
				$text .= "<option value='$rid2'>Send to $room_name2</option>";
		}
		$options[$rid] = $text;
	}
}
?>

<!DOCTYPE html>
<html>
	<head>
<?php if (is_null($gid)) { ?>
		<title>Invalid Game | ModKiwi</title>
<?php } else if (!$allowed) { ?>
		<title>Access Denied | ModKiwi</title>
<?php } else { ?>
		<title><?php echo "$type_short #$game_index: $game_name" ?></title>
<?php } ?>
		<link rel='stylesheet' href='<?php echo ROOT ?>/bgg.css' />
	</head>
	<body>
		<?php print_header($mysqli); ?>
<?php if (is_null($gid)) { ?>
		The specified game could not be found.
<?php } else if (!$allowed) { ?>
		You do not have permission to access this page.
<?php } else { ?>
		<center>
		<?php echo $message ?>
		<form action='<?php echo ROOT ?>/game/<?php echo $gid ?>' method='post' name='next_round_form'>
		<table><tr>
<?php
		$stmt = $mysqli->prepare("SELECT p.pid, username FROM room_players r LEFT JOIN players p ON r.pid = p.pid WHERE rid = ? ORDER BY username");
		$stmt->bind_param('i', $rid);
		foreach ($rooms as $rid => $room_name) { ?>
			<td><table width='100%' class='forum_table' cellpadding='2'>
				<tr><th colspan='2'><?php echo $room_name ?></th></tr>
<?php
		$stmt->execute();
		$stmt->bind_result($pid, $pname);
		while ($stmt->fetch())
		{
			echo "<tr><td>$pname</td><td><select name='pid_$pid'>" . $options[$rid] . "</select></td></tr>";
		}
		?>
			</table></td>
<?php }
		$stmt->close(); ?>
		</tr></table>
		<input type='hidden' name='action' value='end-2r1b' />
		<input type='submit' value='End Game' onclick='this.form.submit();' /></form>
		</center>
<?php } ?>
	</body>
</html>
