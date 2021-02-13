#!/bin/bash

set -x

#### Set up MySQL Server
export DEBIAN_FRONTEND=noninteractive
sudo echo "127.0.0.1 $(hostname)" >> /etc/hosts

# Pre-set the MySQL password so apt doesn't pop up a password dialog
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password abc123"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password abc123"

#### Install System Packages ####
apt-get update
apt-get install -qq -y python mysql-server

#### Set up Cloud Watch ####
cloud_watch_log_config () {
cat << EOF >/etc/awslogs-config-file
[general]
state_file = /var/awslogs/state/agent-state

[/var/log/syslog]
file = /var/log/mysql/mysql*.log
log_group_name = ${mysql_log_group}
log_stream_name = ${mysql_log_stream}
datetime_format = %b %d %H:%M:%S
EOF
}

cloud_watch_logs () {
  cloud_watch_log_config
  curl -s https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py --output /usr/local/awslogs-agent-setup.py
  python /usr/local/awslogs-agent-setup.py -n -r ${aws_region} -c /etc/awslogs-config-file
  systemctl enable awslogs
  systemctl start awslogs
}

cloud_watch_logs
###########################################

#### Install MySQL

touch /var/log/mysql/mysql.log
chown mysql:mysql /var/log/mysql/mysql.log
touch /var/log/mysql/mysql-error.log
chown mysql:mysql /var/log/mysql/mysql-error.log
chmod +x /var/log/mysql/
chmod +r /var/log/mysql/*

cat << EOF > /etc/mysql/mysql.conf.d/petclinic.cnf
[mysqld]
performance_schema = on
general_log = on
general_log_file=/var/log/mysql/mysql.log
log_error=/var/log/mysql/mysql-error.log
bind-address = 0.0.0.0
lower_case_table_names=1
character-set-server=utf8
collation-server=utf8_general_ci
innodb_large_prefix=on
innodb_file_format=Barracuda
EOF


systemctl restart mysql

mysql -u root -pabc123 -e "create user if not exists root@'%' identified by 'ech9Weith4Phei7W'"
mysql -u root -pabc123 -e "grant all privileges on *.* to root@'%' with grant option"
mysql -u root -pabc123 -e "grant proxy on '@' to root@'%'"
mysql -u root -pabc123 -e "create database if not exists petclinic"
mysql -u root -pabc123 -e "flush privileges"
###########################################

#### Clean up
apt-get clean
rm -rf /var/lib/apt/lists/*
###########################################