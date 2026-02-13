#!/usr/bin/env bash
set -xeuo pipefail

systemctl enable tools-overlay-setup.service
systemctl enable jetbrains-toolbox-install.service
systemctl enable jetbrains-desktop-sync.timer
