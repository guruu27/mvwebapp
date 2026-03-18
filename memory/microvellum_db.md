# Microvellum DB — Confirmed Join Patterns

## Connection
Server: `PSF-GuruprasadT\SQLEXPRESS`, Database: `guru`, Windows Auth

## Schema Naming
Each workorder = its own SQL schema: `P1987_D077`, `P1987_D018`, `P1987_D001`
Always prefix tables: `[P1987_D077].[Parts]` etc.

## ID Format Rules
- `.ID` = GUID format `{8009313F-26F9-...}` — used as physical PK only
- `.LinkID` = Microvellum non-GUID `261JGM3G1PWG` — used for ALL foreign key references
- ALL FK joins must use `.LinkID`, never `.ID`
- ALL string comparisons need `LTRIM(RTRIM(...))` — trailing spaces present in NVARCHAR

## Correct Join Chain (PlacedSheet → Part → Product)
```sql
FROM [P1987_D077].[PlacedSheets] ps
INNER JOIN [P1987_D077].[OptimizationResults] opt
    ON LTRIM(RTRIM(opt.LinkIDSheet)) = LTRIM(RTRIM(ps.LinkID))
INNER JOIN [P1987_D077].[Parts] pt
    ON LTRIM(RTRIM(pt.LinkID)) = LTRIM(RTRIM(opt.LinkIDPart))
INNER JOIN [P1987_D077].[Products] p
    ON LTRIM(RTRIM(p.LinkID)) = LTRIM(RTRIM(pt.LinkIDProduct))
```
- `OptimizationResults.LinkIDSheet = PlacedSheets.LinkID` (direct, NOT Index-based!)
- `OptimizationResults.LinkIDPart = Parts.LinkID`
- `Parts.LinkIDProduct = Products.LinkID`

## WorkOrderBatch Join
```sql
WorkOrderBatches.LinkID = PlacedSheets.LinkIDWorkOrderBatch
WorkOrderBatches.LinkID = OptimizationResults.LinkIDWorkOrderBatch
```
NOT `WorkOrderBatches.ID` (that's the GUID).

## Edgebanding Metric
- Column: `LinFt` (stored in mm despite name — it's the linear edge length in mm)
- No `Length` or `Width` columns in Edgebanding

## Routes Metric
- Column: `TotalRouteLength` (in mm)
- Parts can have multiple routes — use `SUM(DISTINCT TotalRouteLength)` to avoid duplicates

## P1987_D077 Missing Tables
- No `DrillsHorizontal` (present in P1987_D018)
- No `DrillsVertical` (present in P1987_D018)
- No `Hardware` (present in P1987_D018)

## Index-based join (AVOID — use direct LinkIDSheet join instead)
Old pattern from schema doc that is less reliable:
`CAST(opt.[Index] AS INT) + 1 = CAST(ps.[Index] AS INT)`

## Row Counts (P1987_D077)
Parts=230, Products=92, PlacedSheets=134, OptimizationResults=468
WorkOrderBatches=2 (WO: 261JGM0XQM4E + 261JH098GWME)
ProcessingStations: 3 distinct (21BMOJSH9M90, 1966O1PHUNP10, 215ROFJ6TWV10)
