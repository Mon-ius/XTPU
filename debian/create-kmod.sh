#!/bin/dash

export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y kmod

if  dpkg -l | grep -q "google-cloud-cli"; then
    echo "Removing Google Cloud CLI..."
    sudo -E apt-get remove -y google-cloud-cli
    sudo -E apt-get autoremove -y
    echo "Google Cloud CLI removed."
fi

if dpkg -l | grep -q "google-guest-agent"; then
    echo "Removing Google Guest Agent..."
    sudo apt-get remove -y google-guest-agent
    sudo apt-get autoremove -y
    echo "Google Guest Agent removed."
fi

sudo tee /etc/security/limits.conf > /dev/null << 'EOF'
root soft nofile 2000000
root hard nofile 2000000
*       hard    nofile  2000000
*       soft    nofile  2000000
EOF

sudo tee -a /etc/modules > /dev/null << 'EOF'
tun
loop
ip_tables
tcp_bbr
EOF

sudo tee /etc/sysctl.d/bbr.conf > /dev/null << 'EOF'

net.core.default_qdisc=fq_codel
net.core.optmem_max = 25165824
net.core.wmem_max = 26214400
net.core.rmem_max = 26214400
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_adv_win_scale=-2
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 5
net.netfilter.nf_conntrack_max = 1048576
fs.file-max = 2097152
fs.inode-max = 4194304
fs.nr_open = 1073741816
vm.max_map_count = 524288
EOF

sudo tee /etc/sysctl.d/99-allow-ping.conf > /dev/null << 'EOF'
net.ipv4.ping_group_range=1001 10001
EOF