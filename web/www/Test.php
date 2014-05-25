<?php
include_once '../include/db_connect.php';

echo $mysqli->query("SELECT count(*) FROM players");
?>
