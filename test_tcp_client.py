#!/usr/bin/env python3
"""
TCP Test Client for MLS Delivery Service
Tests the TCP-based MLS delivery service
"""

import socket
import json
import time
import sys

class TCPTestClient:
    def __init__(self, host="127.0.0.1", port=8080):
        self.host = host
        self.port = port
        
    def send_message(self, message):
        """Send a JSON message to the service"""
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(5)
                s.connect((self.host, self.port))
                
                # Send the message
                json_data = json.dumps(message) + "\n"
                s.send(json_data.encode('utf-8'))
                
                # Receive response
                response = s.recv(1024).decode('utf-8').strip()
                return response
        except Exception as e:
            print(f"❌ Connection failed: {e}")
            return None
            
    def test_health(self):
        """Test health check by trying to list key packages"""
        print("🔍 Testing health check...")
        message = {"type": "ListKeyPackages"}
        response = self.send_message(message)
        
        if response:
            try:
                data = json.loads(response)
                if data.get("type") == "KeyPackageListResponse":
                    print("✅ Health check passed")
                    return True
                else:
                    print(f"❌ Health check failed: {data}")
                    return False
            except json.JSONDecodeError:
                print(f"❌ Invalid JSON response: {response}")
                return False
        return False
        
    def test_key_package_store(self):
        """Test KeyPackage storage"""
        print("🔍 Testing KeyPackage storage...")
        message = {
            "type": "StoreKeyPackage",
            "client_id": "test_user_001",
            "key_package": [98, 97, 115, 101, 54, 52, 95, 101, 110, 99, 111, 100, 101, 100, 95, 107, 101, 121, 95, 112, 97, 99, 107, 97, 103, 101, 95, 100, 97, 116, 97, 95, 104, 101, 114, 101]
        }
        response = self.send_message(message)
        
        if response:
            try:
                data = json.loads(response)
                if data.get("type") == "MessageResponse" and data.get("success") == True:
                    print("✅ KeyPackage stored successfully")
                    return True
                else:
                    print(f"❌ KeyPackage storage failed: {data}")
                    return False
            except json.JSONDecodeError:
                print(f"❌ Invalid JSON response: {response}")
                return False
        return False
        
    def test_key_package_retrieve(self):
        """Test KeyPackage retrieval"""
        print("🔍 Testing KeyPackage retrieval...")
        message = {
            "type": "FetchKeyPackage",
            "client_id": "test_user_001"
        }
        response = self.send_message(message)
        
        if response:
            try:
                data = json.loads(response)
                if data.get("type") == "KeyPackageResponse" and data.get("key_package"):
                    print("✅ KeyPackage retrieved successfully")
                    return True
                else:
                    print(f"❌ KeyPackage retrieval failed: {data}")
                    return False
            except json.JSONDecodeError:
                print(f"❌ Invalid JSON response: {response}")
                return False
        return False
        
    def test_group_create(self):
        """Test group creation"""
        print("🔍 Testing group creation...")
        message = {
            "type": "CreateGroup",
            "group_id": "test_group_001",
            "creator_id": "user1"
        }
        response = self.send_message(message)
        
        if response:
            try:
                data = json.loads(response)
                if data.get("type") == "GroupResponse" and data.get("members"):
                    print("✅ Group created successfully")
                    return True
                else:
                    print(f"❌ Group creation failed: {data}")
                    return False
            except json.JSONDecodeError:
                print(f"❌ Invalid JSON response: {response}")
                return False
        return False
        
    def test_message_broadcast(self):
        """Test message broadcasting"""
        print("🔍 Testing message broadcasting...")
        message = {
            "type": "RelayMessage",
            "group_id": "test_group_001",
            "sender_id": "user1",
            "message": [109, 101, 115, 115, 97, 103, 101, 95, 100, 97, 116, 97],
            "message_type": "Application"
        }
        response = self.send_message(message)
        
        if response:
            try:
                data = json.loads(response)
                if data.get("type") == "MessageResponse" and data.get("success") == True:
                    print("✅ Message broadcasted successfully")
                    return True
                else:
                    print(f"❌ Message broadcasting failed: {data}")
                    return False
            except json.JSONDecodeError:
                print(f"❌ Invalid JSON response: {response}")
                return False
        return False
        
    def run_all_tests(self):
        """Run all tests"""
        print("🚀 Starting TCP MLS Delivery Service Tests")
        print("=" * 50)
        
        tests = [
            ("Health Check", self.test_health),
            ("KeyPackage Storage", self.test_key_package_store),
            ("KeyPackage Retrieval", self.test_key_package_retrieve),
            ("Group Creation", self.test_group_create),
            ("Message Broadcasting", self.test_message_broadcast),
        ]
        
        passed = 0
        total = len(tests)
        
        for test_name, test_func in tests:
            try:
                if test_func():
                    passed += 1
            except Exception as e:
                print(f"❌ {test_name} failed with exception: {e}")
                
        print("\n" + "=" * 50)
        print(f"📊 Test Results: {passed}/{total} tests passed")
        
        if passed == total:
            print("🎉 All tests passed! The MLS Delivery Service is working correctly.")
        else:
            print("⚠️  Some tests failed. Please check the service configuration.")
            
        return passed == total

def main():
    """Main test execution"""
    if len(sys.argv) > 1:
        host = sys.argv[1]
    else:
        host = "127.0.0.1"
        
    if len(sys.argv) > 2:
        port = int(sys.argv[2])
    else:
        port = 8080
        
    client = TCPTestClient(host, port)
    success = client.run_all_tests()
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main() 