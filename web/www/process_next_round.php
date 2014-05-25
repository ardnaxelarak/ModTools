<?php
include_once '../include/db_connect.php';
include_once '../include/functions.php';
include_once '../include/header.php';
 
sec_session_start();

if (!isset($_SESSION['user_id']))
	header('Location: ' . ROOT . '/login');

$gid = $_GET['gid'];
$stmt = $mysqli->prepare("SELECT tid, type_short, sid, status_name, game_index, game_name FROM game_view WHERE gid = ?");
$stmt->bind_param('i', $gid);
$stmt->execute();
$stmt->store_result();
$stmt->bind_result($tid, $type_short, $sid, $status_name, $game_index, $game_name);
if (!($stmt->fetch()))
	$gid = null;
$stmt->close();

if (!is_null($gid)) {
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
}
?>

<!DOCTYPE html>
<html>
	<head>
<?php if (is_null($gid)) { ?>
		<title>Invalid Game | ModKiwi</title>
<?php } else { ?>
		<title><?php echo "$type_short #$game_index: $game_name" ?></title>
<?php } ?>
		<link rel="stylesheet" href="<?php echo ROOT ?>/bgg.css" />
	</head>
	<body>
		<?php print_header($mysqli); ?>
<?php if (is_null($gid)) { ?>
		The specified game could not be found.
<?php } else { ?>
		<center>
		<?php print_r($_POST); ?>
		<form action='<?php echo esc_url($_SERVER['PHP_SELF']); ?>' method="post" name="next_round_form">
		<table><tr><td>
<?php
		$stmt = $mysqli->prepare("SELECT username FROM room_players r LEFT JOIN players p ON r.pid = p.pid WHERE rid = ? ORDER BY username");
		$stmt->bind_param('i', $rid);
		foreach ($rooms as $rid => $room_name) { ?>
			<table width='100%' class='forum_table' cellpadding='2'>
				<tr><th colspan='2'><?php echo $room_name ?></th></tr>
<?php
		$stmt->execute();
		$stmt->bind_result($pname);
		while ($stmt->fetch())
		{
			echo "<tr><td>$pname</td><td>select</td></tr>";
		}
		?>
			</table><br>
<?php }
		$stmt->close(); ?>
		</td></tr></table>
		<input type="submit" value="Next Round" onclick="this.form.submit();" /></form>
		<input type="hidden" name="gid" id="gid" value="<?php echo $gid ?>" />
		</center>
<?php } ?>
	</body>
</html>
