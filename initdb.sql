create database squiddb;
create user 'squid'@'localhost' identified by 'root@2019';
grant all privileges on squiddb.* to 'squid'@'localhost';
use squiddb;
CREATE TABLE IF NOT EXISTS `IPMASTER` (

  `IPID` int(4) unsigned NOT NULL AUTO_INCREMENT,

  `IPADDRESS` INT(12) UNSIGNED NOT NULL,

  `STATUS` BOOLEAN,
  
  `MUL` int(2) unsigned NOT NULL,
  
  `USED` int(2) unsigned NOT NULL,

  PRIMARY KEY (`IPID`)

);
ALTER TABLE IPMASTER AUTO_INCREMENT=1001;

CREATE TABLE IF NOT EXISTS `USERMASTER` (

  `USERID` int(3) unsigned NOT NULL AUTO_INCREMENT,

  `USERNAME` VARCHAR(12) NOT NULL,

  `PASSWORD` VARCHAR(12) NOT NULL,
  
  `TYPE` VARCHAR(1) NOT NULL,

  PRIMARY KEY (`USERID`)

);
ALTER TABLE USERMASTER AUTO_INCREMENT=101;

CREATE TABLE IF NOT EXISTS `PROXYMASTER` (

  `PXYID` int(4) unsigned NOT NULL AUTO_INCREMENT,

  `USERID` int(3) unsigned NOT NULL,

  `IPID` int(4) unsigned NOT NULL,

  `PORT` int(5) unsigned NOT NULL,

  `SDATE` DATE NOT NULL,

  `STIME` TIME NOT NULL,

  `EDATE` DATE NOT NULL,

  `ETIME` TIME NOT NULL,

  PRIMARY KEY (`PXYID`)

);
ALTER TABLE PROXYMASTER AUTO_INCREMENT=1001;
