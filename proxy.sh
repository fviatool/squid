#!/bin/bash

### Global Variables ###
OS=$(uname -s)
DISTRIB=$(cat /etc/*release* | grep -i DISTRIB_ID | cut -f2 -d=)
SQUID_VERSION=4.8
BASEDIR="/opt/squid"
CONFIGDIR="/etc/squid"
CONFIG_FILE="${BASEDIR}/config.cfg"
PASSWDMASTER="/etc/squid/squid.passwd"
BLACKLIST="/etc/squid/blacklist.acl"
MYSQLDB="squiddb"
MYSQLUSER="squid"
MYSQL_PWD="root@2019"
export MYSQL_PWD

if [ $# -eq 1 ]; then
    userid=$(mysql -N -h localhost -u $MYSQLUSER $MYSQLDB -e "SELECT USERID FROM USERMASTER WHERE USERNAME='$1';")
    if [ -z "$userid" ]; then
        echo "User $1 doesn't exist!!!"
        exit 32
    fi
    ipids=$(mysql -N -h localhost -u $MYSQLUSER $MYSQLDB -e "select IPID from PROXYMASTER where USERID=$userid;")
    for IPID in $ipids; do
        mysql -h localhost -u $MYSQLUSER $MYSQLDB -e "DELETE from PROXYMASTER WHERE IPID=$IPID and USERID=$userid;"
        mysql -h localhost -u $MYSQLUSER $MYSQLDB -e "UPDATE IPMASTER SET STATUS=0 WHERE IPID=$IPID;"
    done
    mysql -N -h localhost -u $MYSQLUSER $MYSQLDB -e "DELETE from USERMASTER WHERE USERNAME='$1';"
    echo "User: $1 DELETED!!!!"
    rm -rf /etc/squid/conf.d/${userid}.conf
    systemctl reload squid
    exit 0
else
    echo > /dev/null
fi

checkRoot() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Script must be run as root user"
        exit 13
    else
        echo "User: root" > /dev/null
    fi
}

checkOS() {
    if [ "$OS" == "Linux" ] && [ "$DISTRIB" == "Ubuntu" ]; then
        echo "Operating System = $DISTRIB $OS" > /dev/null
    else
        echo "Please run this script on Ubuntu Linux"
        exit 12
    fi
}

checkSquid() {
    dpkg-query --list squid >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Squid Installed" > /dev/null
    else
        apt-get install squid apache2-utils -y
    fi
    clear
}

# Function to print the menu
printMenu() {
    clear
    tput clear
    for I in {1..80}; do
        tput cup 1 $I
        printf "#"
    done
    printf "\n"
    R=2
    C1=1
    C2=45
    M=1
    while read LINE; do
        tput cup $R $C1
        printf "[$M]$(echo $LINE | awk -F, '{print $1}')"
        M=$((M + 1))
        tput cup $R $C2
        printf "[$M]$(echo $LINE | awk -F, '{print $2}')"
        M=$((M + 1))
        R=$((R + 1))
    done <<EOM
ADD IP TO SERVER,SHOW AVAILABLE PROXIES
ADD USER,ASSIGN IP TO USER
SHOW USERS EXPIRY DATE,MODIFY USERS EXPIRY DATE
SHOW USERS PROXY INFO,DELETE IP FROM SERVER
DELETE USER PROXY,DELETE USER
SHUTDOWN PROXY,START PROXY
EXPORT AVAILABLE PROXY,EXPORT USERS PROXY
ADD BLACK LIST,SHOW BLACKLIST
DELETE BLACKLIST,EXIT
RANDOM PROXIES,CHANGE IP-MULTIPLIER
EOM
    for I in {1..11}; do
        tput cup $I 80
        printf "#"
    done
    for I in {1..80}; do
        tput cup 12 $I
        printf "#"
    done
    printf "\n"
    tput sgr0
}

# Function to create proxy file
createProxyFile() {
    cd ${CONFIGDIR}/conf.d/
    printf "acl $1_$2 myip $1\n" >>$5
    printf "tcp_outgoing_address $1 $1_$2\n" >>$5
    printf "http_access allow $3 $1_$2 $3_$2\n" >>$5
}

# Menu functions
Menu_1() {
    INT=$(cat ${CONFIG_FILE} | grep INTERFACE | awk -F"=" '{print $2}')
    echo "Please Enter IP Address Block Details"
    read -p "Enter Starting IP address:" IPBLK
    read -p "Enter total number of IP :" N
    read -p "Enter Subnet[21|22|23|24]:" S
    J=$(echo ${IPBLK} | cut -f3 -d.)
    IP=$(echo ${IPBLK} | cut -f1,2 -d.)
    M=0
    I=$(echo ${IPBLK} | cut -f4 -d.)
    while [ $M -lt $N ]; do
        if [ $I -eq 256 ]; then
            J=$((J + 1))
            I=0
        fi
        NEWIP="$IP.$J.$I"
        I=$((I + 1))
        M=$((M + 1))
        mysql -h localhost -u $MYSQLUSER $MYSQLDB -e "insert into IPMASTER (IPADDRESS,STATUS,MUL,USED) values (INET_ATON('$NEWIP'),0,2,0);"
        ip addr add $NEWIP/$S dev $INT
        touch /etc/network/interfaces.d/${NEWIP}
        echo "auto $INT" >>/etc/network/interfaces.d/${NEWIP}
        echo "iface $INT inet static" >>/etc/network/interfaces.d/${NEWIP}
        echo "address ${NEWIP}" >>/etc/network/interfaces.d/${NEWIP}
        echo "netmask 255.255.255.255" >>/etc/network/interfaces.d/${NEWIP}
    done
}

Menu_2() {
    mysql -h localhost -u $MYSQLUSER $MYSQLDB -e "SELECT INET_NTOA(IPADDRESS) AS IP,STATUS,MUL,USED FROM IPMASTER;”
}

Menu_3() {
read -p “Enter username:” U
read -p “Enter password:” P
read -p “Enter expiry date[yyyy-mm-dd]:” E
mysql -h localhost -u $MYSQLUSER $MYSQLDB -e “insert into USERMASTER (USERNAME,PASSWORD,EXPIRYDATE) values (’$U’,MD5(’$P’),’$E’);”
}

Menu_4() {
mysql -h localhost -u $MYSQLUSER $MYSQLDB -e “SELECT USERNAME,INET_NTOA(IPADDRESS),EXPIRYDATE FROM USERMASTER INNER JOIN PROXYMASTER ON USERMASTER.USERID=PROXYMASTER.USERID;”
}

Menu_5() {
mysql -h localhost -u $MYSQLUSER $MYSQLDB -e “SELECT USERNAME,INET_NTOA(IPADDRESS),DATE_FORMAT(EXPIRYDATE,’%d-%m-%Y’) FROM USERMASTER INNER JOIN PROXYMASTER ON USERMASTER.USERID=PROXYMASTER.USERID WHERE USERID=$1;”
}

Menu_6() {
read -p “Enter username:” U
userid=$(mysql -N -h localhost -u $MYSQLUSER $MYSQLDB -e “SELECT USERID FROM USERMASTER WHERE USERNAME=’$U’;”)
if [ -z “$userid” ]; then
echo “User $U doesn’t exist!!!”
exit 31
fi
ipids=$(mysql -N -h localhost -u $MYSQLUSER $MYSQLDB -e “select IPID from PROXYMASTER where USERID=$userid;”)
for IPID in $ipids; do
mysql -h localhost -u $MYSQLUSER $MYSQLDB -e “DELETE from PROXYMASTER WHERE IPID=$IPID and USERID=$userid;”
mysql -h localhost -u $MYSQLUSER $MYSQLDB -e “UPDATE IPMASTER SET STATUS=0 WHERE IPID=$IPID;”
done
echo “User: $U proxy DELETED!!!!”
rm -rf /etc/squid/conf.d/${userid}.conf
systemctl reload squid
}

Menu_7() {
read -p “Enter username:” U
userid=$(mysql -N -h localhost -u $MYSQLUSER $MYSQLDB -e “SELECT USERID FROM USERMASTER WHERE USERNAME=’$U’;”)
if [ -z “$userid” ]; then
echo “User $U doesn’t exist!!!”
exit 31
fi
mysql -h localhost -u $MYSQLUSER $MYSQLDB -e “DELETE from PROXYMASTER WHERE USERID=$userid;”
echo “User: $U proxy DELETED!!!!”
rm -rf /etc/squid/conf.d/${userid}.conf
systemctl reload squid
}

Menu_8() {
systemctl stop squid
}

Menu_9() {
systemctl start squid
}

Menu_10() {
mysql -h localhost -u $MYSQLUSER $MYSQLDB -e “SELECT INET_NTOA(IPADDRESS) AS IP,STATUS,MUL,USED FROM IPMASTER where STATUS=0;”
}

Menu_11() {
read -p “Enter URL to add to blacklist:” URL
printf “$URL\n” >>$BLACKLIST
systemctl reload squid
}

Menu_12() {
cat $BLACKLIST
}

Menu_13() {
read -p “Enter URL to delete from blacklist:” URL
sed -i “/$URL/d” $BLACKLIST
systemctl reload squid
}

Menu_14() {
exit
}

Menu_15() {
mysql -h localhost -u $MYSQLUSER $MYSQLDB -e “SELECT INET_NTOA(IPADDRESS) AS IP FROM IPMASTER WHERE MUL=1 AND STATUS=0 ORDER BY RAND() LIMIT 1;”
}

Menu_16() {
read -p “Enter username:” U
read -p “Enter Multiplier [1|2]:” M
userid=$(mysql -N -h localhost -u $MYSQLUSER $MYSQLDB -e “SELECT USERID FROM USERMASTER WHERE USERNAME=’$U’;”)
if [ -z “$userid” ]; then
echo “User $U doesn’t exist!!!”
exit 31
fi
ipid=$(mysql -N -h localhost -u $MYSQLUSER $MYSQLDB -e “SELECT IPID FROM PROXYMASTER WHERE USERID=$userid;”)
mysql -h localhost -u $MYSQLUSER $MYSQLDB -e “UPDATE IPMASTER SET MUL=$M WHERE IPID=$ipid;”
echo “User: $U’s IP Multiplier set to $M!!!!”
}
checkRoot
checkOS
checkSquid
while true; do
printMenu
read -p “Enter your choice [1-16]:” CHOICE
case $CHOICE in
1)
Menu_1
;;
2)
Menu_2
;;
3)
Menu_3
;;
4)
Menu_4
;;
5)
read -p “Enter username:” U
Menu_5 $U
;;
6)
Menu_6
;;
7)
Menu_7
;;
8)
Menu_8
;;
9)
Menu_9
;;
10)
Menu_10
;;
11)
Menu_11
;;
12)
Menu_12
;;
13)
Menu_13
;;
14)
Menu_14
;;
15)
Menu_15
;;
16)
Menu_16
;;
*)
echo “Invalid Choice”
;;
esac
read -p “Press [Enter] key to continue…” readEnterKey
done
