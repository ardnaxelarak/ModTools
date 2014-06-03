<?php
include_once '../include/game.inc.php';
?>
<!DOCTYPE html>
<html>
	<head>
		<meta charset="UTF-8">
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
		<h1><?php echo $game_name ?></h1>
		<?php echo $message ?>
		<table class='forum_table' cellpadding='2'>
		<tr><td><b>Moderator<?php if (count($mods) > 1) { echo "s"; } ?>:</b></td><td><?php echo join(", ", array_map('username_link', $mods)) ?></td></tr>
		<tr><td><b>Status:</b></td><td><table width='100%'><tr><td><?php echo $status_name ?></td>
<?php	if ($can_signup && $logged && !$player && (is_null($max_players) || count($p_list) < $max_players)) { ?>
		<td><form action='<?php echo game_link($gid) ?>' method="post" name="signup"><input type='hidden' name='action' value='signup' /><input type='submit' value='Sign Me Up!' action='this.form.submit();' /></form></td>
<?php	} else if ($can_signup && $player) { ?>
		<td><form action='<?php echo game_link($gid) ?>' method="post" name="remove"><input type='hidden' name='action' value='unsignup' /><input type='submit' value='Remove Me!' action='this.form.submit();' /></form></td>
<?php	} ?>
		</tr></table></td></tr>
		</table>
<?php	if ($thread_id != "") { ?>
		<p><a href='http://www.boardgamegeek.com/thread/<?php echo $thread_id ?>'>Go to Game Thread</a> (<a href='http://www.boardgamegeek.com/thread/<?php echo $thread_id ?>/new'>newest</a>)</p>
<?php	} ?>
		<?php if ($moderator) { ?>
		<form action='<?php echo game_link($gid) ?>' method="post" name="modify_form">
		<?php } ?>
		<table><tr>
<?php	if ($show_rooms) {
			$stmt = $mysqli->prepare("SELECT p.pid, username, r1.name, r2.name, t.name FROM room_players r LEFT JOIN players p ON r.pid = p.pid LEFT JOIN role_view rv ON (rv.pid = p.pid AND rv.gid = ?) LEFT JOIN roles r1 ON rv.first = r1.id LEFT JOIN roles r2 ON rv.last = r2.id LEFT JOIN teams t ON t.id = r2.team WHERE rid = ? ORDER BY username");
			$stmt->bind_param('ii', $gid, $rid);
			foreach ($rooms as $rid => $room_name) { ?>
				<td><table width='100%' class='forum_table' cellpadding='2'>
				<tr><th colspan='5'><?php echo $room_name ?></th></tr>
				<tr><th>Player</th>
<?php	if ($change) {
			echo "<th>Starting</th>";
			echo "<th>Ending</th>";
		} else {
			echo "<th>Role</th>";
		} ?>
				<th>Team</th></tr>
<?php
				$stmt->execute();
				$stmt->bind_result($pid, $pname, $prole1, $prole2, $pteam);
				while ($stmt->fetch())
				{
					echo "<tr><td>" . username_link($pname) . "</td>";
					if (!$moderator && !$closed && ($pid != $user_id || is_null($user_id)))
					{
						$prole1 = null;
					}
					if (!$moderator && !$closed && ($change || $pid != $user_id || is_null($user_id)))
					{
						$prole2 = null;
						$pteam = null;
					}
					echo "<td>$prole1</td>";
					if ($change)
						echo "<td>$prole2</td>";
					echo "<td>$pteam</td>";
					echo "</tr>";
					if ($moderator && !$closed)
						echo "<td><select name='pid_$pid'>" . $options[$rid] . "</select></td>";
					echo "</tr>";
				}
				echo "</table></td>";
			}
			$stmt->close();
		} else {
			$stmt = $mysqli->prepare("SELECT p.pid, username, r1.name, r2.name, t.name FROM game_players g LEFT JOIN players p ON g.pid = p.pid LEFT JOIN role_view rv ON (rv.pid = p.pid AND rv.gid = g.gid) LEFT JOIN roles r1 ON rv.first = r1.id LEFT JOIN roles r2 ON rv.last = r2.id LEFT JOIN teams t ON t.id = r2.team WHERE g.gid = ? ORDER BY username");
			$stmt->bind_param('i', $gid);
			$stmt->execute();
			$stmt->store_result();
			$stmt->bind_result($pid, $pname, $prole1, $prole2, $pteam); ?>
			<td><table width='100%' class='forum_table' cellpadding='2'>
			<tr><th colspan='5'>Players (<?php echo $stmt->num_rows() . (is_null($max_players) ? "" : " / " . $max_players) ?>)</th></tr>
			<tr><th>Player</th>
<?php	if ($change) {
			echo "<th>Starting</th>";
			echo "<th>Ending</th>";
		} else {
			echo "<th>Role</th>";
		} ?>
			<th>Team</th></tr>
	<?php
			while ($stmt->fetch())
			{
				echo "<tr><td>" . username_link($pname) . "</td>";
				if (!$moderator && !$closed && ($pid != $user_id || is_null($user_id)))
				{
					$prole1 = null;
				}
				if (!$moderator && !$closed && ($change || $pid != $user_id || is_null($user_id)))
				{
					$prole2 = null;
					$pteam = null;
				}
				echo "<td>$prole1</td>";
				if ($change)
					echo "<td>$prole2</td>";
				echo "<td>$pteam</td>";
				echo "</tr>";
			}
			echo "</table></td>";
			$stmt->close();
		} ?>
		</tr></table>
<?php	if ($moderator) { ?>
		<input type='hidden' name='action' value='modify' />
		<input type='submit' value='Modify' onclick='this.form.submit();' /></form>
<?php 	} ?>
		</center>
<?php } ?>
	</body>
</html>
