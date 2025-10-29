# Block List Manager
# Quick script to view and manage block lists

$blockListsFolder = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "    BLOCK LIST MANAGER" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Get all category files
$categoryFiles = Get-ChildItem -Path $blockListsFolder -Filter "*.txt" | 
    Where-Object { $_.Name -notin @("README.txt", "SITE-LIST.txt") }

$totalSites = 0

foreach ($file in $categoryFiles) {
    $sites = Get-Content $file.FullName | Where-Object { 
        $_ -notmatch "^#" -and $_ -notmatch "^\s*$" 
    }
    
    $count = $sites.Count
    $totalSites += $count
    
    Write-Host "[$count sites]" -ForegroundColor Green -NoNewline
    Write-Host " $($file.Name)" -ForegroundColor Yellow
    
    # Show first 3 sites as preview
    $preview = $sites | Select-Object -First 3
    foreach ($site in $preview) {
        Write-Host "   - $site" -ForegroundColor Gray
    }
    if ($count -gt 3) {
        Write-Host "   ... and $($count - 3) more" -ForegroundColor DarkGray
    }
    Write-Host ""
}

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "TOTAL SITES ACROSS ALL LISTS: $totalSites" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Show instructions
Write-Host "QUICK ACTIONS:" -ForegroundColor Yellow
Write-Host "1. To ADD a site: Open the category file and add the domain"
Write-Host "2. To REMOVE a site: Delete the line from the category file"
Write-Host "3. To DISABLE a category: Rename file (e.g., .txt.disabled)"
Write-Host "4. To CREATE category: Add new .txt file with domains"
Write-Host ""

Read-Host "Press Enter to exit"
