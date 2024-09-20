{ pkgs }: {
	deps = [
    pkgs.busybox
    pkgs.php
    pkgs.phpExtensions.mbstring
    pkgs.phpExtensions.pdo
    pkgs.phpExtensions.opcache
    pkgs.phpExtensions.mysqli
    pkgs.mariadb
	];
}