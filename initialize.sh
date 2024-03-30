#!/bin/bash

### Global Variables
OS=$(uname -s)
DISTRIB=$(awk -F= '/^ID=/{print tolower($2)}' /etc/*release*)
SQUID_VERSION=4.8
CONFIG_FILE="config.cfg"
BASEDIR="/opt/squid"
MYSQLDB="squiddb"
MYSQLUSER="squid"
PRIMARYKEY=18000
DEFAULT_KEY="123"  # Giá trị key mặc định

# Function to generate a random password
generatePassword() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1
}

# Function to install MariaDB
installMariadb() {
    # Generate a random password for MySQL
    MYSQLROOTPWD=$(generatePassword)

    # Install MariaDB
    apt-get install -y mariadb-server

    # Enable and start MySQL service
    systemctl enable mysql
    systemctl start mysql

    # Secure MySQL installation
    mysql_secure_installation <<EOF

y
$MYSQLROOTPWD
$MYSQLROOTPWD
y
y
y
y
EOF

    # Store the MySQL password in a temporary file
    echo "$MYSQLROOTPWD" > /tmp/mysql_root_password
}

# Function to initialize the database
initializeDB() {
    # Retrieve the MySQL password from the temporary file
    MYSQLROOTPWD=$(cat /tmp/mysql_root_password)

    echo "Initializing Database structure"
    mysql -u "$MYSQLUSER" -p"$MYSQLROOTPWD" "$MYSQLDB" < initdb.sql
}

# Main Function
main() {
    checkRoot
    checkOS
    getInterface
    installSquid
    initializeFiles
    installMariadb
    secureMySQL
    initializeDB
    setconfig
    ln -s "$BASEDIR/proxy.sh" /usr/bin/proxy
    touch /etc/squid/blacklist.acl
}

# Execute Main Function
main
