<?php function print_header($username)
{
	echo "<table border='0' width='100%' style='background:#F5F5FF; color:#000000'>";
	echo "<td align='center'><b>Welcome <a href='" . ROOT . "/profile.php'>" . $username . "</a></b><br />";
	echo "<a href='" . ROOT . "/logout.php'>Log Out</a></td>";
	echo "</table>";
} ?>
