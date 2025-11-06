# ============================================
# PC Management System - Main Script
# ============================================
# Domain: Auto-detected from current system
# Target PCs: PC-1 to PC-35
# ============================================

# Get script path
$script:scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:functionsPath = Join-Path $scriptPath "Functions"
$script:blockListsFolder = Join-Path $scriptPath "BlockLists"

# Auto-detect current domain
$defaultDomain = "csitlab.local"
$detectedDomain = ""

try {
    $detectedDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
    if ([string]::IsNullOrWhiteSpace($detectedDomain) -or $detectedDomain -eq "WORKGROUP") {
        $detectedDomain = "Not domain-joined (WORKGROUP)"
    }
} catch {
    $detectedDomain = "Unable to detect"
}

# Display detected domain with color coding
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "     DOMAIN CONFIGURATION                    " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Show detected domain
Write-Host "Detected Domain: " -NoNewline
if ($detectedDomain -eq $defaultDomain) {
    Write-Host "$detectedDomain" -ForegroundColor Green
    Write-Host "  ✓ Matches default domain" -ForegroundColor Green
} elseif ($detectedDomain -eq "Not domain-joined (WORKGROUP)" -or $detectedDomain -eq "Unable to detect") {
    Write-Host "$detectedDomain" -ForegroundColor Red
} else {
    Write-Host "$detectedDomain" -ForegroundColor Red
    Write-Host "  ✗ Different from default domain ($defaultDomain)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Default Domain: " -NoNewline
Write-Host "$defaultDomain" -ForegroundColor Cyan
Write-Host ""

# Allow user to change or confirm
Write-Host "Options:" -ForegroundColor Yellow
Write-Host "  1. Use detected domain: $detectedDomain"
Write-Host "  2. Use default domain: $defaultDomain"
Write-Host "  3. Enter custom domain"
Write-Host ""

$domainChoice = Read-Host "Select option (1-3) [Press Enter for detected domain]"

switch ($domainChoice) {
    "2" {
        $script:targetDomain = $defaultDomain
        Write-Host "Using default domain: $defaultDomain" -ForegroundColor Green
    }
    "3" {
        $script:targetDomain = Read-Host "Enter domain name"
        Write-Host "Using custom domain: $script:targetDomain" -ForegroundColor Cyan
    }
    default {
        if ($detectedDomain -eq "Not domain-joined (WORKGROUP)" -or $detectedDomain -eq "Unable to detect") {
            Write-Host "Cannot use detected domain. Using default: $defaultDomain" -ForegroundColor Yellow
            $script:targetDomain = $defaultDomain
        } else {
            $script:targetDomain = $detectedDomain
            Write-Host "Using detected domain: $script:targetDomain" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Import all function modules
Write-Host "Loading modules..." -ForegroundColor Cyan
Import-Module (Join-Path $functionsPath "Helpers.ps1") -Force
Import-Module (Join-Path $functionsPath "PC-Management.ps1") -Force
Import-Module (Join-Path $functionsPath "Web-Blocking.ps1") -Force
Import-Module (Join-Path $functionsPath "Utilities.ps1") -Force
Write-Host "Modules loaded successfully!" -ForegroundColor Green
Write-Host ""

# Main Menu Function
function Show-Menu {
    Clear-Host
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "     PC MANAGEMENT SYSTEM - MAIN MENU       " -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "Active Domain: " -NoNewline
    if ($script:targetDomain -eq "csitlab.local") {
        Write-Host "$script:targetDomain" -ForegroundColor Green
    } else {
        Write-Host "$script:targetDomain" -ForegroundColor Red
    }
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "█ PC MANAGEMENT" -ForegroundColor Green
    Write-Host "  1.  Get status of ALL PCs (PC-1 to PC-35)"
    Write-Host "  2.  Shutdown a single PC"
    Write-Host "  3.  Shutdown a range of PCs"
    Write-Host "  4.  Shutdown ALL PCs (PC-1 to PC-35)"
    Write-Host "  5.  Restart a single PC"
    Write-Host "  6.  Restart a range of PCs"
    Write-Host "  7.  Restart ALL PCs (PC-1 to PC-35)"
    Write-Host ""
    Write-Host "█ WEB BLOCKING" -ForegroundColor Yellow
    Write-Host "  8.  Block Web/DNS access on a single PC"
    Write-Host "  9.  Block Web/DNS access on a range of PCs"
    Write-Host "  10. Block Web/DNS access on ALL PCs (PC-1 to PC-35)"
    Write-Host "  11. Unblock Web/DNS access on a single PC"
    Write-Host "  12. Unblock Web/DNS access on a range of PCs"
    Write-Host "  13. Unblock Web/DNS access on ALL PCs (PC-1 to PC-35)"
    Write-Host "  14. Deep Scan - Check blocking status on all PCs"
    Write-Host "  15. View Current Block Lists"
    Write-Host "  16. Block AI Sites ONLY on ALL PCs (PC-1 to PC-35)" -ForegroundColor DarkYellow
    Write-Host ""
    Write-Host "█ UTILITIES" -ForegroundColor Magenta
    Write-Host "  17. Sync Time/Date/Timezone to ALL PCs from Server"
    Write-Host "  18. Clean up backup hosts files on ALL PCs"
    Write-Host "  19. Export MySQL Database from a single PC"
    Write-Host "  20. Export MySQL Databases from a range of PCs"
    Write-Host "  21. Export MySQL Databases from ALL PCs"
    Write-Host ""
    Write-Host "█ SYSTEM" -ForegroundColor DarkGray
    Write-Host "  22. Clear screen and return to menu"
    Write-Host "  23. Exit"
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
}

# Ask for credentials once (must have admin rights on all target PCs)
Write-Host "===== DOMAIN-SPECIFIC WEB BLOCKING SYSTEM =====" -ForegroundColor Cyan
Write-Host "Active Domain: " -NoNewline
if ($script:targetDomain -eq $defaultDomain) {
    Write-Host "$script:targetDomain" -ForegroundColor Green
} else {
    Write-Host "$script:targetDomain" -ForegroundColor Red
}
Write-Host ""
Write-Host "Please enter admin credentials for domain PCs:" -ForegroundColor Yellow
$script:cred = Get-Credential
Write-Host ""

# Load block lists from BlockLists folder
Write-Host "Loading block lists from: $blockListsFolder" -ForegroundColor Cyan

$script:blockedSites = @()
$script:blockListStats = @{}
$script:aiSitesOnly = @()

# Check if BlockLists folder exists
if (Test-Path $blockListsFolder) {
    $blockFiles = Get-ChildItem -Path $blockListsFolder -Filter "*.txt" | Where-Object { 
        $_.Name -notin @("README.txt", "QUICK-REFERENCE.txt", "SITE-LIST.txt") 
    }
    
    foreach ($file in $blockFiles) {
        Write-Host "  Loading: $($file.Name)" -ForegroundColor Gray
        $sites = Get-Content $file.FullName | Where-Object { 
            $_ -notmatch "^#" -and $_ -notmatch "^\s*$" 
        }
        
        $blockListStats[$file.BaseName] = $sites.Count
        $blockedSites += $sites
        
        if ($file.BaseName -eq "ai-sites") {
            $aiSitesOnly = $sites
            Write-Host "    Added $($sites.Count) AI sites (available for AI-only blocking)" -ForegroundColor DarkCyan
        } else {
            Write-Host "    Added $($sites.Count) sites from $($file.Name)" -ForegroundColor DarkGray
        }
    }
    
    Write-Host ""
    Write-Host "BLOCK LIST SUMMARY:" -ForegroundColor Yellow
    foreach ($category in $blockListStats.Keys) {
        Write-Host "  $category`: $($blockListStats[$category]) sites" -ForegroundColor White
    }
    Write-Host "  TOTAL SITES TO BLOCK: $($blockedSites.Count)" -ForegroundColor Green
} else {
    Write-Host "WARNING: BlockLists folder not found at $blockListsFolder" -ForegroundColor Red
    Write-Host "Creating default block list..." -ForegroundColor Yellow
    
    $blockedSites = @(
        "www.google.com", "google.com",
        "www.facebook.com", "facebook.com",
        "www.youtube.com", "youtube.com",
        "www.twitter.com", "twitter.com"
    )
}

Write-Host ""
Write-Host "IMPORTANT: Operations will only apply to PCs in the '$script:targetDomain' domain!" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to continue to main menu..." -ForegroundColor Cyan
$null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Main program loop
do {
    Show-Menu
    $choice = Read-Host "Enter your choice (1-23)"

    switch ($choice) {
        # ===== PC MANAGEMENT =====
        '1' {
            $targets = foreach ($i in 1..35) { "PC-$i" }
            Get-AllPCStatus -Targets $targets
        }
        '2' {
            $pc = Read-Host "Enter the PC name (e.g., PC-1)"
            $targets = @($pc)
            Invoke-PCShutdown -Targets $targets
        }
        '3' {
            $start = Read-Host "Enter start number (e.g., 5)"
            $end   = Read-Host "Enter end number (e.g., 10)"
            $targets = foreach ($i in $start..$end) { "PC-$i" }
            Invoke-PCShutdown -Targets $targets
        }
        '4' {
            $targets = foreach ($i in 1..35) { "PC-$i" }
            Invoke-PCShutdown -Targets $targets
        }
        '5' {
            $pc = Read-Host "Enter the PC name (e.g., PC-1)"
            $targets = @($pc)
            Invoke-PCRestart -Targets $targets
        }
        '6' {
            $start = Read-Host "Enter start number (e.g., 5)"
            $end   = Read-Host "Enter end number (e.g., 10)"
            $targets = foreach ($i in $start..$end) { "PC-$i" }
            Invoke-PCRestart -Targets $targets
        }
        '7' {
            $targets = foreach ($i in 1..35) { "PC-$i" }
            Invoke-PCRestart -Targets $targets
        }
        
        # ===== WEB BLOCKING =====
        '8' {
            $pc = Read-Host "Enter the PC name (e.g., PC-1)"
            $targets = @($pc)
            Invoke-WebBlocking -Targets $targets -BlockedSites $blockedSites
        }
        '9' {
            $start = Read-Host "Enter start number (e.g., 5)"
            $end   = Read-Host "Enter end number (e.g., 10)"
            $targets = foreach ($i in $start..$end) { "PC-$i" }
            Invoke-WebBlocking -Targets $targets -BlockedSites $blockedSites
        }
        '10' {
            $targets = foreach ($i in 1..35) { "PC-$i" }
            Invoke-WebBlocking -Targets $targets -BlockedSites $blockedSites
        }
        '11' {
            $pc = Read-Host "Enter the PC name (e.g., PC-1)"
            $targets = @($pc)
            Invoke-WebUnblocking -Targets $targets
        }
        '12' {
            $start = Read-Host "Enter start number (e.g., 5)"
            $end   = Read-Host "Enter end number (e.g., 10)"
            $targets = foreach ($i in $start..$end) { "PC-$i" }
            Invoke-WebUnblocking -Targets $targets
        }
        '13' {
            $targets = foreach ($i in 1..35) { "PC-$i" }
            Invoke-WebUnblocking -Targets $targets
        }
        '14' {
            Invoke-DeepScan
        }
        '15' {
            Show-BlockLists -BlockedSites $blockedSites -BlockListsFolder $blockListsFolder
        }
        '16' {
            Write-Host "===== AI SITES BLOCKING (ALL PCs) =====" -ForegroundColor Yellow
            Write-Host "This will block ONLY AI sites from ai-sites.txt ($($aiSitesOnly.Count) sites)" -ForegroundColor Cyan
            Write-Host "Other sites (social media, video, gaming, shopping) will remain accessible" -ForegroundColor Gray
            Write-Host ""
            
            $targets = foreach ($i in 1..35) { "PC-$i" }
            Invoke-AIBlocking -Targets $targets -AISites $aiSitesOnly
        }
        
        # ===== UTILITIES =====
        '17' {
            Sync-TimeToAllPCs
        }
        '18' {
            Invoke-BackupCleanup
        }
        '19' {
            $pc = Read-Host "Enter the PC name (e.g., PC-1)"
            $targets = @($pc)
            Export-MySQLDatabases -Targets $targets -ExportType "Single PC: $pc" -ScriptPath $scriptPath
        }
        '20' {
            $start = Read-Host "Enter start number (e.g., 5)"
            $end   = Read-Host "Enter end number (e.g., 10)"
            $targets = foreach ($i in $start..$end) { "PC-$i" }
            Export-MySQLDatabases -Targets $targets -ExportType "Range: PC-$start to PC-$end" -ScriptPath $scriptPath
        }
        '21' {
            $targets = foreach ($i in 1..35) { "PC-$i" }
            Export-MySQLDatabases -Targets $targets -ExportType "ALL PCs" -ScriptPath $scriptPath
        }
        
        # ===== SYSTEM =====
        '22' {
            continue  # Just clears and redraws menu
        }
        '23' {
            Write-Host "Exiting..." -ForegroundColor Yellow
            break
        }
        default {
            Write-Host "Invalid choice. Try again..." -ForegroundColor Red
            Start-Sleep -Seconds 2
            continue
        }
    }

} while ($choice -ne '23')

Write-Host ""
Write-Host "Thank you for using PC Management System!" -ForegroundColor Cyan
Write-Host ""
