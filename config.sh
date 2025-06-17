#!/bin/bash
# -*- coding: utf-8 -*-

# Linux Toolbox - Configuration File

# --- Color Definitions ---
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# --- Directory and File Paths ---
TOOLBOX_INSTALL_DIR="/etc/linux-toolbox"
CONFIG_FILE="$TOOLBOX_INSTALL_DIR/config.cfg"
TOOLBOX_LIB_DIR="/usr/local/lib/linux-toolbox"
TOOL_EXECUTABLE="/usr/local/bin/tool"

# --- Default Configuration Values ---
INSTALLED=false
OS_TYPE=""
OS_CODENAME=""
OS_VERSION=""
