<?php
include_once '../include/db_connect.php';
include_once '../include/header.php';
include_once '../include/functions.php';

sec_session_start();
 
$uname = $_GET["username"];
$stmt = $mysqli->prepare("SELECT pid FROM players WHERE username=?");
$stmt->bind_param('s', $uname);
$stmt->execute();
$stmt->store_result();
$stmt->bind_result($upid);
if (!($stmt->fetch()))
	$upid = null;
$stmt->close();
?>
<!DOCTYPE html>
<html>
	<head>
		<meta charset="UTF-8">
<?php if (is_null($upid)) { ?>
		<title>User not found | ModKiwi</title>
<?php } else { ?>
		<title>User <?php echo $uname ?> | ModKiwi</title>
<?php } ?>
		<link rel="stylesheet" href="<?php echo ROOT ?>/bgg.css" />
	</head>
	<?php print_header($mysqli) ?>
	<body>
<?php if (is_null($upid)) { ?>
		<p>The specified user could not be found.</p>
<?php } else {
		$stmt = $mysqli->prepare("SELECT nick FROM nicks WHERE pid=?");
		$stmt->bind_param('i', $upid);
		$stmt->execute();
		$stmt->store_result();

		$nicks = array();
		$stmt->bind_result($nick);
		while ($stmt->fetch())
		{
			$nicks[] = $nick;
		}
		$stmt->close();
		?>
		<p>The following nicknames are registered for <?php echo $uname?>:
		<table>
			<?php foreach ($nicks as $nick) {
				echo "<tr><td>" . $nick . "</td></tr>";
			} ?>
		</table></p>
<?php } ?>
		<p>Return to <a href='<?php echo ROOT ?>'>index page</a></p>
	</body>
</html>
