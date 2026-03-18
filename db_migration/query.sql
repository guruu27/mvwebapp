-- =============================================================================
-- MICROVELLUM PRODUCTION PLAN QUERY
-- Schema: P1987_D077
-- Structure: WorkOrder -> ProcessingStation -> Sheet (MaterialName + metrics)
--            with Product -> Part on the right
--
-- KEY: All FK joins use .LinkID (non-GUID), not .ID (GUID)
--      All string joins require LTRIM/RTRIM (NVARCHAR columns have trailing spaces)
-- =============================================================================

WITH PartMetrics AS (
    -- Per-part aggregated metrics (Routes + Edgebanding)
    SELECT
        pt.LinkID                                                           AS PartKey,
        pt.Name                                                             AS PartName,
        CAST(pt.Length AS FLOAT)                                            AS PartLength_mm,
        CAST(pt.Width AS FLOAT)                                             AS PartWidth_mm,
        CAST(pt.Thickness AS FLOAT)                                         AS PartThickness_mm,
        pt.MaterialName                                                     AS PartMaterial,
        pt.LinkIDProduct,

        -- Tool path: sum all routes for this part (mm)
        ISNULL(SUM(DISTINCT CAST(r.TotalRouteLength AS FLOAT)), 0)          AS PartToolPath_mm,

        -- Edgebanding: sum linear mm across all edges
        ISNULL(SUM(CAST(eb.LinFt AS FLOAT)), 0)                             AS PartEdgeBand_mm

    FROM [P1987_D077].[Parts] pt
    LEFT JOIN [P1987_D077].[Routes] r
        ON LTRIM(RTRIM(r.LinkIDPart)) = LTRIM(RTRIM(pt.LinkID))
    LEFT JOIN [P1987_D077].[Edgebanding] eb
        ON LTRIM(RTRIM(eb.LinkIDPart)) = LTRIM(RTRIM(pt.LinkID))
    GROUP BY
        pt.LinkID, pt.Name, pt.Length, pt.Width, pt.Thickness,
        pt.MaterialName, pt.LinkIDProduct
),

SheetParts AS (
    -- Core join: PlacedSheets -> OptimizationResults -> Parts
    SELECT
        ps.LinkIDWorkOrder                                                  AS WorkOrderID,
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
        pm.PartToolPath_mm,
        pm.PartEdgeBand_mm,
        (pm.PartLength_mm * pm.PartWidth_mm) / 1000000.0                   AS PartArea_sqm

    FROM [P1987_D077].[PlacedSheets] ps
    INNER JOIN [P1987_D077].[OptimizationResults] opt
        ON LTRIM(RTRIM(opt.LinkIDSheet)) = LTRIM(RTRIM(ps.LinkID))
    INNER JOIN PartMetrics pm
        ON LTRIM(RTRIM(pm.PartKey)) = LTRIM(RTRIM(opt.LinkIDPart))
)

SELECT
    -- =========================================================
    -- LEFT HIERARCHY: WorkOrder -> ProcessingStation -> Sheet
    -- =========================================================
    sp.WorkOrderID,
    sp.ProcessingStation,
    sp.MaterialName,
    sp.SheetNumber,
    CAST(sp.SheetLength_mm AS INT)                                          AS SheetLength_mm,
    CAST(sp.SheetWidth_mm  AS INT)                                          AS SheetWidth_mm,
    CAST(sp.SheetThickness_mm AS INT)                                       AS SheetThickness_mm,

    -- Sheet-level totals (window over all parts on this placed sheet)
    CAST(SUM(sp.PartToolPath_mm)  OVER (PARTITION BY sp.PlacedSheetKey) / 1000.0 AS DECIMAL(10,3))  AS Sheet_ToolPath_m,
    CAST(SUM(sp.PartEdgeBand_mm)  OVER (PARTITION BY sp.PlacedSheetKey) / 1000.0 AS DECIMAL(10,3))  AS Sheet_EdgeBand_m,
    CAST(SUM(sp.PartArea_sqm)     OVER (PARTITION BY sp.PlacedSheetKey)           AS DECIMAL(10,4))  AS Sheet_Area_sqm,
    COUNT(sp.PartKey)             OVER (PARTITION BY sp.PlacedSheetKey)                              AS Sheet_PartCount,

    -- =========================================================
    -- RIGHT HIERARCHY: Product -> Part
    -- =========================================================
    p.Name                                                                  AS ProductName,
    sp.PartName,
    CAST(sp.PartLength_mm  AS INT)                                          AS PartLength_mm,
    CAST(sp.PartWidth_mm   AS INT)                                          AS PartWidth_mm,
    CAST(sp.PartThickness_mm AS INT)                                        AS PartThickness_mm,
    sp.PartMaterial,

    -- Part-level metrics
    CAST(sp.PartToolPath_mm  / 1000.0 AS DECIMAL(10,3))                     AS Part_ToolPath_m,
    CAST(sp.PartEdgeBand_mm  / 1000.0 AS DECIMAL(10,3))                     AS Part_EdgeBand_m,
    CAST(sp.PartArea_sqm              AS DECIMAL(10,4))                      AS Part_Area_sqm

FROM SheetParts sp
INNER JOIN [P1987_D077].[Products] p
    ON LTRIM(RTRIM(p.LinkID)) = LTRIM(RTRIM(sp.LinkIDProduct))

ORDER BY
    sp.WorkOrderID,
    sp.ProcessingStation,
    sp.SheetNumber,
    p.Name,
    sp.PartName;
