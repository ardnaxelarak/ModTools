<?php
function print_header($mysqli)
{
	$logged = login_check($mysqli);
	if ($logged)
	{
		$username = htmlentities($_SESSION['username']); ?>
		<table border='0' width='100%' style='background:#F5F5FF; color:#000000'>
		<tr>
		<td><b>Welcome <a href='<?php echo ROOT ?>/user/<?php echo $username ?>'><?php echo $username?></a></b></td>
		<td><a href='<?php echo ROOT ?>'>ModKiwi Home</a></td>
		<td><a href='<?php echo ROOT ?>/logout'>Log Out</a></td>
		</tr>
		<tr>
		<td><a href='<?php echo ROOT ?>/profile'>Edit Profile</a></td>
		</tr>
		</table>
<?php } else { ?>
		<table border='0' width='100%' style='background:#F5F5FF; color:#000000'>
		<tr><td align='center'><b>Welcome!</b><br />
		<a href='<?php echo ROOT ?>/login'>Log In</a></td></tr>
		</table>
<?php
	}
} ?>
