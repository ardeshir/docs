# Azure RAG multi-species nutrition research.

## Architecture Strategy


### 1. **SharePoint Integration Layer**

Since data lives in SharePoint:

- **Microsoft Graph API** for document access and metadata extraction
- **Azure Logic Apps or Functions** to monitor SharePoint for document updates (webhooks for real-time, or scheduled polling)
- Consider **SharePoint Online Management Shell** for bulk operations during initial ingestion

### 2. **Document Processing Pipeline**

Robust extraction since we have mixed formats:

- **Azure Document Intelligence (formerly Form Recognizer)** - excellent for PDFs and complex layouts
- **For Excel files**: Direct parsing for structured data, but also consider converting sheets to markdown/text for better LLM understanding
- **For PowerPoint**: Extract both text and potentially image descriptions (Azure Computer Vision if slides contain charts/diagrams)
- **For Word docs**: Relatively straightforward with python-docx or similar

### 3. **Metadata Strategy** (Critical for use case!)

This is where we can really add value beyond basic RAG

```python
# Example metadata schema
{
    "document_id": "...",
    "species": ["swine", "ruminants"],  # Multi-value for comparative studies
    "document_type": "protocol|report|study|analysis",
    "innovation_center": "center_name",
    "research_area": "nutrition|digestion|growth|health",
    "date_published": "...",
    "authors": [...],
    "related_protocols": [...],  # Cross-references
    "version": "..."
}
```

### 4. **RAG Enhancement for Research Domain**

**Chunking Strategy:**

- Protocols often have hierarchical structure (materials → methods → results)
- Consider **semantic chunking** over fixed-size chunks
- Maintain section headers as metadata for better context

**Hybrid Search:**

- **Dense embeddings** (Azure OpenAI ada-002 or text-embedding-3) for semantic search
- **Sparse/keyword search** (Azure AI Search BM25) for exact protocol numbers, chemical names, specific measurements
- Combine both for best results

**Vector Database Options:**

- **Azure AI Search** (my recommendation - native Azure integration, hybrid search built-in)
- Azure Cosmos DB with vector search
- Your existing setup probably uses one of these already

### 5. **Query Understanding & Routing**

For research scientists, we'll want:

**Query classification:**

```
"What's the protein requirement for growing swine?" 
→ Factual lookup across multiple protocols

"Compare ruminant digestion protocols between Iowa and Minnesota centers"
→ Comparative analysis + center filtering

"Show me the latest vitamin supplementation reports"
→ Temporal filtering + document type filtering
```

**LLM Features to Build:**

- **Citation with source documents** - critical for research validity
- **Cross-species comparison** - “How does this differ between swine and ruminants?”
- **Protocol version tracking** - researchers need to know which version they’re referencing
- **Data extraction from Excel/tables** - “What were the growth rates in study X?”

### 6. **Integration Points**

Since we want to extend existing Azure applications:

**API Layer** (see https://api.cargillai.com):

- Expose REST API similar to your [cargillai.com](http://cargillai.com) demo
- Consider adding **streaming responses** for long answers
- **SSO integration** with Azure AD for scientist authentication

**Potential Integrations:**

- **Teams bot** - scientists can query from Teams
- **SharePoint embedded app** - query within the document library itself
- **Power BI integration** - if they use dashboards
- **Outlook add-in** - query while drafting emails/reports

## Implementation Phases

**Phase 1: Foundation (Weeks 1-3)**

- SharePoint connector + document ingestion pipeline
- Metadata extraction and enrichment
- Azure AI Search index setup with hybrid search
- Basic RAG query endpoint

**Phase 2: Domain Optimization (Weeks 4-6)**

- Gather stakeholder queries (you mentioned this is coming)
- Refine chunking and metadata based on actual use cases
- Add species-specific and center-specific filtering
- Citation and source tracking

**Phase 3: Integration & UX (Weeks 7-10)**

- Build preferred interface(s) - Teams, Web, etc.
- Add comparative analysis features
- Implement feedback loop for improving results
- Testing with 10 scientists

## Key Considerations for Your Domain

**1. Data Quality & Versioning:**

- Research protocols get updated - need version control
- Consider marking deprecated protocols
- Link related documents (protocol → reports using that protocol)

**2. Regulatory & Compliance:**

- Animal research may have compliance requirements
- Audit trail for queries if needed
- Data retention policies

**3. Specialized Terminology:**

- Fine-tune embeddings or use domain-specific vocabulary if needed
- Build glossary of terms shared across species
- Handle abbreviations common in nutrition research

## Quick Win: MVP Scope

For initial build with 10 scientists:

1. Index all SharePoint documents with basic metadata
1. Hybrid search with Azure AI Search
1. Simple web interface (extend your Rust WASM client?)
1. Focus on 2-3 most common query types from stakeholders
1. Always cite sources with document links

-----

**Next Steps for You:**

1. **Gather those stakeholder queries** - this will heavily influence your chunking strategy and metadata schema
1. **Map out your SharePoint structure** - how many sites, how documents are organized by species/center
1. **Choose your initial interface** - Teams bot? Web app? Both?

**Questions for you:**

- Use Azure AI Search set up, or are we using a different vector store?
- What’s your LLM preference - Azure OpenAI GPT-4? Something else?
- Are there any existing taxonomy or tagging systems in SharePoint you can leverage?
- Timeline expectations from your Project Owner?
