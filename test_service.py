#!/usr/bin/env python3
"""
MLS Delivery Service Test Script
Tests all endpoints and functionality of the MLS delivery service
"""

import requests
import json
import time
import threading
import sys
from typing import Dict, Any, List

class MLSDeliveryServiceTester:
    def __init__(self, base_url: str = "http://127.0.0.1:8080"):
        self.base_url = base_url
        self.test_results = []
        
    def log_test(self, test_name: str, success: bool, message: str = ""):
        """Log test results"""
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status} {test_name}: {message}")
        self.test_results.append({
            "test": test_name,
            "success": success,
            "message": message
        })
        
    def test_server_health(self) -> bool:
        """Test if server is running and responding"""
        try:
            response = requests.get(f"{self.base_url}/health", timeout=5)
            if response.status_code == 200:
                self.log_test("Server Health Check", True, "Server is running")
                return True
            else:
                self.log_test("Server Health Check", False, f"Unexpected status: {response.status_code}")
                return False
        except requests.exceptions.RequestException as e:
            self.log_test("Server Health Check", False, f"Connection failed: {e}")
            return False
            
    def test_key_package_operations(self) -> bool:
        """Test KeyPackage storage and retrieval"""
        try:
            # Test data
            user_id = "test_user_001"
            key_package_data = {
                "key_package": "base64_encoded_key_package_data_here",
                "user_id": user_id,
                "timestamp": int(time.time())
            }
            
            # Store KeyPackage
            response = requests.post(
                f"{self.base_url}/keypackages",
                json=key_package_data,
                timeout=5
            )
            
            if response.status_code == 200:
                self.log_test("Store KeyPackage", True, f"Stored for user {user_id}")
            else:
                self.log_test("Store KeyPackage", False, f"Status: {response.status_code}")
                return False
                
            # Retrieve KeyPackage
            response = requests.get(f"{self.base_url}/keypackages/{user_id}", timeout=5)
            
            if response.status_code == 200:
                retrieved_data = response.json()
                if retrieved_data.get("user_id") == user_id:
                    self.log_test("Retrieve KeyPackage", True, f"Retrieved for user {user_id}")
                    return True
                else:
                    self.log_test("Retrieve KeyPackage", False, "Data mismatch")
                    return False
            else:
                self.log_test("Retrieve KeyPackage", False, f"Status: {response.status_code}")
                return False
                
        except requests.exceptions.RequestException as e:
            self.log_test("KeyPackage Operations", False, f"Request failed: {e}")
            return False
            
    def test_group_operations(self) -> bool:
        """Test group creation and management"""
        try:
            # Create a test group
            group_data = {
                "group_id": "test_group_001",
                "members": ["user1", "user2"],
                "creator": "user1"
            }
            
            response = requests.post(
                f"{self.base_url}/groups",
                json=group_data,
                timeout=5
            )
            
            if response.status_code == 200:
                self.log_test("Create Group", True, f"Created group {group_data['group_id']}")
            else:
                self.log_test("Create Group", False, f"Status: {response.status_code}")
                return False
                
            # Get group info
            response = requests.get(f"{self.base_url}/groups/{group_data['group_id']}", timeout=5)
            
            if response.status_code == 200:
                group_info = response.json()
                if group_info.get("group_id") == group_data["group_id"]:
                    self.log_test("Get Group Info", True, f"Retrieved group {group_data['group_id']}")
                    return True
                else:
                    self.log_test("Get Group Info", False, "Data mismatch")
                    return False
            else:
                self.log_test("Get Group Info", False, f"Status: {response.status_code}")
                return False
                
        except requests.exceptions.RequestException as e:
            self.log_test("Group Operations", False, f"Request failed: {e}")
            return False
            
    def test_message_broadcasting(self) -> bool:
        """Test message broadcasting functionality"""
        try:
            # Test MLS message data
            message_data = {
                "group_id": "test_group_001",
                "sender_id": "user1",
                "message_type": "Application",
                "encrypted_message": "base64_encoded_mls_message_here",
                "timestamp": int(time.time())
            }
            
            response = requests.post(
                f"{self.base_url}/messages",
                json=message_data,
                timeout=5
            )
            
            if response.status_code == 200:
                self.log_test("Broadcast Message", True, f"Broadcasted {message_data['message_type']} message")
                return True
            else:
                self.log_test("Broadcast Message", False, f"Status: {response.status_code}")
                return False
                
        except requests.exceptions.RequestException as e:
            self.log_test("Message Broadcasting", False, f"Request failed: {e}")
            return False
            
    def test_error_handling(self) -> bool:
        """Test error handling for invalid requests"""
        try:
            # Test invalid KeyPackage retrieval
            response = requests.get(f"{self.base_url}/keypackages/nonexistent_user", timeout=5)
            
            if response.status_code == 404:
                self.log_test("Error Handling - 404", True, "Correctly returned 404 for non-existent user")
            else:
                self.log_test("Error Handling - 404", False, f"Expected 404, got {response.status_code}")
                return False
                
            # Test invalid group retrieval
            response = requests.get(f"{self.base_url}/groups/nonexistent_group", timeout=5)
            
            if response.status_code == 404:
                self.log_test("Error Handling - Group 404", True, "Correctly returned 404 for non-existent group")
                return True
            else:
                self.log_test("Error Handling - Group 404", False, f"Expected 404, got {response.status_code}")
                return False
                
        except requests.exceptions.RequestException as e:
            self.log_test("Error Handling", False, f"Request failed: {e}")
            return False
            
    def test_concurrent_operations(self) -> bool:
        """Test concurrent operations to ensure thread safety"""
        def store_key_package(user_id: str):
            try:
                key_package_data = {
                    "key_package": f"key_package_for_{user_id}",
                    "user_id": user_id,
                    "timestamp": int(time.time())
                }
                response = requests.post(
                    f"{self.base_url}/keypackages",
                    json=key_package_data,
                    timeout=5
                )
                return response.status_code == 200
            except:
                return False
                
        # Create multiple threads
        threads = []
        results = []
        
        for i in range(5):
            user_id = f"concurrent_user_{i}"
            thread = threading.Thread(
                target=lambda u=user_id: results.append(store_key_package(u))
            )
            threads.append(thread)
            thread.start()
            
        # Wait for all threads to complete
        for thread in threads:
            thread.join()
            
        success_count = sum(results)
        if success_count == 5:
            self.log_test("Concurrent Operations", True, "All 5 concurrent operations succeeded")
            return True
        else:
            self.log_test("Concurrent Operations", False, f"Only {success_count}/5 operations succeeded")
            return False
            
    def run_all_tests(self) -> Dict[str, Any]:
        """Run all tests and return results"""
        print("🚀 Starting MLS Delivery Service Tests")
        print("=" * 50)
        
        tests = [
            ("Server Health", self.test_server_health),
            ("KeyPackage Operations", self.test_key_package_operations),
            ("Group Operations", self.test_group_operations),
            ("Message Broadcasting", self.test_message_broadcasting),
            ("Error Handling", self.test_error_handling),
            ("Concurrent Operations", self.test_concurrent_operations),
        ]
        
        passed = 0
        total = len(tests)
        
        for test_name, test_func in tests:
            try:
                if test_func():
                    passed += 1
            except Exception as e:
                self.log_test(test_name, False, f"Exception: {e}")
                
        print("\n" + "=" * 50)
        print(f"📊 Test Results: {passed}/{total} tests passed")
        
        if passed == total:
            print("🎉 All tests passed! The MLS Delivery Service is working correctly.")
        else:
            print("⚠️  Some tests failed. Please check the service configuration.")
            
        return {
            "total_tests": total,
            "passed_tests": passed,
            "failed_tests": total - passed,
            "results": self.test_results
        }

def main():
    """Main test execution"""
    if len(sys.argv) > 1:
        base_url = sys.argv[1]
    else:
        base_url = "http://127.0.0.1:8080"
        
    tester = MLSDeliveryServiceTester(base_url)
    results = tester.run_all_tests()
    
    # Exit with appropriate code
    if results["passed_tests"] == results["total_tests"]:
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main() 