<?php
include_once '../include/newgame.inc.php';
?>
<!DOCTYPE html>
<html>
	<head>
		<meta charset="UTF-8">
		<title>New Game | ModKiwi</title>
		<link rel="stylesheet" href="<?php echo ROOT ?>/bgg.css" />
		<script>
			function update() {
				document.getElementById("max_players").disabled = !document.getElementById("limit_players").checked;
			}
		</script>
	</head>
	<body>
		<?php print_header($mysqli); ?>
<?php if (!$logged) { ?>
		You must be logged in to create a new game.
<?php } else { ?>
		<center>
		<h1>New Game</h1>
		<?php echo $message ?>
		<form action='<?php echo ROOT . "/new" ?>' method="post" name="new_game">
		<table>
			<tr><td>Game Type:</td><td><select name='game_type'><?php echo $options ?></select></td>
			<tr><td>Game Thread ID:</td><td><input type='text' name='thread_id' <?php if (isset($_POST['thread_id'])) { echo "value='" . $_POST['thread_id'] . "'"; } ?>/></td></tr>
			<tr><td>Game Index:</td><td><input type='text' name='game_index' <?php if (isset($_POST['game_index'])) { echo "value='" . $_POST['game_index'] . "'"; } ?>/></td></tr>
			<tr><td>Game Name:</td><td><input type='text' name='game_name' <?php if (isset($_POST['game_name'])) { echo "value='" . $_POST['game_name'] . "'"; } ?>/></td></tr>
<?php $limit = isset($_POST['limit_players']); ?>
			<tr><td colspan='2'><input type='checkbox' name='limit_players' id='limit_players' <?php if ($limit) { echo "checked='true'"; } ?> onclick='update();' />Limit number of players</td></tr>
			<tr><td>Max Players:</td><td><input type='number' name='max_players' min='1' id='max_players' <?php if (!$limit) { echo "disabled='true'"; } ?><?php if (isset($_POST['max_players'])) { echo "value='" . $_POST['max_players'] . "'"; } ?>/></td></tr>
		</table>
		<input type='checkbox' name='signups' <?php if (!isset($_POST['action']) || isset($_POST['signups'])) { echo "checked='true'"; }?> />Allow signups
		<input type='checkbox' name='signuplist' <?php if (!isset($_POST['action']) || isset($_POST['signuplist'])) { echo "checked='true'"; }?> />Create post listing signups<br>
		<input type='submit' value='Create' onclick='this.form.submit();' name='action'/></form>
		</center>
<?php } ?>
	</body>
</html>
