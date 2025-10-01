# Azure RAG multi-species nutrition research

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
- Our existing setup probably uses one of these already

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

- Expose REST API similar to our [cargillai.com](https://api.cargillai.com) demo
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

- Gather stakeholder queries 
- Refine chunking and metadata based on actual use cases
- Add species-specific and center-specific filtering
- Citation and source tracking

**Phase 3: Integration & UX (Weeks 7-10)**

- Build preferred interface(s) - Teams, Web, etc.
- Add comparative analysis features
- Implement feedback loop for improving results
- Testing with 10 scientists

## Key Considerations for Our Domain

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
1. Simple web interface (extend Our Rust WASM client?)
1. Focus on 2-3 most common query types from stakeholders
1. Always cite sources with document links

-----

**Next Steps for You:**

1. **Gather those stakeholder queries** - this will heavily influence Our chunking strategy and metadata schema
1. **Map out our SharePoint structure** - how many sites, how documents are organized by species/center
1. **Choose our initial interface** - Teams bot? Web app? Both?

**Questions for you:**

- Use Azure AI Search set up, or are we using a different vector store?
- What’s our LLM preference - Azure OpenAI GPT-4? Something else?
- Are there any existing taxonomy or tagging systems in SharePoint you can leverage?
- Timeline expectations from our Project Owner?

# Technical Overview 

SharePoint integration -- critical foundation for RAG system. 
Once we have this working, everything else flows from there.


## SharePoint Data Extraction & Indexing Pipeline

Let me give you a concrete architecture for C# + SharePoint + Azure AI Search.

### Architecture Overview

```
SharePoint Sites
    ↓
Microsoft Graph API (C# SDK)
    ↓
Document Processing (extract + chunk)
    ↓
Azure OpenAI Embeddings (text-embedding-3-large)
    ↓
Azure AI Search Index
```

### Step 1: SharePoint Connection with Microsoft Graph

**NuGet Packages you’ll need:**

```xml
<PackageReference Include="Microsoft.Graph" Version="5.x" />
<PackageReference Include="Azure.Identity" Version="1.x" />
<PackageReference Include="Azure.Search.Documents" Version="11.x" />
<PackageReference Include="Azure.AI.OpenAI" Version="1.x" />
```

**Authentication Setup:**

```csharp
using Microsoft.Graph;
using Azure.Identity;

public class SharePointService
{
    private readonly GraphServiceClient _graphClient;
    
    public SharePointService(string tenantId, string clientId, string clientSecret)
    {
        var credential = new ClientSecretCredential(
            tenantId, 
            clientId, 
            clientSecret
        );
        
        _graphClient = new GraphServiceClient(credential);
    }
    
    // Alternative: If running in Azure, use Managed Identity
    public SharePointService()
    {
        var credential = new DefaultAzureCredential();
        _graphClient = new GraphServiceClient(credential);
    }
}
```

**You’ll need to register an App in Azure AD with these permissions:**

- `Sites.Read.All` (or Sites.ReadWrite.All if you need to update metadata)
- `Files.Read.All`

### Step 2: Document Discovery & Extraction

```csharp
public class SharePointDocument
{
    public string Id { get; set; }
    public string Name { get; set; }
    public string WebUrl { get; set; }
    public string FileType { get; set; }
    public DateTime LastModified { get; set; }
    public string SiteId { get; set; }
    public string SiteName { get; set; }
    public Dictionary<string, object> Metadata { get; set; }
}

public class SharePointExtractor
{
    private readonly GraphServiceClient _graphClient;
    
    public async Task<List<SharePointDocument>> GetDocumentsFromSite(
        string siteId, 
        string libraryName = "Documents")
    {
        var documents = new List<SharePointDocument>();
        
        // Get the document library
        var drive = await _graphClient.Sites[siteId]
            .Drives
            .Request()
            .Filter($"name eq '{libraryName}'")
            .GetAsync();
            
        if (drive.Count == 0) return documents;
        
        var driveId = drive[0].Id;
        
        // Get all items recursively
        var items = await GetAllItemsRecursive(siteId, driveId, "root");
        
        foreach (var item in items)
        {
            if (item.File != null) // It's a file, not a folder
            {
                var doc = new SharePointDocument
                {
                    Id = item.Id,
                    Name = item.Name,
                    WebUrl = item.WebUrl,
                    FileType = Path.GetExtension(item.Name).ToLower(),
                    LastModified = item.LastModifiedDateTime?.DateTime ?? DateTime.MinValue,
                    SiteId = siteId,
                    Metadata = ExtractMetadataFromItem(item)
                };
                
                documents.Add(doc);
            }
        }
        
        return documents;
    }
    
    private async Task<List<DriveItem>> GetAllItemsRecursive(
        string siteId, 
        string driveId, 
        string folderId)
    {
        var allItems = new List<DriveItem>();
        
        var items = await _graphClient.Sites[siteId]
            .Drives[driveId]
            .Items[folderId]
            .Children
            .Request()
            .GetAsync();
            
        foreach (var item in items)
        {
            allItems.Add(item);
            
            // If it's a folder, recurse
            if (item.Folder != null)
            {
                var childItems = await GetAllItemsRecursive(siteId, driveId, item.Id);
                allItems.AddRange(childItems);
            }
        }
        
        return allItems;
    }
    
    private Dictionary<string, object> ExtractMetadataFromItem(DriveItem item)
    {
        var metadata = new Dictionary<string, object>();
        
        // Standard metadata
        metadata["created_by"] = item.CreatedBy?.User?.DisplayName ?? "Unknown";
        metadata["created_date"] = item.CreatedDateTime?.DateTime ?? DateTime.MinValue;
        metadata["modified_by"] = item.LastModifiedBy?.User?.DisplayName ?? "Unknown";
        metadata["modified_date"] = item.LastModifiedDateTime?.DateTime ?? DateTime.MinValue;
        metadata["file_size"] = item.Size ?? 0;
        
        // SharePoint custom columns (if you have them)
        // These would be in item.ListItem.Fields
        // You'll need to request this separately with expand
        
        return metadata;
    }
    
    public async Task<byte[]> DownloadDocument(string siteId, string driveId, string itemId)
    {
        var stream = await _graphClient.Sites[siteId]
            .Drives[driveId]
            .Items[itemId]
            .Content
            .Request()
            .GetAsync();
            
        using var memoryStream = new MemoryStream();
        await stream.CopyToAsync(memoryStream);
        return memoryStream.ToArray();
    }
}
```

### Step 3: Document Processing & Content Extraction

**For different file types:**

```csharp
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using ClosedXML.Excel;
using DocumentFormat.OpenXml.Presentation;

public class DocumentProcessor
{
    public async Task<string> ExtractText(byte[] fileBytes, string fileType)
    {
        return fileType switch
        {
            ".pdf" => await ExtractFromPdf(fileBytes),
            ".docx" => ExtractFromWord(fileBytes),
            ".doc" => await ExtractFromLegacyWord(fileBytes),
            ".xlsx" => ExtractFromExcel(fileBytes),
            ".xls" => await ExtractFromLegacyExcel(fileBytes),
            ".pptx" => ExtractFromPowerPoint(fileBytes),
            ".txt" => System.Text.Encoding.UTF8.GetString(fileBytes),
            _ => string.Empty
        };
    }
    
    // Word Document
    private string ExtractFromWord(byte[] fileBytes)
    {
        using var stream = new MemoryStream(fileBytes);
        using var doc = WordprocessingDocument.Open(stream, false);
        
        var body = doc.MainDocumentPart.Document.Body;
        return body.InnerText;
    }
    
    // Excel Workbook
    private string ExtractFromExcel(byte[] fileBytes)
    {
        using var stream = new MemoryStream(fileBytes);
        using var workbook = new XLWorkbook(stream);
        
        var text = new StringBuilder();
        
        foreach (var worksheet in workbook.Worksheets)
        {
            text.AppendLine($"Sheet: {worksheet.Name}");
            
            var usedRange = worksheet.RangeUsed();
            if (usedRange == null) continue;
            
            // Get headers (first row)
            var firstRow = usedRange.FirstRow();
            var headers = firstRow.Cells()
                .Select(c => c.GetString())
                .ToList();
            
            text.AppendLine(string.Join(" | ", headers));
            
            // Get data rows
            foreach (var row in usedRange.RowsUsed().Skip(1))
            {
                var values = row.Cells()
                    .Select(c => c.GetString())
                    .ToList();
                    
                text.AppendLine(string.Join(" | ", values));
            }
            
            text.AppendLine();
        }
        
        return text.ToString();
    }
    
    // PowerPoint
    private string ExtractFromPowerPoint(byte[] fileBytes)
    {
        using var stream = new MemoryStream(fileBytes);
        using var presentation = PresentationDocument.Open(stream, false);
        
        var text = new StringBuilder();
        var slideNumber = 1;
        
        foreach (var slidePart in presentation.PresentationPart.SlideParts)
        {
            text.AppendLine($"Slide {slideNumber}:");
            
            // Extract text from shapes
            var slide = slidePart.Slide;
            foreach (var paragraph in slide.Descendants<DocumentFormat.OpenXml.Drawing.Paragraph>())
            {
                text.AppendLine(paragraph.InnerText);
            }
            
            text.AppendLine();
            slideNumber++;
        }
        
        return text.ToString();
    }
    
    // PDF - Use Azure Document Intelligence
    private async Task<string> ExtractFromPdf(byte[] fileBytes)
    {
        // Use Azure Document Intelligence (Form Recognizer)
        var credential = new AzureKeyCredential(Environment.GetEnvironmentVariable("DOCUMENT_INTELLIGENCE_KEY"));
        var client = new DocumentAnalysisClient(
            new Uri(Environment.GetEnvironmentVariable("DOCUMENT_INTELLIGENCE_ENDPOINT")),
            credential
        );
        
        using var stream = new MemoryStream(fileBytes);
        var operation = await client.AnalyzeDocumentAsync(
            WaitUntil.Completed,
            "prebuilt-layout", // or "prebuilt-read" for simpler extraction
            stream
        );
        
        var result = operation.Value;
        var text = new StringBuilder();
        
        foreach (var page in result.Pages)
        {
            foreach (var line in page.Lines)
            {
                text.AppendLine(line.Content);
            }
        }
        
        return text.ToString();
    }
}
```

### Step 4: Intelligent Chunking Strategy

This is critical for research documents:

```csharp
public class DocumentChunker
{
    private readonly int _chunkSize = 1000; // tokens ~750 words
    private readonly int _chunkOverlap = 200; // tokens for context
    
    public List<DocumentChunk> ChunkDocument(
        SharePointDocument document, 
        string content,
        string fileType)
    {
        // Choose chunking strategy based on file type
        return fileType switch
        {
            ".pdf" or ".docx" => ChunkBySemanticSections(content, document),
            ".xlsx" => ChunkSpreadsheetBySheet(content, document),
            ".pptx" => ChunkBySlides(content, document),
            _ => ChunkByFixedSize(content, document)
        };
    }
    
    // Semantic chunking for protocols/reports
    private List<DocumentChunk> ChunkBySemanticSections(
        string content, 
        SharePointDocument document)
    {
        var chunks = new List<DocumentChunk>();
        
        // Common research document sections
        var sectionHeaders = new[]
        {
            "abstract", "introduction", "materials", "methods", 
            "results", "discussion", "conclusion", "references",
            "protocol", "procedure", "equipment", "analysis"
        };
        
        // Split by sections if they exist
        var sections = SplitBySections(content, sectionHeaders);
        
        if (sections.Count > 1)
        {
            // We found sections, chunk each one
            foreach (var (sectionName, sectionContent) in sections)
            {
                if (EstimateTokens(sectionContent) <= _chunkSize)
                {
                    // Section fits in one chunk
                    chunks.Add(CreateChunk(document, sectionContent, sectionName));
                }
                else
                {
                    // Section too large, split it
                    var subChunks = ChunkByFixedSize(sectionContent, document);
                    foreach (var chunk in subChunks)
                    {
                        chunk.SectionName = sectionName;
                        chunks.Add(chunk);
                    }
                }
            }
        }
        else
        {
            // No clear sections, use fixed-size chunking
            chunks = ChunkByFixedSize(content, document);
        }
        
        return chunks;
    }
    
    private List<(string section, string content)> SplitBySections(
        string content, 
        string[] headers)
    {
        var sections = new List<(string, string)>();
        var lines = content.Split('\n');
        
        string currentSection = "Introduction";
        var currentContent = new StringBuilder();
        
        foreach (var line in lines)
        {
            var lowerLine = line.ToLower().Trim();
            
            // Check if this line is a section header
            var matchedHeader = headers.FirstOrDefault(h => 
                lowerLine.StartsWith(h) || 
                lowerLine.Contains($"{h}:") ||
                lowerLine == h
            );
            
            if (matchedHeader != null && line.Length < 100) // Likely a header
            {
                // Save previous section
                if (currentContent.Length > 0)
                {
                    sections.Add((currentSection, currentContent.ToString()));
                    currentContent.Clear();
                }
                
                currentSection = matchedHeader;
            }
            else
            {
                currentContent.AppendLine(line);
            }
        }
        
        // Add final section
        if (currentContent.Length > 0)
        {
            sections.Add((currentSection, currentContent.ToString()));
        }
        
        return sections;
    }
    
    private List<DocumentChunk> ChunkByFixedSize(
        string content, 
        SharePointDocument document)
    {
        var chunks = new List<DocumentChunk>();
        var sentences = SplitIntoSentences(content);
        
        var currentChunk = new StringBuilder();
        var currentTokens = 0;
        
        foreach (var sentence in sentences)
        {
            var sentenceTokens = EstimateTokens(sentence);
            
            if (currentTokens + sentenceTokens > _chunkSize && currentChunk.Length > 0)
            {
                // Create chunk
                chunks.Add(CreateChunk(document, currentChunk.ToString()));
                
                // Start new chunk with overlap
                currentChunk.Clear();
                currentTokens = 0;
                
                // Add last few sentences for overlap
                var overlapSentences = GetLastSentences(currentChunk.ToString(), _chunkOverlap);
                currentChunk.Append(overlapSentences);
                currentTokens = EstimateTokens(overlapSentences);
            }
            
            currentChunk.Append(sentence).Append(" ");
            currentTokens += sentenceTokens;
        }
        
        // Add final chunk
        if (currentChunk.Length > 0)
        {
            chunks.Add(CreateChunk(document, currentChunk.ToString()));
        }
        
        return chunks;
    }
    
    // For Excel files - each sheet is meaningful
    private List<DocumentChunk> ChunkSpreadsheetBySheet(
        string content, 
        SharePointDocument document)
    {
        var chunks = new List<DocumentChunk>();
        var sheets = content.Split("Sheet:", StringSplitOptions.RemoveEmptyEntries);
        
        foreach (var sheet in sheets)
        {
            if (string.IsNullOrWhiteSpace(sheet)) continue;
            
            var lines = sheet.Split('\n');
            var sheetName = lines[0].Trim();
            var sheetContent = string.Join("\n", lines.Skip(1));
            
            chunks.Add(CreateChunk(document, sheetContent, $"Sheet: {sheetName}"));
        }
        
        return chunks;
    }
    
    private DocumentChunk CreateChunk(
        SharePointDocument document, 
        string content, 
        string sectionName = null)
    {
        return new DocumentChunk
        {
            Id = $"{document.Id}_{Guid.NewGuid()}",
            DocumentId = document.Id,
            DocumentName = document.Name,
            DocumentUrl = document.WebUrl,
            Content = content.Trim(),
            SectionName = sectionName,
            Metadata = document.Metadata,
            FileType = document.FileType,
            LastModified = document.LastModified
        };
    }
    
    private int EstimateTokens(string text)
    {
        // Rough estimate: 1 token ≈ 4 characters
        return text.Length / 4;
    }
    
    private List<string> SplitIntoSentences(string text)
    {
        // Simple sentence splitter
        return Regex.Split(text, @"(?<=[.!?])\s+")
            .Where(s => !string.IsNullOrWhiteSpace(s))
            .ToList();
    }
    
    private string GetLastSentences(string text, int maxTokens)
    {
        var sentences = SplitIntoSentences(text);
        var result = new List<string>();
        var tokens = 0;
        
        for (int i = sentences.Count - 1; i >= 0; i--)
        {
            var sentenceTokens = EstimateTokens(sentences[i]);
            if (tokens + sentenceTokens > maxTokens) break;
            
            result.Insert(0, sentences[i]);
            tokens += sentenceTokens;
        }
        
        return string.Join(" ", result);
    }
}

public class DocumentChunk
{
    public string Id { get; set; }
    public string DocumentId { get; set; }
    public string DocumentName { get; set; }
    public string DocumentUrl { get; set; }
    public string Content { get; set; }
    public string SectionName { get; set; }
    public string FileType { get; set; }
    public DateTime LastModified { get; set; }
    public Dictionary<string, object> Metadata { get; set; }
    public float[] Embedding { get; set; }
}
```

### Step 5: Generate Embeddings & Index

```csharp
using Azure.AI.OpenAI;
using Azure.Search.Documents;
using Azure.Search.Documents.Indexes;
using Azure.Search.Documents.Indexes.Models;

public class SearchIndexer
{
    private readonly OpenAIClient _openAiClient;
    private readonly SearchIndexClient _searchIndexClient;
    private readonly SearchClient _searchClient;
    private readonly string _indexName = "nutrition-research-index";
    
    public SearchIndexer(
        string openAiEndpoint,
        string openAiKey,
        string searchEndpoint,
        string searchKey)
    {
        _openAiClient = new OpenAIClient(
            new Uri(openAiEndpoint),
            new AzureKeyCredential(openAiKey)
        );
        
        _searchIndexClient = new SearchIndexClient(
            new Uri(searchEndpoint),
            new AzureKeyCredential(searchKey)
        );
        
        _searchClient = _searchIndexClient.GetSearchClient(_indexName);
    }
    
    public async Task CreateOrUpdateIndex()
    {
        var index = new SearchIndex(_indexName)
        {
            Fields =
            {
                new SimpleField("id", SearchFieldDataType.String) { IsKey = true, IsFilterable = true },
                new SearchableField("content") { IsFilterable = false },
                new SearchableField("documentName") { IsFilterable = true, IsFacetable = true },
                new SimpleField("documentUrl", SearchFieldDataType.String) { IsFilterable = false },
                new SearchableField("sectionName") { IsFilterable = true, IsFacetable = true },
                new SimpleField("fileType", SearchFieldDataType.String) { IsFilterable = true, IsFacetable = true },
                new SimpleField("lastModified", SearchFieldDataType.DateTimeOffset) { IsFilterable = true, IsSortable = true },
                
                // Domain-specific metadata
                new SimpleField("species", SearchFieldDataType.Collection(SearchFieldDataType.String)) { IsFilterable = true, IsFacetable = true },
                new SimpleField("innovationCenter", SearchFieldDataType.String) { IsFilterable = true, IsFacetable = true },
                new SimpleField("documentType", SearchFieldDataType.String) { IsFilterable = true, IsFacetable = true },
                new SimpleField("researchArea", SearchFieldDataType.String) { IsFilterable = true, IsFacetable = true },
                
                // Vector field for embeddings
                new SearchField("contentVector", SearchFieldDataType.Collection(SearchFieldDataType.Single))
                {
                    IsSearchable = true,
                    VectorSearchDimensions = 1536, // text-embedding-ada-002 dimension
                    VectorSearchProfileName = "vector-profile"
                }
            },
            VectorSearch = new VectorSearch
            {
                Profiles =
                {
                    new VectorSearchProfile("vector-profile", "vector-config")
                },
                Algorithms =
                {
                    new HnswAlgorithmConfiguration("vector-config")
                }
            },
            SemanticSearch = new SemanticSearch
            {
                Configurations =
                {
                    new SemanticConfiguration("semantic-config", new()
                    {
                        TitleField = new SemanticField("documentName"),
                        ContentFields =
                        {
                            new SemanticField("content"),
                            new SemanticField("sectionName")
                        }
                    })
                }
            }
        };
        
        await _searchIndexClient.CreateOrUpdateIndexAsync(index);
    }
    
    public async Task<float[]> GenerateEmbedding(string text)
    {
        var embeddingOptions = new EmbeddingsOptions(
            deploymentName: "text-embedding-ada-002", // or text-embedding-3-large
            input: new List<string> { text }
        );
        
        var response = await _openAiClient.GetEmbeddingsAsync(embeddingOptions);
        return response.Value.Data[0].Embedding.ToArray();
    }
    
    public async Task IndexChunks(List<DocumentChunk> chunks)
    {
        // Generate embeddings in batches
        const int batchSize = 16; // Azure OpenAI limit
        
        for (int i = 0; i < chunks.Count; i += batchSize)
        {
            var batch = chunks.Skip(i).Take(batchSize).ToList();
            
            // Generate embeddings for batch
            var embeddingTasks = batch.Select(async chunk =>
            {
                chunk.Embedding = await GenerateEmbedding(chunk.Content);
                return chunk;
            });
            
            await Task.WhenAll(embeddingTasks);
            
            // Upload to search index
            var searchDocuments = batch.Select(chunk => new SearchDocument
            {
                ["id"] = chunk.Id,
                ["content"] = chunk.Content,
                ["documentName"] = chunk.DocumentName,
                ["documentUrl"] = chunk.DocumentUrl,
                ["sectionName"] = chunk.SectionName,
                ["fileType"] = chunk.FileType,
                ["lastModified"] = chunk.LastModified,
                ["contentVector"] = chunk.Embedding,
                
                // Extract species from metadata or document name
                ["species"] = ExtractSpecies(chunk),
                ["innovationCenter"] = chunk.Metadata.GetValueOrDefault("innovation_center", "Unknown"),
                ["documentType"] = ClassifyDocumentType(chunk.DocumentName),
                ["researchArea"] = chunk.Metadata.GetValueOrDefault("research_area", "General")
            });
            
            await _searchClient.UploadDocumentsAsync(searchDocuments);
            
            Console.WriteLine($"Indexed batch {i / batchSize + 1} ({batch.Count} chunks)");
        }
    }
    
    private List<string> ExtractSpecies(DocumentChunk chunk)
    {
        var species = new List<string>();
        var contentLower = (chunk.Content + " " + chunk.DocumentName).ToLower();
        
        if (contentLower.Contains("swine") || contentLower.Contains("pig")) species.Add("swine");
        if (contentLower.Contains("ruminant") || contentLower.Contains("cattle") || contentLower.Contains("cow")) species.Add("ruminants");
        if (contentLower.Contains("poultry") || contentLower.Contains("chicken")) species.Add("poultry");
        if (contentLower.Contains("aqua") || contentLower.Contains("fish")) species.Add("aquaculture");
        
        return species.Count > 0 ? species : new List<string> { "unspecified" };
    }
    
    private string ClassifyDocumentType(string documentName)
    {
        var nameLower = documentName.ToLower();
        
        if (nameLower.Contains("protocol")) return "protocol";
        if (nameLower.Contains("report")) return "report";
        if (nameLower.Contains("study")) return "study";
        if (nameLower.Contains("analysis")) return "analysis";
        
        return "document";
    }
}
```

### Step 6: Orchestration - Putting It All Together

```csharp
public class IndexingOrchestrator
{
    private readonly SharePointExtractor _extractor;
    private readonly DocumentProcessor _processor;
    private readonly DocumentChunker _chunker;
    private readonly SearchIndexer _indexer;
    
    public async Task IndexSharePointSite(string siteId, string libraryName = "Documents")
    {
        Console.WriteLine($"Starting indexing for site {siteId}...");
        
        // 1. Get all documents from SharePoint
        var documents = await _extractor.GetDocumentsFromSite(siteId, libraryName);
        Console.WriteLine($"Found {documents.Count} documents");
        
        // 2. Process each document
        var allChunks = new List<DocumentChunk>();
        
        foreach (var doc in documents)
        {
            try
            {
                Console.WriteLine($"Processing: {doc.Name}");
                
                // Download document
                var fileBytes = await _extractor.DownloadDocument(siteId, doc.Id);
                
                // Extract text
                var content = await _processor.ExtractText(fileBytes, doc.FileType);
                
                if (string.IsNullOrWhiteSpace(content))
                {
                    Console.WriteLine($"  Skipped (no content extracted)");
                    continue;
                }
                
                // Chunk document
                var chunks = _chunker.ChunkDocument(doc, content, doc.FileType);
                allChunks.AddRange(chunks);
                
                Console.WriteLine($"  Created {chunks.Count} chunks");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  Error: {ex.Message}");
            }
        }
        
        // 3. Index all chunks
        Console.WriteLine($"\nIndexing {allChunks.Count} total chunks...");
        await _indexer.IndexChunks(allChunks);
        
        Console.WriteLine("Indexing complete!");
    }
    
    // For incremental updates
    public async Task IndexChangedDocuments(string siteId, DateTime since)
    {
        var documents = await _extractor.GetDocumentsFromSite(siteId);
        var changedDocs = documents.Where(d => d.LastModified > since).ToList();
        
        Console.WriteLine($"Found {changedDocs.Count} documents modified since {since}");
        
        // Process only changed documents
        // You'll want to delete old chunks for these documents first
        // Then re-index them
    }
}
```

### Step 7: Running It

**Azure Function for scheduled indexing:**

```csharp
public class ScheduledIndexing
{
    private readonly IndexingOrchestrator _orchestrator;
    
    [FunctionName("IndexSharePointDocuments")]
    public async Task Run(
        [TimerTrigger("0 0 2 * * *")] TimerInfo timer, // Run at 2 AM daily
        ILogger log)
    {
        log.LogInformation("Starting SharePoint indexing job");
        
        var sites = new[]
        {
            "site-id-1",
            "site-id-2",
            "site-id-3"
        };
        
        foreach (var siteId in sites)
        {
            try
            {
                await _orchestrator.IndexSharePointSite(siteId);
                log.LogInformation($"Successfully indexed site {siteId}");
            }
            catch (Exception ex)
            {
                log.LogError($"Failed to index site {siteId}: {ex.Message}");
            }
        }
    }
}
```

-----

## Key Considerations for Production

1. **Error Handling & Retry Logic**: Implement polly for retries on transient failures
1. **Rate Limiting**: Both Graph API and OpenAI have rate limits
1. **Incremental Updates**: Track last successful index time, only process new/changed docs
1. **Monitoring**: Application Insights to track indexing progress
1. **Cost Management**: Embeddings cost money - batch processing and caching help
1. **Permissions**: Ensure the app has least-privilege access to SharePoint

-----

## Next Steps

1. **Set up App Registration** in Azure AD with SharePoint permissions
1. **Test with one small SharePoint site first**
1. **Validate chunking quality** - manually review a few documents
1. **Test search relevance** with real scientist queries
1. **Add metadata enrichment** based on our domain taxonomy

### Next Todos:

- Setting up the Azure AD app registration?
- More sophisticated metadata extraction (e.g., using GPT to classify documents)?
- Building the query/search interface?
- Handling specific document types you have?


