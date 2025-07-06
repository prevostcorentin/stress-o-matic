# Test script to verify JSON file is sent correctly
# Start the Go application in the background
# Try to find the Go executable
$goExe = $null

# Check common Go installation paths
$possiblePaths = @(
    "C:\Program Files\Go\bin\go.exe",
    "C:\Go\bin\go.exe",
    "$env:LOCALAPPDATA\go\bin\go.exe",
    "$env:GOPATH\bin\go.exe"
)

foreach ($path in $possiblePaths)
{
    if (Test-Path $path)
    {
        $goExe = $path
        break
    }
}

# If Go executable was found, use it
if ($goExe)
{
    Start-Process -NoNewWindow -FilePath $goExe -ArgumentList "run", "main.go"
}
else
{
    # Fallback: run directly using PowerShell
    Write-Host "Go executable not found in common locations. Trying to run directly..."
    Start-Job -ScriptBlock {
        Set-Location $using:PWD
        & go run main.go
    } | Out-Null
}

# Wait for the application to start
Start-Sleep -Seconds 3

# Execute the curl command to send the JSON file
Write-Host "Sending JSON file to the application..."
$result = & C:\Windows\System32\curl.exe -X POST http://localhost:8080/data -d @data/decp-2025.json -v

# Display the result
Write-Host "Result from curl command:"
Write-Host $result

# Stop the Go application (find and kill the process)
# Try to find the Go process by looking for processes running main.go
$goProcess = Get-Process | Where-Object {
    $_.Name -eq "go" -or
            ($_.CommandLine -and ($_.CommandLine -like "*go run main.go*" -or $_.CommandLine -like "*main.go*"))
}

if ($goProcess)
{
    foreach ($proc in $goProcess)
    {
        Write-Host "Stopping Go process with ID: $( $proc.Id )"
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
}
else
{
    Write-Host "No Go process found to stop. Checking for background jobs..."
    # Stop any background jobs we might have started
    Get-Job | Stop-Job -ErrorAction SilentlyContinue
    Get-Job | Remove-Job -ErrorAction SilentlyContinue
}

Write-Host "Test completed."
