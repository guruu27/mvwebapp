# Database Migration

This directory contains tools and scripts for migrating Microvellum SDF (SQL Server Compact Edition) files to the main SQL Server database.

## Contents

### SQL Query Files
- `production_plan.sql` - Main production planning aggregation query
- `production_plan_detail.sql` - Detailed production plan with per-sheet breakdown
- `production_plan_original.sql` - Original SDF query (reference)
- `query.sql` - Per-sheet detail queries
- `query_D018.sql` - Specific drawing query examples

### PowerShell Scripts
- `explore_db.ps1` - Database exploration utilities
- `check_dbo_tables.ps1` - Validate dbo table structure
- `check_toolpath.ps1` - Toolpath validation
- `debug_p2p_miter.ps1` - Debug P2P and Miter calculations
- `run_query.ps1` - Execute queries against database
- `run_detail_query.ps1` - Run detailed query scripts
- `validate_metrics.ps1` - Validate calculated metrics

### Documentation
- `SCHEMA_RELATIONSHIPS.md` - Complete schema documentation with table relationships

## Key Concepts

### Index Offset
PlacedSheets uses 1-based Index while OptimizationResults uses 0-based:
```sql
JOIN PlacedSheets ps ON ps.Index = opt.Index + 1
```

### Data Types
All migrated columns are `NVARCHAR(MAX)` - must CAST for numeric operations:
```sql
CAST(column AS INT)
CAST(column AS DECIMAL(18,2))
```

### LinkID Convention
Foreign keys use `LinkID` prefix: `LinkIDProduct`, `LinkIDPart`, `LinkIDWorkOrderBatch`
