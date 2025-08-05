#!/bin/bash
#
# Lares Raspberry Pi App Uninstaller
#
# This is a generated uninstaller. Do not edit directly.
#

set -e

# --- Configuration (Baked in during packaging) ---
APP_INSTALL_DIR="/opt/lares-pi-app"
SERVICE_NAME="lares-pi-app"
# ---

# Helper functions for colored output
info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

warn() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
    # Don't exit on error during uninstall, just report it
}

# --- Main Uninstallation Logic ---

main() {
    info "Starting Lares Raspberry Pi App uninstallation..."

    INSTALL_USER=$(whoami)

    # 1. Stop and Disable Systemd Service
    info "Stopping and disabling systemd service: ${SERVICE_NAME}..."
    if sudo systemctl is-active --quiet ${SERVICE_NAME}; then
        sudo systemctl stop ${SERVICE_NAME}
        success "Service stopped."
    else
        info "Service was not running."
    fi
    if sudo systemctl is-enabled --quiet ${SERVICE_NAME}; then
        sudo systemctl disable ${SERVICE_NAME} > /dev/null
        success "Service disabled."
    else
        info "Service was not enabled."
    fi

    # 2. Remove Systemd Service File
    SERVICE_FILE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"
    info "Removing systemd service file: ${SERVICE_FILE_PATH}..."
    if [ -f "$SERVICE_FILE_PATH" ]; then
        sudo rm -f "$SERVICE_FILE_PATH"
        sudo systemctl daemon-reload
        success "Service file removed and systemd reloaded."
    else
        info "Service file not found."
    fi

    # 3. Remove Sudoers Entry
    info "Removing sudoers entry for network_control.sh..."
    SUDOERS_LINE="${INSTALL_USER} ALL=(ALL) NOPASSWD: $APP_INSTALL_DIR/network_control.sh *"
    if sudo grep -Fxq "$SUDOERS_LINE" /etc/sudoers; then
        # Use a temporary file to edit sudoers safely
        sudo cp /etc/sudoers /tmp/sudoers.bak
        sudo grep -Fv "$SUDOERS_LINE" /tmp/sudoers.bak | sudo tee /etc/sudoers > /dev/null
        sudo rm /tmp/sudoers.bak
        success "Sudoers entry removed."
    else
        info "Sudoers entry not found."
    fi

    # 4. Remove Application Directory
    info "Removing installation directory: $APP_INSTALL_DIR..."
    if [ -d "$APP_INSTALL_DIR" ]; then
        sudo rm -rf "$APP_INSTALL_DIR"
        success "Application directory removed."
    else
        info "Application directory not found."
    fi

    echo
    success "Uninstallation Complete!"
    info "System dependencies (like curl, git, python3-venv) were not removed as they might be used by other applications."
    echo
}

# Run the main function
main
