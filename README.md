# mls-delivery-service
MLS Delivery Service for message relaying

## Overview

A minimal Rust-based Delivery Service that supports Messaging Layer Security (MLS) messaging applications. This service provides a relay infrastructure for MLS key packages and encrypted messages between clients, supporting group messaging with extensible architecture.

## Features

- **MLS Protocol Support**: Uses OpenMLS (v0.5) with openmls_rust_crypto (v0.1) for cryptographic operations
- **Group Messaging**: Supports at least two users with extensible architecture for larger groups
- **Asynchronous Networking**: Built with tokio (v1.0) for high-performance TCP networking
- **Key Package Management**: Store and retrieve MLS KeyPackages for client discovery
- **Message Relaying**: Relay encrypted MLS messages (Welcome, Add, Application, Commit, Proposal)
- **Cryptographic Agility**: Configured to support future integration of various Key Encapsulation Mechanisms (KEMs)
- **In-Memory Storage**: Uses HashMap for storing KeyPackages and group state (suitable for development/testing)

## Architecture

### Core Components

1. **DeliveryService**: Main service struct managing KeyPackages and group states
2. **GroupState**: Tracks group membership and message history
3. **DeliveryMessage**: JSON-serializable message protocol for client-server communication
4. **MlsMessageType**: Enumeration of supported MLS message types

### Message Types

- **KeyPackage Operations**: Store, fetch, and list KeyPackages
- **Group Operations**: Create groups, join groups
- **Message Relaying**: Relay various MLS message types between group members

## Usage

### Starting the Service

```bash
# Clone the repository
git clone https://github.com/krich11/mls-delivery-service.git
cd mls-delivery-service

# Build and run the service
cargo run
```

The service will start on `127.0.0.1:8080` by default.

### Environment Variables

- `RUST_LOG`: Set logging level (e.g., `RUST_LOG=info cargo run`)

### Client Communication

The service expects JSON messages over TCP connections. Here are the supported message types:

#### Store KeyPackage
```json
{
  "type": "StoreKeyPackage",
  "client_id": "client1",
  "key_package": [/* binary data as byte array */]
}
```

#### Fetch KeyPackage
```json
{
  "type": "FetchKeyPackage",
  "client_id": "client1"
}
```

#### Create Group
```json
{
  "type": "CreateGroup",
  "group_id": "group1",
  "creator_id": "client1"
}
```

#### Join Group
```json
{
  "type": "JoinGroup",
  "group_id": "group1",
  "client_id": "client2"
}
```

#### Relay Message
```json
{
  "type": "RelayMessage",
  "group_id": "group1",
  "sender_id": "client1",
  "message": [/* encrypted MLS message as byte array */],
  "message_type": "Application"
}
```

### Testing with netcat

You can test the service using netcat:

```bash
# Start the service
cargo run

# In another terminal, connect and send a test message
echo '{"type":"ListKeyPackages"}' | nc 127.0.0.1 8080
```

## Development

### Building

```bash
# Debug build
cargo build

# Release build
cargo build --release

# Run tests
cargo test

# Check code
cargo check
```

### Project Structure

```
src/
├── main.rs          # Main server implementation
Cargo.toml           # Dependencies and project configuration
README.md           # This file
.gitignore          # Git ignore rules
```

## Troubleshooting

### Common Issues

#### 1. Port Already in Use
**Error**: `Address already in use (os error 98)`

**Solution**: 
- Check if another process is using port 8080: `lsof -i :8080`
- Kill the process or change the port in the code
- Wait a few seconds for the port to be released

#### 2. Connection Refused
**Error**: `Connection refused when trying to connect`

**Solution**:
- Ensure the service is running: `cargo run`
- Check that it's listening on the correct address: `netstat -tlnp | grep 8080`
- Verify firewall settings allow connections to port 8080

#### 3. Dependency Issues
**Error**: `error: failed to resolve dependencies`

**Solution**:
- Update Rust: `rustup update`
- Clean and rebuild: `cargo clean && cargo build`
- Check internet connectivity for dependency downloads

#### 4. OpenMLS Compatibility Issues
**Error**: `OpenMLS version conflicts or API changes`

**Solution**:
- Ensure you're using the correct OpenMLS version (0.5)
- Check the OpenMLS documentation for breaking changes
- Verify openmls_rust_crypto version compatibility (0.1)

#### 5. Large Message Handling
**Error**: `Message too large or connection drops`

**Solution**:
- The current buffer size is 8192 bytes
- For larger messages, implement message fragmentation
- Consider using a streaming JSON parser for large payloads

#### 6. Memory Usage
**Issue**: High memory usage with many groups/clients

**Solution**:
- The current implementation uses in-memory storage
- For production, consider implementing persistent storage
- Monitor memory usage and implement cleanup for old groups

### Debugging

#### Enable Detailed Logging
```bash
RUST_LOG=debug cargo run
```

#### Log Levels
- `error`: Only errors
- `warn`: Warnings and errors
- `info`: General information (default)
- `debug`: Detailed debugging information
- `trace`: Very detailed tracing

#### Common Log Messages
- `"MLS Delivery Service running on 127.0.0.1:8080"`: Service started successfully
- `"New client connected from: {}"`: Client connection established
- `"Client disconnected"`: Client connection closed
- `"Stored KeyPackage for client: {}"`: KeyPackage successfully stored
- `"Created group: {} by {}"`: Group created successfully
- `"Relayed message from {} to group {}"`: Message successfully relayed

### Performance Considerations

1. **Concurrent Connections**: The service uses tokio for async handling of multiple clients
2. **Memory Usage**: In-memory storage scales with number of clients and groups
3. **Message Size**: Current buffer size limits message size to 8KB
4. **Group Size**: No artificial limits on group size, but memory usage increases linearly

### Security Considerations

1. **No Authentication**: The current implementation doesn't authenticate clients
2. **No TLS**: Communications are not encrypted at the transport layer
3. **No Rate Limiting**: No protection against DoS attacks
4. **In-Memory Storage**: Data is lost when service restarts

### Future Enhancements

1. **Persistent Storage**: Replace HashMap with database storage
2. **Authentication**: Add client authentication mechanisms
3. **TLS Support**: Encrypt transport layer communications
4. **Rate Limiting**: Implement connection and message rate limiting
5. **Message Persistence**: Store messages for offline clients
6. **Load Balancing**: Support for multiple server instances

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Search existing issues on GitHub
3. Create a new issue with detailed information about your problem
