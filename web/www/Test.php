<?php
echo hash('sha512', uniqid(openssl_random_pseudo_bytes(16), TRUE));
?>
