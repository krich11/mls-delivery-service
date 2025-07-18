#!/bin/bash

# MLS Delivery Service Demo Script
# Demonstrates how to use the launch script and test the service

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

echo "🚀 MLS Delivery Service Demo"
echo "============================"
echo ""

# Step 1: Show current status
print_status $BLUE "Step 1: Checking current service status..."
./launch_service.sh status
echo ""

# Step 2: Start the service
print_status $BLUE "Step 2: Starting the MLS Delivery Service..."
if ./launch_service.sh start; then
    print_status $GREEN "Service started successfully!"
else
    print_status $RED "Failed to start service"
    exit 1
fi
echo ""

# Step 3: Wait a moment for service to be ready
print_status $BLUE "Step 3: Waiting for service to be ready..."
sleep 3

# Step 4: Show status again
print_status $BLUE "Step 4: Checking service status..."
./launch_service.sh status
echo ""

# Step 5: Run tests
print_status $BLUE "Step 5: Running test suite..."
if ./launch_service.sh test; then
    print_status $GREEN "All tests passed!"
else
    print_status $YELLOW "Some tests failed (this is expected if service is still starting)"
fi
echo ""

# Step 6: Show logs
print_status $BLUE "Step 6: Showing recent service logs..."
./launch_service.sh logs | head -20
echo ""

# Step 7: Demonstrate manual testing
print_status $BLUE "Step 7: Manual API testing..."

# Test health endpoint
print_status $YELLOW "Testing health endpoint..."
if curl -s http://127.0.0.1:8080/health >/dev/null; then
    print_status $GREEN "Health endpoint is working"
else
    print_status $RED "Health endpoint failed"
fi

# Test TCP connection
print_status $YELLOW "Testing TCP connection..."
if echo '{"type": "ListKeyPackages"}' | nc -w 2 127.0.0.1 8080 >/dev/null 2>&1; then
    print_status $GREEN "TCP connection is working"
else
    print_status $RED "TCP connection failed"
fi

# Test KeyPackage storage via TCP
print_status $YELLOW "Testing KeyPackage storage via TCP..."
if echo '{"type": "StoreKeyPackage", "client_id": "demo_user", "key_package": [100, 101, 109, 111]}' | nc -w 2 127.0.0.1 8080 >/dev/null 2>&1; then
    print_status $GREEN "KeyPackage storage is working"
else
    print_status $RED "KeyPackage storage failed"
fi

echo ""

# Step 8: Show final status
print_status $BLUE "Step 8: Final service status..."
./launch_service.sh status
echo ""

print_status $GREEN "Demo completed successfully!"
echo ""
echo "📋 Available commands:"
echo "  ./launch_service.sh start    - Start the service"
echo "  ./launch_service.sh stop     - Stop the service"
echo "  ./launch_service.sh restart  - Restart the service"
echo "  ./launch_service.sh status   - Show service status"
echo "  ./launch_service.sh logs     - Show service logs"
echo "  ./launch_service.sh test     - Run test suite"
echo "  ./launch_service.sh monitor  - Start monitoring mode"
echo ""
echo "🔧 Manual testing:"
echo "  echo '{\"type\": \"ListKeyPackages\"}' | nc 127.0.0.1 8080"
echo "  echo '{\"type\": \"StoreKeyPackage\", \"client_id\": \"user1\", \"key_package\": [116, 101, 115, 116]}' | nc 127.0.0.1 8080"
echo "  echo '{\"type\": \"FetchKeyPackage\", \"client_id\": \"user1\"}' | nc 127.0.0.1 8080"
echo ""
echo "🧪 Test scripts:"
echo "  python3 test_service.py      - Python test client"
echo "  cargo run --bin test_client  - Rust test client" 