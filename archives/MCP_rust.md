### Show and explain the use of MCP (agent LLM context protocol) with  example code in Rust programming language! 

# MCP - Agent LLM Context Protocol

The MCP (Agent LLM Context Protocol) is a way to structure interactions between language models and other systems, allowing LLMs to function more effectively as agents with persistent memory and context management. I'll explain the concept and show you an implementation example in Rust.

```rust
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::error::Error;
use reqwest;
use tokio;

// MCP Context Structure
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct MCPContext {
    // Core context elements
    pub messages: Vec<Message>,
    pub memory: HashMap<String, String>,
    pub state: AgentState,
    pub tools: Vec<Tool>,
    pub config: AgentConfig,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Message {
    pub role: String,
    pub content: String,
    pub timestamp: u64,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AgentState {
    pub current_task: Option<String>,
    pub task_progress: f32, // 0.0 to 1.0
    pub status: String,     // "idle", "thinking", "executing", etc.
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Tool {
    pub name: String,
    pub description: String,
    pub parameters: HashMap<String, ToolParameter>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ToolParameter {
    pub description: String,
    pub required: bool,
    pub schema_type: String, // "string", "number", "boolean", etc.
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AgentConfig {
    pub name: String,
    pub version: String,
    pub description: String,
    pub max_context_size: usize,
    pub metadata: HashMap<String, String>,
}

// MCP Protocol Implementation
pub struct MCPAgent {
    context: MCPContext,
    llm_client: Box<dyn LLMClient>,
}

// Trait for LLM interaction
pub trait LLMClient {
    async fn generate_response(&self, prompt: &str) -> Result<String, Box<dyn Error>>;
}

// Example LLM client implementation
pub struct SimpleAPIClient {
    api_url: String,
    api_key: String,
}

#[async_trait::async_trait]
impl LLMClient for SimpleAPIClient {
    async fn generate_response(&self, prompt: &str) -> Result<String, Box<dyn Error>> {
        let client = reqwest::Client::new();
        let response = client
            .post(&self.api_url)
            .header("Authorization", format!("Bearer {}", self.api_key))
            .json(&serde_json::json!({
                "prompt": prompt,
                "max_tokens": 1000,
                "temperature": 0.7,
            }))
            .send()
            .await?
            .json::<serde_json::Value>()
            .await?;
            
        // Extract the completion from the response
        let generated_text = response["choices"][0]["text"]
            .as_str()
            .ok_or("Failed to extract completion")?
            .to_string();
            
        Ok(generated_text)
    }
}

impl MCPAgent {
    pub fn new(llm_client: Box<dyn LLMClient>, config: AgentConfig) -> Self {
        let context = MCPContext {
            messages: Vec::new(),
            memory: HashMap::new(),
            state: AgentState {
                current_task: None,
                task_progress: 0.0,
                status: "idle".to_string(),
            },
            tools: Vec::new(),
            config,
        };
        
        MCPAgent { context, llm_client }
    }
    
    // Register available tools for the agent
    pub fn register_tool(&mut self, tool: Tool) {
        self.context.tools.push(tool);
    }
    
    // Add a message to the context
    pub fn add_message(&mut self, role: &str, content: &str) {
        let timestamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
            
        let message = Message {
            role: role.to_string(),
            content: content.to_string(),
            timestamp,
        };
        
        self.context.messages.push(message);
        
        // Implement context window management if needed
        self.trim_context_if_needed();
    }
    
    // Store information in persistent memory
    pub fn memorize(&mut self, key: &str, value: &str) {
        self.context.memory.insert(key.to_string(), value.to_string());
    }
    
    // Retrieve information from memory
    pub fn recall(&self, key: &str) -> Option<&String> {
        self.context.memory.get(key)
    }
    
    // Update agent state
    pub fn update_state(&mut self, task: Option<String>, progress: f32, status: &str) {
        self.context.state.current_task = task;
        self.context.state.task_progress = progress;
        self.context.state.status = status.to_string();
    }
    
    // Main processing function
    pub async fn process_input(&mut self, user_input: &str) -> Result<String, Box<dyn Error>> {
        // Add user message to context
        self.add_message("user", user_input);
        
        // Update state
        self.update_state(Some("processing_input".to_string()), 0.0, "thinking");
        
        // Format prompt with full context
        let prompt = self.format_prompt();
        
        // Get LLM response
        let llm_response = self.llm_client.generate_response(&prompt).await?;
        
        // Parse LLM response for actions or responses
        let (response_text, actions) = self.parse_response(&llm_response);
        
        // Execute any actions from the response
        let action_results = self.execute_actions(actions).await?;
        
        // Update context with assistant's response
        self.add_message("assistant", &response_text);
        
        // Update state to idle
        self.update_state(None, 1.0, "idle");
        
        Ok(response_text)
    }
    
    // Format a prompt that includes the full context for the LLM
    fn format_prompt(&self) -> String {
        let mut prompt = String::new();
        
        // Add system instructions
        prompt.push_str("You are an AI assistant operating with MCP protocol. Follow these guidelines:\n");
        prompt.push_str("1. Use available tools when appropriate\n");
        prompt.push_str("2. Maintain context and memory\n");
        prompt.push_str("3. Respond directly to the user's query\n\n");
        
        // Add available tools description
        prompt.push_str("Available tools:\n");
        for tool in &self.context.tools {
            prompt.push_str(&format!("- {}: {}\n", tool.name, tool.description));
        }
        prompt.push_str("\n");
        
        // Add relevant memory items
        prompt.push_str("Relevant memories:\n");
        for (key, value) in &self.context.memory {
            prompt.push_str(&format!("- {}: {}\n", key, value));
        }
        prompt.push_str("\n");
        
        // Add conversation history
        prompt.push_str("Conversation history:\n");
        for message in &self.context.messages {
            prompt.push_str(&format!("{}: {}\n", message.role, message.content));
        }
        
        prompt
    }
    
    // Parse the LLM response to extract actions and the user-facing response
    fn parse_response(&self, response: &str) -> (String, Vec<AgentAction>) {
        // This is a simplified example - in a real implementation,
        // you would parse structured output from the LLM
        
        // Just returning the response text and no actions for simplicity
        (response.to_string(), Vec::new())
    }
    
    // Execute actions identified in the LLM response
    async fn execute_actions(&mut self, actions: Vec<AgentAction>) -> Result<Vec<ActionResult>, Box<dyn Error>> {
        let mut results = Vec::new();
        
        for action in actions {
            match action.tool_name.as_str() {
                "search" => {
                    // Implement search functionality
                    let result = ActionResult {
                        tool_name: "search".to_string(),
                        result: "Search results would appear here".to_string(),
                        success: true,
                    };
                    results.push(result);
                },
                "calculator" => {
                    // Implement calculator functionality
                    let result = ActionResult {
                        tool_name: "calculator".to_string(),
                        result: "Calculation result would appear here".to_string(),
                        success: true,
                    };
                    results.push(result);
                },
                _ => {
                    // Unknown tool
                    let result = ActionResult {
                        tool_name: action.tool_name,
                        result: "Unknown tool".to_string(),
                        success: false,
                    };
                    results.push(result);
                }
            }
        }
        
        Ok(results)
    }
    
    // Keep context within max size limits
    fn trim_context_if_needed(&mut self) {
        let max_size = self.context.config.max_context_size;
        
        // If we have too many messages, remove oldest ones
        while self.context.messages.len() > max_size {
            self.context.messages.remove(0);
        }
    }
}

#[derive(Debug)]
pub struct AgentAction {
    pub tool_name: String,
    pub parameters: HashMap<String, String>,
}

#[derive(Debug)]
pub struct ActionResult {
    pub tool_name: String,
    pub result: String,
    pub success: bool,
}

// Example usage
#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Create LLM client
    let llm_client = SimpleAPIClient {
        api_url: "https://api.example.com/v1/completions".to_string(),
        api_key: "your-api-key".to_string(),
    };
    
    // Create agent config
    let config = AgentConfig {
        name: "MCP Example Agent".to_string(),
        version: "0.1.0".to_string(),
        description: "An example agent using MCP protocol".to_string(),
        max_context_size: 100,
        metadata: HashMap::new(),
    };
    
    // Create agent
    let mut agent = MCPAgent::new(Box::new(llm_client), config);
    
    // Register tools
    let mut search_params = HashMap::new();
    search_params.insert("query".to_string(), ToolParameter {
        description: "Search query string".to_string(),
        required: true,
        schema_type: "string".to_string(),
    });
    
    let search_tool = Tool {
        name: "search".to_string(),
        description: "Search the web for information".to_string(),
        parameters: search_params,
    };
    
    agent.register_tool(search_tool);
    
    // Process a user query
    let response = agent.process_input("What's the weather today?").await?;
    println!("Agent response: {}", response);
    
    Ok(())
}

```

## Key Components of MCP Protocol

The MCP protocol provides a structured way for LLMs to maintain context and interact with external systems. Here's an explanation of the key components in the implementation:

### 1. Context Management
- **MCPContext**: The central structure that maintains the agent's state, conversation history, memory, and available tools
- **Messages**: Structured conversation history with timestamps
- **Memory**: A key-value store for persistent information across interactions

### 2. Tools and Actions
- **Tools**: Capabilities available to the agent, with defined parameters and schemas
- **AgentActions**: Parsed instructions from the LLM to execute specific functions
- **ActionResults**: Outcomes from executed actions that can be fed back to the LLM

### 3. State Management
- **AgentState**: Tracks the current task, progress, and status of the agent
- **Context Window Management**: Handles trimming older messages when context size limits are reached

### 4. LLM Integration
- **LLMClient trait**: Abstract interface for interacting with different LLM providers
- **Format and Parse functions**: Transform between the agent's internal context and LLM-friendly prompts

## How MCP Works

1. **Input Reception**: The agent receives user input and adds it to the context
2. **Context Formatting**: The full context (history, memory, tools) is formatted into a prompt
3. **LLM Generation**: The prompt is sent to the LLM for processing
4. **Response Parsing**: The LLM response is parsed to extract both user-facing text and actions
5. **Action Execution**: Any tools or functions referenced are executed
6. **Context Update**: Results are stored and the agent's state is updated

This approach allows the LLM agent to:
- Maintain longer-term memory beyond token limits
- Handle complex multi-step tasks
- Interact with external systems in a structured way
- Learn from past interactions

```rust 
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::error::Error;
use reqwest;
use tokio;

// MCP Context Structure
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct MCPContext {
    // Core context elements
    pub messages: Vec<Message>,
    pub memory: HashMap<String, String>,
    pub state: AgentState,
    pub tools: Vec<Tool>,
    pub config: AgentConfig,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Message {
    pub role: String,
    pub content: String,
    pub timestamp: u64,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AgentState {
    pub current_task: Option<String>,
    pub task_progress: f32, // 0.0 to 1.0
    pub status: String,     // "idle", "thinking", "executing", etc.
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Tool {
    pub name: String,
    pub description: String,
    pub parameters: HashMap<String, ToolParameter>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ToolParameter {
    pub description: String,
    pub required: bool,
    pub schema_type: String, // "string", "number", "boolean", etc.
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AgentConfig {
    pub name: String,
    pub version: String,
    pub description: String,
    pub max_context_size: usize,
    pub metadata: HashMap<String, String>,
}

// MCP Protocol Implementation
pub struct MCPAgent {
    context: MCPContext,
    llm_client: Box<dyn LLMClient>,
}

// Trait for LLM interaction
pub trait LLMClient {
    async fn generate_response(&self, prompt: &str) -> Result<String, Box<dyn Error>>;
}

// Example LLM client implementation
pub struct SimpleAPIClient {
    api_url: String,
    api_key: String,
}

#[async_trait::async_trait]
impl LLMClient for SimpleAPIClient {
    async fn generate_response(&self, prompt: &str) -> Result<String, Box<dyn Error>> {
        let client = reqwest::Client::new();
        let response = client
            .post(&self.api_url)
            .header("Authorization", format!("Bearer {}", self.api_key))
            .json(&serde_json::json!({
                "prompt": prompt,
                "max_tokens": 1000,
                "temperature": 0.7,
            }))
            .send()
            .await?
            .json::<serde_json::Value>()
            .await?;
            
        // Extract the completion from the response
        let generated_text = response["choices"][0]["text"]
            .as_str()
            .ok_or("Failed to extract completion")?
            .to_string();
            
        Ok(generated_text)
    }
}

impl MCPAgent {
    pub fn new(llm_client: Box<dyn LLMClient>, config: AgentConfig) -> Self {
        let context = MCPContext {
            messages: Vec::new(),
            memory: HashMap::new(),
            state: AgentState {
                current_task: None,
                task_progress: 0.0,
                status: "idle".to_string(),
            },
            tools: Vec::new(),
            config,
        };
        
        MCPAgent { context, llm_client }
    }
    
    // Register available tools for the agent
    pub fn register_tool(&mut self, tool: Tool) {
        self.context.tools.push(tool);
    }
    
    // Add a message to the context
    pub fn add_message(&mut self, role: &str, content: &str) {
        let timestamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
            
        let message = Message {
            role: role.to_string(),
            content: content.to_string(),
            timestamp,
        };
        
        self.context.messages.push(message);
        
        // Implement context window management if needed
        self.trim_context_if_needed();
    }
    
    // Store information in persistent memory
    pub fn memorize(&mut self, key: &str, value: &str) {
        self.context.memory.insert(key.to_string(), value.to_string());
    }
    
    // Retrieve information from memory
    pub fn recall(&self, key: &str) -> Option<&String> {
        self.context.memory.get(key)
    }
    
    // Update agent state
    pub fn update_state(&mut self, task: Option<String>, progress: f32, status: &str) {
        self.context.state.current_task = task;
        self.context.state.task_progress = progress;
        self.context.state.status = status.to_string();
    }
    
    // Main processing function
    pub async fn process_input(&mut self, user_input: &str) -> Result<String, Box<dyn Error>> {
        // Add user message to context
        self.add_message("user", user_input);
        
        // Update state
        self.update_state(Some("processing_input".to_string()), 0.0, "thinking");
        
        // Format prompt with full context
        let prompt = self.format_prompt();
        
        // Get LLM response
        let llm_response = self.llm_client.generate_response(&prompt).await?;
        
        // Parse LLM response for actions or responses
        let (response_text, actions) = self.parse_response(&llm_response);
        
        // Execute any actions from the response
        let action_results = self.execute_actions(actions).await?;
        
        // Update context with assistant's response
        self.add_message("assistant", &response_text);
        
        // Update state to idle
        self.update_state(None, 1.0, "idle");
        
        Ok(response_text)
    }
    
    // Format a prompt that includes the full context for the LLM
    fn format_prompt(&self) -> String {
        let mut prompt = String::new();
        
        // Add system instructions
        prompt.push_str("You are an AI assistant operating with MCP protocol. Follow these guidelines:\n");
        prompt.push_str("1. Use available tools when appropriate\n");
        prompt.push_str("2. Maintain context and memory\n");
        prompt.push_str("3. Respond directly to the user's query\n\n");
        
        // Add available tools description
        prompt.push_str("Available tools:\n");
        for tool in &self.context.tools {
            prompt.push_str(&format!("- {}: {}\n", tool.name, tool.description));
        }
        prompt.push_str("\n");
        
        // Add relevant memory items
        prompt.push_str("Relevant memories:\n");
        for (key, value) in &self.context.memory {
            prompt.push_str(&format!("- {}: {}\n", key, value));
        }
        prompt.push_str("\n");
        
        // Add conversation history
        prompt.push_str("Conversation history:\n");
        for message in &self.context.messages {
            prompt.push_str(&format!("{}: {}\n", message.role, message.content));
        }
        
        prompt
    }
    
    // Parse the LLM response to extract actions and the user-facing response
    fn parse_response(&self, response: &str) -> (String, Vec<AgentAction>) {
        // This is a simplified example - in a real implementation,
        // you would parse structured output from the LLM
        
        // Just returning the response text and no actions for simplicity
        (response.to_string(), Vec::new())
    }
    
    // Execute actions identified in the LLM response
    async fn execute_actions(&mut self, actions: Vec<AgentAction>) -> Result<Vec<ActionResult>, Box<dyn Error>> {
        let mut results = Vec::new();
        
        for action in actions {
            match action.tool_name.as_str() {
                "search" => {
                    // Implement search functionality
                    let result = ActionResult {
                        tool_name: "search".to_string(),
                        result: "Search results would appear here".to_string(),
                        success: true,
                    };
                    results.push(result);
                },
                "calculator" => {
                    // Implement calculator functionality
                    let result = ActionResult {
                        tool_name: "calculator".to_string(),
                        result: "Calculation result would appear here".to_string(),
                        success: true,
                    };
                    results.push(result);
                },
                _ => {
                    // Unknown tool
                    let result = ActionResult {
                        tool_name: action.tool_name,
                        result: "Unknown tool".to_string(),
                        success: false,
                    };
                    results.push(result);
                }
            }
        }
        
        Ok(results)
    }
    
    // Keep context within max size limits
    fn trim_context_if_needed(&mut self) {
        let max_size = self.context.config.max_context_size;
        
        // If we have too many messages, remove oldest ones
        while self.context.messages.len() > max_size {
            self.context.messages.remove(0);
        }
    }
}

#[derive(Debug)]
pub struct AgentAction {
    pub tool_name: String,
    pub parameters: HashMap<String, String>,
}

#[derive(Debug)]
pub struct ActionResult {
    pub tool_name: String,
    pub result: String,
    pub success: bool,
}

// Example usage
#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Create LLM client
    let llm_client = SimpleAPIClient {
        api_url: "https://api.example.com/v1/completions".to_string(),
        api_key: "your-api-key".to_string(),
    };
    
    // Create agent config
    let config = AgentConfig {
        name: "MCP Example Agent".to_string(),
        version: "0.1.0".to_string(),
        description: "An example agent using MCP protocol".to_string(),
        max_context_size: 100,
        metadata: HashMap::new(),
    };
    
    // Create agent
    let mut agent = MCPAgent::new(Box::new(llm_client), config);
    
    // Register tools
    let mut search_params = HashMap::new();
    search_params.insert("query".to_string(), ToolParameter {
        description: "Search query string".to_string(),
        required: true,
        schema_type: "string".to_string(),
    });
    
    let search_tool = Tool {
        name: "search".to_string(),
        description: "Search the web for information".to_string(),
        parameters: search_params,
    };
    
    agent.register_tool(search_tool);
    
    // Process a user query
    let response = agent.process_input("What's the weather today?").await?;
    println!("Agent response: {}", response);
    
    Ok(())
}
```

