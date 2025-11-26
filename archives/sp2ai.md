# Comprehensive ETL Solution for SharePoint to Azure AI Search Migration
## CQN Nutrition Optimizer Project - Technical Architecture Guide

Microsoft's Azure ecosystem provides robust capabilities for extracting nutrition data from SharePoint archives with nested zip files, processing multiple document types, and indexing for LLM-powered search. This architecture enables R&D teams to maintain normal workflows while demonstrating transformative search capabilities to leadership.

## SharePoint data extraction with Microsoft Graph API delivers optimal performance

**Microsoft Graph API emerges as the definitive choice** for production ETL pipelines extracting from SharePoint Online. This modern API consumes 1-2 resource units per request compared to legacy REST API approaches, features predetermined throttling profiles to avoid service disruptions, and provides delta query capabilities that efficiently track only changed files. The resource unit advantage proves critical: Graph's delta queries consume just 1 resource unit when using tokens versus 2 without, while SharePoint REST API lacks predetermined costs and incurs additional internal resource limits.

Authentication through Azure Managed Identity eliminates credential management overhead entirely. System-assigned managed identities automatically rotate credentials, integrate seamlessly with Azure Key Vault, and provide comprehensive audit trails through Azure AD. **For the POV phase, configure managed identity on Azure Functions with Sites.ReadWrite.All permissions**, then optionally restrict to Sites.Selected for specific site collections in production. This approach requires no stored secrets and aligns with Microsoft's strategic direction.

**Delta query implementation for incremental sync:**

```python
from azure.identity import DefaultAzureCredential
from msgraph import GraphServiceClient

class SharePointETL:
    def __init__(self):
        self.credential = DefaultAzureCredential()
        self.client = GraphServiceClient(self.credential)
        self.last_delta_token = self.load_delta_token()
        
    async def get_changed_files(self, site_id, drive_id):
        """Retrieve only files changed since last sync"""
        delta_url = f"/sites/{site_id}/drives/{drive_id}/root/delta"
        
        if self.last_delta_token:
            # Subsequent sync - returns only changes
            response = await self.client.get(f"{delta_url}?token={self.last_delta_token}")
        else:
            # Initial sync - returns all files
            response = await self.client.get(delta_url)
        
        changed_files = [item for item in response.value if 'file' in item]
        
        # Save new delta token for next iteration
        new_token = response.odata_delta_link.split('token=')[1]
        self.save_delta_token(new_token)
        
        return changed_files
```

Change detection through **SharePoint webhooks combined with GetChanges API** provides near real-time updates without polling overhead. Webhooks batch notifications approximately once per minute, trigger Azure Functions to queue processing tasks, then retrieve actual change details via GetChanges API. This architecture minimizes API calls while maintaining responsiveness. Store change tokens in Azure Table Storage for persistence across function invocations. Webhook subscriptions expire after 180 days maximum; implement automatic renewal 30 days before expiration.

**Throttling protection requires honoring Retry-After headers and implementing exponential backoff.** SharePoint Online enforces application throttling based on tenant license count, with limits ranging from 1,200 resource units per minute for small tenants to 18,000 for enterprise deployments. Monitor RateLimit headers proactively and slow requests when remaining capacity drops below 20%. Use batch requests for up to 20 operations per call. Decorate all traffic with descriptive User-Agent strings like "ISV|CompanyName|NutritionOptimizer/1.0" for better throttling profile management.

## Nested zip extraction demands recursive processing with memory-efficient patterns

**Python's built-in zipfile library handles nested archives effectively** without external dependencies. The recursive approach detects zip files within extracted contents and processes them iteratively until reaching actual document files. For production ETL at scale, implement in-memory extraction using io.BytesIO to avoid writing intermediate files to disk, reducing I/O overhead and enabling parallel processing.

**Production-ready nested zip extractor:**

```python
import zipfile
import io
import os

class NestedZipExtractor:
    def __init__(self, max_depth=10):
        self.max_depth = max_depth  # Prevent infinite recursion
        self.extracted_files = []
    
    def extract_nested_zip_memory(self, zip_data, current_depth=0):
        """Extract nested zips in-memory without disk writes"""
        if current_depth >= self.max_depth:
            raise RecursionError(f"Maximum nesting depth {self.max_depth} reached")
        
        with io.BytesIO(zip_data) as zip_buffer:
            with zipfile.ZipFile(zip_buffer) as zf:
                for file_info in zf.namelist():
                    file_data = zf.read(file_info)
                    
                    if file_info.lower().endswith('.zip'):
                        # Recursively extract nested zip
                        self.extract_nested_zip_memory(
                            file_data, 
                            current_depth + 1
                        )
                    else:
                        # Store actual document file
                        self.extracted_files.append({
                            'name': file_info,
                            'data': file_data,
                            'depth': current_depth
                        })
        
        return self.extracted_files

# Usage in Azure Function
extractor = NestedZipExtractor(max_depth=10)
files = extractor.extract_nested_zip_memory(sharepoint_zip_data)
for file in files:
    await process_document(file['name'], file['data'])
```

For .NET implementations, System.IO.Compression provides equivalent functionality with similar recursive patterns. The commercial Aspose.ZIP library offers advanced features like 7z and TAR support if needed, but the built-in library suffices for standard ZIP archives. **Implement depth limits to prevent maliciously crafted deeply-nested archives from consuming excessive resources.** Set maximum depth to 10 levels, which accommodates legitimate organizational structures while preventing abuse.

Error handling for corrupt or password-protected archives should log failures to a dead letter queue and continue processing other files. Don't let a single corrupted archive block the entire pipeline. Track extraction metrics including depth distribution, file counts, and extraction times to identify optimization opportunities.

## Multi-format document processing combines specialized libraries with Azure Document Intelligence

Different file types require different extraction approaches. **PyMuPDF (fitz) delivers 10-20x faster PDF text extraction than alternatives** while supporting table detection, image extraction, and native markdown output through the PyMuPDF4LLM package. For scenarios requiring maximum table accuracy, pdfplumber provides superior table extraction capabilities built on pdfminer.six. The AGPL license on PyMuPDF may require consideration for commercial deployments; pypdf offers a permissive BSD license as an alternative despite slower performance.

**Excel processing through pandas enables efficient data extraction and markdown conversion:**

```python
import pandas as pd
from pathlib import Path

def process_excel_for_llm(file_path):
    """Extract Excel data optimized for LLM consumption"""
    excel_file = pd.ExcelFile(file_path)
    chunks = []
    
    for sheet_name in excel_file.sheet_names:
        df = pd.read_excel(excel_file, sheet_name=sheet_name)
        
        # Convert to markdown table format
        markdown_table = df.to_markdown(index=False)
        
        # Add context for better retrieval
        chunk_text = f"""
## Excel Sheet: {sheet_name}
**Source:** {Path(file_path).name}

{markdown_table}

**Summary:** This sheet contains {len(df)} rows and {len(df.columns)} columns
with data about {', '.join(df.columns.tolist())}.
        """
        chunks.append(chunk_text)
    
    return chunks
```

Word documents process cleanly through python-docx for extracting paragraphs and tables, while PowerPoint requires python-pptx for slide content and embedded tables. CSV files convert efficiently to markdown using pandas.to_markdown(), which produces LLM-friendly table formats that models parse effectively.

**Azure Document Intelligence (formerly Form Recognizer) excels at scanned documents, complex layouts, and structured forms.** The Layout model provides semantic chunking based on document structure, extracts tables with preservation of hierarchies, and outputs markdown directly. This service charges per page analyzed, with 500 pages free monthly. For the POV phase processing primarily born-digital office documents, open-source libraries provide better cost efficiency. **Reserve Azure Document Intelligence for scanned PDFs, handwritten notes, and prebuilt form types like invoices or receipts** where its OCR and structure understanding justify the per-page cost.

**Universal document processor supporting all required formats:**

```python
import fitz  # PyMuPDF
from docx import Document
from pptx import Presentation
import pandas as pd
from pathlib import Path

class UniversalDocumentProcessor:
    def process_pdf(self, file_path):
        doc = fitz.open(file_path)
        text = []
        for page_num, page in enumerate(doc):
            page_text = page.get_text()
            text.append(f"[Page {page_num + 1}]\n{page_text}")
        return "\n\n".join(text)
    
    def process_word(self, file_path):
        doc = Document(file_path)
        text = []
        
        # Extract paragraphs
        for para in doc.paragraphs:
            if para.text.strip():
                text.append(para.text)
        
        # Extract tables as markdown
        for table in doc.tables:
            table_data = [[cell.text for cell in row.cells] 
                         for row in table.rows]
            if table_data:
                df = pd.DataFrame(table_data[1:], columns=table_data[0])
                text.append("\n" + df.to_markdown(index=False))
        
        return "\n\n".join(text)
    
    def process_powerpoint(self, file_path):
        prs = Presentation(file_path)
        text = []
        
        for slide_num, slide in enumerate(prs.slides):
            slide_text = [f"[Slide {slide_num + 1}]"]
            
            for shape in slide.shapes:
                if hasattr(shape, "text") and shape.text.strip():
                    slide_text.append(shape.text)
                
                if shape.has_table:
                    table_data = [[cell.text for cell in row.cells] 
                                 for row in shape.table.rows]
                    df = pd.DataFrame(table_data[1:], columns=table_data[0])
                    slide_text.append(df.to_markdown(index=False))
            
            text.append("\n".join(slide_text))
        
        return "\n\n".join(text)
    
    def process_excel(self, file_path):
        excel_file = pd.ExcelFile(file_path)
        sheets = []
        
        for sheet_name in excel_file.sheet_names:
            df = pd.read_excel(excel_file, sheet_name=sheet_name)
            sheets.append(f"## {sheet_name}\n{df.to_markdown(index=False)}")
        
        return "\n\n".join(sheets)
    
    def process_csv(self, file_path):
        df = pd.read_csv(file_path)
        return df.to_markdown(index=False)
    
    def process_document(self, file_path):
        """Route to appropriate processor based on file extension"""
        suffix = Path(file_path).suffix.lower()
        
        processors = {
            '.pdf': self.process_pdf,
            '.docx': self.process_word,
            '.doc': self.process_word,
            '.xlsx': self.process_excel,
            '.xls': self.process_excel,
            '.pptx': self.process_powerpoint,
            '.csv': self.process_csv,
            '.txt': lambda p: Path(p).read_text(encoding='utf-8')
        }
        
        if suffix in processors:
            return processors[suffix](file_path)
        else:
            raise ValueError(f"Unsupported file type: {suffix}")
```

Tables require special handling to preserve structure for LLMs. **Convert all tables to markdown format** rather than plain text, as GPT-4o and GPT-5 understand markdown table syntax effectively. Pandas .to_markdown() method produces clean, token-efficient representations. Keep small tables intact within single chunks; for large tables exceeding chunk size limits, split by rows while maintaining column headers. Add contextual information above tables describing their contents and source for improved retrieval relevance.

## Document chunking strategy balances context preservation with retrieval precision

**Token-based chunking with 512-token chunks and 50-token overlap** provides optimal balance for Azure OpenAI embeddings. The text-embedding-3-large model supports 8,191 token inputs, but smaller chunks improve retrieval precision by matching more specifically to user queries. Overlap ensures that concepts spanning chunk boundaries remain searchable. For technical nutrition documents containing experimental data, 512-token chunks (approximately 2,000 characters) capture complete experimental procedures or results without fragmenting context.

LangChain's RecursiveCharacterTextSplitter provides production-ready implementation with token counting via tiktoken:

```python
from langchain.text_splitters import CharacterTextSplitter

text_splitter = CharacterTextSplitter.from_tiktoken_encoder(
    encoding_name="cl100k_base",  # GPT-3.5/4 encoding
    chunk_size=512,                # tokens
    chunk_overlap=50,              # 10% overlap
    separators=["\n\n", "\n", ". ", " ", ""]
)

# Process document with metadata
chunks = []
for i, chunk_text in enumerate(text_splitter.split_text(document_text)):
    chunks.append({
        'id': f"{document_id}_chunk_{i}",
        'content': chunk_text,
        'document_title': document_metadata['title'],
        'source_file': document_metadata['filename'],
        'chunk_index': i,
        'experiment_id': extract_experiment_id(chunk_text),
        'metadata': document_metadata
    })
```

**Semantic chunking using Azure Document Intelligence Layout model** offers superior quality by respecting document structure. This approach chunks at paragraph and section boundaries rather than arbitrary character counts, preserving semantic coherence. The Layout model outputs markdown that maintains headings, lists, and tables. For the POV phase, start with fixed-size token chunking for simplicity and cost efficiency, then evaluate semantic chunking in production if retrieval quality requires enhancement.

LangChain's SemanticChunker uses embeddings to identify natural breakpoints based on semantic similarity between sentences. This approach produces variable-sized chunks that maintain topical coherence but requires embedding each sentence during chunking, increasing processing cost. **Reserve semantic chunking for high-value document collections** where retrieval quality justifies additional processing time and embedding costs.

**Chunk metadata enrichment dramatically improves filtering and relevance.** For nutrition documents, include experiment IDs, nutritional components, formulation types, study dates, and compound names as separate indexed fields. This enables hybrid queries combining vector similarity with metadata filters: "Find vitamin D studies from 2024" becomes a vector search for vitamin D semantics filtered to study_date >= 2024-01-01.

## Durable Functions orchestration delivers optimal ETL architecture for POV requirements

**Azure Durable Functions emerges as the recommended orchestration service** for this use case, providing stateful workflow coordination with built-in retry logic, checkpointing for resumability, and fan-out patterns for parallel document processing. This architecture handles all key requirements: extracting nested zips, processing multiple file formats, generating embeddings, and batching uploads to Azure AI Search. Cost runs $5-20 monthly for POV workloads in the Consumption plan with automatic scaling.

Azure Data Factory suits large-scale production deployments (100GB+ daily) but introduces unnecessary complexity for POV phase. Logic Apps offers low-code development but becomes expensive at scale ($200+ monthly) and provides less control over zip extraction logic. **The native Azure AI Search SharePoint indexer remains in preview** with significant limitations including no support for nested zips, no custom preprocessing, and broken incremental sync when folders rename. Microsoft explicitly recommends Microsoft Copilot Studio for production SharePoint indexing instead.

**Production-ready Durable Functions architecture:**

```
Timer Trigger (15 min) → Business Hours Check → Orchestrator Function
    ↓
Get Changed Files (Delta Query) → Fan-Out: Process Documents
    ↓
Parallel Activities:
├─ Extract Zip (if needed)
├─ Extract Text (multi-format)
├─ Chunk Document (512 tokens)
├─ Generate Embeddings (batch 16)
└─ Upload to Search (batch 100)
    ↓
Update State (delta tokens, checksums)
```

**Timer trigger with business hours enforcement:**

```python
import azure.functions as func
import azure.durable_functions as df
from datetime import datetime
from pytz import timezone

app = df.DFApp(http_auth_level=func.AuthLevel.ANONYMOUS)

@app.timer_trigger(schedule="0 */15 * * * *", arg_name="timer")
@app.durable_client_input(client_name="client")
async def timer_trigger(timer: func.TimerRequest, client):
    """Trigger every 15 minutes during business hours"""
    est = timezone('US/Eastern')
    now = datetime.now(est)
    
    is_business_hours = (
        now.weekday() < 5 and           # Monday-Friday
        9 <= now.hour < 17 and          # 9am-5pm
        not is_holiday(now.date())      # Exclude holidays
    )
    
    if is_business_hours:
        instance_id = await client.start_new("orchestrator_main")
        return {"status": "started", "instance_id": instance_id}
    
    return {"status": "skipped", "reason": "outside business hours"}

@app.orchestration_trigger(context_name="context")
def orchestrator_main(context: df.DurableOrchestrationContext):
    """Main orchestration workflow"""
    # Get files changed since last sync
    changed_files = yield context.call_activity("get_changed_files")
    
    # Fan-out: Process documents in parallel (max 100 concurrent)
    tasks = []
    for file in changed_files:
        tasks.append(context.call_activity("process_document", file))
    
    results = yield context.task_all(tasks)
    
    # Collect successful chunks
    all_chunks = []
    for result in results:
        if result['status'] == 'success':
            all_chunks.extend(result['chunks'])
    
    # Batch upload to Azure AI Search (100 docs per batch)
    for i in range(0, len(all_chunks), 100):
        batch = all_chunks[i:i+100]
        yield context.call_activity("upload_to_search", batch)
    
    # Update sync state
    yield context.call_activity("update_delta_token", changed_files[-1])
    
    return {"processed": len(results), "chunks_indexed": len(all_chunks)}

@app.activity_trigger(input_name="file_info")
async def process_document(file_info: dict):
    """Process single document through complete pipeline"""
    try:
        # Download from SharePoint
        file_data = await download_file(file_info['url'])
        
        # Handle zips
        if file_info['name'].endswith('.zip'):
            extractor = NestedZipExtractor()
            files = extractor.extract_nested_zip_memory(file_data)
        else:
            files = [{'name': file_info['name'], 'data': file_data}]
        
        # Process each extracted file
        all_chunks = []
        for file in files:
            text = extract_text(file['data'], file['name'])
            chunks = chunk_text(text, 512)
            embeddings = generate_embeddings_batch(chunks)
            
            for chunk, embedding in zip(chunks, embeddings):
                all_chunks.append({
                    'id': generate_chunk_id(file_info, chunk),
                    'content': chunk,
                    'content_vector': embedding,
                    'source_file': file_info['name'],
                    'document_title': file_info['title'],
                    'study_date': file_info.get('modified_date')
                })
        
        return {'status': 'success', 'chunks': all_chunks}
    
    except Exception as e:
        return {'status': 'failed', 'error': str(e), 'file': file_info['name']}
```

State management across multiple Azure Storage components ensures resumability. **Azure Table Storage persists delta tokens and file processing status**, tracking which files completed successfully and which require retry. Durable Functions automatically persists orchestration state in Azure Storage, enabling replay after failures without reprocessing completed activities. For long-running pipelines approaching end of business hours, implement graceful shutdown that saves checkpoints and resumes the next business day.

**Retry logic with exponential backoff handles transient failures:**

```python
from azure.durable_functions import RetryOptions

retry_options = RetryOptions(
    first_retry_interval_in_milliseconds=5000,      # 5 seconds
    max_number_of_attempts=3,
    backoff_coefficient=2,                          # Exponential
    max_retry_interval_in_milliseconds=60000,       # Max 1 minute
    retry_timeout_in_milliseconds=300000            # 5 minute total timeout
)

result = yield context.call_activity_with_retry(
    'generate_embeddings',
    retry_options,
    chunk_batch
)
```

Dead letter queues in Azure Service Bus capture permanently failed documents after retry exhaustion. Monitor DLQ depth and configure alerts when it exceeds 10 messages. Implement separate processing for DLQ review, allowing manual intervention or modified retry logic for edge cases. Common causes include corrupt files, permission errors, and API throttling - track failure categories to identify systemic issues.

## Azure AI Search hybrid configuration maximizes retrieval quality for nutrition queries

**Text-embedding-3-large with 1024 dimensions provides optimal balance** between embedding quality and storage efficiency for nutrition documents. This model, released in 2024, achieves 54.9% MIRACL performance versus 31.4% for the deprecated text-embedding-ada-002. The 1024-dimensional configuration reduces storage by 33% compared to the 1536-dimensional default while maintaining 99% of quality. Note that text-embedding-ada-002 reaches deprecation on October 3, 2025; all new implementations should use the 3-series models.

Azure AI Search supports hybrid search combining keyword (BM25), vector similarity, and semantic ranking through a multi-stage retrieval process. **Hybrid search addresses complementary weaknesses**: keyword search provides precision for exact compound names and experiment IDs, while vector search captures semantic relationships like "bone density" matching "osteoporosis prevention studies." Reciprocal Rank Fusion (RRF) combines rankings from both approaches, then semantic ranking reorders the top 50 results using Microsoft's language models for final relevance optimization.

**Complete index schema for nutrition documents:**

```json
{
  "name": "nutrition-data-index",
  "fields": [
    {
      "name": "chunk_id",
      "type": "Edm.String",
      "key": true,
      "filterable": true,
      "sortable": true
    },
    {
      "name": "parent_document_id",
      "type": "Edm.String",
      "filterable": true
    },
    {
      "name": "document_title",
      "type": "Edm.String",
      "searchable": true,
      "filterable": true,
      "sortable": true
    },
    {
      "name": "chunk_content",
      "type": "Edm.String",
      "searchable": true,
      "analyzer": "standard.lucene"
    },
    {
      "name": "chunk_vector",
      "type": "Collection(Edm.Single)",
      "dimensions": 1024,
      "vectorSearchProfile": "nutrition-vector-profile",
      "searchable": true,
      "retrievable": false,
      "stored": false
    },
    {
      "name": "experiment_id",
      "type": "Edm.String",
      "searchable": true,
      "filterable": true,
      "facetable": true
    },
    {
      "name": "nutritional_components",
      "type": "Collection(Edm.String)",
      "searchable": true,
      "filterable": true,
      "facetable": true
    },
    {
      "name": "compound_names",
      "type": "Collection(Edm.String)",
      "searchable": true,
      "filterable": true
    },
    {
      "name": "formulation_type",
      "type": "Edm.String",
      "filterable": true,
      "facetable": true
    },
    {
      "name": "study_date",
      "type": "Edm.DateTimeOffset",
      "filterable": true,
      "sortable": true,
      "facetable": true
    },
    {
      "name": "measurement_values",
      "type": "Edm.String",
      "searchable": true
    },
    {
      "name": "metadata_json",
      "type": "Edm.String",
      "retrievable": true
    }
  ],
  "vectorSearch": {
    "algorithms": [
      {
        "name": "nutrition-hnsw",
        "kind": "hnsw",
        "hnswParameters": {
          "m": 4,
          "efConstruction": 400,
          "metric": "cosine"
        }
      }
    ],
    "profiles": [
      {
        "name": "nutrition-vector-profile",
        "algorithm": "nutrition-hnsw",
        "vectorizer": "nutrition-vectorizer"
      }
    ],
    "vectorizers": [
      {
        "name": "nutrition-vectorizer",
        "kind": "azureOpenAI",
        "azureOpenAIParameters": {
          "resourceUri": "https://<resource>.openai.azure.com",
          "deploymentId": "text-embedding-3-large",
          "modelName": "text-embedding-3-large"
        }
      }
    ]
  },
  "semantic": {
    "configurations": [
      {
        "name": "nutrition-semantic-config",
        "prioritizedFields": {
          "titleField": {
            "fieldName": "document_title"
          },
          "prioritizedContentFields": [
            {"fieldName": "chunk_content"},
            {"fieldName": "measurement_values"}
          ],
          "prioritizedKeywordsFields": [
            {"fieldName": "nutritional_components"},
            {"fieldName": "compound_names"}
          ]
        }
      }
    ]
  }
}
```

Critical schema optimizations reduce costs and improve performance. **Setting retrievable=false and stored=false on vector fields** eliminates redundant storage since embeddings need not return in query results, reducing index size by 30-40%. Use keyword analyzer for exact-match fields like experiment_id and compound_names. Mark fields searchable, filterable, or facetable only when required - each attribute can quadruple storage requirements for that field.

**Hybrid search query implementation:**

```python
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizedQuery
from azure.identity import DefaultAzureCredential

def hybrid_search_nutrition(query_text: str):
    """Execute hybrid search with semantic ranking"""
    # Generate query embedding
    query_vector = generate_embedding(query_text)
    
    # Configure vector search component
    vector_query = VectorizedQuery(
        vector=query_vector,
        k_nearest_neighbors=50,  # Set to 50 for semantic ranker
        fields="chunk_vector"
    )
    
    # Execute hybrid search
    search_client = SearchClient(
        endpoint=os.environ['SEARCH_ENDPOINT'],
        index_name="nutrition-data-index",
        credential=DefaultAzureCredential()
    )
    
    results = search_client.search(
        search_text=query_text,              # Keyword component
        vector_queries=[vector_query],        # Vector component
        select=["chunk_id", "chunk_content", "document_title", 
                "nutritional_components", "measurement_values"],
        filter="study_date ge 2023-01-01",   # Optional metadata filter
        query_type="semantic",                # Enable semantic ranking
        semantic_configuration_name="nutrition-semantic-config",
        query_caption="extractive|highlight-true",
        top=10
    )
    
    return results
```

**Set k_nearest_neighbors=50 for vector queries when using semantic ranking**, as the L2 semantic reranker operates on the top 50 results from the L1 retrieval stage. Semantic ranking applies Microsoft's language models to reorder results by semantic relevance, extract highlighted captions, and generate direct answers to questions. This capability increased maximum summary tokens to 2,048 in November 2024, supporting richer context extraction from nutrition documents.

## Azure AI Foundry integration enables GPT-4o and GPT-5 RAG workflows

Azure AI Foundry (formerly Azure AI Studio) provides unified orchestration for RAG applications combining Azure AI Search retrieval with GPT model generation. **The platform offers GPT-4o for production RAG deployments with 128K context windows and general availability status**. GPT-4o handles multi-modal inputs including images from nutrition documents, processes tables effectively, and maintains strong instruction-following for consistent output formatting.

GPT-5 series models released in 2025 provide enhanced reasoning capabilities with GPT-5 offering 272K context and GPT-5-chat optimized for multi-turn conversations at 128K context. However, native Azure AI Search "Add your data" integration for GPT-5 remains incomplete. **Workaround: Deploy GPT-4o or GPT-4.1 agents with Azure AI Search integration**, then route complex reasoning tasks to GPT-5 agents through multi-agent orchestration.

**RAG implementation with Azure AI Foundry:**

```python
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential

project_client = AIProjectClient(
    credential=DefaultAzureCredential(),
    subscription_id=os.environ['AZURE_SUBSCRIPTION_ID'],
    resource_group_name=os.environ['RESOURCE_GROUP'],
    project_name=os.environ['PROJECT_NAME']
)

def create_nutrition_data_source():
    """Configure Azure AI Search as RAG data source"""
    return {
        "type": "azure_search",
        "parameters": {
            "endpoint": os.environ['SEARCH_ENDPOINT'],
            "index_name": "nutrition-data-index",
            "semantic_configuration": "nutrition-semantic-config",
            "query_type": "vector_simple_hybrid",
            "fields_mapping": {
                "content_fields": ["chunk_content"],
                "title_field": "document_title",
                "vector_fields": ["chunk_vector"]
            },
            "authentication": {
                "type": "system_assigned_managed_identity"
            },
            "embedding_dependency": {
                "type": "deployment_name",
                "deployment_name": "text-embedding-3-large"
            },
            "in_scope": True,
            "strictness": 3,
            "top_n_documents": 5
        }
    }

def query_nutrition_rag(user_question: str):
    """Execute RAG query with GPT-4o"""
    messages = [
        {
            "role": "system",
            "content": """You are a nutrition research assistant with expertise in 
            analyzing experimental data and formulations. When answering questions:
            - Cite specific experiment IDs and study dates from the documents
            - Include relevant measurement values and statistical significance
            - Note any methodological limitations or caveats
            - Always provide document citations for claims"""
        },
        {
            "role": "user",
            "content": user_question
        }
    ]
    
    response = project_client.inference.get_chat_completions(
        model="gpt-4o",
        messages=messages,
        data_sources=[create_nutrition_data_source()],
        temperature=0.3,  # Lower temperature for factual accuracy
        max_tokens=1500
    )
    
    return response
```

Prompt Flow within Azure AI Foundry enables visual orchestration of RAG pipelines with modular components. Build flows connecting user input → embedding generation → hybrid search → context assembly → GPT generation → response formatting. This approach facilitates A/B testing different prompts, switching between GPT models, and monitoring token usage across pipeline stages. **For POV demonstrations to leadership, Prompt Flow's visual interface effectively communicates the technical architecture** while providing actual working implementation.

The in_scope parameter restricts responses to retrieved documents rather than general knowledge, preventing hallucination. Set strictness to 3 (default) for balanced filtering; increase to 5 for highly precise retrieval that may miss relevant context, or decrease to 1 for broader recall. Monitor citation patterns - if responses consistently lack citations, increase top_n_documents from 5 to 10 or adjust retrieval parameters.

## POV phase requires Basic tier infrastructure with business hours optimization

**Recommended POV configuration minimizes costs while demonstrating capabilities:**

- Azure AI Search: Basic tier ($75/month) supporting 50,000-150,000 documents, 15 indexes, and 45GB storage
- Azure OpenAI: Pay-as-you-go with text-embedding-3-large for embeddings ($0.00013 per 1K tokens) and GPT-4o-mini for query enhancement ($0.15 per 1M input tokens)
- Azure Functions: Consumption plan ($5-20/month) with first 1M executions free
- Azure Blob Storage: Hot tier ($1.80/month per 100GB)
- Application Insights: 5GB monthly ingestion with 20% sampling ($10/month)

**Total POV monthly cost: $100-120 for small deployment (10K-50K documents, 100 users)**

Business hours scheduling (9am-5pm, Monday-Friday) reduces compute costs by 67% compared to 24/7 operation. Combined with delta query incremental sync processing only changed files, this approach minimizes both API usage and compute time. For the POV phase with infrequent data updates, 15-minute sync intervals during business hours provide adequate freshness without overwhelming systems.

**Cost optimization strategies for POV:**

1. **Batch embeddings 16 texts per API call** to Azure OpenAI, reducing request overhead
2. **Use 1024-dimensional embeddings** instead of 1536 to reduce storage by 33%
3. **Implement 20% sampling in Application Insights** to control monitoring costs
4. **Set 7-day retention on temporary files** with automatic deletion lifecycle policies
5. **Start with single replica in Basic tier** - acceptable for POV, not production
6. **Cache frequently accessed query embeddings** in Redis to avoid redundant generation

**Success metrics demonstrating value to leadership should include:**

- **Search success rate improvement**: Percentage of searches resulting in relevant document clicks (target: 70%+ vs. typical 40-60% SharePoint baseline)
- **Time to information**: Average minutes to locate specific data (target: 50%+ reduction from baseline)
- **Zero-result rate**: Queries returning no results (target: <5% vs. 15-20% typical SharePoint)
- **User satisfaction score**: Monthly survey of pilot users (target: 8+/10)
- **Adoption rate**: Percentage of pilot users actively searching daily (target: 80%+)

**ROI calculation framework for leadership presentations:**

```
Annual Time Savings Calculation:
- Pilot users: 100 nutrition researchers
- Average time saved per search: 5 minutes
- Searches per day: 10
- Total daily savings: 100 users × 10 searches × 5 minutes = 5,000 minutes = 83 hours
- Hourly rate (loaded): $75
- Daily value: 83 hours × $75 = $6,225
- Annual value: $6,225 × 250 workdays = $1,556,250

Annual Cost:
- Infrastructure: $120/month × 12 = $1,440
- Implementation: $50,000 one-time (allocated over 3 years = $16,667/year)
- Support: $10,000/year
- Total annual cost: $28,107

ROI = ($1,556,250 - $28,107) / $28,107 = 5,436%
Payback period: 6.6 days
```

Conservative estimates using 2 minutes saved per search and 5 searches daily still yield 1,089% ROI. **Frame the POV as risk mitigation** - the $360 three-month cost represents minimal investment to validate assumptions before committing to production infrastructure. Include qualitative benefits like improved research quality from finding previously undiscovered relevant studies and reduced duplicate experimental work.

## Production scaling path multiplies infrastructure requirements

Transitioning from POV to production requires architectural enhancements for high availability, security hardening, and performance optimization. **Production deployment needs 2-3 replicas for SLA compliance** (99.9% uptime with 2 replicas for read operations, 3 for read-write). Upgrade from Basic to Standard S1 tier for increased partition limits, more concurrent queries, and better CPU/memory resources.

**Production infrastructure changes:**

- Azure AI Search: Standard S1 (1 partition, 2 replicas) = $500/month
- Multi-region deployment: Secondary search service in different region for disaster recovery
- Azure API Management: Rate limiting, authentication, usage tracking ($140/month Developer tier)
- Azure Monitor: Full observability with custom metrics and dashboards
- Virtual Network integration: Private endpoints for Azure AI Search and Storage
- Azure DevOps/GitHub Actions: CI/CD pipelines for automated index updates
- Professional support: Standard or Professional Direct support plan

**Total production monthly cost: $700-800 for small-scale (10K-50K documents)**

Scale testing should verify performance at 2x expected peak load. For 500 concurrent users with 10 searches per user per hour, test at 1,000 concurrent users querying 10 times per hour. Monitor query latency (target: <200ms for standard queries, <2s for AI-enhanced), indexing throughput, and API throttling rates. Azure AI Search services created after April 2024 receive 6x more storage and 2x better throughput compared to legacy services, improving cost-efficiency at scale.

**Scaling strategy by document volume:**

- 100K-500K documents: Standard S2 (2 partitions, 3 replicas) = $6,000/month
- 500K-1M documents: Standard S2-S3 (3 partitions, 3 replicas) = $12,000-18,000/month
- 1M+ documents: Standard S3 with careful partitioning strategy

Implement gradual rollout starting with 10% of users in pilot phase, expanding to 50% in staged rollout, then 100% in general availability. Monitor adoption rates, query patterns, and failure rates at each stage. **Establish clear rollback criteria** including: sustained error rate above 5%, query latency above 3 seconds P95, or user satisfaction below 7/10.

## Real-world implementations provide proven architectural patterns

Microsoft's official reference architecture "Automate Document Classification with Durable Functions" demonstrates production-ready patterns for document processing pipelines. This architecture uses Azure Service Bus queues to trigger Durable Functions orchestrations, processes documents through Azure AI Document Intelligence, stores metadata in Cosmos DB, and indexes chunks in Azure AI Search. **The correlation ID pattern links search results back to full documents** - search returns chunk IDs, application retrieves complete document metadata from Cosmos DB using correlation IDs stored in each chunk.

The Azure-Samples/azure-search-openai-demo GitHub repository (10K+ stars) provides complete working implementation of ChatGPT-style search over custom documents. Features include integrated vectorization through Azure AI Search indexers, citation rendering with source highlighting, optional GPT-4 with vision for image-heavy documents, and user authentication through Microsoft Entra. **Deploy in 30 minutes using Azure Developer CLI** with estimated costs of $50-200/month depending on usage patterns.

For enterprise deployments requiring zero-trust security, the Azure/GPT-RAG repository implements comprehensive RBAC, network isolation, and Key Vault integration. The architecture separates concerns into orchestrator, web UI, and data ingestion components with auto-loader supporting incremental processing. This pattern aligns with enterprise security requirements for production nutrition data containing proprietary formulations.

**SharePoint integration approaches vary by requirements:**

The preview Azure AI Search SharePoint Online indexer provides native connectivity but includes significant limitations: no nested zip support, broken incremental sync when folders rename, no custom preprocessing logic, and no support for SharePoint lists or sub-sites. Microsoft's documentation explicitly recommends Microsoft Copilot Studio for production SharePoint indexing rather than this indexer.

**Recommended production approach uses Microsoft Graph API as primary extraction method**, storing documents in Azure Blob Storage as an intermediate layer, then using Azure Blob Storage indexer for final ingestion. This architecture provides better incremental tracking through delta tokens, supports custom preprocessing for zip extraction and multi-format processing, and enables security trimming through ACL handling. The intermediate storage layer also facilitates debugging and audit trails.

Community implementations like the AzureSearch.SharePointOnline connector demonstrate custom patterns bridging SharePoint and Azure AI Search through blob storage intermediation. These approaches discover documents via SharePoint APIs, extract metadata from custom columns, and associate SharePoint permissions with indexed content for security trimming.

## Architectural recommendations and implementation timeline

**Recommended POV architecture combines Durable Functions orchestration with Azure AI Search hybrid search:**

```
SharePoint Online (source)
    ↓ Delta Query API (every 15 min, business hours)
Azure Function (webhook receiver)
    ↓ Queue changed files
Azure Storage Queue
    ↓ Trigger orchestration
Durable Functions Orchestrator
    ├─ Extract nested zips (recursive)
    ├─ Process documents (parallel, 100 concurrent)
    │   ├─ Extract text (PyMuPDF/pandas/python-docx)
    │   ├─ Chunk (512 tokens, 50 overlap)
    │   └─ Embed (text-embedding-3-large, batch 16)
    └─ Batch upload (100 docs per batch)
        ↓
Azure AI Search (Basic tier)
    ├─ Hybrid search (keyword + vector)
    ├─ Semantic ranking (top 50 results)
    └─ 1024-dim vectors
        ↓
Azure AI Foundry
    └─ GPT-4o RAG queries
        ↓
User Interface (Prompt Flow/custom app)
```

**Implementation timeline for 6-week POV:**

**Week 1: Foundation Setup**
- Provision Azure resources (AI Search Basic, OpenAI, Functions, Storage)
- Configure managed identity with SharePoint permissions (Sites.Selected for specific site)
- Implement Microsoft Graph API delta query integration
- Set up Application Insights monitoring

**Week 2: Document Processing Pipeline**
- Build nested zip extractor with depth limits and error handling
- Implement multi-format text extraction (PDF, Excel, Word, PowerPoint, CSV)
- Develop chunking logic with token counting (512 tokens, 50 overlap)
- Create embedding generation with batching (16 texts per call)

**Week 3: Search Infrastructure**
- Design and create Azure AI Search index schema with nutrition-specific fields
- Configure vector search with HNSW algorithm and 1024 dimensions
- Set up semantic ranking configuration
- Implement hybrid search queries

**Week 4: Orchestration and Scheduling**
- Build Durable Functions orchestrator with fan-out parallelization
- Implement business hours scheduling with holiday exclusions
- Configure state management with Azure Table Storage for delta tokens
- Add retry logic with exponential backoff and dead letter queue

**Week 5: Integration and Testing**
- Integrate Azure AI Foundry with GPT-4o for RAG queries
- Build user interface (Prompt Flow or custom application)
- Test with sample nutrition documents spanning all file types
- Performance testing with concurrent operations

**Week 6: Documentation and Demonstration**
- Compile metrics comparing SharePoint baseline to new search
- Create leadership presentation with ROI calculations
- Document architecture and operational procedures
- Train pilot users and gather initial feedback

**Critical success factors for POV:**

1. **Establish quantitative baseline metrics** before deploying new search - current search success rate, average time to find documents, zero-result query percentage
2. **Select representative pilot user group** (20-30 nutrition researchers) representing diverse use cases and technical proficiency levels
3. **Weekly feedback sessions** to identify usability issues early and demonstrate iteration responsiveness
4. **Monitor costs daily** through Azure Cost Management with alerts at 80% of budget
5. **Document specific examples** of time savings and research insights discovered through improved search

**Risk mitigation strategies:**

- **Technical risk**: Implement comprehensive error handling and monitoring from day one to quickly identify issues
- **Data quality risk**: Validate text extraction accuracy on sample documents before full processing
- **Adoption risk**: Provide training sessions and quick reference guides for pilot users
- **Cost overrun risk**: Set Azure budget alerts and implement query rate limiting
- **Schedule risk**: Use proven reference implementations rather than building from scratch

The architecture scales naturally to production through tier upgrades and replica additions without fundamental redesign. Delta query incremental sync minimizes disruption to R&D teams by processing only changed files during business hours. Comprehensive error handling with dead letter queues ensures no data loss during processing failures. This foundation enables demonstrating transformative search capabilities to justify production investment and eventual ZFS migration.
