#!/bin/dash

sudo apt-get update && sudo apt install kmod -y

cat <<EOF | sudo tee -a /etc/security/limits.conf
root soft nofile 100000
root hard nofile 100000
*       hard    nofile  100000
*       soft    nofile  100000
EOF

cat <<EOF | sudo tee -a /etc/modules
tun
loop
ip_tables
tcp_bbr
EOF

cat <<EOF | sudo tee /etc/sysctl.d/bbr.conf
net.core.default_qdisc=fq_codel
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_moderate_rcvbuf = 1
net.core.wmem_max = 26214400
net.core.rmem_max = 26214400
fs.file-max = 65535
EOF

cat <<EOF | sudo tee /etc/sysctl.d/99-allow-ping.conf
net.ipv4.ping_group_range=1001 10001
EOF
