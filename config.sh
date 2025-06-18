#!/bin/bash
# -*- coding: utf-8 -*-

# Linux Toolbox - Configuration File

# --- High-Intensity Bright Color Definitions ---
# Using high-intensity codes (90-97) for maximum brightness and compatibility.
RED='\033[91m'        # High-Intensity Red
GREEN='\033[92m'      # High-Intensity Green
YELLOW='\033[93m'     # High-Intensity Yellow
BLUE='\033[94m'       # High-Intensity Blue
PURPLE='\033[95m'     # High-Intensity Magenta
CYAN='\033[96m'       # High-Intensity Cyan
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
