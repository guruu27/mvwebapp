-- =============================================================================
-- MICROVELLUM PRODUCTION PLAN — GENERAL QUERY
-- Exact replica of the SDF Compact Edition query, adapted for SQL Server
-- Runs against dbo schema (= last imported workorder)
--
-- Output: One row per WorkOrderBatch × ProcessingStation
-- Columns match the SDF query: NestSht, NestPrts, PnlSht, PnlPrts,
--   Edge, P2P, Miter, Solid, Product, TtlPrts, BatchName
-- Plus: Hours calculations (uncomment to enable)
--
-- Station IDs:
--   21BMOJSH9M90   = CNC Nesting
--   1966O1PHUNP10  = Panel Saw (primary)
--   1966O9J0UOZ10  = Panel Saw (secondary)
--   215ROFJ6TWV10  = Ghost station (excluded via HAVING)
-- =============================================================================

SELECT

    -- ===================== NESTING STATION =====================
    CASE WHEN OpRe.LinkIDProcessingStation = '21BMOJSH9M90'
         THEN Sheets.[count]
    END                                                         AS NestSht,

    CASE WHEN OpRe.LinkIDProcessingStation = '21BMOJSH9M90'
         THEN OpRe.OptimizedQuantity
    END                                                         AS NestPrts,

    -- ===================== PANEL SAW STATION =====================
    CASE WHEN OpRe.LinkIDProcessingStation IN ('1966O1PHUNP10', '1966O9J0UOZ10')
         THEN Sheets.[count]
    END                                                         AS PnlSht,

    CASE WHEN OpRe.LinkIDProcessingStation IN ('1966O1PHUNP10', '1966O9J0UOZ10')
         THEN OpRe.OptimizedQuantity
    END                                                         AS PnlPrts,

    -- ===================== WORKORDER-LEVEL METRICS =====================
    ROUND(Edgeing.Linft, 0)                                     AS Edge,
    P2P.Qty                                                     AS P2P,
    Miter.Qty                                                   AS Miter,
    Solid.Qty                                                   AS Solid,
    Product.Product                                             AS Product,
    Part.Parts                                                  AS TtlPrts,

    -- ===================== HOURS ESTIMATES =====================
    -- Uncomment below to include labor hour estimates

    -- Nesting hours: 9.5 min per part
    -- CASE WHEN OpRe.LinkIDProcessingStation = '21BMOJSH9M90'
    --      THEN OpRe.OptimizedQuantity * 9.5 / 60
    -- END                                                      AS NestingHours,

    -- Panel Saw hours: 3.5 min per part
    -- CASE WHEN OpRe.LinkIDProcessingStation IN ('1966O1PHUNP10', '1966O9J0UOZ10')
    --      THEN OpRe.OptimizedQuantity * 3.5 / 60
    -- END                                                      AS PanelHours,

    -- P2P hours: 5 min per part × 1.12 factor
    -- CASE WHEN OpRe.LinkIDProcessingStation IN ('1966O1PHUNP10', '1966O9J0UOZ10')
    --      THEN ROUND(P2P.Qty * 5.0 / 60 * 1.12, 2)
    -- END                                                      AS P2pHours,

    -- Miter hours: 5 min per part
    -- Miter.Qty * 5.0 / 60                                    AS MiterHours,

    -- Edgebanding hours: 2.8 min per linear ft
    -- ROUND(Edgeing.Linft, 0) * 2.8 / 60                      AS EdgingHours,

    -- Solid hours: 5 min per unit
    -- ROUND(Solid.Qty * 5.0 / 60, 2)                          AS SolidHours,

    -- ===================== BATCH IDENTITY =====================
    [WorkOrderBatches].[Name]                                   AS BatchName

-- =============================================================================
-- CORE: OptimizationResults aggregated per WO × Batch × Station
-- =============================================================================
FROM (
    SELECT
        SUM(CAST(OptimizationResults.OptimizedQuantity AS FLOAT)) AS OptimizedQuantity,
        OptimizationResults.LinkIDWorkOrder,
        OptimizationResults.LinkIDWorkOrderBatch,
        OptimizationResults.LinkIDProcessingStation
    FROM dbo.OptimizationResults
    WHERE OptimizationResults.ScrapType = 0
    GROUP BY
        OptimizationResults.LinkIDWorkOrder,
        OptimizationResults.LinkIDProcessingStation,
        OptimizationResults.LinkIDWorkOrderBatch
    HAVING SUM(CAST(OptimizationResults.OptimizedQuantity AS FLOAT)) > 0
) OpRe

-- =============================================================================
-- SHEETS: count per station per batch (Width > 350 = full sheets only)
-- Joins on: ProcessingStation + WorkOrder + WorkOrderBatch
-- =============================================================================
LEFT JOIN (
    SELECT
        COUNT(PlacedSheets.ID)                                  AS [count],
        PlacedSheets.LinkIDProcessingStation,
        PlacedSheets.LinkIDWorkOrder,
        PlacedSheets.LinkIDWorkOrderBatch
    FROM dbo.PlacedSheets
    WHERE CAST(PlacedSheets.Width AS FLOAT) > 350
    GROUP BY
        PlacedSheets.LinkIDProcessingStation,
        PlacedSheets.LinkIDWorkOrder,
        PlacedSheets.LinkIDWorkOrderBatch
) Sheets
    ON  OpRe.LinkIDProcessingStation = Sheets.LinkIDProcessingStation
    AND OpRe.LinkIDWorkOrderBatch    = Sheets.LinkIDWorkOrderBatch
    AND OpRe.LinkIDWorkOrder         = Sheets.LinkIDWorkOrder

-- =============================================================================
-- PRODUCTS: total product quantity per workorder
-- =============================================================================
LEFT JOIN (
    SELECT
        SUM(CAST([Products].[Quantity] AS FLOAT))               AS Product,
        [Products].[LinkIDWorkOrder]
    FROM dbo.Products
    GROUP BY [Products].[LinkIDWorkOrder]
) Product
    ON OpRe.LinkIDWorkOrder = Product.LinkIDWorkOrder

-- =============================================================================
-- EDGEBANDING: total linear feet per workorder
-- SUM(Quantity) * 0.00105 = conversion to linear feet
-- =============================================================================
LEFT JOIN (
    SELECT
        SUM(CAST([Edgebanding].[Quantity] AS FLOAT)) * 0.00105  AS Linft,
        [Edgebanding].[LinkIDWorkOrder]
    FROM dbo.Edgebanding
    GROUP BY [Edgebanding].[LinkIDWorkOrder]
) Edgeing
    ON OpRe.LinkIDWorkOrder = Edgeing.LinkIDWorkOrder

-- =============================================================================
-- TOTAL PARTS: all non-scrap optimized parts across all stations
-- =============================================================================
LEFT JOIN (
    SELECT
        SUM(CAST(OptimizationResults.OptimizedQuantity AS FLOAT)) AS Parts,
        LinkIDWorkOrder
    FROM dbo.OptimizationResults
    WHERE OptimizationResults.ScrapType = 0
    GROUP BY LinkIDWorkOrder
) Part
    ON OpRe.LinkIDWorkOrder = Part.LinkIDWorkOrder

-- =============================================================================
-- WORKORDER BATCHES: batch name
-- =============================================================================
INNER JOIN dbo.WorkOrderBatches
    ON OpRe.LinkIDWorkOrderBatch = [WorkOrderBatches].[LinkID]

-- =============================================================================
-- P2P: parts needing second CNC pass (Face6Barcode populated)
-- =============================================================================
LEFT JOIN (
    SELECT
        LinkIDWorkOrder,
        'P2P'                                                   AS Operation,
        COUNT(Quantity)                                          AS Qty
    FROM dbo.Parts
    WHERE LEN(LTRIM(RTRIM(ISNULL(Face6Barcode, '')))) > 0
    GROUP BY LinkIDWorkOrder
) P2P
    ON OpRe.LinkIDWorkOrder = P2P.LinkIDWorkOrder

-- =============================================================================
-- MITER: parts flagged with '@' in Comments
-- =============================================================================
LEFT JOIN (
    SELECT
        LinkIDWorkOrder,
        'Miter'                                                 AS Operation,
        COUNT(Quantity)                                          AS Qty
    FROM dbo.Parts
    WHERE Comments LIKE '%@%'
    GROUP BY LinkIDWorkOrder
) Miter
    ON OpRe.LinkIDWorkOrder = Miter.LinkIDWorkOrder

-- =============================================================================
-- SOLID WOOD: linear meters of solid material sheets
-- CEILING(SUM(Quantity * Length) * 0.001)
-- =============================================================================
LEFT JOIN (
    SELECT
        LinkIDWorkOrder,
        CEILING(SUM(CAST(PlacedSheets.Quantity AS FLOAT) * CAST(PlacedSheets.Length AS FLOAT)) * 0.001) AS Qty
    FROM dbo.PlacedSheets
    WHERE PlacedSheets.Name LIKE '%Solid%'
      AND PlacedSheets.Name NOT LIKE '%Solid Surface%'
    GROUP BY LinkIDWorkOrder
) Solid
    ON OpRe.LinkIDWorkOrder = Solid.LinkIDWorkOrder

-- =============================================================================
-- OPTIONAL: Filter to a specific batch
-- Uncomment and modify the batch name pattern as needed
-- =============================================================================
-- WHERE [WorkOrderBatches].[Name] LIKE '%1'

ORDER BY
    [WorkOrderBatches].[Name],
    OpRe.LinkIDProcessingStation;
