#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
SCHEDULED_REBOOT="0 21 * * 5 root /sbin/shutdown -r now"
MEMORY_CHECK_SCRIPT="/usr/local/bin/check_memory.sh"

cat > /tmp/check_memory.sh << 'EOF'
#!/bin/bash

MEM_INFO=$(free | grep Mem)
TOTAL=$(echo $MEM_INFO | awk '{print $2}')
USED=$(echo $MEM_INFO | awk '{print $3}')
PERCENTAGE=$(awk "BEGIN {printf \"%.2f\", $USED/$TOTAL*100}")

if (( $(echo "$PERCENTAGE > 66" | bc -l) )); then
    /sbin/shutdown -r now
    exit 1
fi

exit 0
EOF

if [ -f /etc/alpine-release ]; then
    doas apk add --no-cache tzdata bc
    doas cp /usr/share/zoneinfo/UTC /etc/localtime
    echo "UTC" | doas tee /etc/timezone
    
    doas mv /tmp/check_memory.sh $MEMORY_CHECK_SCRIPT
    doas chmod +x $MEMORY_CHECK_SCRIPT
    
    doas sed -i '/shutdown -[rh]/d' /etc/crontabs/root
    doas sed -i "\|$MEMORY_CHECK_SCRIPT|d" /etc/crontabs/root
    
    echo "$SCHEDULED_REBOOT" | doas tee -a /etc/crontabs/root
    echo "0 * * * * root $MEMORY_CHECK_SCRIPT" | doas tee -a /etc/crontabs/root
    
    doas /etc/init.d/crond restart
else
    sudo -E apt-get -qq update
    sudo -E apt-get -qq install -y tzdata cron bc
    sudo ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    echo "UTC" | sudo tee /etc/timezone
    sudo /usr/sbin/dpkg-reconfigure -f noninteractive tzdata
    
    sudo mv /tmp/check_memory.sh $MEMORY_CHECK_SCRIPT
    sudo chmod +x $MEMORY_CHECK_SCRIPT
    
    sudo sed -i '/shutdown -[rh]/d' /etc/crontab
    sudo sed -i "\|$MEMORY_CHECK_SCRIPT|d" /etc/crontab
    
    echo "$SCHEDULED_REBOOT" | sudo tee -a /etc/crontab
    echo "0 * * * * root $MEMORY_CHECK_SCRIPT" | sudo tee -a /etc/crontab
    
    sudo systemctl restart cron
fi