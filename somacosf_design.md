# Design Document - Phase 1: Foundation Setup

## Overview

The Oligarchology Data Population System Phase 1 focuses on establishing the foundational infrastructure for a comprehensive oligarch intelligence database. This phase prioritizes getting the schema deployed to Gibson AI, setting up the GitHub repository structure, and creating the foundation for Emergent.sh frontend development.

The simplified architecture uses Gibson AI as the primary database and API provider, with the 46-table oligarchology schema deployed to project ID `39dc81c7-99b8-434b-a6df-5d5dc99ccc17`. This approach allows us to work "schema-out" - first establishing the data structure, then building population tools, and finally creating the UI/UX through Emergent.sh.

## Architecture

### Phase 1 Simplified Architecture

```mermaid
graph TB
    subgraph "Development Environment"
        DEV[Development Machine<br/>Windows + Kiro + uv venv]
        REPO[GitHub Repository<br/>SoMaCoSF/oligarchology]
    end
    
    subgraph "Gibson AI Platform"
        GIBSON_DB[(Gibson AI Database<br/>Project: 39dc81c7-99b8-434b-a6df-5d5dc99ccc17)]
        GIBSON_API[Gibson AI API<br/>Auto-generated endpoints]
    end
    
    subgraph "Data Population Tools"
        SHOT_SCRAPER[Modified shot-scraper<br/>Web scraping tool]
        API_CLIENT[Gibson API Client<br/>Python integration]
    end
    
    subgraph "Frontend Development"
        EMERGENT[Emergent.sh AI<br/>Frontend generator]
        EMERGENT_MD[Emergent.md<br/>Instructions file]
    end
    
    DEV --> REPO
    REPO --> EMERGENT_MD
    EMERGENT_MD --> EMERGENT
    
    DEV --> GIBSON_DB
    GIBSON_DB --> GIBSON_API
    
    SHOT_SCRAPER --> API_CLIENT
    API_CLIENT --> GIBSON_API
    
    EMERGENT --> GIBSON_API
```

### Gibson AI Configuration

**Project Details**:
- Project ID: `39dc81c7-99b8-434b-a6df-5d5dc99ccc17`
- Project Name: `Oligarchology`
- Schema File: `oligarchology.sql`

**Connection Strings**:
- Production: `mysql://us_6jM1N1IDLLESrfmIujO:mjjlt4Dtt86E6tk1gbemZeAmzgP932uO@mysql-assembly.gibsonai.com/db_6jM1N1IDLLESrfmIujO`
- Development: `mysql://us_vECsesceVB7VTLdeobM:CyvsymsnMBCqDzaPjpB37IOxvghgn0Vr@mysql-assembly.gibsonai.com/db_vECsesceVB7VTLdeobM`

**API Endpoints**:
- Base URL: `https://app.gibsonai.com/project/39dc81c7-99b8-434b-a6df-5d5dc99ccc17/docs`
- Auto-generated REST endpoints for all 46 tables
- Authentication via encrypted API keys

## Components and Interfaces

### 1. Schema Deployment to Gibson AI

**Primary Schema Tables** (46 total):
- `oligarch_core_entity` - Central entity table
- `oligarch_personal_data` - Biographical information
- `oligarch_asset_portfolio` - Asset tracking
- `oligarch_network_relationship` - Relationship mapping
- `oligarch_financial_activity` - Financial transactions
- `oligarch_corporate_entity` - Corporate structures
- `oligarch_sanctions_exposure` - Sanctions tracking
- `oligarch_digital_footprint` - Online presence
- And 38 additional specialized tables

**Gibson AI Auto-Generated Features**:
- REST API endpoints for all tables
- CRUD operations with validation
- Relationship queries
- Search and filtering
- Authentication and authorization

### 2. GitHub Repository Structure

```
oligarchology/
├── README.md
├── oligarchology.sql          # Main schema file
├── Emergent.md               # Instructions for Emergent.sh
├── .gibsonai                 # Gibson AI configuration
├── docs/
│   ├── schema-overview.md
│   └── api-documentation.md
├── scripts/
│   ├── shot-scraper-modified/
│   └── data-population/
├── examples/
│   ├── sample-queries.sql
│   └── api-examples.py
└── frontend/
    └── emergent-instructions/
```

### 3. Modified shot-scraper Integration

**Base Repository**: https://github.com/simonw/shot-scraper
**Modifications Needed**:
- Add Gibson AI API client integration
- Create data extraction pipelines
- Implement rate limiting and error handling
- Add data validation before API calls

**Example Integration**:
```python
from gibson_client import GibsonAPI
from shot_scraper import ShotScraper

class OligarchScraper(ShotScraper):
    def __init__(self):
        super().__init__()
        self.gibson = GibsonAPI(
            project_id="39dc81c7-99b8-434b-a6df-5d5dc99ccc17",
            api_key=os.getenv("GDB_API_DEV")
        )
    
    def scrape_and_populate(self, target_url: str):
        # Scrape data using shot-scraper
        data = self.scrape(target_url)
        
        # Extract oligarch information
        oligarch_data = self.extract_oligarch_info(data)
        
        # Populate Gibson AI database
        self.gibson.create_oligarch(oligarch_data)
```

### 4. Emergent.sh Integration

**Emergent.md Structure**:
```markdown
# Oligarchology Frontend Instructions

## Project Overview
Build a comprehensive web interface for the Oligarchology database - a strategic intelligence platform for tracking oligarch networks and relationships.

## Database Schema
Connect to Gibson AI API: https://app.gibsonai.com/project/39dc81c7-99b8-434b-a6df-5d5dc99ccc17/docs

## Key Features to Implement
1. Oligarch profile pages with comprehensive data visualization
2. Network relationship mapping with interactive graphs
3. Asset portfolio tracking with financial visualizations
4. Search and filtering across all data dimensions
5. Real-time updates and monitoring dashboard

## UI/UX Requirements
- Dark theme with intelligence/security aesthetic
- Interactive network graphs using D3.js or similar
- Responsive design for desktop and mobile
- Advanced search with multiple filters
- Data export capabilities

## Technical Stack
- Frontend: React/Next.js with TypeScript
- Visualization: D3.js, Chart.js, or similar
- API Integration: Gibson AI REST endpoints
- Styling: Tailwind CSS or styled-components
```

## Data Models

### Core Entity Structure
```sql
-- Central oligarch entity
CREATE TABLE oligarch_core_entity (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    uuid VARCHAR(36) UNIQUE NOT NULL,
    research_classification ENUM('business', 'celebrities', 'politicians'),
    priority_level ENUM('critical', 'high', 'medium', 'low'),
    verification_status ENUM('verified', 'pending', 'rejected'),
    source ENUM('lbb_address_book', 'x_leads', 'web_scraping'),
    investigation_stage ENUM('new', 'in_progress', 'completed', 'on_hold')
);

-- Personal information
CREATE TABLE oligarch_personal_data (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    oligarch_id BIGINT REFERENCES oligarch_core_entity(id),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE,
    nationality VARCHAR(100),
    net_worth DECIMAL(20,2)
);
```

### Relationship Mapping
```sql
-- Network relationships
CREATE TABLE oligarch_network_relationship (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    oligarch_id BIGINT REFERENCES oligarch_core_entity(id),
    related_oligarch_id BIGINT REFERENCES oligarch_core_entity(id),
    relationship_category ENUM('business', 'family', 'political', 'social', 'criminal'),
    strength_score DECIMAL(5,2), -- 0.00 to 100.00
    evidence TEXT,
    verification_level ENUM('confirmed', 'likely', 'suspected', 'unverified')
);
```

## Error Handling

### Gibson AI Integration
```python
class GibsonAPIError(Exception):
    def __init__(self, status_code: int, message: str):
        self.status_code = status_code
        self.message = message
        super().__init__(f"Gibson API Error {status_code}: {message}")

def handle_gibson_errors(func):
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except requests.HTTPError as e:
            if e.response.status_code == 429:
                # Rate limiting - implement backoff
                time.sleep(60)
                return func(*args, **kwargs)
            elif e.response.status_code == 401:
                raise GibsonAPIError(401, "Authentication failed")
            else:
                raise GibsonAPIError(e.response.status_code, str(e))
    return wrapper
```

### Data Validation
```python
def validate_oligarch_data(data: dict) -> bool:
    required_fields = ['first_name', 'last_name']
    
    for field in required_fields:
        if not data.get(field):
            raise ValueError(f"Missing required field: {field}")
    
    # Validate data types and ranges
    if 'net_worth' in data and data['net_worth'] < 0:
        raise ValueError("Net worth cannot be negative")
    
    return True
```

## Testing Strategy

### Phase 1 Testing Focus
1. **Schema Deployment**: Verify all 46 tables deploy correctly to Gibson AI
2. **API Connectivity**: Test all auto-generated endpoints
3. **Data Population**: Validate shot-scraper modifications work
4. **GitHub Integration**: Ensure repository structure supports Emergent.sh

### Test Cases
```python
def test_gibson_connection():
    """Test connection to Gibson AI database"""
    gibson = GibsonAPI(project_id="39dc81c7-99b8-434b-a6df-5d5dc99ccc17")
    assert gibson.test_connection() == True

def test_schema_deployment():
    """Verify all tables exist in Gibson AI"""
    expected_tables = [
        'oligarch_core_entity',
        'oligarch_personal_data',
        'oligarch_asset_portfolio',
        # ... all 46 tables
    ]
    actual_tables = gibson.list_tables()
    assert set(expected_tables).issubset(set(actual_tables))

def test_api_endpoints():
    """Test auto-generated API endpoints"""
    response = requests.get(f"{gibson.base_url}/oligarch_core_entity")
    assert response.status_code == 200
```

## Deployment Strategy

### Phase 1 Deployment Steps
1. **Deploy Schema to Gibson AI**
   ```bash
   gibson deploy --schema oligarchology.sql --project-id 39dc81c7-99b8-434b-a6df-5d5dc99ccc17
   ```

2. **Setup GitHub Repository**
   ```bash
   git init
   git add .
   git commit -m "Initial Oligarchology setup"
   git remote add origin https://github.com/SoMaCoSF/oligarchology.git
   git push -u origin main
   ```

3. **Test API Connectivity**
   ```python
   python scripts/test_gibson_connection.py
   ```

4. **Create Emergent.md Instructions**
   - Document API endpoints
   - Define UI/UX requirements
   - Specify data visualization needs

### Success Criteria
- ✅ All 46 tables deployed to Gibson AI
- ✅ API endpoints accessible and functional
- ✅ GitHub repository structured for Emergent.sh
- ✅ shot-scraper modifications working
- ✅ Sample data successfully populated
- ✅ Emergent.md instructions complete

## Next Phase Planning

### Phase 2: Data Population
- Implement comprehensive web scraping
- Build automated data collection agents
- Create data verification systems
- Establish real-time monitoring

### Phase 3: Advanced Analytics
- Network analysis algorithms
- Relationship scoring systems
- Predictive modeling
- Advanced visualization features

This Phase 1 approach ensures we have a solid foundation before building complex systems, following your "schema-out" methodology.