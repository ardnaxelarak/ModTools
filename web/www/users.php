<?php
include_once '../include/authorize.php';
include_once '../include/header.php';
 
if ($logged) {
	$uname = $_GET["username"];
	$stmt = $mysqli->prepare("SELECT pid FROM players WHERE username=?");
	$stmt->bind_param('s', $uname);
	$stmt->execute();
	$stmt->store_result();
	$stmt->bind_result($upid);
	if ($stmt->num_rows < 1)
	{
?>
<!DOCTYPE html>
<html>
	<head>
		<meta charset="UTF-8">
		<title>User not found</title>
		<link rel="stylesheet" href="styles/main.css" />
	</head>
	<?php print_header($username) ?>
	<body>
		<p>The specified user <?php echo $uname ?> could not be found.</p>
		<p>Return to <a href="index.php">index page</a></p>
	</body>
</html>
<?php }
	else
	{
		$stmt->fetch();

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
?>
<!DOCTYPE html>
<html>
	<head>
		<meta charset="UTF-8">
		<title>User: <?php echo $uname?></title>
		<link rel="stylesheet" href="styles/main.css" />
	</head>
	<?php print_header($username) ?>
	<body>
		<p>This page is also pretty boring right now.</p>
		<p>The following nicknames are registered for <?php echo $uname?>:
		<table>
			<?php foreach ($nicks as $nick) {
				echo "<tr><td>" . $nick . "</td></tr>";
			} ?>
		</table></p>
		<p>Return to <a href="index.php">index page</a></p>
	</body>
</html>
<?php } } ?>
