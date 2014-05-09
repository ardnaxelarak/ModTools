<?php
include_once '../include/authorize.php';
include_once '../include/header.php';
 
if ($logged) {
	$stmt = $mysqli->prepare("SELECT nick FROM nicks WHERE pid=?");
	$stmt->bind_param('i', $user_id);
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
		<title>User Profile: <?php echo $username ?></title>
		<link rel="stylesheet" href="styles/main.css" />
	</head>
	<?php print_header($username) ?>
	<body>
		<p>This page is also pretty boring right now.</p>
		<p>The following nicknames are registered for you:
		<table>
			<?php foreach ($nicks as $nick) {
				echo "<tr><td>" . $nick . "</td></tr>";
			} ?>
		</table></p>
		<p>Return to <a href="index.php">index page</a></p>
	</body>
</html>
<?php } ?>
