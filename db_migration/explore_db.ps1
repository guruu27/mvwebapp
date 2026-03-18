$conn = New-Object System.Data.SqlClient.SqlConnection
$conn.ConnectionString = 'Server=PSF-GuruprasadT\SQLEXPRESS;Database=guru;Integrated Security=True;'
$conn.Open()

$sql = Get-Content -Path "C:\Users\GTandlekar\DataPSF\MicrovellumWebApp\production_plan.sql" -Raw
$cmd = $conn.CreateCommand()
$cmd.CommandText = $sql
$cmd.CommandTimeout = 60

$da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
$dt = New-Object System.Data.DataTable
$da.Fill($dt) | Out-Null

Write-Host "`n=== PRODUCTION PLAN ===" -ForegroundColor Cyan

# Show column names first
Write-Host "Columns: " ($dt.Columns | ForEach-Object { $_.ColumnName }) -ForegroundColor DarkGray

foreach ($row in $dt.Rows) {
    Write-Host ""
    Write-Host ("Batch: " + $row["BatchName"] + "   WO: " + $row["LinkIDWorkOrder"]) -ForegroundColor Yellow
    Write-Host ("  Station:     " + $row["StationName"] + " (" + $row["StationID"] + ")")
    Write-Host ("  Sheets:      " + $row["Sheets"])
    Write-Host ("  Parts:       " + $row["Parts"] + " (station)  /  " + $row["TotalParts"] + " (WO total)")
    Write-Host ("  Products:    " + $row["Products"])
    Write-Host ("  EdgeBand:    " + $row["EdgeBand_m"] + " m")
    Write-Host ("  P2P Parts:   " + $row["P2P_Parts"])
    Write-Host ("  Miter Parts: " + $row["Miter_Parts"])
    Write-Host ("  Solid Wood:  " + $row["Solid_m"] + " m")
}

Write-Host "`nTotal rows: $($dt.Rows.Count)" -ForegroundColor Green

Write-Host "`n=== CROSS-CHECK (raw totals) ===" -ForegroundColor Cyan
$checks = @(
    "Total optimized qty (non-scrap)|SELECT SUM(CAST(OptimizedQuantity AS INT)) FROM dbo.OptimizationResults WHERE ScrapType=0",
    "Placed sheets (Width>350)      |SELECT COUNT(*) FROM dbo.PlacedSheets WHERE CAST(Width AS FLOAT) > 350",
    "EdgeBand m (Qty*0.00105)       |SELECT ROUND(SUM(CAST(Quantity AS FLOAT))*0.00105,1) FROM dbo.Edgebanding",
    "P2P parts                      |SELECT COUNT(1) FROM dbo.Parts WHERE LEN(LTRIM(RTRIM(ISNULL(Face6Barcode, '')))) > 0",
    "Miter parts                    |SELECT COUNT(1) FROM dbo.Parts WHERE Comments LIKE '%@%'",
    "Total products (sum qty)       |SELECT SUM(CAST(Quantity AS FLOAT)) FROM dbo.Products"
)
foreach ($chk in $checks) {
    $parts = $chk.Split("|")
    $qc = $conn.CreateCommand(); $qc.CommandText = $parts[1]
    Write-Host ("  " + $parts[0] + " : " + $qc.ExecuteScalar())
}

$conn.Close()
