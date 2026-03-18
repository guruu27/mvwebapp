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

# P2P parts from dbo.Parts directly
Run-Query "SELECT Name, Face6Barcode, Quantity, LinkIDWorkOrder FROM dbo.Parts WHERE LEN(LTRIM(RTRIM(ISNULL(Face6Barcode, '')))) > 0" "P2P Parts (raw from dbo.Parts)"

# Miter parts from dbo.Parts directly
Run-Query "SELECT Name, Comments, Quantity, LinkIDWorkOrder FROM dbo.Parts WHERE Comments LIKE '%@%'" "Miter Parts (raw from dbo.Parts)"

# How many times does each P2P part appear in OptimizationResults?
Run-Query "
SELECT pt.Name, pt.Face6Barcode, COUNT(opt.LinkIDPart) AS OptResultRows
FROM dbo.Parts pt
INNER JOIN dbo.OptimizationResults opt
    ON LTRIM(RTRIM(opt.LinkIDPart)) = LTRIM(RTRIM(pt.LinkID))
WHERE LEN(LTRIM(RTRIM(ISNULL(pt.Face6Barcode, '')))) > 0
  AND opt.ScrapType = 0
GROUP BY pt.Name, pt.Face6Barcode
" "P2P parts × OptimizationResults rows"

# Same for Miter
Run-Query "
SELECT pt.Name, pt.Comments, COUNT(opt.LinkIDPart) AS OptResultRows
FROM dbo.Parts pt
INNER JOIN dbo.OptimizationResults opt
    ON LTRIM(RTRIM(opt.LinkIDPart)) = LTRIM(RTRIM(pt.LinkID))
WHERE pt.Comments LIKE '%@%'
  AND opt.ScrapType = 0
GROUP BY pt.Name, pt.Comments
" "Miter parts × OptimizationResults rows"

# Check: does the SDF query count DISTINCT parts or total placements?
# SDF query: count([Quantity]) from Parts where len(Face6Barcode) > 0
# This counts ROWS in Parts table, not placements in OptimizationResults
Run-Query "SELECT COUNT(Quantity) AS P2P_SDF_Style FROM dbo.Parts WHERE LEN(LTRIM(RTRIM(ISNULL(Face6Barcode, '')))) > 0" "P2P count (SDF-style = dbo.Parts rows)"
Run-Query "SELECT COUNT(Quantity) AS Miter_SDF_Style FROM dbo.Parts WHERE Comments LIKE '%@%'" "Miter count (SDF-style = dbo.Parts rows)"

$conn.Close()
