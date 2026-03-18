$conn = New-Object System.Data.SqlClient.SqlConnection
$conn.ConnectionString = 'Server=PSF-GuruprasadT\SQLEXPRESS;Database=guru;Trusted_Connection=True;'
$conn.Open()

function Run-Query($sql, $label) {
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $sql
    $reader = $cmd.ExecuteReader()
    $table = New-Object System.Data.DataTable
    $table.Load($reader)
    Write-Host "`n=== $label ==="
    $table | Format-Table -AutoSize
}

# 1. All dbo tables
Run-Query "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' ORDER BY TABLE_NAME" "All dbo Tables"

# 2. Check if DrillsHorizontal and DrillsVertical exist in dbo
Run-Query "SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME IN ('DrillsHorizontal', 'DrillsVertical', 'Routes', 'Hardware') ORDER BY TABLE_SCHEMA, TABLE_NAME" "Drills/Routes/Hardware Tables (all schemas)"

# 3. PlacedSheets columns
Run-Query "SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'PlacedSheets' ORDER BY ORDINAL_POSITION" "dbo.PlacedSheets Columns"

# 4. Parts columns (check for Face6Barcode, Comments, etc.)
Run-Query "SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Parts' ORDER BY ORDINAL_POSITION" "dbo.Parts Columns"

# 5. OptimizationResults columns
Run-Query "SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'OptimizationResults' ORDER BY ORDINAL_POSITION" "dbo.OptimizationResults Columns"

# 6. Quick row counts
Run-Query "
SELECT 'PlacedSheets' AS Tbl, COUNT(*) AS Cnt FROM dbo.PlacedSheets UNION ALL
SELECT 'OptimizationResults', COUNT(*) FROM dbo.OptimizationResults UNION ALL
SELECT 'Parts', COUNT(*) FROM dbo.Parts UNION ALL
SELECT 'Products', COUNT(*) FROM dbo.Products UNION ALL
SELECT 'Edgebanding', COUNT(*) FROM dbo.Edgebanding UNION ALL
SELECT 'WorkOrderBatches', COUNT(*) FROM dbo.WorkOrderBatches
" "Row Counts (dbo)"

# 7. Check Routes if exists
Run-Query "SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Routes' ORDER BY ORDINAL_POSITION" "dbo.Routes Columns (if exists)"

# 8. Edgebanding columns
Run-Query "SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Edgebanding' ORDER BY ORDINAL_POSITION" "dbo.Edgebanding Columns"

$conn.Close()
