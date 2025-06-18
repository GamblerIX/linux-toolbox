#!/bin/bash
# -*- coding: utf-8 -*-

# Linux Toolbox - Configuration File

# --- Bright Color Definitions ---
RED='\033[1;91m'      # Bright Red
GREEN='\033[1;92m'    # Bright Green
YELLOW='\033[1;93m'   # Bright Yellow
BLUE='\033[1;94m'     # Bright Blue
PURPLE='\033[1;95m'   # Bright Magenta
CYAN='\033[1;96m'     # Bright Cyan
NC='\033[0m'          # No Color

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
