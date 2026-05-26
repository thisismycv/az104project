#!/bin/bash

# Update package list
apt update

# Install packages (fixed typo on second line)
apt install -y vim git apache2 php
apt install -y vim git apache2 php mariadb-server

# Configure SSH for key authentication only
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH to apply changes
systemctl restart sshd

echo "Done. SSH now requires key authentication only."