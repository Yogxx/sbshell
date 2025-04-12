#!/bin/bash

# Clear firewall rules and stop services
sudo systemctl stop sing-box
nft flush ruleset

echo "The sing-box service has been stopped and the firewall rules have been cleared."
