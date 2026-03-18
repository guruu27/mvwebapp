# Microvellum Data Platform

A comprehensive platform for managing Microvellum manufacturing data, from database migration through visualization and predictive analytics.

## Project Structure

```
MicrovellumWebApp/
├── db_migration/      # SDF file migration to SQL Server
├── webapp/            # Web application (backend API + frontend UI)
├── ml/                # Machine learning for hours prediction
└── memory/            # Shared knowledge base and documentation
```

## Components

### 1. Database Migration (`db_migration/`)

Handles the migration of Microvellum SDF (SQL Server Compact Edition) files to the main SQL Server database.

**Contents:**
- SQL query files for production planning and data extraction
- PowerShell automation scripts for migration tasks
- Schema documentation and relationship mappings

**Key Files:**
- `production_plan.sql` - Main production planning query
- `SCHEMA_RELATIONSHIPS.md` - Complete database schema documentation
- `*.ps1` - Automation scripts for validation and migration

### 2. Web Application (`webapp/`)

Full-stack web application for visualizing and querying Microvellum data.

**Architecture:**
- **Backend**: FastAPI REST API (Python)
- **Frontend**: Vanilla HTML/CSS/JavaScript

**Features:**
- Project and work order navigation
- Interactive schema visualization
- SQL query builder
- Sheet tracking and scrap analysis
- Production plan aggregation

### 3. Machine Learning (`ml/`)

Predictive analytics for manufacturing time estimation based on historical performance data.

**Planned Capabilities:**
- Hours prediction per work order
- Processing time estimation by station
- Performance trend analysis
- Resource planning optimization

## Quick Start

### Prerequisites
- Python 3.8+
- SQL Server with ODBC Driver 17
- Access to Microvellum database

### Running the Web Application

```powershell
# Start backend
cd webapp/backend
pip install -r requirements.txt
python main.py

# Serve frontend (separate terminal)
cd webapp/frontend
python -m http.server 3000
```

- API: http://localhost:8000
- Frontend: http://localhost:3000
- API Docs: http://localhost:8000/docs

## Database Configuration

Connection settings in `webapp/backend/main.py`:

```python
DB_CONFIG = {
    'server': 'PSF-GuruprasadT\\SQLEXPRESS',
    'database': 'guru',
    'driver': 'ODBC Driver 17 for SQL Server',
    'trusted_connection': 'yes'
}
```

## Documentation

- `db_migration/SCHEMA_RELATIONSHIPS.md` - Database schema and join patterns
- `memory/` - Development notes and validated patterns

## License

Internal use only
