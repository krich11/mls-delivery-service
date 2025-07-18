use anyhow::Result;
use log::{error, info, warn};
use openmls::prelude::*;
use openmls_rust_crypto::OpenMlsRustCrypto;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::RwLock;
use uuid::Uuid;

type ClientId = String;
type GroupId = String;

// MLS Protocol Configuration with cryptographic agility
fn mls_crypto_config() -> CryptoConfig {
    CryptoConfig {
        ciphersuite: Ciphersuite::MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519,
        version: ProtocolVersion::Mls10,
    }
}

// Message types for the delivery service
#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(tag = "type")]
pub enum DeliveryMessage {
    // KeyPackage operations
    StoreKeyPackage {
        client_id: ClientId,
        key_package: Vec<u8>,
    },
    FetchKeyPackage {
        client_id: ClientId,
    },
    ListKeyPackages,
    
    // MLS Group operations
    CreateGroup {
        group_id: GroupId,
        creator_id: ClientId,
    },
    JoinGroup {
        group_id: GroupId,
        client_id: ClientId,
    },
    
    // MLS Message relaying
    RelayMessage {
        group_id: GroupId,
        sender_id: ClientId,
        message: Vec<u8>,
        message_type: MlsMessageType,
    },
    
    // Responses
    KeyPackageResponse {
        client_id: ClientId,
        key_package: Option<Vec<u8>>,
    },
    KeyPackageListResponse {
        clients: Vec<ClientId>,
    },
    GroupResponse {
        group_id: GroupId,
        members: Vec<ClientId>,
    },
    MessageResponse {
        success: bool,
        message: String,
    },
    Error {
        message: String,
    },
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub enum MlsMessageType {
    Welcome,
    Add,
    Application,
    Commit,
    Proposal,
}

// Group state tracking
#[derive(Debug, Clone)]
pub struct GroupState {
    pub id: GroupId,
    pub members: Vec<ClientId>,
    pub creator: ClientId,
    pub messages: Vec<(ClientId, Vec<u8>, MlsMessageType)>,
}

impl GroupState {
    pub fn new(id: GroupId, creator: ClientId) -> Self {
        Self {
            id,
            members: vec![creator.clone()],
            creator,
            messages: Vec::new(),
        }
    }
    
    pub fn add_member(&mut self, client_id: ClientId) {
        if !self.members.contains(&client_id) {
            self.members.push(client_id);
        }
    }
    
    pub fn add_message(&mut self, sender: ClientId, message: Vec<u8>, msg_type: MlsMessageType) {
        self.messages.push((sender, message, msg_type));
    }
}

// Main delivery service state
#[derive(Debug)]
pub struct DeliveryService {
    key_packages: Arc<RwLock<HashMap<ClientId, Vec<u8>>>>,
    groups: Arc<RwLock<HashMap<GroupId, GroupState>>>,
    crypto_provider: OpenMlsRustCrypto,
}

impl DeliveryService {
    pub fn new() -> Self {
        Self {
            key_packages: Arc::new(RwLock::new(HashMap::new())),
            groups: Arc::new(RwLock::new(HashMap::new())),
            crypto_provider: OpenMlsRustCrypto::default(),
        }
    }
    
    pub async fn store_key_package(&self, client_id: ClientId, key_package: Vec<u8>) -> Result<()> {
        let mut packages = self.key_packages.write().await;
        packages.insert(client_id.clone(), key_package);
        info!("Stored KeyPackage for client: {}", client_id);
        Ok(())
    }
    
    pub async fn fetch_key_package(&self, client_id: &ClientId) -> Option<Vec<u8>> {
        let packages = self.key_packages.read().await;
        packages.get(client_id).cloned()
    }
    
    pub async fn list_key_packages(&self) -> Vec<ClientId> {
        let packages = self.key_packages.read().await;
        packages.keys().cloned().collect()
    }
    
    pub async fn create_group(&self, group_id: GroupId, creator_id: ClientId) -> Result<GroupState> {
        let mut groups = self.groups.write().await;
        if groups.contains_key(&group_id) {
            return Err(anyhow::anyhow!("Group already exists: {}", group_id));
        }
        
        let group = GroupState::new(group_id.clone(), creator_id);
        groups.insert(group_id.clone(), group.clone());
        info!("Created group: {} by {}", group_id, group.creator);
        Ok(group)
    }
    
    pub async fn join_group(&self, group_id: &GroupId, client_id: ClientId) -> Result<GroupState> {
        let mut groups = self.groups.write().await;
        match groups.get_mut(group_id) {
            Some(group) => {
                group.add_member(client_id.clone());
                info!("Client {} joined group {}", client_id, group_id);
                Ok(group.clone())
            }
            None => Err(anyhow::anyhow!("Group not found: {}", group_id)),
        }
    }
    
    pub async fn relay_message(
        &self,
        group_id: &GroupId,
        sender_id: ClientId,
        message: Vec<u8>,
        message_type: MlsMessageType,
    ) -> Result<()> {
        let mut groups = self.groups.write().await;
        match groups.get_mut(group_id) {
            Some(group) => {
                if !group.members.contains(&sender_id) {
                    return Err(anyhow::anyhow!("Sender not in group: {}", sender_id));
                }
                group.add_message(sender_id.clone(), message, message_type);
                info!("Relayed message from {} to group {}", sender_id, group_id);
                Ok(())
            }
            None => Err(anyhow::anyhow!("Group not found: {}", group_id)),
        }
    }
    
    pub async fn get_group(&self, group_id: &GroupId) -> Option<GroupState> {
        let groups = self.groups.read().await;
        groups.get(group_id).cloned()
    }
}

// Handle individual client connections
async fn handle_client(
    mut stream: TcpStream,
    service: Arc<DeliveryService>,
) -> Result<()> {
    let mut buffer = [0; 8192];
    
    loop {
        match stream.read(&mut buffer).await {
            Ok(0) => {
                info!("Client disconnected");
                break;
            }
            Ok(n) => {
                let request_data = &buffer[..n];
                let response = match serde_json::from_slice::<DeliveryMessage>(request_data) {
                    Ok(message) => handle_message(message, service.clone()).await,
                    Err(e) => {
                        error!("Failed to parse message: {}", e);
                        DeliveryMessage::Error {
                            message: format!("Invalid message format: {}", e),
                        }
                    }
                };
                
                let response_data = match serde_json::to_vec(&response) {
                    Ok(data) => data,
                    Err(e) => {
                        error!("Failed to serialize response: {}", e);
                        continue;
                    }
                };
                
                if let Err(e) = stream.write_all(&response_data).await {
                    error!("Failed to write response: {}", e);
                    break;
                }
            }
            Err(e) => {
                error!("Failed to read from socket: {}", e);
                break;
            }
        }
    }
    
    Ok(())
}

// Handle different types of messages
async fn handle_message(
    message: DeliveryMessage,
    service: Arc<DeliveryService>,
) -> DeliveryMessage {
    match message {
        DeliveryMessage::StoreKeyPackage { client_id, key_package } => {
            match service.store_key_package(client_id.clone(), key_package).await {
                Ok(()) => DeliveryMessage::MessageResponse {
                    success: true,
                    message: format!("KeyPackage stored for {}", client_id),
                },
                Err(e) => DeliveryMessage::Error {
                    message: format!("Failed to store KeyPackage: {}", e),
                },
            }
        }
        
        DeliveryMessage::FetchKeyPackage { client_id } => {
            match service.fetch_key_package(&client_id).await {
                Some(key_package) => DeliveryMessage::KeyPackageResponse {
                    client_id,
                    key_package: Some(key_package),
                },
                None => DeliveryMessage::KeyPackageResponse {
                    client_id,
                    key_package: None,
                },
            }
        }
        
        DeliveryMessage::ListKeyPackages => {
            let clients = service.list_key_packages().await;
            DeliveryMessage::KeyPackageListResponse { clients }
        }
        
        DeliveryMessage::CreateGroup { group_id, creator_id } => {
            match service.create_group(group_id.clone(), creator_id).await {
                Ok(group) => DeliveryMessage::GroupResponse {
                    group_id,
                    members: group.members,
                },
                Err(e) => DeliveryMessage::Error {
                    message: format!("Failed to create group: {}", e),
                },
            }
        }
        
        DeliveryMessage::JoinGroup { group_id, client_id } => {
            match service.join_group(&group_id, client_id).await {
                Ok(group) => DeliveryMessage::GroupResponse {
                    group_id,
                    members: group.members,
                },
                Err(e) => DeliveryMessage::Error {
                    message: format!("Failed to join group: {}", e),
                },
            }
        }
        
        DeliveryMessage::RelayMessage { group_id, sender_id, message, message_type } => {
            match service.relay_message(&group_id, sender_id, message, message_type).await {
                Ok(()) => DeliveryMessage::MessageResponse {
                    success: true,
                    message: "Message relayed successfully".to_string(),
                },
                Err(e) => DeliveryMessage::Error {
                    message: format!("Failed to relay message: {}", e),
                },
            }
        }
        
        // These are response messages, should not be received by server
        _ => DeliveryMessage::Error {
            message: "Invalid message type for server".to_string(),
        },
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logging
    env_logger::init();
    
    // Create the delivery service
    let service = Arc::new(DeliveryService::new());
    
    // Bind to localhost:8080
    let listener = TcpListener::bind("127.0.0.1:8080").await?;
    info!("MLS Delivery Service running on 127.0.0.1:8080");
    info!("Supporting OpenMLS with cryptographic agility for future KEMs");
    
    // Accept connections
    loop {
        match listener.accept().await {
            Ok((stream, addr)) => {
                info!("New client connected from: {}", addr);
                let service_clone = Arc::clone(&service);
                
                tokio::spawn(async move {
                    if let Err(e) = handle_client(stream, service_clone).await {
                        error!("Error handling client {}: {}", addr, e);
                    }
                });
            }
            Err(e) => {
                error!("Failed to accept connection: {}", e);
            }
        }
    }
}
