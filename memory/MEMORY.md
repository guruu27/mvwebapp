# MicrovellumWebApp Memory

## Critical DB Join Patterns (P1987_D077 schema)

See [microvellum_db.md](microvellum_db.md) for full details.

Key rules:
- Use `.LinkID` (non-GUID) NOT `.ID` (GUID) for all FK joins
- All string joins need `LTRIM(RTRIM(...))` — NVARCHAR columns have trailing spaces
- `OptimizationResults.LinkIDSheet = PlacedSheets.LinkID` (direct, with TRIM)
- `WorkOrderBatches.LinkID` (not `.ID`) = `PlacedSheets.LinkIDWorkOrderBatch`
- Schema per workorder: `P1987_D077`, `P1987_D018`, `P1987_D001` (not `dbo`)

## SDF Query Origin
- Each Microvellum workorder produces an `.sdf` file (SQL Compact Edition)
- The SDF query is the gold standard — run directly against each workorder's SDF
- SDF tables have NO schema prefix (bare table names)
- SQL Server schemas (P1987_D018 etc.) are manual migrations of SDF files
- `dbo` = last imported workorder (currently P1987_D018)

## Processing Station IDs
- `21BMOJSH9M90`  = CNC Nesting
- `1966O1PHUNP10` = Panel Saw (primary)
- `1966O9J0UOZ10` = Panel Saw (secondary)
- `215ROFJ6TWV10` = Ghost station (exclude via HAVING > 0)

## SDF Metric Formulas
- **Edgebanding**: `SUM(Quantity) * 0.00105` = linear feet
- **P2P**: `COUNT(Quantity) WHERE LEN(Face6Barcode) > 0`
- **Miter**: `COUNT(Quantity) WHERE Comments LIKE '%@%'`
- **Solid**: `CEILING(SUM(Quantity * Length) * 0.001)` on PlacedSheets WHERE Name LIKE '%Solid%' AND NOT LIKE '%Solid Surface%'
- **Products**: `SUM(Products.Quantity)`
- **Total Parts**: `SUM(OptimizedQuantity) WHERE ScrapType = 0` (all stations)
- **Sheets**: `COUNT(PlacedSheets.ID) WHERE Width > 350` (per station per batch)

## Hours Calculations (from SDF, currently commented out)
- Nesting: parts × 9.5 min / 60
- Panel Saw: parts × 3.5 min / 60
- P2P: qty × 5.0 / 60 × 1.12
- Miter: qty × 5 / 60
- Edgebanding: linft × 2.8 / 60
- Solid: qty × 5 / 60

## Sheets Join (SDF vs SQL Server)
- SDF joins Sheets on: `ProcessingStation + WorkOrderBatch` (also has WorkOrder)
- SQL Server: same, plus added `LinkIDWorkOrder` for safety
- Width > 350 filter excludes off-cut strips

## Validated Numbers (P1987_D018 / dbo)
- NestSht=8, NestPrts=51, PnlSht=3, PnlPrts=33
- Edge=72 linft, P2P=2, Miter=3, Solid=NULL (no solid in this WO)
- Products=15, TotalParts=84 (51+33=84 ✓)

## dbo Schema Available Tables
PlacedSheets, OptimizationResults, Parts, Products, Edgebanding,
WorkOrderBatches, Routes, Hardware, Sheets, Subassemblies, Prompts, ProductsPrompts
- NO DrillsHorizontal or DrillsVertical in dbo (only in P1987_D018/D001)

## Query 2 (production_plan_detail.sql) — VALIDATED
- 84 rows total (= 33 Panel Saw + 51 CNC Nesting) matches Query 1
- Panel Saw: 3 sheets (18mm Plywood, 19.5mm VC, 18.9mm FR_MR-50 MDF)
- CNC Nesting: 8 sheets (18.9mm FR MDF G1S ×2, G2S ×3, 36.4mm FR MDF ×3)
- P2P in detail: 2 unique parts (Base Division Open, Drawer Bottom) appear 6× across placements
- Miter in detail: 3 unique parts (Miterfold Left/Right/Front) appear 9× across placements
- Edgebanding: Query 1 uses SUM(Quantity)*0.00105=72 linft; Query 2 uses LinFt per part (mm)
- Tool path: uses TotalRouteLength from Routes (mm) — shows routing for CNC parts

## Files
- `production_plan.sql` — General query matching SDF logic (VALIDATED ✓)
- `production_plan_detail.sql` — Per-sheet detail query using dbo (VALIDATED ✓)
- `production_plan_original.sql` — Backup of previous production_plan version
- `query.sql` — Per-sheet detail for P1987_D077 (schema-specific)
- `query_D018.sql` — Per-sheet detail for P1987_D018 (with drills)
- `run_query.ps1` — Helper to execute production_plan.sql
- `run_detail_query.ps1` — Helper to execute production_plan_detail.sql
- `validate_metrics.ps1` — Cross-check individual metrics
