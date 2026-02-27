# Ask user for directory
$directory = Read-Host "Enter the directory path"

# Check if directory exists
if (Test-Path $directory) {
    Write-Host "`nSearching for .txt files in $directory ...`n"
    
    Get-ChildItem -Path $directory -Filter *.txt -Recurse -File |
        ForEach-Object {
            Write-Host $_.FullName
        }
}
else {
    Write-Host "Directory not found."
}
