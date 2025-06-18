#!/bin/bash
# -*- coding: utf-8 -*-

# Linux Toolbox - Configuration File

# --- High-Intensity Bright & Bold Color Definitions ---
# Using a more robust syntax ($'\e[...]) with bold (1;) and high-intensity
# codes (90-97) for maximum brightness and compatibility across terminals.
RED=$'\e[1;91m'        # Bold High-Intensity Red
GREEN=$'\e[1;92m'      # Bold High-Intensity Green
YELLOW=$'\e[1;93m'     # Bold High-Intensity Yellow
BLUE=$'\e[1;94m'       # Bold High-Intensity Blue
PURPLE=$'\e[1;95m'     # Bold High-Intensity Magenta
CYAN=$'\e[1;96m'       # Bold High-Intensity Cyan
NC=$'\e[0m'          # No Color

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
