# Validate individual metrics against the production plan

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

# 1. Products total
Run-Query "SELECT SUM(CAST(Quantity AS FLOAT)) AS ProductQty FROM dbo.Products" "Products Total"

# 2. Edgebanding total (linear ft)
Run-Query "SELECT ROUND(SUM(CAST(Quantity AS FLOAT)) * 0.00105, 0) AS Edge FROM dbo.Edgebanding" "Edgebanding (LinFt)"

# 3. P2P count
Run-Query "SELECT COUNT(Quantity) AS P2P FROM dbo.Parts WHERE LEN(LTRIM(RTRIM(ISNULL(Face6Barcode, '')))) > 0" "P2P Count"

# 4. Miter count
Run-Query "SELECT COUNT(Quantity) AS Miter FROM dbo.Parts WHERE Comments LIKE '%@%'" "Miter Count"

# 5. Solid
Run-Query "SELECT CEILING(SUM(CAST(Quantity AS FLOAT) * CAST(Length AS FLOAT)) * 0.001) AS Solid FROM dbo.PlacedSheets WHERE Name LIKE '%Solid%' AND Name NOT LIKE '%Solid Surface%'" "Solid Wood"

# 6. Total parts (non-scrap)
Run-Query "SELECT SUM(CAST(OptimizedQuantity AS FLOAT)) AS TtlPrts FROM dbo.OptimizationResults WHERE ScrapType = 0" "Total Parts"

# 7. Nesting sheets (Width > 350, Station = 21BMOJSH9M90)
Run-Query "SELECT COUNT(ID) AS NestSht FROM dbo.PlacedSheets WHERE CAST(Width AS FLOAT) > 350 AND LinkIDProcessingStation = '21BMOJSH9M90'" "Nesting Sheets"

# 8. Panel Saw sheets
Run-Query "SELECT COUNT(ID) AS PnlSht FROM dbo.PlacedSheets WHERE CAST(Width AS FLOAT) > 350 AND (LinkIDProcessingStation = '1966O1PHUNP10' OR LinkIDProcessingStation = '1966O9J0UOZ10')" "Panel Saw Sheets"

# 9. Check if Solid PlacedSheets exist at all
Run-Query "SELECT TOP 5 Name, Length, Quantity FROM dbo.PlacedSheets WHERE Name LIKE '%Solid%'" "Solid PlacedSheets (sample)"

# 10. Products - check data
Run-Query "SELECT TOP 5 Name, Quantity, LinkIDWorkOrder FROM dbo.Products" "Products (sample)"

$conn.Close()
