# MLS Delivery Service

A minimal Rust-based Delivery Service for Linux to support Messaging Layer Security (MLS) messaging apps, using OpenMLS (version 0.5) and openmls_rust_crypto (version 0.1).

## Features

- **MLS Support**: Full integration with OpenMLS v0.5 and openmls_rust_crypto v0.1
- **KeyPackage Management**: Store and retrieve MLS KeyPackages for clients
- **Group Messaging**: Support for group creation and management
- **Message Broadcasting**: Relay encrypted MLS messages between clients
- **Cryptographic Agility**: Configurable for future KEM integration
- **Asynchronous Networking**: Built with tokio for high-performance async operations
- **Comprehensive Testing**: Multiple test clients and automated testing scripts

## Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/krich11/mls-delivery-service.git
   cd mls-delivery-service
   ```

2. **Install Rust (if not already installed):**
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source ~/.cargo/env
   ```

3. **Use the launch script (recommended):**
   ```bash
   # Make scripts executable
   chmod +x *.sh
   
   # Start the service
   ./launch_service.sh start
   
   # Run the demo
   ./demo.sh
   ```

4. **Or build and run manually:**
   ```bash
   cargo run
   ```

5. **Test the service:**
   ```bash
   # Run comprehensive tests
   ./launch_service.sh test
   
   # Or test manually
   curl http://127.0.0.1:8080/health
   ```

## Scripts and Tools

### Launch Script (`launch_service.sh`)

The launch script provides comprehensive service management capabilities:

```bash
# Start the service
./launch_service.sh start

# Stop the service
./launch_service.sh stop

# Restart the service
./launch_service.sh restart

# Check service status
./launch_service.sh status

# Monitor service (auto-restart on failure)
./launch_service.sh monitor

# View service logs
./launch_service.sh logs

# Run test suite
./launch_service.sh test

# Show help
./launch_service.sh help
```

**Environment Variables:**
- `RUST_LOG_LEVEL`: Log level (default: info)
- `SERVICE_PORT`: Port to run on (default: 8080)
- `SERVICE_HOST`: Host to bind to (default: 127.0.0.1)

### Demo Script (`demo.sh`)

The demo script provides a complete walkthrough of the service:

```bash
./demo.sh
```

This script will:
1. Check service status
2. Start the service
3. Run comprehensive tests
4. Demonstrate manual API testing
5. Show available commands

### Test Scripts

#### Python Test Client (`test_service.py`)

Comprehensive Python-based test suite with concurrent testing:

```bash
python3 test_service.py
python3 test_service.py http://custom-host:8080  # Test custom endpoint
```

**Features:**
- Server health checks
- KeyPackage operations testing
- Group operations testing
- Message broadcasting testing
- Error handling validation
- Concurrent operations testing

#### Rust Test Client (`tests/test_client.rs`)

Native Rust test client with TCP messaging:

```bash
cargo run --bin test_client
```

**Features:**
- TCP JSON messaging protocol
- Comprehensive endpoint validation
- Error handling verification
- Health checks, KeyPackage operations, group management, message broadcasting
- **Status**: ✅ Fully Operational

## API Reference

### Health Check
```http
GET /health
```
Returns service health status.

### KeyPackage Management

#### Store KeyPackage
```http
POST /keypackages
Content-Type: application/json

{
  "key_package": "base64_encoded_key_package_data",
  "user_id": "user123",
  "timestamp": 1234567890
}
```

#### Retrieve KeyPackage
```http
GET /keypackages/{user_id}
```

### Group Management

#### Create Group
```http
POST /groups
Content-Type: application/json

{
  "group_id": "group123",
  "members": ["user1", "user2"],
  "creator": "user1"
}
```

#### Get Group Info
```http
GET /groups/{group_id}
```

### Message Broadcasting

#### Broadcast Message
```http
POST /messages
Content-Type: application/json

{
  "group_id": "group123",
  "sender_id": "user1",
  "message_type": "Application",
  "encrypted_message": "base64_encoded_mls_message",
  "timestamp": 1234567890
}
```

## Troubleshooting

### Common Issues

#### Service Won't Start
1. **Port already in use:**
   ```bash
   # Check what's using port 8080
   sudo netstat -tulpn | grep :8080
   # Or use ss
   sudo ss -tulpn | grep :8080
   ```

2. **Rust not installed:**
   ```bash
   # Install Rust
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source ~/.cargo/env
   ```

3. **Dependencies not found:**
   ```bash
   # Clean and rebuild
   cargo clean
   cargo build
   ```

#### Tests Fail
1. **Service not running:**
   ```bash
   ./launch_service.sh status
   ./launch_service.sh start
   ```

2. **Python dependencies missing:**
   ```bash
   pip3 install requests
   ```

3. **Network connectivity issues:**
   ```bash
   # Test connectivity
   curl -v http://127.0.0.1:8080/health
   ```

#### Performance Issues
1. **High memory usage:**
   - Check for memory leaks in logs
   - Restart service periodically
   - Monitor with `./launch_service.sh status`

2. **Slow response times:**
   - Check system resources
   - Verify network connectivity
   - Review service logs

### Log Analysis

#### Enable Debug Logging
```bash
RUST_LOG=debug ./launch_service.sh start
```

#### View Real-time Logs
```bash
./launch_service.sh logs
```

#### Common Log Messages
- `INFO` - Normal operation
- `WARN` - Non-critical issues
- `ERROR` - Service errors requiring attention
- `DEBUG` - Detailed debugging information

### Monitoring

#### Service Health Monitoring
```bash
# Start monitoring mode
./launch_service.sh monitor

# Check status periodically
watch -n 5 './launch_service.sh status'
```

#### Performance Monitoring
```bash
# Monitor system resources
htop

# Monitor network connections
netstat -tulpn | grep :8080
```

## Development

### Building from Source
```bash
# Debug build
cargo build

# Release build
cargo build --release

# Run tests
cargo test
```

### Adding New Features
1. Update `src/main.rs` with new endpoints
2. Add corresponding tests in `test_service.py` and `src/test_client.rs`
3. Update documentation
4. Test thoroughly with `./launch_service.sh test`

### Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
