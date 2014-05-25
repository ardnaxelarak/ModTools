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
<?php	if ($can_signup && $logged && !$player && count($p_list) < $max_players) { ?>
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
					echo "<tr><td>" . username_link($pname) . "</td>";
					if ($moderator)
						echo "<td><select name='pid_$pid'>" . $options[$rid] . "</select></td>";
					echo "</tr>";
				}
				echo "</table></td>";
			}
			$stmt->close();
		} else {
			$stmt = $mysqli->prepare("SELECT p.pid, username FROM game_players g LEFT JOIN players p ON g.pid = p.pid WHERE gid = ? ORDER BY username");
			$stmt->bind_param('i', $gid);
			$stmt->execute();
			$stmt->store_result();
			$stmt->bind_result($pid, $pname); ?>
			<td><table width='100%' class='forum_table' cellpadding='2'>
			<tr><th>Players (<?php echo $stmt->num_rows() . "/" . $max_players ?>)</th></tr>
	<?php
			while ($stmt->fetch())
			{
				echo "<tr><td>" . username_link($pname) . "</td></tr>";
			}
			echo "</table></td>";
			$stmt->close();
		} ?>
		</tr></table>
<?php	if ($moderator) { ?>
		<input type='hidden' name='gid' value='<?php echo $gid ?>' />
		<input type='hidden' name='action' value='modify' />
		<input type='submit' value='Modify' onclick='this.form.submit();' /></form>
<?php 	} ?>
		</center>
<?php } ?>
	</body>
</html>
