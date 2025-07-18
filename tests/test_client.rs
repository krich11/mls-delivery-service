use std::collections::HashMap;
use std::env;
use serde_json::{json, Value};
use tokio::time::{sleep, Duration};
use tokio::net::TcpStream;
use tokio::io::{AsyncReadExt, AsyncWriteExt};

/// Simple test client for MLS Delivery Service
pub struct TestClient {
    base_url: String,
}

impl TestClient {
    pub fn new(base_url: String) -> Self {
        Self { base_url }
    }

    /// Send a TCP message to the service
    async fn send_tcp_message(&self, message: &Value) -> Result<String, Box<dyn std::error::Error>> {
        let addr = self.base_url.replace("http://", "").replace("https://", "");
        let stream = TcpStream::connect(&addr).await?;
        
        let mut stream = stream;
        let message_str = serde_json::to_string(message)? + "\n";
        stream.write_all(message_str.as_bytes()).await?;
        
        let mut buffer = [0; 1024];
        let n = stream.read(&mut buffer).await?;
        let response = String::from_utf8_lossy(&buffer[..n]).to_string();
        
        Ok(response)
    }

    /// Test server health endpoint
    pub async fn test_health(&self) -> bool {
        println!("🔍 Testing server health...");
        
        let message = json!({"type": "ListKeyPackages"});
        match self.send_tcp_message(&message).await {
            Ok(response) => {
                if let Ok(data) = serde_json::from_str::<Value>(&response) {
                    if data.get("type") == Some(&Value::String("KeyPackageListResponse".to_string())) {
                        println!("✅ Health check passed");
                        return true;
                    }
                }
                println!("❌ Health check failed: unexpected response");
                false
            }
            Err(e) => {
                println!("❌ Health check failed: {}", e);
                false
            }
        }
    }

    /// Test KeyPackage storage and retrieval
    pub async fn test_key_packages(&self) -> bool {
        println!("🔍 Testing KeyPackage operations...");
        
        let user_id = "rust_test_user_001";

        // Test data
        let key_package_data = json!({
            "type": "StoreKeyPackage",
            "client_id": user_id,
            "key_package": [98, 97, 115, 101, 54, 52, 95, 101, 110, 99, 111, 100, 101, 100, 95, 107, 101, 121, 95, 112, 97, 99, 107, 97, 103, 101, 95, 100, 97, 116, 97, 95, 104, 101, 114, 101]
        });

        // Store KeyPackage
        match self.send_tcp_message(&key_package_data).await {
            Ok(response) => {
                if let Ok(data) = serde_json::from_str::<Value>(&response) {
                    if data.get("type") == Some(&Value::String("MessageResponse".to_string())) && 
                       data.get("success") == Some(&Value::Bool(true)) {
                        println!("✅ KeyPackage stored successfully");
                    } else {
                        println!("❌ Failed to store KeyPackage: {}", response);
                        return false;
                    }
                } else {
                    println!("❌ Failed to parse store response: {}", response);
                    return false;
                }
            }
            Err(e) => {
                println!("❌ Failed to store KeyPackage: {}", e);
                return false;
            }
        }

        // Retrieve KeyPackage
        let fetch_data = json!({
            "type": "FetchKeyPackage",
            "client_id": user_id
        });

        match self.send_tcp_message(&fetch_data).await {
            Ok(response) => {
                if let Ok(data) = serde_json::from_str::<Value>(&response) {
                    if data.get("type") == Some(&Value::String("KeyPackageResponse".to_string())) && 
                       data.get("key_package").is_some() {
                        println!("✅ KeyPackage retrieved successfully");
                        true
                    } else {
                        println!("❌ KeyPackage data mismatch: {}", response);
                        false
                    }
                } else {
                    println!("❌ Failed to parse KeyPackage response: {}", response);
                    false
                }
            }
            Err(e) => {
                println!("❌ Failed to retrieve KeyPackage: {}", e);
                false
            }
        }
    }

    /// Test group operations
    pub async fn test_groups(&self) -> bool {
        println!("🔍 Testing group operations...");
        
        let group_id = "rust_test_group_001";

        // Test data
        let group_data = json!({
            "type": "CreateGroup",
            "group_id": group_id,
            "creator_id": "user1"
        });

        // Create group
        match self.send_tcp_message(&group_data).await {
            Ok(response) => {
                if let Ok(data) = serde_json::from_str::<Value>(&response) {
                    if data.get("type") == Some(&Value::String("GroupResponse".to_string())) && 
                       data.get("members").is_some() {
                        println!("✅ Group created successfully");
                    } else {
                        println!("❌ Failed to create group: {}", response);
                        return false;
                    }
                } else {
                    println!("❌ Failed to parse group response: {}", response);
                    return false;
                }
            }
            Err(e) => {
                println!("❌ Failed to create group: {}", e);
                return false;
            }
        }

        // Note: The service doesn't have a direct "get group" endpoint
        // We'll consider group creation success as the test passing
        true
    }

    /// Test message broadcasting
    pub async fn test_messages(&self) -> bool {
        println!("🔍 Testing message broadcasting...");

        // Test data
        let message_data = json!({
            "type": "RelayMessage",
            "group_id": "rust_test_group_001",
            "sender_id": "user1",
            "message": [109, 101, 115, 115, 97, 103, 101, 95, 100, 97, 116, 97],
            "message_type": "Application"
        });

        match self.send_tcp_message(&message_data).await {
            Ok(response) => {
                if let Ok(data) = serde_json::from_str::<Value>(&response) {
                    if data.get("type") == Some(&Value::String("MessageResponse".to_string())) && 
                       data.get("success") == Some(&Value::Bool(true)) {
                        println!("✅ Message broadcasted successfully");
                        true
                    } else {
                        println!("❌ Failed to broadcast message: {}", response);
                        false
                    }
                } else {
                    println!("❌ Failed to parse message response: {}", response);
                    false
                }
            }
            Err(e) => {
                println!("❌ Failed to broadcast message: {}", e);
                false
            }
        }
    }

    /// Test error handling
    pub async fn test_error_handling(&self) -> bool {
        println!("🔍 Testing error handling...");

        // Test invalid message format
        let invalid_message = json!({
            "type": "InvalidMessageType"
        });

        match self.send_tcp_message(&invalid_message).await {
            Ok(response) => {
                if let Ok(data) = serde_json::from_str::<Value>(&response) {
                    if data.get("type") == Some(&Value::String("Error".to_string())) {
                        println!("✅ Correctly returned error for invalid message type");
                    } else {
                        println!("❌ Expected error, got: {}", response);
                        return false;
                    }
                } else {
                    println!("❌ Failed to parse error response: {}", response);
                    return false;
                }
            }
            Err(e) => {
                println!("❌ Error handling test failed: {}", e);
                return false;
            }
        }

        // Test non-existent KeyPackage
        let fetch_nonexistent = json!({
            "type": "FetchKeyPackage",
            "client_id": "nonexistent_user"
        });

        match self.send_tcp_message(&fetch_nonexistent).await {
            Ok(response) => {
                if let Ok(data) = serde_json::from_str::<Value>(&response) {
                    if data.get("type") == Some(&Value::String("KeyPackageResponse".to_string())) && 
                       data.get("key_package") == Some(&Value::Null) {
                        println!("✅ Correctly returned null for non-existent user");
                        true
                    } else {
                        println!("❌ Expected null key_package, got: {}", response);
                        false
                    }
                } else {
                    println!("❌ Failed to parse response: {}", response);
                    false
                }
            }
            Err(e) => {
                println!("❌ Error handling test failed: {}", e);
                false
            }
        }
    }

    /// Run all tests
    pub async fn run_all_tests(&self) -> HashMap<String, bool> {
        println!("🚀 Starting MLS Delivery Service Tests");
        println!("{}", "=".repeat(50));

        let tests = vec![
            ("Health Check", self.test_health().await),
            ("KeyPackage Operations", self.test_key_packages().await),
            ("Group Operations", self.test_groups().await),
            ("Message Broadcasting", self.test_messages().await),
            ("Error Handling", self.test_error_handling().await),
        ];

        let mut results = HashMap::new();
        let mut passed = 0;
        let total = tests.len();

        for (test_name, result) in tests {
            results.insert(test_name.to_string(), result);
            if result {
                passed += 1;
            }
        }

        println!("\n{}", "=".repeat(50));
        println!("📊 Test Results: {}/{} tests passed", passed, total);

        if passed == total {
            println!("🎉 All tests passed! The MLS Delivery Service is working correctly.");
        } else {
            println!("⚠️  Some tests failed. Please check the service configuration.");
        }

        results
    }
}

fn print_help() {
    println!("MLS Delivery Service Rust Test Client");
    println!("=====================================");
    println!();
    println!("Usage: cargo run --bin test_client [OPTIONS]");
    println!();
    println!("Options:");
    println!("  -h, --help     Show this help message");
    println!("  --host HOST    Service host (default: 127.0.0.1)");
    println!("  --port PORT    Service port (default: 8080)");
    println!("  --url URL      Full service URL (overrides host/port)");
    println!();
    println!("Environment Variables:");
    println!("  SERVICE_URL    Full service URL (default: http://127.0.0.1:8080)");
    println!();
    println!("Examples:");
    println!("  cargo run --bin test_client");
    println!("  cargo run --bin test_client --host 192.168.1.100 --port 9000");
    println!("  SERVICE_URL=http://custom-host:8080 cargo run --bin test_client");
    println!();
    println!("Test Coverage:");
    println!("  • Health checks and service validation");
    println!("  • KeyPackage storage and retrieval");
    println!("  • Group creation and management");
    println!("  • Message broadcasting and relay");
    println!("  • Error handling and edge cases");
    println!();
    println!("Exit Codes:");
    println!("  0 - All tests passed");
    println!("  1 - Some tests failed");
    println!("  2 - Invalid arguments");
}

#[tokio::main]
async fn main() {
    let args: Vec<String> = env::args().collect();
    
    // Check for help flag
    if args.iter().any(|arg| arg == "-h" || arg == "--help") {
        print_help();
        std::process::exit(0);
    }
    
    // Parse command line arguments
    let mut host = "127.0.0.1".to_string();
    let mut port = "8080".to_string();
    let mut custom_url = None;
    
    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--host" => {
                if i + 1 < args.len() {
                    host = args[i + 1].clone();
                    i += 2;
                } else {
                    eprintln!("Error: --host requires a value");
                    std::process::exit(2);
                }
            }
            "--port" => {
                if i + 1 < args.len() {
                    port = args[i + 1].clone();
                    i += 2;
                } else {
                    eprintln!("Error: --port requires a value");
                    std::process::exit(2);
                }
            }
            "--url" => {
                if i + 1 < args.len() {
                    custom_url = Some(args[i + 1].clone());
                    i += 2;
                } else {
                    eprintln!("Error: --url requires a value");
                    std::process::exit(2);
                }
            }
            _ => {
                eprintln!("Error: Unknown argument '{}'", args[i]);
                eprintln!("Use --help for usage information");
                std::process::exit(2);
            }
        }
    }
    
    // Determine service URL
    let base_url = if let Some(url) = custom_url {
        url
    } else {
        env::var("SERVICE_URL").unwrap_or_else(|_| format!("http://{}:{}", host, port))
    };
    
    let client = TestClient::new(base_url);
    
    // Wait a bit for service to start if needed
    sleep(Duration::from_secs(2)).await;
    
    let results = client.run_all_tests().await;
    
    // Exit with appropriate code
    let all_passed = results.values().all(|&passed| passed);
    std::process::exit(if all_passed { 0 } else { 1 });
} 