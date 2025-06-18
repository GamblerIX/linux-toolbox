#!/bin/bash
# -*- coding: utf-8 -*-

# Linux Toolbox - Configuration File

# --- Directory and File Paths ---
TOOLBOX_INSTALL_DIR="/etc/linux-toolbox"
CONFIG_FILE="$TOOLBOX_INSTALL_DIR/config.cfg"
TOOLBOX_LIB_DIR="/usr/local/lib/linux-toolbox"
TOOL_EXECUTABLE="/usr/local/bin/tool"

# --- High-Intensity Bright & Bold Color Definitions (Global) ---
RED=$'\e[1;91m'
GREEN=$'\e[1;92m'
YELLOW=$'\e[1;93m'
BLUE=$'\e[1;94m'
PURPLE=$'\e[1;95m'
CYAN=$'\e[1;96m'
NC=$'\e[0m' # No Color

# --- Compatibility Colors for Superbench ---
# These variables are mapped to the main color definitions above.
SKYBLUE="${CYAN}"
PLAIN="${NC}"

# --- Default Configuration Values ---
INSTALLED=false
OS_TYPE=""
OS_CODENAME=""
OS_VERSION=""
