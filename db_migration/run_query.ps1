$query = Get-Content -Path "C:\Users\GTandlekar\DataPSF\MicrovellumWebApp\production_plan.sql" -Raw

# Remove comment lines (-- ...) to avoid SQL issues
$cleanLines = ($query -split "`n") | Where-Object { $_ -notmatch '^\s*--' }
$cleanQuery = $cleanLines -join "`n"

$conn = New-Object System.Data.SqlClient.SqlConnection
$conn.ConnectionString = 'Server=PSF-GuruprasadT\SQLEXPRESS;Database=guru;Trusted_Connection=True;'
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandText = $cleanQuery
$reader = $cmd.ExecuteReader()
$table = New-Object System.Data.DataTable
$table.Load($reader)
$table | Format-Table -AutoSize
Write-Host "`nRow count: $($table.Rows.Count)"
$conn.Close()
