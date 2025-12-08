# GraphBit Integration Guide for Rust WASM LLM Applications

GraphBit is an enterprise-grade agentic AI framework   built by InfinitiBit GmbH that combines a high-performance **Rust core** (54.4% of codebase) with an accessible **Python API** (45.5%) via PyO3 bindings. For your Rust WASM LLM client deployed on AWS EKS Fargate at api.cargillai.com, **direct WASM compilation is not currently supported**—however, a sidecar/microservice integration pattern provides full access to GraphBit’s capabilities with minimal architectural changes.

The framework delivers claimed performance gains of **68× lower CPU usage** and **140× lower memory footprint** compared to Python-only alternatives  through its compiled Rust execution engine, lock-free concurrency, and dependency-aware batch scheduling.  Production-grade features including circuit breakers, exponential backoff retries, and built-in observability make it suitable for enterprise deployments. 

## Three-tier architecture powers high-performance orchestration

GraphBit’s architecture separates concerns across three distinct layers. The **Rust Core** implements the workflow engine, agent execution, LLM provider integrations, and resilience primitives—all compiled to native code that bypasses Python’s Global Interpreter Lock. The **Orchestration Layer** handles project management, workflow validation (cycle detection, edge validity), and batch scheduling based on topological ordering. The **Python API Layer** uses PyO3 bindings to expose an ergonomic interface while keeping orchestration in the compiled hot path. 

The concurrency model uses per-node-type atomic counters rather than a global semaphore, enabling high-throughput scheduling without bottlenecks.  Independent nodes execute in parallel batches, while the framework automatically injects parent outputs into downstream agent prompts as structured JSON context blocks.  Memory management on Unix systems optionally uses jemalloc for reduced fragmentation,  with worker threads configured at 2× CPU cores and a separate blocking pool at 4× cores for I/O operations.

```python
from graphbit import Workflow, Node, Executor, LlmConfig

config = LlmConfig.openai(api_key, "gpt-4o-mini")
workflow = Workflow("Research Pipeline")

# Agents execute in dependency-aware batches
researcher = Node.agent(name="Researcher", prompt="Research: {topic}", temperature=0.3)
writer = Node.agent(name="Writer", prompt="Write article from research", temperature=0.8)
editor = Node.agent(name="Editor", prompt="Edit for clarity", temperature=0.5)

id1 = workflow.add_node(researcher)
id2 = workflow.add_node(writer)
id3 = workflow.add_node(editor)
workflow.connect(id1, id2)
workflow.connect(id2, id3)

executor = Executor(config, timeout_seconds=120)
result = executor.execute(workflow)
```

## Multi-agent workflows support sophisticated coordination patterns

GraphBit enables three primary multi-agent patterns. **Sequential pipelines** chain agents where each receives the prior agent’s output via automatic context injection. **Parallel branches** allow independent agents to execute concurrently—useful for simultaneous sentiment analysis, entity extraction, and summarization that converge at an aggregator node. **Quality gate patterns** implement conditional branching where agents route work based on evaluation criteria.

State management occurs through the `WorkflowContext` structure containing workflow state (Running/Completed/Failed), shared variables accessible via `context.set_variable()`, node outputs indexed by both ID and name, and execution statistics. Context propagates automatically: parent outputs appear in downstream prompts as titled sections plus a JSON block, eliminating boilerplate and improving answer quality in multi-step flows. 

The framework currently supports five fully implemented node types: **Agent** (LLM-powered), **Condition** (branching logic), **Transform** (data manipulation), **Delay** (timing), and **DocumentLoader** (file parsing). Three additional types—Split, Join, and HttpRequest—are scaffolded but not yet production-ready.

## WASM integration requires API-based architecture rather than direct compilation

Direct WASM compilation of GraphBit faces fundamental obstacles. PyO3 bindings require the CPython interpreter and cannot target `wasm32-unknown-unknown`. Tokio’s async runtime has limited WASM support—only the single-threaded `rt` feature works, and `Runtime::new()` is unsupported. GraphBit’s lock-free concurrency mechanisms use threading primitives not fully available in WASM environments.

The recommended architecture for AWS EKS Fargate deploys GraphBit as a **native container sidecar** alongside your WASM LLM client:

```
┌─────────────────────────────────────────────────────────┐
│                     EKS Fargate Pod                      │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    HTTP/gRPC    ┌────────────────┐ │
│  │  WASM LLM Client│ ◄──────────────► │   GraphBit     │ │
│  │  (Rust+WASM)    │                  │   Service      │ │
│  │  api.cargillai  │                  │   (Native)     │ │
│  └─────────────────┘                  └────────────────┘ │
│            │                                  │          │
│            └────────────── EFS ───────────────┘          │
└─────────────────────────────────────────────────────────┘
```

Your WASM client communicates with GraphBit over HTTP, while shared state persists via EFS volumes. This pattern preserves GraphBit’s reliability features (circuit breakers, retries) while allowing your WASM components to operate in their optimal runtime.

```rust
// WASM client integration pattern
#[wasm_bindgen]
pub async fn invoke_graphbit_workflow(task: String) -> Result<String, JsValue> {
    let client = reqwest::Client::new();
    let resp = client
        .post("http://graphbit-service:8080/workflow/execute")
        .json(&serde_json::json!({ "task": task }))
        .send()
        .await
        .map_err(|e| JsValue::from_str(&e.to_string()))?;
    resp.text().await.map_err(|e| JsValue::from_str(&e.to_string()))
}
```

## RAG pipelines leverage built-in document processing and embeddings

GraphBit includes native RAG components without requiring external libraries. **Document Loaders** support PDF, DOCX, TXT, JSON, CSV, XML, and HTML formats. **Text Splitters** implement four strategies: character-based (fixed chunks), token-based (critical for context windows), sentence-based (semantic coherence), and recursive (hierarchical using multiple separators).

**Embedding integration** supports OpenAI (`text-embedding-3-small`) and HuggingFace (`sentence-transformers/all-MiniLM-L6-v2`) models through a unified `EmbeddingClient` interface offering single and batch embedding, async operations, and built-in cosine similarity calculations.

```python
from graphbit import EmbeddingConfig, EmbeddingClient, TextSplitter, DocumentLoader

# Load and split documents
loader = DocumentLoader()
documents = loader.load("./documents/")
splitter = TextSplitter.recursive(chunk_size=1000, chunk_overlap=100)
chunks = splitter.split_documents(documents)

# Generate embeddings
config = EmbeddingConfig.openai(api_key, model="text-embedding-3-small")
client = EmbeddingClient(config)
vectors = client.embed_many([chunk.content for chunk in chunks])
```

**Vector store connectors** support Pinecone, Qdrant, ChromaDB, Milvus, Weaviate, FAISS, Elasticsearch, AstraDB, Redis, and PostgreSQL (PGVector). Cloud integrations include AWS Boto3, Azure, and Google Cloud Platform.  

## Tool orchestration uses a two-phase execution model without native MCP support

GraphBit does not implement the Model Context Protocol (MCP) standard. Instead, it uses a proprietary **two-phase tool orchestration** system. In Phase 1, the LLM analyzes the prompt and signals which tools to invoke via structured output. In Phase 2, Python executes the registered tools and injects results back into the prompt for final LLM completion.  

Tools are registered using the `@tool` decorator with automatic JSON Schema generation from Python type hints:  

```python
from graphbit import tool

@tool(_description="Get current weather for any city")
def get_weather(location: str) -> dict:
    return {"location": location, "temperature": 22, "condition": "sunny"}

@tool(_description="Calculate mathematical expressions")
def calculate(expression: str) -> str:
    return f"Result: {eval(expression)}"

agent = Node.agent(
    name="Smart Agent",
    prompt="What's the weather in Paris and calculate 15 + 27?",
    tools=[get_weather, calculate]
)
```

For MCP server integration, developers can create wrapper tools that act as MCP clients, bridging external MCP-compatible tools into GraphBit’s execution framework. The `ToolRegistry` maintains global tool metadata with thread-local storage in the Rust core, and `ExecutorConfig` controls timeouts, maximum tool calls, and error handling behavior.

## GraphBit excels in performance but trades ecosystem maturity

Compared to established frameworks, GraphBit occupies a unique niche as the only Rust-core agentic framework with Python ergonomics:

|Framework     |Stars |Architecture      |Best For                              |
|--------------|------|------------------|--------------------------------------|
|**GraphBit**  |451   |Rust core + Python|Production efficiency, edge deployment|
|**LangChain** |~119k |Python            |General LLM orchestration, prototyping|
|**LangGraph** |~21.8k|Python            |Complex stateful graph workflows      |
|**LlamaIndex**|~43k  |Python            |RAG and data indexing                 |
|**CrewAI**    |~30k  |Python            |Role-based multi-agent teams          |
|**AutoGen**   |Large |Python            |Conversational agents (Microsoft)     |

GraphBit’s **advantages** include claimed 68× CPU efficiency, 140× memory efficiency, 100% task reliability in stress tests, and production-first features (circuit breakers, observability).  Its **limitations** include incomplete node types (Split, Join, HttpRequest not implemented), a smaller community (12 contributors vs. hundreds), a proprietary license requiring enterprise terms for commercial use, and internal-only benchmark validation. 

**Choose GraphBit when**: Resource efficiency is critical, you need deterministic multi-agent execution, circuit breakers and fault tolerance are requirements, or you’re deploying to edge/resource-constrained environments. 

**Consider alternatives when**: Rapid prototyping is the priority (CrewAI), complex cyclical workflows dominate (LangGraph), RAG is the primary focus (LlamaIndex), or you need Microsoft ecosystem integration (AutoGen).

## Production deployment on Kubernetes requires native container strategy

For AWS EKS Fargate deployment alongside your WASM workload, deploy GraphBit as a standard container:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: graphbit-orchestrator
spec:
  template:
    spec:
      containers:
      - name: wasm-llm-client
        image: your-wasm-runtime:latest
        runtimeClassName: wasmedge  # If using WASM runtime
      - name: graphbit-service
        image: python:3.11-slim
        command: ["python", "-m", "graphbit.server"]
        ports:
        - containerPort: 8080
        env:
        - name: OPENAI_API_KEY
          valueFrom:
            secretKeyRef:
              name: llm-secrets
              key: openai-key
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
          limits:
            cpu: "2000m"
            memory: "2Gi"
```

Key configuration considerations include setting `timeout_seconds` based on expected LLM latency (120s typical), using `lightweight_mode=False` for production throughput, enabling observability via GraphBit’s built-in tracing, and implementing health checks using the framework’s health endpoint.

The framework’s reliability primitives—circuit breakers with Closed/Open/HalfOpen states, exponential backoff retries with jitter, and per-node-type concurrency limits—require no additional infrastructure.   Execution traces, token statistics, and latency metrics are available through the Python API for integration with your existing monitoring stack.