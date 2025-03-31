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
net.core.netdev_budget = 600
net.core.optmem_max = 25165824
net.core.somaxconn = 3276800
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_collapse_max_bytes=6291456
net.ipv4.tcp_notsent_lowat=131072
net.ipv4.tcp_abort_on_overflow=1
net.ipv4.tcp_adv_win_scale=-2
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_slow_start_after_idle=1
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_mtu_probing = 1

net.ipv4.tcp_syn_retries=3
net.ipv4.tcp_synack_retries=3
net.ipv4.tcp_retries2=5
net.ipv4.tcp_syncookies=0
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_rmem=4096 87380 192000000
net.ipv4.tcp_wmem=4096 65536 192000000
net.ipv4.route.gc_timeout=100
net.unix.max_dgram_qlen=1024

net.nf_conntrack_max=1000000
net.netfilter.nf_conntrack_max = 1000000
net.netfilter.nf_conntrack_tcp_timeout_fin_wait=30
net.netfilter.nf_conntrack_tcp_timeout_time_wait=30
net.netfilter.nf_conntrack_tcp_timeout_close_wait=15
net.netfilter.nf_conntrack_tcp_timeout_established=300
net.ipv4.netfilter.ip_conntrack_tcp_timeout_established=7200

fs.file-max = 2097152
fs.inode-max = 4194304
fs.nr_open = 1073741816

vm.dirty_ratio=10
vm.overcommit_memory=1
vm.panic_on_oom=1
vm.swappiness=10
vm.vfs_cache_pressure=250
vm.zone_reclaim_mode=0
vm.max_map_count = 524288

kernel.panic=1
kernel.pid_max=32768
kernel.shmall=1073741824
kernel.shmmax=4294967296
kernel.sysrq=1
EOF

sudo tee /etc/sysctl.d/99-allow-ping.conf > /dev/null << 'EOF'
net.ipv4.ping_group_range=1001 10001
EOF