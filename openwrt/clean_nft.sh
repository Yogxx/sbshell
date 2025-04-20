#!/bin/bash

nft list table inet sing-box >/dev/null 2>&1 && nft delete table inet sing-box

echo "Sing-box service has been stopped, sing-box related firewall rules have been cleared."
