#!/bin/bash

# MLS Delivery Service Systemd Installation Script
# This script installs the MLS Delivery Service as a systemd service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] ${message}${NC}"
}

print_help() {
    echo "MLS Delivery Service Systemd Installation Script"
    echo "================================================"
    echo ""
    echo "This script installs the MLS Delivery Service as a systemd service"
    echo "with proper security settings and system integration."
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --user USER    Service user (default: mls-delivery)"
    echo "  --group GROUP  Service group (default: mls-delivery)"
    echo "  --prefix PATH  Installation prefix (default: /opt/mls-delivery-service)"
    echo "  --port PORT    Service port (default: 8080)"
    echo "  --host HOST    Service host (default: 127.0.0.1)"
    echo "  --uninstall    Uninstall the service instead of installing"
    echo "  --force        Force installation (overwrite existing files)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Install with default settings"
    echo "  $0 --user myuser      # Install with custom user"
    echo "  $0 --port 9000        # Install on custom port"
    echo "  $0 --uninstall        # Uninstall the service"
    echo ""
    echo "Prerequisites:"
    echo "  • Root privileges (run with sudo)"
    echo "  • Rust and Cargo installed"
    echo "  • systemd-enabled system"
    echo ""
    echo "What this script does:"
    echo "  1. Creates service user and group"
    echo "  2. Creates installation directory"
    echo "  3. Builds the service in release mode"
    echo "  4. Installs systemd service file"
    echo "  5. Sets up log rotation"
    echo "  6. Enables and starts the service"
    echo ""
    echo "Exit Codes:"
    echo "  0 - Installation successful"
    echo "  1 - Installation failed"
    echo "  2 - Invalid arguments"
}

# Default values
SERVICE_USER="mls-delivery"
SERVICE_GROUP="mls-delivery"
INSTALL_PREFIX="/opt/mls-delivery-service"
SERVICE_PORT="8080"
SERVICE_HOST="127.0.0.1"
UNINSTALL=false
FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_help
            exit 0
            ;;
        --user)
            SERVICE_USER="$2"
            shift 2
            ;;
        --group)
            SERVICE_GROUP="$2"
            shift 2
            ;;
        --prefix)
            INSTALL_PREFIX="$2"
            shift 2
            ;;
        --port)
            SERVICE_PORT="$2"
            shift 2
            ;;
        --host)
            SERVICE_HOST="$2"
            shift 2
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            echo "Error: Unknown option '$1'"
            echo "Use --help for usage information"
            exit 2
            ;;
    esac
done

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_status $RED "This script must be run as root (use sudo)"
    exit 1
fi

# Function to uninstall the service
uninstall_service() {
    print_status $BLUE "Uninstalling MLS Delivery Service..."
    
    # Stop and disable the service
    if systemctl is-active --quiet mls-delivery-service; then
        print_status $YELLOW "Stopping service..."
        systemctl stop mls-delivery-service
    fi
    
    if systemctl is-enabled --quiet mls-delivery-service; then
        print_status $YELLOW "Disabling service..."
        systemctl disable mls-delivery-service
    fi
    
    # Remove systemd service file
    if [[ -f /etc/systemd/system/mls-delivery-service.service ]]; then
        print_status $YELLOW "Removing systemd service file..."
        rm -f /etc/systemd/system/mls-delivery-service.service
    fi
    
    # Reload systemd
    print_status $YELLOW "Reloading systemd..."
    systemctl daemon-reload
    
    # Remove installation directory
    if [[ -d "$INSTALL_PREFIX" ]]; then
        print_status $YELLOW "Removing installation directory..."
        rm -rf "$INSTALL_PREFIX"
    fi
    
    # Remove service user and group
    if id "$SERVICE_USER" &>/dev/null; then
        print_status $YELLOW "Removing service user..."
        userdel -r "$SERVICE_USER" 2>/dev/null || userdel "$SERVICE_USER"
    fi
    
    if getent group "$SERVICE_GROUP" >/dev/null 2>&1; then
        print_status $YELLOW "Removing service group..."
        groupdel "$SERVICE_GROUP" 2>/dev/null || true
    fi
    
    print_status $GREEN "Uninstallation completed successfully!"
    exit 0
}

# Uninstall if requested
if [[ "$UNINSTALL" == true ]]; then
    uninstall_service
fi

# Function to check prerequisites
check_prerequisites() {
    print_status $BLUE "Checking prerequisites..."
    
    # Check if Rust is installed
    if ! command -v cargo >/dev/null 2>&1; then
        print_status $RED "Rust/Cargo is not installed. Please install Rust first:"
        echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        exit 1
    fi
    
    # Check if systemd is available
    if ! command -v systemctl >/dev/null 2>&1; then
        print_status $RED "systemd is not available on this system"
        exit 1
    fi
    
    # Check if we're in the project directory
    if [[ ! -f "Cargo.toml" ]] || [[ ! -f "src/main.rs" ]]; then
        print_status $RED "This script must be run from the MLS Delivery Service project directory"
        exit 1
    fi
    
    print_status $GREEN "Prerequisites check passed"
}

# Function to create service user and group
create_service_user() {
    print_status $BLUE "Creating service user and group..."
    
    # Create group if it doesn't exist
    if ! getent group "$SERVICE_GROUP" >/dev/null 2>&1; then
        groupadd "$SERVICE_GROUP"
        print_status $GREEN "Created group: $SERVICE_GROUP"
    else
        print_status $YELLOW "Group already exists: $SERVICE_GROUP"
    fi
    
    # Create user if it doesn't exist
    if ! id "$SERVICE_USER" &>/dev/null; then
        useradd -r -g "$SERVICE_GROUP" -s /bin/false -d "$INSTALL_PREFIX" "$SERVICE_USER"
        print_status $GREEN "Created user: $SERVICE_USER"
    else
        print_status $YELLOW "User already exists: $SERVICE_USER"
    fi
}

# Function to create installation directory
create_install_directory() {
    print_status $BLUE "Creating installation directory..."
    
    if [[ -d "$INSTALL_PREFIX" ]] && [[ "$FORCE" != true ]]; then
        print_status $YELLOW "Installation directory already exists: $INSTALL_PREFIX"
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status $RED "Installation cancelled"
            exit 1
        fi
    fi
    
    mkdir -p "$INSTALL_PREFIX"/{logs,data,scripts}
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_PREFIX"
    chmod 755 "$INSTALL_PREFIX"
    chmod 750 "$INSTALL_PREFIX"/{logs,data}
    
    print_status $GREEN "Created installation directory: $INSTALL_PREFIX"
}

# Function to build the service
build_service() {
    print_status $BLUE "Building MLS Delivery Service..."
    
    # Build in release mode
    if cargo build --release; then
        print_status $GREEN "Build completed successfully"
    else
        print_status $RED "Build failed"
        exit 1
    fi
}

# Function to install files
install_files() {
    print_status $BLUE "Installing service files..."
    
    # Copy binary
    cp target/release/mls-delivery-service "$INSTALL_PREFIX/"
    chown "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_PREFIX/mls-delivery-service"
    chmod 755 "$INSTALL_PREFIX/mls-delivery-service"
    
    # Copy scripts
    cp launch_service.sh "$INSTALL_PREFIX/scripts/"
    cp demo.sh "$INSTALL_PREFIX/scripts/"
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_PREFIX/scripts/"
    chmod 755 "$INSTALL_PREFIX/scripts/"*.sh
    
    # Copy test clients
    cp test_tcp_client.py "$INSTALL_PREFIX/scripts/"
    cp -r tests "$INSTALL_PREFIX/scripts/"
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_PREFIX/scripts/"
    chmod 644 "$INSTALL_PREFIX/scripts/"*.py
    
    # Copy documentation
    cp README.md "$INSTALL_PREFIX/"
    chown "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_PREFIX/README.md"
    chmod 644 "$INSTALL_PREFIX/README.md"
    
    print_status $GREEN "Files installed successfully"
}

# Function to install systemd service
install_systemd_service() {
    print_status $BLUE "Installing systemd service..."
    
    # Update service file with custom settings
    sed -e "s|User=mls-delivery|User=$SERVICE_USER|g" \
        -e "s|Group=mls-delivery|Group=$SERVICE_GROUP|g" \
        -e "s|WorkingDirectory=/opt/mls-delivery-service|WorkingDirectory=$INSTALL_PREFIX|g" \
        -e "s|ExecStart=/opt/mls-delivery-service/target/release/mls-delivery-service|ExecStart=$INSTALL_PREFIX/mls-delivery-service|g" \
        -e "s|ReadWritePaths=/opt/mls-delivery-service/logs /opt/mls-delivery-service/data|ReadWritePaths=$INSTALL_PREFIX/logs $INSTALL_PREFIX/data|g" \
        -e "s|Environment=SERVICE_HOST=127.0.0.1|Environment=SERVICE_HOST=$SERVICE_HOST|g" \
        -e "s|Environment=SERVICE_PORT=8080|Environment=SERVICE_PORT=$SERVICE_PORT|g" \
        mls-delivery-service.service > /tmp/mls-delivery-service.service
    
    # Install service file
    cp /tmp/mls-delivery-service.service /etc/systemd/system/
    chmod 644 /etc/systemd/system/mls-delivery-service.service
    
    # Reload systemd
    systemctl daemon-reload
    
    print_status $GREEN "Systemd service installed successfully"
}

# Function to setup log rotation
setup_log_rotation() {
    print_status $BLUE "Setting up log rotation..."
    
    cat > /etc/logrotate.d/mls-delivery-service << EOF
$INSTALL_PREFIX/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $SERVICE_USER $SERVICE_GROUP
    postrotate
        systemctl reload mls-delivery-service > /dev/null 2>&1 || true
    endscript
}
EOF
    
    chmod 644 /etc/logrotate.d/mls-delivery-service
    print_status $GREEN "Log rotation configured"
}

# Function to enable and start service
enable_service() {
    print_status $BLUE "Enabling and starting service..."
    
    # Enable the service
    systemctl enable mls-delivery-service
    
    # Start the service
    if systemctl start mls-delivery-service; then
        print_status $GREEN "Service started successfully"
    else
        print_status $RED "Failed to start service"
        systemctl status mls-delivery-service
        exit 1
    fi
    
    # Wait a moment and check status
    sleep 2
    if systemctl is-active --quiet mls-delivery-service; then
        print_status $GREEN "Service is running"
    else
        print_status $RED "Service failed to start properly"
        systemctl status mls-delivery-service
        exit 1
    fi
}

# Function to display installation summary
show_summary() {
    print_status $GREEN "Installation completed successfully!"
    echo ""
    echo "📋 Installation Summary"
    echo "======================"
    echo "Service User:     $SERVICE_USER"
    echo "Service Group:    $SERVICE_GROUP"
    echo "Install Path:     $INSTALL_PREFIX"
    echo "Service Host:     $SERVICE_HOST"
    echo "Service Port:     $SERVICE_PORT"
    echo ""
    echo "🚀 Service Management"
    echo "===================="
    echo "Start:            systemctl start mls-delivery-service"
    echo "Stop:             systemctl stop mls-delivery-service"
    echo "Restart:          systemctl restart mls-delivery-service"
    echo "Status:           systemctl status mls-delivery-service"
    echo "Logs:             journalctl -u mls-delivery-service -f"
    echo ""
    echo "🔧 Manual Testing"
    echo "================"
    echo "Test Client:      $INSTALL_PREFIX/scripts/test_tcp_client.py"
    echo "Demo Script:      $INSTALL_PREFIX/scripts/demo.sh"
    echo ""
    echo "📚 Documentation"
    echo "==============="
    echo "README:           $INSTALL_PREFIX/README.md"
    echo "GitHub:           https://github.com/krich11/mls-delivery-service"
    echo ""
    echo "🔍 Quick Test"
    echo "============"
    echo "Test connection:  echo '{\"type\": \"ListKeyPackages\"}' | nc $SERVICE_HOST $SERVICE_PORT"
}

# Main installation process
main() {
    print_status $BLUE "Starting MLS Delivery Service installation..."
    echo ""
    
    check_prerequisites
    create_service_user
    create_install_directory
    build_service
    install_files
    install_systemd_service
    setup_log_rotation
    enable_service
    show_summary
}

# Run main function
main 