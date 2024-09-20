#! /bin/sh
export MYSQL_HOME=$HOME/$REPL_SLUG/sql_data

# clean shutdown of existing database
mariadb-admin shutdown 2> /dev/null

# Enable this if you want to reset the database (or manually delete sql_data folder)
#read -p "Delete sql data? (y/n)" response
if [ "$response" == "y" ]; then
    rm -rf "$MYSQL_HOME"
    read -p "Continue..." response
fi

# Create dirs
mkdir -p htdocs
if [ ! -d "$MYSQL_HOME" ]; then
    fresh_install=1
    mkdir "$MYSQL_HOME"
else
    fresh_install=0
fi

# kill any existing php server(s)
kill $(ps aux | grep '[p]hp' | awk '{print $2}') 2> /dev/null

# Download phpmyadmin
pma_version="5.2.1"
if [ ! -f htdocs/RELEASE-DATE-${pma_version} ]; then
    curl -sL "https://files.phpmyadmin.net/phpMyAdmin/${pma_version}/phpMyAdmin-${pma_version}-all-languages.zip" -o phpMyAdmin.zip
    busybox unzip -q phpMyAdmin.zip && mv -f phpMyAdmin-${pma_version}-all-languages/{.,}* ./htdocs 2> /dev/null
    rm phpMyAdmin.zip && rmdir phpMyAdmin-${pma_version}-all-languages
fi

# run mysql as background task
# note: data directory assumed to be called 'sql_data'
# You can put neccessary configs on command line, e.g.
# mysqld_safe --datadir=$HOME/$REPL_SLUG/sql_data --log-error=logfile.err --innodb-log-file-size=4194304 &
# Or build a custom my.cnf, set MYSQL_HOME and use that.
# Fiddly, but Unix environment variables aren't expanded in my.cnf 
# so an effective way of being able to fork this repl without having 
# to edit any config files.
cat <<EOT > $MYSQL_HOME/my.cnf
[server]
datadir = $MYSQL_HOME
user = runner
bind-address = 127.0.0.1
pid-file = mysqld.pid
log-error = error.log
general_log_file = general.log
general_log = 1
disable-log-bin = 1
innodb-log-file-size = 4194304
# I prefer case-insensitive table names
lower_case_table_names = 1
default-storage-engine = InnoDB
EOT

if [ ! -z "${fresh_install}" ]; then
    mysql_install_db --skip-test-db --ldata="$MYSQL_HOME" &> /dev/null
    mysqld_safe &> /dev/null &
    while ! mysqladmin ping &> /dev/null; do
        sleep 1
    done
    cat <<EOT | mysql
CREATE DATABASE IF NOT EXISTS $db_name;
CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_pass';
GRANT ALL PRIVILEGES ON *.* TO '$db_user'@'localhost';
FLUSH PRIVILEGES;
QUIT
EOT
    mariadb-admin shutdown &> /dev/null
fi

# run php server as background task
php -S 0.0.0.0:8000 -t ./htdocs &> /dev/null &

# Now start the mariadb server as a background task with the parameters in my.cnf
mysqld_safe