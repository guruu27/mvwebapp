-- =============================================================================
-- MICROVELLUM PRODUCTION PLAN — WORKORDER SUMMARY
-- One row per active processing station per workorder batch
-- Excludes stations with zero optimized quantity (e.g. 215ROFJ6TWV10)
-- Uses dbo schema (active/current workorder import)
-- =============================================================================

SELECT

    -- Batch and workorder identity
    wob.[Name]                                              AS BatchName,
    ore.LinkIDWorkOrder,

    -- Processing station
    ore.LinkIDProcessingStation                             AS StationID,
    CASE ore.LinkIDProcessingStation
        WHEN '21BMOJSH9M90'  THEN 'CNC Nesting'
        WHEN '1966O1PHUNP10' THEN 'Panel Saw'
        WHEN '1966O9J0UOZ10' THEN 'Panel Saw'
        ELSE ore.LinkIDProcessingStation                    -- future stations show raw ID
    END                                                     AS StationName,

    -- Sheets going through this station (full sheets only, Width > 350mm)
    ISNULL(sh.SheetCount, 0)                                AS Sheets,

    -- Parts going through this station (non-scrap, optimized quantity)
    ore.StationParts                                        AS Parts,

    -- ---- WorkOrder-level totals (same value on every station row for this WO) ----

    -- Edgebanding: SUM(Quantity) * 0.00105 = total meters incl. 5% waste
    ROUND(ISNULL(eb.EdgeBand_m, 0), 1)                      AS EdgeBand_m,

    -- P2P: parts where Face6Barcode is populated (needs second CNC pass)
    ISNULL(p2p.P2P_Count, 0)                                AS P2P_Parts,

    -- Miter: parts where Comments contains '@' (Microvellum miter flag)
    ISNULL(mit.Miter_Count, 0)                              AS Miter_Parts,

    -- Solid wood: linear meters of sheets named '%Solid%' (excl. Solid Surface)
    ISNULL(sol.Solid_m, 0)                                  AS Solid_m,

    -- Total products in this workorder
    ISNULL(prod.ProductQty, 0)                              AS Products,

    -- Total non-scrap parts across ALL stations for this workorder
    ISNULL(tot.TotalParts, 0)                               AS TotalParts

FROM (
    -- Core: one row per station per workorder batch, with actual work only
    SELECT
        LinkIDWorkOrder,
        LinkIDWorkOrderBatch,
        LinkIDProcessingStation,
        SUM(CAST(OptimizedQuantity AS FLOAT))               AS StationParts
    FROM dbo.OptimizationResults
    WHERE ScrapType = 0
    GROUP BY LinkIDWorkOrder, LinkIDWorkOrderBatch, LinkIDProcessingStation
    HAVING SUM(CAST(OptimizedQuantity AS FLOAT)) > 0        -- drop ghost stations
) ore

INNER JOIN dbo.WorkOrderBatches wob
    ON wob.LinkID = ore.LinkIDWorkOrderBatch

-- Sheets per station (Width > 350 excludes off-cut strips)
LEFT JOIN (
    SELECT
        LinkIDProcessingStation,
        LinkIDWorkOrderBatch,
        COUNT(ID)                                           AS SheetCount
    FROM dbo.PlacedSheets
    WHERE CAST(Width AS FLOAT) > 350
    GROUP BY LinkIDProcessingStation, LinkIDWorkOrderBatch
) sh
    ON  sh.LinkIDProcessingStation = ore.LinkIDProcessingStation
    AND sh.LinkIDWorkOrderBatch    = ore.LinkIDWorkOrderBatch

-- Edgebanding total (workorder level)
LEFT JOIN (
    SELECT
        LinkIDWorkOrder,
        SUM(CAST(Quantity AS FLOAT)) * 0.00105              AS EdgeBand_m
    FROM dbo.Edgebanding
    GROUP BY LinkIDWorkOrder
) eb ON eb.LinkIDWorkOrder = ore.LinkIDWorkOrder

-- P2P: count of parts needing Face 6 machining
LEFT JOIN (
    SELECT
        LinkIDWorkOrder,
        COUNT(1)                                            AS P2P_Count
    FROM dbo.Parts
    WHERE LEN(LTRIM(RTRIM(ISNULL(Face6Barcode, '')))) > 0
    GROUP BY LinkIDWorkOrder
) p2p ON p2p.LinkIDWorkOrder = ore.LinkIDWorkOrder

-- Miter: count of parts flagged with '@' in Comments
LEFT JOIN (
    SELECT
        LinkIDWorkOrder,
        COUNT(1)                                            AS Miter_Count
    FROM dbo.Parts
    WHERE Comments LIKE '%@%'
    GROUP BY LinkIDWorkOrder
) mit ON mit.LinkIDWorkOrder = ore.LinkIDWorkOrder

-- Solid wood linear meters
LEFT JOIN (
    SELECT
        LinkIDWorkOrder,
        CEILING(SUM(CAST(Quantity AS FLOAT) * CAST(Length AS FLOAT)) * 0.001) AS Solid_m
    FROM dbo.PlacedSheets
    WHERE Name LIKE '%Solid%'
      AND Name NOT LIKE '%Solid Surface%'
    GROUP BY LinkIDWorkOrder
) sol ON sol.LinkIDWorkOrder = ore.LinkIDWorkOrder

-- Total product quantity
LEFT JOIN (
    SELECT
        LinkIDWorkOrder,
        SUM(CAST(Quantity AS FLOAT))                        AS ProductQty
    FROM dbo.Products
    GROUP BY LinkIDWorkOrder
) prod ON prod.LinkIDWorkOrder = ore.LinkIDWorkOrder

-- Total non-scrap parts (all stations combined)
LEFT JOIN (
    SELECT
        LinkIDWorkOrder,
        SUM(CAST(OptimizedQuantity AS FLOAT))               AS TotalParts
    FROM dbo.OptimizationResults
    WHERE ScrapType = 0
    GROUP BY LinkIDWorkOrder
) tot ON tot.LinkIDWorkOrder = ore.LinkIDWorkOrder

ORDER BY
    wob.[Name],
    ore.LinkIDWorkOrder,
    ore.LinkIDProcessingStation;
