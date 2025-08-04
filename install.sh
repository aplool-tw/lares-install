#!/bin/bash
#
# Lares Raspberry Pi App Installer
#
# This is a generated installer. Do not edit directly.
#

set -e

# --- Configuration (Baked in during packaging) ---
GITHUB_REPO="aplool-tw/lares-pi-app"
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
    exit 1
}

# --- Main Installation Logic ---

main() {
    info "Starting Lares Raspberry Pi App installation..."

    # 1. Install System Dependencies
    info "Updating package list and installing dependencies (curl, git, python3-venv, network-manager)..."
    sudo apt-get update > /dev/null
    sudo apt-get install -y curl git python3-venv network-manager > /dev/null
    success "Dependencies installed."

    # 2. Create Project Directory
    info "Creating installation directory at $APP_INSTALL_DIR..."
    sudo mkdir -p "$APP_INSTALL_DIR"
    sudo chown -R pi:pi "$APP_INSTALL_DIR" # Grant user 'pi' ownership
    cd "$APP_INSTALL_DIR"
    success "Directory created."

    # 3. Download and Extract Latest Release
    info "Fetching latest release from GitHub repository: $GITHUB_REPO..."
    LATEST_RELEASE_INFO=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest")
    # Find the download URL for the asset that matches the package file name
    DOWNLOAD_URL=$(echo "$LATEST_RELEASE_INFO" | grep "browser_download_url" | grep "lares-pi-app-v1.0.0.tar.gz" | head -n 1 | cut -d '"' -f 4)
    
    if [ -z "$DOWNLOAD_URL" ]; then
        error "Could not find the download URL for lares-pi-app-v1.0.0.tar.gz in the latest release. Please check the repository."
    fi

    info "Downloading and extracting latest version..."
    wget -q -O /tmp/lares-release.tar.gz "$DOWNLOAD_URL"
    tar -xzf /tmp/lares-release.tar.gz -C "$APP_INSTALL_DIR"
    rm /tmp/lares-release.tar.gz
    success "Latest version downloaded and extracted."

    # 4. Set Up Python Environment
    info "Creating Python virtual environment and installing dependencies..."
    python3 -m venv .venv
    source .venv/bin/activate
    # Install the project and its dependencies from pyproject.toml
    pip install . > /dev/null
    deactivate
    success "Python environment is ready."

    # 5. Grant Execute Permissions
    info "Setting execute permissions for scripts..."
    # Note: network_control.sh is now inside lares_pi_app
    chmod +x lares_pi_app/network_control.sh update.sh lares_pi_app/start_real.sh lares_pi_app/start_virtual.sh
    success "Permissions set."

    # 6. Configure Sudoers for Passwordless Execution
    info "Configuring passwordless sudo for network_control.sh..."
    SUDOERS_LINE="pi ALL=(ALL) NOPASSWD: $APP_INSTALL_DIR/lares_pi_app/network_control.sh *"
    if sudo grep -Fxq "$SUDOERS_LINE" /etc/sudoers; then
        success "Sudoers entry already exists."
    else
        echo "$SUDOERS_LINE" | sudo tee -a /etc/sudoers > /dev/null
        success "Sudoers entry added."
    fi

    # 7. Set Up Systemd Service
    info "Configuring systemd service..."
    # Generate a random token for the update endpoint
    UPDATE_TOKEN=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)
    
    SERVICE_FILE_CONTENT="[Unit]
Description=Lares Raspberry Pi Control Service
After=network.target

[Service]
User=pi
WorkingDirectory=$APP_INSTALL_DIR
ExecStart=$APP_INSTALL_DIR/lares_pi_app/start_real.sh
Restart=always
Environment=\"LARES_UPDATE_TOKEN=$UPDATE_TOKEN\"

[Install]
WantedBy=multi-user.target
"
    echo "$SERVICE_FILE_CONTENT" | sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null
    
    sudo systemctl daemon-reload
    sudo systemctl enable ${SERVICE_NAME}.service > /dev/null
    sudo systemctl start ${SERVICE_NAME}.service
    success "Systemd service '${SERVICE_NAME}' created and started."

    # --- Final Instructions ---
    echo
    success "Installation Complete!"
    echo
    info "The application is now running in the background."
    info "You can check its status with: sudo systemctl status ${SERVICE_NAME}"
    echo
    warn "IMPORTANT: Your secret update token is: $UPDATE_TOKEN"
    warn "Store this token securely. You will need it to trigger remote updates."
    echo
}

# Run the main function
main
