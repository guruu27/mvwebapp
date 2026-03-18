# MICROVELLUM DATABASE SCHEMA DOCUMENTATION
## Complete Table Relationships and Dependencies

---

## TABLE OVERVIEW (20 Tables, 2,105 Total Rows)

### Core Tables
- **Products** (5 rows) - Top-level items in work order
- **Parts** (28 rows) - Individual components to be manufactured
- **OptimizationResults** (105 rows) - Part placement on sheets
- **PlacedSheets** (11 rows) - Optimized sheet layouts
- **Sheets** (7 rows) - Sheet material definitions

### Processing Tables
- **PartsProcessingStations** (41 rows) - Manufacturing sequence
- **Routes** (20 rows) - Tool paths and machining operations
- **Edgebanding** (42 rows) - Edge banding specifications
- **DrillsHorizontal** (44 rows) - Horizontal drilling operations
- **DrillsVertical** (62 rows) - Vertical drilling operations
- **Hardware** (17 rows) - Hardware attachments
- **Vectors** (129 rows) - Vector geometry for routes

### Configuration Tables
- **WorkOrderBatches** (1 row) - Batch grouping
- **Subassemblies** (7 rows) - Sub-assembly definitions
- **FaceFrameImages** (10 rows) - Face frame visual data
- **ProductsPrompts** (1,537 rows) - Product configuration prompts
- **Prompts** (1,537 rows) - Prompt definitions

### Optimization Tables
- **SawCutLines** (45 rows) - Saw cutting patterns
- **SawStacks** (3 rows) - Sheet stacking for sawing
- **OptimizationResultAssociates** (39 rows) - Optimization associations

---

## PRIMARY ENTITY RELATIONSHIPS

```
┌─────────────────────────────────────────────────────────────────┐
│                      PROJECT HIERARCHY                          │
└─────────────────────────────────────────────────────────────────┘

Project (External)
    │
    ├─► WorkOrder (External)
    │       │
    │       ├─► Products (LinkIDWorkOrder)
    │       │       │
    │       │       ├─► Parts (LinkIDProduct)
    │       │       │
    │       │       └─► Subassemblies (LinkIDParentProduct)
    │       │
    │       └─► WorkOrderBatches (LinkIDWorkOrder)
    │
    └─► All tables have LinkIDWorkOrder for traceability


┌─────────────────────────────────────────────────────────────────┐
│                  SHEET OPTIMIZATION FLOW                         │
└─────────────────────────────────────────────────────────────────┘

WorkOrderBatch
    │
    ├─► PlacedSheets (LinkIDWorkOrderBatch)
    │       │                              
    │       ├─► Sheets (PlacedSheets.LinkID = Sheets.ID)
    │       │   [Material definitions]
    │       │
    │       └─► OptimizationResults (LinkIDWorkOrderBatch + Index match)
    │               │
    │               └─► Parts (LinkIDPart)
    │
    └─► SawCutLines (LinkIDWorkOrderBatch)
            │
            └─► SawStacks (LinkIDWorkOrderBatch)

CRITICAL JOIN:
PlacedSheets.Index (1-based) = OptimizationResults.Index (0-based) + 1


┌─────────────────────────────────────────────────────────────────┐
│                  PART MANUFACTURING FLOW                         │
└─────────────────────────────────────────────────────────────────┘

Parts
    │
    ├─► PartsProcessingStations (LinkIDPart)
    │   [Sequence of manufacturing stations]
    │
    ├─► Routes (LinkIDPart)
    │   │   [Tool paths and machining]
    │   │
    │   └─► Vectors (LinkIDRoute)
    │       [Geometric vectors for routes]
    │
    ├─► Edgebanding (LinkIDPart)
    │   [Edge banding operations]
    │
    ├─► DrillsHorizontal (LinkIDPart)
    │   [Horizontal drilling]
    │
    ├─► DrillsVertical (LinkIDPart)
    │   │   [Vertical drilling]
    │   │
    │   └─► DrillsVertical (LinkIDParentDrill - self-reference)
    │
    └─► Hardware (LinkIDPart)
        [Hardware attachments]


┌─────────────────────────────────────────────────────────────────┐
│                    CONFIGURATION & METADATA                      │
└─────────────────────────────────────────────────────────────────┘

Products
    │
    ├─► ProductsPrompts (LinkIDProduct)
    │       │
    │       └─► Prompts (LinkIDPrompt)
    │
    └─► FaceFrameImages (LinkIDProduct)

Subassemblies
    │
    ├─► Parts (LinkIDParentSubAssembly)
    │
    ├─► Hardware (LinkIDParentSubAssembly)
    │
    └─► Subassemblies (LinkIDParentSubassembly - hierarchical)


┌─────────────────────────────────────────────────────────────────┐
│              EXTERNAL REFERENCE TABLES (Not Migrated)            │
└─────────────────────────────────────────────────────────────────┘

These LinkID columns reference external tables:
- Category (LinkIDCategory)
- Material (LinkIDMaterial)
- ProcessingStation (LinkIDProcessingStation)
- Library (LinkIDLibrary)
- Location (LinkIDLocation)
- Vendor (LinkIDVendor / LinkIDDefaultVendor)
- Rendering (LinkIDTopFaceRendering, LinkIDBottomFaceRendering, LinkIDCoreRendering)
- SheetSize (LinkIDSheetSize)
- MaterialStorageLocation (LinkIDMaterialStorageLocation)
```

---

## TABLE DEPENDENCY MATRIX

### Level 1 - No Dependencies
- **Products** (depends on external: WorkOrder, Project, Category)
- **WorkOrderBatches** (depends on external: WorkOrder)
- **Sheets** (depends on external: Material, Category)
- **Prompts** (depends on external: Category)
- **Subassemblies** (depends on external: Category, Library, Project)

### Level 2 - Depends on Level 1
- **Parts** → Products
- **PlacedSheets** → WorkOrderBatches, Sheets
- **ProductsPrompts** → Products, Prompts
- **FaceFrameImages** → Products

### Level 3 - Depends on Level 2
- **OptimizationResults** → Parts, PlacedSheets (via WorkOrderBatch)
- **PartsProcessingStations** → Parts
- **Routes** → Parts
- **Edgebanding** → Parts, Products
- **DrillsHorizontal** → Parts
- **DrillsVertical** → Parts
- **Hardware** → Parts, Products
- **SawCutLines** → Parts, PlacedSheets

### Level 4 - Depends on Level 3
- **Vectors** → Routes
- **SawStacks** → WorkOrderBatches
- **OptimizationResultAssociates** → (Parent/Child relationships)

---

## CRITICAL JOIN PATTERNS

### 1. Product to All Part Details
```sql
FROM Products p
INNER JOIN Parts pt ON pt.LinkIDProduct = p.ID
LEFT JOIN PartsProcessingStations pps ON pps.LinkIDPart = pt.ID
LEFT JOIN Routes r ON r.LinkIDPart = pt.ID
LEFT JOIN Edgebanding e ON e.LinkIDPart = pt.ID
LEFT JOIN DrillsHorizontal dh ON dh.LinkIDPart = pt.ID
LEFT JOIN DrillsVertical dv ON dv.LinkIDPart = pt.ID
LEFT JOIN Hardware h ON h.LinkIDPart = pt.ID
```

### 2. Part to Sheet Optimization (COMPLEX!)
```sql
FROM Parts pt
INNER JOIN OptimizationResults opt ON opt.LinkIDPart = pt.ID
INNER JOIN PlacedSheets ps ON ps.LinkIDWorkOrderBatch = opt.LinkIDWorkOrderBatch
                            AND CAST(ps.[Index] AS INT) = CAST(opt.[Index] AS INT) + 1
INNER JOIN Sheets s ON s.ID = ps.LinkID
```
**Note**: Index offset is critical - OptimizationResults uses 0-based, PlacedSheets uses 1-based

### 3. Route to Vector Geometry
```sql
FROM Routes r
INNER JOIN Parts pt ON pt.ID = r.LinkIDPart
LEFT JOIN Vectors v ON v.LinkIDRoute = r.ID
```

### 4. Work Order Batch to All Sheets
```sql
FROM WorkOrderBatches wob
INNER JOIN PlacedSheets ps ON ps.LinkIDWorkOrderBatch = wob.ID
INNER JOIN Sheets s ON s.ID = ps.LinkID
LEFT JOIN OptimizationResults opt ON opt.LinkIDWorkOrderBatch = wob.ID
```

---

## KEY FIELD REFERENCE

### Identifiers
| Field | Type | Description |
|-------|------|-------------|
| ID | NVARCHAR(MAX) | Primary key (GUID format) |
| LinkID* | NVARCHAR(MAX) | Foreign key references |
| ScanCode | NVARCHAR(MAX) | Barcode identifier |

### Measurements (ALL NVARCHAR - Must CAST to FLOAT!)
| Field | Table | Unit | Calculation |
|-------|-------|------|-------------|
| Length | Parts, Sheets | mm | CAST(Length AS FLOAT) |
| Width | Parts, Sheets | mm | CAST(Width AS FLOAT) |
| Thickness | Parts | mm | CAST(Thickness AS FLOAT) |
| TotalRouteLength | Routes | m | CAST(TotalRouteLength AS FLOAT) |
| Quantity | Edgebanding | count | CAST(Quantity AS FLOAT) * 0.00105 = Linear m |

### Sheet Tracking
| Field | Table | Description |
|-------|-------|-------------|
| Index | PlacedSheets | Sheet number (1-based) |
| Index | OptimizationResults | Sheet number (0-based) |
| XCoord, YCoord | OptimizationResults | Part position on sheet |
| SheetNumber | Calculated | ps.Index or opt.Index + 1 |

### Processing
| Field | Table | Description |
|-------|-------|-------------|
| LinkIDProcessingStation | PartsProcessingStations | Station identifier |
| ToolType | Routes | Tool classification (5-AXIS, P2P, MITER) |
| MaterialName | Parts | Material type (CORIAN, SOLID, etc.) |
| FileName | Parts, OptimizationResults | Output file reference |

---

## DATA TYPE WARNINGS

**CRITICAL**: All columns are stored as `NVARCHAR(MAX)` regardless of actual data type!

**Always CAST before calculations:**
```sql
-- Wrong (string concatenation):
SELECT Length * Width FROM Parts

-- Correct (numeric multiplication):
SELECT CAST(Length AS FLOAT) * CAST(Width AS FLOAT) FROM Parts
```

**Common Conversions:**
- Numbers: `CAST(column AS FLOAT)` or `CAST(column AS INT)`
- Booleans: Stored as '0' or '1' strings
- Dates: `CAST(column AS DATETIME)`

---

## SCRAP TRACKING WORKFLOW

For back-propagation when a sheet is scrapped:

1. **Identify scrapped sheet**: PlacedSheets.Index or OptimizationResults.Index
2. **Find all parts on sheet**: Join Parts → OptimizationResults (match Index)
3. **Check processing status**: Join PartsProcessingStations for sequence
4. **Calculate waste**: Sum part areas, edging, tool paths completed
5. **Identify scrap point**: Match station where scrap occurred

```sql
-- Example: Sheet 3 scrapped at Edging
DECLARE @SheetNum INT = 3;
DECLARE @ScrapStation NVARCHAR(100) = 'Edging';

SELECT 
    pt.Name,
    pps.LinkIDProcessingStation,
    CAST(pt.Length AS FLOAT) * CAST(pt.Width AS FLOAT) / 1000000 AS Area_sqm,
    CAST(r.TotalRouteLength AS FLOAT) AS ToolPath_m
FROM Parts pt
INNER JOIN OptimizationResults opt ON opt.LinkIDPart = pt.ID
LEFT JOIN PartsProcessingStations pps ON pps.LinkIDPart = pt.ID
LEFT JOIN Routes r ON r.LinkIDPart = pt.ID
WHERE CAST(opt.[Index] AS INT) = @SheetNum - 1  -- Convert to 0-based
ORDER BY pps.ID;
```

---

## COMMON QUERIES

### Total Parts by Sheet
```sql
SELECT 
    CAST(opt.[Index] AS INT) + 1 AS SheetNumber,
    ps.Name AS SheetMaterial,
    COUNT(DISTINCT pt.ID) AS PartCount
FROM OptimizationResults opt
INNER JOIN Parts pt ON pt.ID = opt.LinkIDPart
INNER JOIN PlacedSheets ps ON ps.LinkIDWorkOrderBatch = opt.LinkIDWorkOrderBatch
WHERE CAST(ps.[Index] AS INT) = CAST(opt.[Index] AS INT) + 1
GROUP BY opt.[Index], ps.Name
ORDER BY SheetNumber;
```

### Processing Station Sequence
```sql
SELECT 
    pt.Name AS PartName,
    pps.LinkIDProcessingStation AS Station,
    ROW_NUMBER() OVER (PARTITION BY pt.ID ORDER BY pps.ID) AS Sequence
FROM Parts pt
INNER JOIN PartsProcessingStations pps ON pps.LinkIDPart = pt.ID
ORDER BY pt.Name, Sequence;
```

### Total Tool Path per Product
```sql
SELECT 
    p.Name AS ProductName,
    SUM(CAST(r.TotalRouteLength AS FLOAT)) AS Total_ToolPath_m
FROM Products p
INNER JOIN Parts pt ON pt.LinkIDProduct = p.ID
LEFT JOIN Routes r ON r.LinkIDPart = pt.ID
GROUP BY p.Name;
```

---

## NOTES

1. **All data is NVARCHAR**: Migration stored everything as strings
2. **Index offsets**: OptimizationResults (0-based) vs PlacedSheets (1-based)
3. **External references**: Many LinkID columns reference tables not in .sdf file
4. **GUIDs**: ID fields use GUID format with curly braces
5. **Processing sequence**: Use ROW_NUMBER() since no explicit sequence column
6. **Sheet matching**: Join via WorkOrderBatch + Index arithmetic

---

Generated: 2026-01-20
Schema: P1987_D018
Database: guru on PSF-GuruprasadT\SQLEXPRESS
