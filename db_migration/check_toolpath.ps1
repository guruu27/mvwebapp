$conn = New-Object System.Data.SqlClient.SqlConnection
$conn.ConnectionString = 'Server=PSF-GuruprasadT\SQLEXPRESS;Database=guru;Trusted_Connection=True;'
$conn.Open()

function Run-Query($sql, $label) {
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $sql
    $cmd.CommandTimeout = 60
    $reader = $cmd.ExecuteReader()
    $table = New-Object System.Data.DataTable
    $table.Load($reader)
    Write-Host "`n=== $label ==="
    $table | Format-Table -AutoSize
}

# Sample CNC Nesting rows with tool path / edge band
Run-Query "
;WITH PartMetrics AS (
    SELECT
        pt.LinkID AS PartKey, pt.Name AS PartName,
        ISNULL(SUM(DISTINCT CAST(r.TotalRouteLength AS FLOAT)), 0) AS PartToolPath_mm,
        ISNULL(SUM(CAST(eb.LinFt AS FLOAT)), 0) AS PartEdgeBand_mm
    FROM dbo.Parts pt
    LEFT JOIN dbo.Routes r ON LTRIM(RTRIM(r.LinkIDPart)) = LTRIM(RTRIM(pt.LinkID))
    LEFT JOIN dbo.Edgebanding eb ON LTRIM(RTRIM(eb.LinkIDPart)) = LTRIM(RTRIM(pt.LinkID))
    GROUP BY pt.LinkID, pt.Name
)
SELECT TOP 15
    ps.Name AS Material, CAST(ps.[Index] AS INT) AS Sheet,
    pm.PartName,
    ROUND(pm.PartToolPath_mm / 1000.0, 2) AS ToolPath_m,
    ROUND(pm.PartEdgeBand_mm / 1000.0, 2) AS EdgeBand_m,
    ps.LinkIDProcessingStation AS Station
FROM dbo.PlacedSheets ps
INNER JOIN dbo.OptimizationResults opt ON LTRIM(RTRIM(opt.LinkIDSheet)) = LTRIM(RTRIM(ps.LinkID)) AND opt.ScrapType = 0
INNER JOIN PartMetrics pm ON LTRIM(RTRIM(pm.PartKey)) = LTRIM(RTRIM(opt.LinkIDPart))
WHERE ps.LinkIDProcessingStation = '21BMOJSH9M90'
ORDER BY ps.[Index], pm.PartName
" "CNC Nesting parts with ToolPath and EdgeBand"

# Check total edgebanding from detail query vs Query 1
Run-Query "
;WITH PartMetrics AS (
    SELECT
        pt.LinkID AS PartKey,
        ISNULL(SUM(CAST(eb.LinFt AS FLOAT)), 0) AS PartEdgeBand_mm
    FROM dbo.Parts pt
    LEFT JOIN dbo.Edgebanding eb ON LTRIM(RTRIM(eb.LinkIDPart)) = LTRIM(RTRIM(pt.LinkID))
    GROUP BY pt.LinkID
)
SELECT
    ROUND(SUM(pm.PartEdgeBand_mm) / 1000.0, 2) AS Total_EdgeBand_m,
    ROUND(SUM(pm.PartEdgeBand_mm) * 0.00105, 2) AS Total_EdgeBand_Linft_check
FROM dbo.OptimizationResults opt
INNER JOIN PartMetrics pm ON LTRIM(RTRIM(pm.PartKey)) = LTRIM(RTRIM(opt.LinkIDPart))
WHERE opt.ScrapType = 0
" "Total EdgeBand from detail vs Query 1 (should be ~72 linft)"

$conn.Close()
