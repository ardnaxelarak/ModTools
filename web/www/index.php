<?php
include_once '../include/db_connect.php';
include_once '../include/functions.php';
include_once '../include/header.php';
 
sec_session_start();
 
?>
<!DOCTYPE html>
<html>
	<head>
		<meta charset="UTF-8">
		<title>Modkiwi</title>
		<link rel="stylesheet" href="bgg.css" />
	</head>
	<body>
		<?php print_header($mysqli); ?>
		<center>
			<table><tr>
			<td valign='top'><table width='100%' class='forum_table' cellpadding='2'>
				<tr><th colspan='3'>In Progress</th></tr>
<?php
		$stmt = $mysqli->prepare("SELECT gid, type_long, type_short, game_index, game_name FROM game_view WHERE sid = 3");
		$stmt->execute();
		$stmt->store_result();
		$stmt->bind_result($gid, $type_long, $type_short, $game_index, $game_name);
		while ($stmt->fetch())
		{
			echo "<tr><td>$gid</td><td>$type_short</td><td><a href='" . ROOT . "/game/$gid'>#$game_index: $game_name</a></td></tr>";
		}
		$stmt->close(); ?>
			</table><br>
			<table width='100%' class='forum_table' cellpadding='2'>
				<tr><th colspan='3'>Recently Ended</th></tr>
<?php
		$stmt = $mysqli->prepare("SELECT gid, type_long, type_short, game_index, game_name FROM game_view WHERE sid IN (4, 5) ORDER BY gid DESC LIMIT 10");
		$stmt->execute();
		$stmt->store_result();
		$stmt->bind_result($gid, $type_long, $type_short, $game_index, $game_name);
		while ($stmt->fetch())
		{
			echo "<tr><td>$gid</td><td>$type_short</td><td><a href='" . ROOT . "/game/$gid'>#$game_index: $game_name</a></td></tr>";
		}
		$stmt->close(); ?>
			</table></td>

			<td valign='top'><table width='100%' class='forum_table' cellpadding='2'>
				<tr><th colspan='3'>In Signups</th>
				<th>Moderator(s)</th>
				<th>Players</th></tr>
<?php
		$ms = $mysqli->prepare("SELECT p.username FROM moderators m JOIN players p ON m.pid = p.pid WHERE m.gid = ?");
		$ms->bind_param('i', $gid);
		$stmt = $mysqli->prepare("SELECT g.gid, type_long, type_short, game_index, game_name, max_players, count(DISTINCT p.pid) FROM game_view g LEFT JOIN game_players p ON g.gid = p.gid WHERE signup GROUP BY g.gid");
		$stmt->execute();
		$stmt->store_result();
		$stmt->bind_result($gid, $type_long, $type_short, $game_index, $game_name, $max_players, $current_players);
		while ($stmt->fetch())
		{
			$mods = [];
			$ms->execute();
			$ms->bind_result($mod_name);
			while ($ms->fetch())
				$mods[] = username_link($mod_name);
			echo "<tr>";
			echo "<td>$gid</td>";
			echo "<td>$type_short</td>";
			echo "<td><a href='" . ROOT . "/game/$gid'>#$game_index: $game_name</a></td>";
			echo "<td>" . join(", ", $mods) . "</td>";
			echo "<td align='center'>$current_players / $max_players</td>";
			echo "</tr>";
		}
		$ms->close();
		$stmt->close(); ?>
			</table></td>
			</tr></table>
		</center>
	</body>
</html>
