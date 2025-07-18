#!/bin/bash

# MLS Delivery Service Launch Script
# Handles service startup, monitoring, and graceful shutdown

set -e  # Exit on any error

# Configuration
SERVICE_NAME="mls-delivery-service"
SERVICE_PORT="8080"
SERVICE_HOST="127.0.0.1"
LOG_FILE="service.log"
PID_FILE="service.pid"
RUST_LOG_LEVEL="${RUST_LOG_LEVEL:-info}"
MAX_RESTARTS=5
RESTART_DELAY=5

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] ${message}${NC}"
}

# Function to check if service is running
is_service_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            rm -f "$PID_FILE"
        fi
    fi
    return 1
}

# Function to check if port is in use
is_port_in_use() {
    if netstat -tuln 2>/dev/null | grep -q ":$SERVICE_PORT "; then
        return 0
    elif ss -tuln 2>/dev/null | grep -q ":$SERVICE_PORT "; then
        return 0
    else
        return 1
    fi
}

# Function to wait for service to be ready
wait_for_service() {
    local max_attempts=30
    local attempt=1
    
    print_status $BLUE "Waiting for service to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        # Try TCP connection test
        if echo '{"type": "ListKeyPackages"}' | nc -w 2 "$SERVICE_HOST" "$SERVICE_PORT" >/dev/null 2>&1; then
            print_status $GREEN "Service is ready and responding!"
            return 0
        fi
        
        print_status $YELLOW "Attempt $attempt/$max_attempts: Service not ready yet..."
        sleep 2
        ((attempt++))
    done
    
    print_status $RED "Service failed to start within expected time"
    return 1
}

# Function to start the service
start_service() {
    print_status $BLUE "Starting MLS Delivery Service..."
    
    # Check if service is already running
    if is_service_running; then
        print_status $YELLOW "Service is already running (PID: $(cat $PID_FILE))"
        return 0
    fi
    
    # Check if port is in use
    if is_port_in_use; then
        print_status $RED "Port $SERVICE_PORT is already in use"
        return 1
    fi
    
    # Set up environment
    export RUST_LOG="$RUST_LOG_LEVEL"
    export RUST_BACKTRACE=1
    
    # Source cargo environment if available
    if [ -f "/usr/local/cargo/env" ]; then
        source /usr/local/cargo/env
    elif [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi
    
    # Start the service in background
    print_status $BLUE "Building and starting service..."
    
    # Run cargo build first to ensure everything compiles
    if ! cargo build --release; then
        print_status $RED "Build failed"
        return 1
    fi
    
    # Start the service
    nohup cargo run --release > "$LOG_FILE" 2>&1 &
    local service_pid=$!
    
    # Save PID
    echo $service_pid > "$PID_FILE"
    
    print_status $GREEN "Service started with PID: $service_pid"
    
    # Wait for service to be ready
    if wait_for_service; then
        print_status $GREEN "MLS Delivery Service is running on http://$SERVICE_HOST:$SERVICE_PORT"
        return 0
    else
        print_status $RED "Service failed to start properly"
        stop_service
        return 1
    fi
}

# Function to stop the service
stop_service() {
    print_status $BLUE "Stopping MLS Delivery Service..."
    
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        
        if kill -0 "$pid" 2>/dev/null; then
            print_status $YELLOW "Sending SIGTERM to PID $pid..."
            kill -TERM "$pid"
            
            # Wait for graceful shutdown
            local timeout=10
            while [ $timeout -gt 0 ] && kill -0 "$pid" 2>/dev/null; do
                sleep 1
                ((timeout--))
            done
            
            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                print_status $YELLOW "Force killing PID $pid..."
                kill -KILL "$pid"
            fi
            
            print_status $GREEN "Service stopped"
        else
            print_status $YELLOW "Service was not running"
        fi
        
        rm -f "$PID_FILE"
    else
        print_status $YELLOW "No PID file found"
    fi
}

# Function to restart the service
restart_service() {
    print_status $BLUE "Restarting MLS Delivery Service..."
    stop_service
    sleep 2
    start_service
}

# Function to show service status
show_status() {
    print_status $BLUE "MLS Delivery Service Status"
    echo "================================"
    
    if is_service_running; then
        local pid=$(cat "$PID_FILE")
        print_status $GREEN "Service is running (PID: $pid)"
        
        if is_port_in_use; then
            print_status $GREEN "Port $SERVICE_PORT is active"
        else
            print_status $RED "Port $SERVICE_PORT is not responding"
        fi
        
        # Show recent logs
        if [ -f "$LOG_FILE" ]; then
            echo ""
            print_status $BLUE "Recent logs (last 10 lines):"
            tail -n 10 "$LOG_FILE" 2>/dev/null || echo "No log file found"
        fi
    else
        print_status $RED "Service is not running"
    fi
}

# Function to monitor the service
monitor_service() {
    print_status $BLUE "Starting service monitoring..."
    
    local restart_count=0
    
    while true; do
        if ! is_service_running; then
            print_status $YELLOW "Service is not running, attempting restart..."
            
            if [ $restart_count -lt $MAX_RESTARTS ]; then
                if start_service; then
                    print_status $GREEN "Service restarted successfully"
                    restart_count=0
                else
                    ((restart_count++))
                    print_status $RED "Restart failed ($restart_count/$MAX_RESTARTS)"
                    
                    if [ $restart_count -ge $MAX_RESTARTS ]; then
                        print_status $RED "Maximum restart attempts reached. Stopping monitor."
                        break
                    fi
                    
                    sleep $RESTART_DELAY
                fi
            else
                print_status $RED "Maximum restart attempts reached. Stopping monitor."
                break
            fi
        else
            # Service is running, check if it's responding
            if ! echo '{"type": "ListKeyPackages"}' | nc -w 2 "$SERVICE_HOST" "$SERVICE_PORT" >/dev/null 2>&1; then
                print_status $YELLOW "Service is not responding, restarting..."
                stop_service
                sleep 2
            else
                # Reset restart count if service is healthy
                restart_count=0
            fi
        fi
        
        sleep 30  # Check every 30 seconds
    done
}

# Function to show usage
show_usage() {
    echo "MLS Delivery Service Launch Script"
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     Start the service"
    echo "  stop      Stop the service"
    echo "  restart   Restart the service"
    echo "  status    Show service status"
    echo "  monitor   Start monitoring (auto-restart on failure)"
    echo "  logs      Show recent logs"
    echo "  test      Run the test suite"
    echo "  help      Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  RUST_LOG_LEVEL  Log level (default: info)"
    echo "  SERVICE_PORT    Port to run on (default: 8080)"
    echo "  SERVICE_HOST    Host to bind to (default: 127.0.0.1)"
}

# Function to show logs
show_logs() {
    if [ -f "$LOG_FILE" ]; then
        print_status $BLUE "Service logs:"
        tail -f "$LOG_FILE"
    else
        print_status $RED "No log file found"
    fi
}

# Function to run tests
run_tests() {
    print_status $BLUE "Running test suite..."
    
    # Check if service is running
    if ! is_service_running; then
        print_status $YELLOW "Starting service for testing..."
        start_service
        sleep 3
    fi
    
    # Try TCP tests first (matches the service protocol)
    if [ -f "test_tcp_client.py" ]; then
        print_status $BLUE "Running TCP test client..."
        if python3 test_tcp_client.py; then
            print_status $GREEN "TCP tests passed!"
            return 0
        else
            print_status $YELLOW "TCP tests failed, trying HTTP tests..."
        fi
    fi
    
    # Fall back to HTTP tests if available
    if [ -f "test_service.py" ]; then
        print_status $BLUE "Running HTTP test client..."
        if python3 test_service.py; then
            print_status $GREEN "HTTP tests passed!"
            return 0
        else
            print_status $YELLOW "HTTP tests failed, trying Rust tests..."
        fi
    fi
    
    # Fall back to Rust tests if available
    if [ -f "tests/test_client.rs" ] && cargo build --bin test_client 2>/dev/null; then
        print_status $BLUE "Running Rust test client..."
        if cargo run --bin test_client; then
            print_status $GREEN "Rust tests passed!"
            return 0
        else
            print_status $RED "Rust tests failed"
            return 1
        fi
    fi
    
    print_status $RED "No test scripts found"
    return 1
}

# Main script logic
case "${1:-help}" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        restart_service
        ;;
    status)
        show_status
        ;;
    monitor)
        monitor_service
        ;;
    logs)
        show_logs
        ;;
    test)
        run_tests
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        print_status $RED "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac 