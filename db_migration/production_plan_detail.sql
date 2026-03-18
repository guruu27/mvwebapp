-- =============================================================================
-- MICROVELLUM PRODUCTION PLAN — PER-SHEET DETAIL (Query 2)
-- Uses dbo schema (= last imported workorder)
--
-- Structure:
--   LEFT:  WorkOrder → ProcessingStation → Sheet (material, size, metrics)
--   RIGHT: Product → Part (name, size, tool path, edgebanding, area)
--
-- Links to production_plan.sql (Query 1) via:
--   WorkOrderBatch + ProcessingStation
--
-- Key Join Rules (SQL Server):
--   - All FK joins use .LinkID (non-GUID), not .ID (GUID)
--   - String joins need LTRIM(RTRIM(...)) for trailing-space NVARCHAR columns
--   - OptimizationResults.LinkIDSheet = PlacedSheets.LinkID (direct)
--   - OptimizationResults.LinkIDPart  = Parts.LinkID
--   - Parts.LinkIDProduct             = Products.LinkID
-- =============================================================================

WITH PartMetrics AS (
    -- =========================================================================
    -- Per-part aggregated metrics: tool path + edgebanding
    -- Routes and Edgebanding can have multiple rows per part → aggregate
    -- =========================================================================
    SELECT
        pt.LinkID                                                           AS PartKey,
        pt.Name                                                             AS PartName,
        CAST(pt.Length AS FLOAT)                                            AS PartLength_mm,
        CAST(pt.Width AS FLOAT)                                             AS PartWidth_mm,
        CAST(pt.Thickness AS FLOAT)                                         AS PartThickness_mm,
        pt.MaterialName                                                     AS PartMaterial,
        pt.LinkIDProduct,
        pt.LinkIDWorkOrder,

        -- P2P flag: part needs Face 6 machining
        CASE WHEN LEN(LTRIM(RTRIM(ISNULL(pt.Face6Barcode, '')))) > 0
             THEN 1 ELSE 0
        END                                                                 AS IsP2P,

        -- Miter flag: part has '@' in Comments
        CASE WHEN pt.Comments LIKE '%@%'
             THEN 1 ELSE 0
        END                                                                 AS IsMiter,

        -- Tool path: sum all routes for this part (mm → m)
        ISNULL(SUM(DISTINCT CAST(r.TotalRouteLength AS FLOAT)), 0)          AS PartToolPath_mm,

        -- Edgebanding: sum linear mm across all edges (LinFt column is actually mm)
        ISNULL(SUM(CAST(eb.LinFt AS FLOAT)), 0)                             AS PartEdgeBand_mm

    FROM dbo.Parts pt
    LEFT JOIN dbo.Routes r
        ON LTRIM(RTRIM(r.LinkIDPart)) = LTRIM(RTRIM(pt.LinkID))
    LEFT JOIN dbo.Edgebanding eb
        ON LTRIM(RTRIM(eb.LinkIDPart)) = LTRIM(RTRIM(pt.LinkID))
    GROUP BY
        pt.LinkID, pt.Name, pt.Length, pt.Width, pt.Thickness,
        pt.MaterialName, pt.LinkIDProduct, pt.LinkIDWorkOrder,
        pt.Face6Barcode, pt.Comments
),

SheetParts AS (
    -- =========================================================================
    -- Core join: PlacedSheets → OptimizationResults → PartMetrics
    -- One row per part placement on a sheet
    -- =========================================================================
    SELECT
        ps.LinkIDWorkOrder                                                  AS WorkOrderID,
        ps.LinkIDWorkOrderBatch                                             AS WorkOrderBatchID,
        ps.LinkIDProcessingStation                                          AS ProcessingStation,
        CAST(ps.[Index] AS INT)                                             AS SheetNumber,
        ps.Name                                                             AS MaterialName,
        CAST(ps.Length AS FLOAT)                                            AS SheetLength_mm,
        CAST(ps.Width AS FLOAT)                                             AS SheetWidth_mm,
        CAST(ps.Thickness AS FLOAT)                                         AS SheetThickness_mm,
        ps.LinkID                                                           AS PlacedSheetKey,

        pm.PartKey,
        pm.PartName,
        pm.PartLength_mm,
        pm.PartWidth_mm,
        pm.PartThickness_mm,
        pm.PartMaterial,
        pm.LinkIDProduct,
        pm.IsP2P,
        pm.IsMiter,
        pm.PartToolPath_mm,
        pm.PartEdgeBand_mm,
        (pm.PartLength_mm * pm.PartWidth_mm) / 1000000.0                   AS PartArea_sqm

    FROM dbo.PlacedSheets ps
    INNER JOIN dbo.OptimizationResults opt
        ON LTRIM(RTRIM(opt.LinkIDSheet)) = LTRIM(RTRIM(ps.LinkID))
       AND opt.ScrapType = 0
    INNER JOIN PartMetrics pm
        ON LTRIM(RTRIM(pm.PartKey)) = LTRIM(RTRIM(opt.LinkIDPart))
)

SELECT
    -- =====================================================================
    -- BATCH & STATION IDENTITY (links to Query 1)
    -- =====================================================================
    wob.[Name]                                                              AS BatchName,
    CASE sp.ProcessingStation
        WHEN '21BMOJSH9M90'  THEN 'CNC Nesting'
        WHEN '1966O1PHUNP10' THEN 'Panel Saw'
        WHEN '1966O9J0UOZ10' THEN 'Panel Saw'
        ELSE sp.ProcessingStation
    END                                                                     AS StationName,

    -- =====================================================================
    -- LEFT: SHEET INFO
    -- =====================================================================
    sp.MaterialName,
    sp.SheetNumber,
    CAST(sp.SheetLength_mm AS INT)                                          AS SheetLength_mm,
    CAST(sp.SheetWidth_mm  AS INT)                                          AS SheetWidth_mm,

    -- Sheet-level aggregated totals (window functions over all parts on this sheet)
    CAST(SUM(sp.PartToolPath_mm)  OVER (PARTITION BY sp.PlacedSheetKey) / 1000.0
         AS DECIMAL(10,2))                                                  AS Sheet_ToolPath_m,
    CAST(SUM(sp.PartEdgeBand_mm)  OVER (PARTITION BY sp.PlacedSheetKey) / 1000.0
         AS DECIMAL(10,2))                                                  AS Sheet_EdgeBand_m,
    CAST(SUM(sp.PartArea_sqm)     OVER (PARTITION BY sp.PlacedSheetKey)
         AS DECIMAL(10,3))                                                  AS Sheet_Area_sqm,
    COUNT(sp.PartKey)             OVER (PARTITION BY sp.PlacedSheetKey)      AS Sheet_PartCount,

    -- =====================================================================
    -- RIGHT: PRODUCT → PART
    -- =====================================================================
    p.Name                                                                  AS ProductName,
    CAST(p.Quantity AS INT)                                                 AS ProductQty,
    sp.PartName,
    CAST(sp.PartLength_mm  AS INT)                                          AS PartLength_mm,
    CAST(sp.PartWidth_mm   AS INT)                                          AS PartWidth_mm,
    sp.PartMaterial,

    -- Part-level metrics
    CAST(sp.PartToolPath_mm  / 1000.0 AS DECIMAL(10,2))                     AS Part_ToolPath_m,
    CAST(sp.PartEdgeBand_mm  / 1000.0 AS DECIMAL(10,2))                     AS Part_EdgeBand_m,
    CAST(sp.PartArea_sqm              AS DECIMAL(10,4))                      AS Part_Area_sqm,
    sp.IsP2P,
    sp.IsMiter

FROM SheetParts sp
INNER JOIN dbo.Products p
    ON LTRIM(RTRIM(p.LinkID)) = LTRIM(RTRIM(sp.LinkIDProduct))
INNER JOIN dbo.WorkOrderBatches wob
    ON LTRIM(RTRIM(wob.LinkID)) = LTRIM(RTRIM(sp.WorkOrderBatchID))

ORDER BY
    wob.[Name],
    sp.ProcessingStation,
    sp.SheetNumber,
    p.Name,
    sp.PartName;
