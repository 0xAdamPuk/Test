#!/bin/bash

systemctl stop komari-agent
systemctl disable komari-agent
rm -f /etc/systemd/system/komari-agent.service 
systemctl daemon-reload
