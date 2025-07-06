# JSON File Sending Verification

## Verification Process

To verify that the JSON file is being sent correctly when using the curl command, a PowerShell script was created and
executed. The script:

1. Started the Go application in the background
2. Executed the curl command to send the JSON file
3. Displayed the result
4. Stopped the Go application

## Results

The test was successful, confirming that the JSON file is being sent correctly when using the curl command with the
`-d @data/decp-2025.json` syntax.

### Key observations from the test:

1. The curl command successfully connected to the local server
2. It sent 347,534,728 bytes of data (the JSON file content)
3. The server responded with HTTP 202 Accepted and the message "Data received"
4. The upload was "completely sent off" according to curl's verbose output

## Conclusion

The curl command in the README.md file is correctly configured to send the JSON file. No modifications are needed to
ensure the JSON file is properly sent, as the current implementation is working as expected.

```bash
curl -X POST http://localhost:8080/data -d @data/decp-2025.json
```

This command correctly reads the content of the JSON file and sends it to the server.