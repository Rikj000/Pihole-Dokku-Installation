#!/bin/bash
# Author: Rikj000
# ===============

# Create the synology macvlan0 bridge network attached to the physical eth0 adapter
ip link add macvlan0 link eth0 type macvlan mode bridge

# Reserve part of the eth0 IP-range scope for the macvlan0
ip addr add 192.168.0.210/28 dev macvlan0

# Bring up the virtual macvlan0 adapter
ip link set macvlan0 up
