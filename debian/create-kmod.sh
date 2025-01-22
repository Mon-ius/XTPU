#!/bin/dash

sudo apt-get update && sudo apt install kmod -y

sudo tee -a /etc/security/limits.conf > /dev/null <<EOT
root soft nofile 100000
root hard nofile 100000
*       hard    nofile  100000
*       soft    nofile  100000
EOT

sudo tee -a /etc/modules > /dev/null <<EOT
tun
loop
ip_tables
tcp_bbr
EOT

sudo tee /etc/sysctl.d/bbr.conf > /dev/null <<EOT
net.core.default_qdisc=fq_codel
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_moderate_rcvbuf = 1
net.core.wmem_max = 26214400
net.core.rmem_max = 26214400
fs.file-max = 2097152
fs.inode-max = 4194304
EOT

sudo tee /etc/sysctl.d/99-allow-ping.conf > /dev/null <<EOT
net.ipv4.ping_group_range=1001 10001
EOT
