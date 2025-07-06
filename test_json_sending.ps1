# Test script to verify JSON file is sent correctly
# Start the Go application in the background
Start-Process -NoNewWindow -FilePath "go" -ArgumentList "run", "main.go"

# Wait for the application to start
Start-Sleep -Seconds 3

# Execute the curl command to send the JSON file
Write-Host "Sending JSON file to the application..."
$result = & C:\Windows\System32\curl.exe -X POST http://localhost:8080/data -d @data/decp-2025.json -v

# Display the result
Write-Host "Result from curl command:"
Write-Host $result

# Stop the Go application (find and kill the process)
$goProcess = Get-Process | Where-Object { $_.CommandLine -like "*go run main.go*" }
if ($goProcess)
{
    Stop-Process -Id $goProcess.Id -Force
}

Write-Host "Test completed."