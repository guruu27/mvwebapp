-- =============================================================================
-- MICROVELLUM PRODUCTION PLAN QUERY
-- Schema: P1987_D018
-- Structure: WorkOrder -> ProcessingStation -> Sheet (MaterialName + metrics)
--            with Product -> Part on the right
-- Extra vs D077: DrillsHorizontal, DrillsVertical, Hardware
-- =============================================================================

WITH PartMetrics AS (
    -- Per-part aggregated metrics
    SELECT
        pt.LinkID                                                               AS PartKey,
        pt.Name                                                                 AS PartName,
        CAST(pt.Length AS FLOAT)                                                AS PartLength_mm,
        CAST(pt.Width AS FLOAT)                                                 AS PartWidth_mm,
        CAST(pt.Thickness AS FLOAT)                                             AS PartThickness_mm,
        pt.MaterialName                                                         AS PartMaterial,
        pt.LinkIDProduct,

        -- Tool path: sum all routes (mm)
        ISNULL(SUM(DISTINCT CAST(r.TotalRouteLength AS FLOAT)), 0)              AS PartToolPath_mm,

        -- Edgebanding: linear mm
        ISNULL(SUM(CAST(eb.LinFt AS FLOAT)), 0)                                 AS PartEdgeBand_mm,

        -- Horizontal drills: count
        COUNT(DISTINCT dh.ID)                                                   AS PartHorizDrills,

        -- Vertical drills: count
        COUNT(DISTINCT dv.ID)                                                   AS PartVertDrills

    FROM [P1987_D018].[Parts] pt
    LEFT JOIN [P1987_D018].[Routes] r
        ON LTRIM(RTRIM(r.LinkIDPart)) = LTRIM(RTRIM(pt.LinkID))
    LEFT JOIN [P1987_D018].[Edgebanding] eb
        ON LTRIM(RTRIM(eb.LinkIDPart)) = LTRIM(RTRIM(pt.LinkID))
    LEFT JOIN [P1987_D018].[DrillsHorizontal] dh
        ON LTRIM(RTRIM(dh.LinkIDPart)) = LTRIM(RTRIM(pt.LinkID))
    LEFT JOIN [P1987_D018].[DrillsVertical] dv
        ON LTRIM(RTRIM(dv.LinkIDPart)) = LTRIM(RTRIM(pt.LinkID))
    GROUP BY
        pt.LinkID, pt.Name, pt.Length, pt.Width, pt.Thickness,
        pt.MaterialName, pt.LinkIDProduct
),

SheetParts AS (
    SELECT
        ps.LinkIDWorkOrder                                                      AS WorkOrderID,
        ps.LinkIDProcessingStation                                              AS ProcessingStation,
        CAST(ps.[Index] AS INT)                                                 AS SheetNumber,
        ps.Name                                                                 AS MaterialName,
        CAST(ps.Length AS FLOAT)                                                AS SheetLength_mm,
        CAST(ps.Width AS FLOAT)                                                 AS SheetWidth_mm,
        CAST(ps.Thickness AS FLOAT)                                             AS SheetThickness_mm,
        ps.LinkID                                                               AS PlacedSheetKey,

        pm.PartKey,
        pm.PartName,
        pm.PartLength_mm,
        pm.PartWidth_mm,
        pm.PartThickness_mm,
        pm.PartMaterial,
        pm.LinkIDProduct,
        pm.PartToolPath_mm,
        pm.PartEdgeBand_mm,
        pm.PartHorizDrills,
        pm.PartVertDrills,
        (pm.PartLength_mm * pm.PartWidth_mm) / 1000000.0                       AS PartArea_sqm

    FROM [P1987_D018].[PlacedSheets] ps
    INNER JOIN [P1987_D018].[OptimizationResults] opt
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
    CAST(sp.SheetLength_mm AS INT)                                              AS SheetLength_mm,
    CAST(sp.SheetWidth_mm  AS INT)                                              AS SheetWidth_mm,
    CAST(sp.SheetThickness_mm AS INT)                                           AS SheetThickness_mm,

    -- Sheet-level totals (all parts on this placed sheet)
    CAST(SUM(sp.PartToolPath_mm)    OVER (PARTITION BY sp.PlacedSheetKey) / 1000.0 AS DECIMAL(10,3)) AS Sheet_ToolPath_m,
    CAST(SUM(sp.PartEdgeBand_mm)    OVER (PARTITION BY sp.PlacedSheetKey) / 1000.0 AS DECIMAL(10,3)) AS Sheet_EdgeBand_m,
    CAST(SUM(sp.PartArea_sqm)       OVER (PARTITION BY sp.PlacedSheetKey)           AS DECIMAL(10,4)) AS Sheet_Area_sqm,
    SUM(sp.PartHorizDrills)         OVER (PARTITION BY sp.PlacedSheetKey)                             AS Sheet_HorizDrills,
    SUM(sp.PartVertDrills)          OVER (PARTITION BY sp.PlacedSheetKey)                             AS Sheet_VertDrills,
    COUNT(sp.PartKey)               OVER (PARTITION BY sp.PlacedSheetKey)                             AS Sheet_PartCount,

    -- =========================================================
    -- RIGHT HIERARCHY: Product -> Part
    -- =========================================================
    p.Name                                                                      AS ProductName,
    sp.PartName,
    CAST(sp.PartLength_mm  AS INT)                                              AS PartLength_mm,
    CAST(sp.PartWidth_mm   AS INT)                                              AS PartWidth_mm,
    CAST(sp.PartThickness_mm AS INT)                                            AS PartThickness_mm,
    sp.PartMaterial,

    -- Part-level metrics
    CAST(sp.PartToolPath_mm  / 1000.0 AS DECIMAL(10,3))                         AS Part_ToolPath_m,
    CAST(sp.PartEdgeBand_mm  / 1000.0 AS DECIMAL(10,3))                         AS Part_EdgeBand_m,
    CAST(sp.PartArea_sqm              AS DECIMAL(10,4))                          AS Part_Area_sqm,
    sp.PartHorizDrills                                                           AS Part_HorizDrills,
    sp.PartVertDrills                                                            AS Part_VertDrills

FROM SheetParts sp
INNER JOIN [P1987_D018].[Products] p
    ON LTRIM(RTRIM(p.LinkID)) = LTRIM(RTRIM(sp.LinkIDProduct))

ORDER BY
    sp.WorkOrderID,
    sp.ProcessingStation,
    sp.SheetNumber,
    p.Name,
    sp.PartName;
