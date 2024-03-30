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

# Function to check if script is run as root
checkRoot() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root" >&2
        exit 1
    else
        echo "User: root"
    fi
}

# Function to check if OS is Ubuntu
checkOS() {
    if [ "$OS" != "Linux" ] || [ "$DISTRIB" != "ubuntu" ]; then
        echo "Please run this script on Ubuntu Linux" >&2
        exit 1
    else
        echo "Operating System: $DISTRIB $OS"
    fi
}

# Function to get network interface
getInterface() {
    echo "Setting default key: $DEFAULT_KEY"
    echo "DEFAULT_KEY=$DEFAULT_KEY" >> "$BASEDIR/$CONFIG_FILE"
}

# Function to install Squid
installSquid() {
    apt-get update -y
    apt-get install -y squid apache2 apache2-utils
    systemctl enable squid
    systemctl start squid
}

# Function to initialize files and directories
initializeFiles() {
    mkdir -p "$BASEDIR"
    cp proxy.sh monitor.sh initdb.sql "$BASEDIR/"
    echo "OS=$OS" >> "$BASEDIR/$CONFIG_FILE"
    echo "DISTRIBUTION=$DISTRIB" >> "$BASEDIR/$CONFIG_FILE"
    echo "BASEDIR=$BASEDIR" >> "$BASEDIR/$CONFIG_FILE"
    echo "PRIMARYKEY=$PRIMARYKEY" >> "$BASEDIR/$CONFIG_FILE"
    chmod +x "$BASEDIR/proxy.sh"
    touch /etc/squid/squiddb
    touch /etc/squid/squid.passwd
    mkdir -p /etc/squid/conf.d/
    touch /etc/squid/conf.d/sample.conf
}

# Function to install MariaDB
installMariadb() {
    apt-get install -y mariadb-server
    systemctl enable mysql
    systemctl start mysql
    mysql_secure_installation <<EOF

y
$MYSQLROOTPWD
$MYSQLROOTPWD
y
y
y
y
EOF
}

# Function to secure MySQL installation and set root password
secureMySQL() {
    echo "Securing MySQL installation and setting root password"
    mysqladmin -u root password "$MYSQLROOTPWD" || {
        echo "Failed to set MySQL root password" >&2
        exit 1
    }
    mysql -u root -p"$MYSQLROOTPWD" -e "DELETE FROM mysql.user WHERE User='';" || {
        echo "Failed to remove anonymous users" >&2
        exit 1
    }
    mysql -u root -p"$MYSQLROOTPWD" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" || {
        echo "Failed to disallow remote root login" >&2
        exit 1
    }
    mysql -u root -p"$MYSQLROOTPWD" -e "DROP DATABASE IF EXISTS test;" || {
        echo "Failed to remove test database" >&2
        exit 1
    }
    mysql -u root -p"$MYSQLROOTPWD" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';" || {
        echo "Failed to remove access to test database" >&2
        exit 1
    }
    mysql -u root -p"$MYSQLROOTPWD" -e "FLUSH PRIVILEGES;" || {
        echo "Failed to reload privileges" >&2
        exit 1
    }
}

# Function to initialize the database
initializeDB() {
    echo "Initializing Database structure"
    mysql -u "$MYSQLUSER" -p"$MYSQLROOTPWD" "$MYSQLDB" < initdb.sql
}

# Function to set Squid configuration
setconfig() {
    cp /etc/squid/squid.conf /etc/squid/squid.conf.orig
    cat <<EOF > /etc/squid/squid.conf
# Squid Configuration
http_port 7656
visible_hostname localhost
# Add more configurations here...
EOF
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
