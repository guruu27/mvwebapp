$query = Get-Content -Path "C:\Users\GTandlekar\DataPSF\MicrovellumWebApp\production_plan_detail.sql" -Raw

# Remove comment lines
$cleanLines = ($query -split "`n") | Where-Object { $_ -notmatch '^\s*--' }
$cleanQuery = $cleanLines -join "`n"

$conn = New-Object System.Data.SqlClient.SqlConnection
$conn.ConnectionString = 'Server=PSF-GuruprasadT\SQLEXPRESS;Database=guru;Trusted_Connection=True;'
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandText = $cleanQuery
$cmd.CommandTimeout = 60
$reader = $cmd.ExecuteReader()
$table = New-Object System.Data.DataTable
$table.Load($reader)

Write-Host "Row count: $($table.Rows.Count)"
Write-Host ""

# Show first 10 rows
Write-Host "=== FIRST 10 ROWS ==="
$table | Select-Object -First 10 | Format-Table -AutoSize

# Station summary
Write-Host "`n=== STATION SUMMARY ==="
$table | Group-Object StationName | ForEach-Object {
    Write-Host "$($_.Name): $($_.Count) rows"
}

# Sheet count
Write-Host "`n=== UNIQUE SHEETS PER STATION ==="
$table | Group-Object StationName | ForEach-Object {
    $station = $_.Name
    $sheets = ($_.Group | Select-Object -Property SheetNumber -Unique).Count
    Write-Host "$station : $sheets sheets"
}

# Total unique parts
$uniqueParts = ($table | Select-Object -Property PartName -Unique).Count
Write-Host "`nUnique part names: $uniqueParts"

# Cross-check: sum of Sheet_PartCount across distinct sheets
Write-Host "`n=== PART COUNT PER SHEET (distinct sheets) ==="
$seen = @{}
foreach ($row in $table.Rows) {
    $key = "$($row.StationName)|$($row.SheetNumber)"
    if (-not $seen.ContainsKey($key)) {
        $seen[$key] = $true
        Write-Host "  $($row.StationName) Sheet#$($row.SheetNumber): $($row.Sheet_PartCount) parts on sheet, Material=$($row.MaterialName)"
    }
}

# P2P and Miter parts
$p2pCount = ($table.Rows | Where-Object { $_.IsP2P -eq 1 }).Count
$miterCount = ($table.Rows | Where-Object { $_.IsMiter -eq 1 }).Count
Write-Host "`nP2P parts in detail: $p2pCount"
Write-Host "Miter parts in detail: $miterCount"

$conn.Close()
