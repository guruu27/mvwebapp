# Web Application

Full-stack web application for managing and visualizing Microvellum database schemas.

## Structure

```
webapp/
├── backend/           # FastAPI REST API
│   ├── main.py       # API endpoints and business logic
│   └── requirements.txt
└── frontend/          # Static HTML/CSS/JS
    ├── index.html    # Main application
    ├── css/
    │   └── styles.css
    └── js/
        └── app.js
```

## Features

- **Project Selection** - Browse available projects from database schemas
- **Work Order View** - View all work orders with stats
- **Schema Visualization** - Interactive database relationship diagrams
- **Query Builder** - Execute SQL queries with formatted results
- **Sheet Tracking** - Track sheets through processing stations
- **Production Planning** - Aggregate manufacturing metrics

## Backend Setup

```powershell
cd backend
pip install -r requirements.txt
python main.py
```

API available at: http://localhost:8000
API Documentation: http://localhost:8000/docs

## Frontend Setup

```powershell
cd frontend
python -m http.server 3000
```

Open: http://localhost:3000

## API Endpoints

### Projects
- `GET /projects` - List all projects
- `GET /projects/{project_number}/workorders` - Get work orders

### Schema
- `GET /schema/{schema_name}/info` - Schema statistics
- `GET /schema/{schema_name}/tables` - Table details
- `GET /schema/{schema_name}/relationships` - Relationships

### Operations
- `POST /query` - Execute SQL query
- `POST /sheet-tracking` - Sheet tracking analysis
- `GET /production-plan/{schema_name}` - Production plan data
