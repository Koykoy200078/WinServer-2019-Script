function Show-Menu {
    Clear-Host
    Write-Host "===== PC Management Menu =====" -ForegroundColor Cyan
    Write-Host "1. Get status of ALL PCs (PC-1 to PC-35)"
    Write-Host "2. Shutdown a single PC"
    Write-Host "3. Shutdown a range of PCs"
    Write-Host "4. Shutdown ALL PCs (PC-1 to PC-35)"
    Write-Host "5. Restart a single PC"
    Write-Host "6. Restart a range of PCs"
    Write-Host "7. Restart ALL PCs (PC-1 to PC-35)"
    Write-Host "8. Block Web/DNS access on a single PC"
    Write-Host "9. Block Web/DNS access on a range of PCs"
    Write-Host "10. Block Web/DNS access on ALL PCs (PC-1 to PC-35)"
    Write-Host "11. Unblock Web/DNS access on a single PC"
    Write-Host "12. Unblock Web/DNS access on a range of PCs"
    Write-Host "13. Unblock Web/DNS access on ALL PCs (PC-1 to PC-35)"
    Write-Host "14. Deep Scan - Check blocking status on all PCs"
    Write-Host "15. View Current Block Lists"
    Write-Host "16. Sync Time/Date/Timezone to ALL PCs from Server"
    Write-Host "17. Clean up backup hosts files on ALL PCs"
    Write-Host "18. Block AI Sites ONLY on ALL PCs (PC-1 to PC-35)" -ForegroundColor Yellow
    Write-Host "19. Export MySQL Databases from ALL PCs" -ForegroundColor Cyan
    Write-Host "20. Clear screen and return to menu"
    Write-Host "21. Exit"
    Write-Host "==============================" -ForegroundColor Cyan
}

function Test-DomainMembership {
    param([string]$ComputerName)
    
    try {
        $result = Invoke-Command -ComputerName $ComputerName -Credential $cred -ScriptBlock {
            $domain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
            return $domain
        } -ErrorAction Stop
        
        return $result -eq "csitlab.local"
    }
    catch {
        return $false
    }
}

function Get-BlockingStatus {
    param([string]$ComputerName)
    
    try {
        $result = Invoke-Command -ComputerName $ComputerName -Credential $cred -ScriptBlock {
            try {
                $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
                
                if (-not (Test-Path $hostsFile)) {
                    throw "Hosts file not found"
                }
                
                # Read content with proper encoding and error handling
                $content = @()
                $retryCount = 0
                $maxRetries = 3
                
                while ($retryCount -lt $maxRetries) {
                    try {
                        # Force release any file handles
                        [System.GC]::Collect()
                        [System.GC]::WaitForPendingFinalizers()
                        
                        # Read with specific encoding to avoid stream issues
                        $content = Get-Content $hostsFile -Encoding UTF8 -ErrorAction Stop
                        break
                    }
                    catch {
                        $retryCount++
                        if ($retryCount -eq $maxRetries) {
                            throw "Failed to read hosts file after $maxRetries attempts"
                        }
                        Start-Sleep -Milliseconds 200
                    }
                }
                
                $blockedCount = ($content | Where-Object { $_ -match "BLOCKED BY ADMIN" }).Count
                $totalLines = $content.Count
                $hasBlocks = ($content | Where-Object { $_ -match "127\.0\.0\.1.*\.(com|net|org)" }).Count -gt 0
                
                return [PSCustomObject]@{
                    Computer = $env:COMPUTERNAME
                    HasBlocks = $hasBlocks
                    BlockedEntries = $blockedCount
                    TotalHostsLines = $totalLines
                    Domain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
                    Status = "SUCCESS"
                }
            }
            catch {
                return [PSCustomObject]@{
                    Computer = $env:COMPUTERNAME
                    HasBlocks = "ERROR"
                    BlockedEntries = "N/A"
                    TotalHostsLines = "N/A"
                    Domain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
                    Status = "ERROR"
                    ErrorMessage = $_.Exception.Message
                }
            }
        } -ErrorAction Stop
        
        return $result
    }
    catch {
        return [PSCustomObject]@{
            Computer = $ComputerName
            HasBlocks = "ERROR"
            BlockedEntries = "N/A"
            TotalHostsLines = "N/A"
            Domain = "N/A"
            Status = "CONNECTION_ERROR"
            ErrorMessage = $_.Exception.Message
        }
    }
}

function Sync-TimeToAllPCs {
    Write-Host "===== TIME/DATE/TIMEZONE SYNCHRONIZATION =====" -ForegroundColor Cyan
    Write-Host "Syncing server time to all domain PCs..." -ForegroundColor Yellow
    Write-Host ""
    
    # Get server's current time and timezone info
    $serverTime = Get-Date
    $serverTimeZone = Get-TimeZone
    
    Write-Host "SERVER TIME INFORMATION:" -ForegroundColor Green
    Write-Host "  Current Time: $($serverTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
    Write-Host "  Timezone: $($serverTimeZone.Id)" -ForegroundColor White
    Write-Host "  Display Name: $($serverTimeZone.DisplayName)" -ForegroundColor White
    Write-Host ""
    
    $targets = foreach ($i in 1..35) { "PC-$i" }
    $syncResults = @()
    $successCount = 0
    $failCount = 0
    
    foreach ($pc in $targets) {
        Write-Host "Syncing time to $pc..." -ForegroundColor Gray
        try {
            if (Test-WSMan -ComputerName $pc -ErrorAction Stop) {
                # Check domain membership first
                $isDomainMember = Test-DomainMembership -ComputerName $pc
                
                if ($isDomainMember) {
                    $result = Invoke-Command -ComputerName $pc -Credential $cred -ArgumentList $serverTime, $serverTimeZone.Id -ScriptBlock {
                        param($targetTime, $targetTimeZone)
                        
                        try {
                            $originalTime = Get-Date
                            $originalTZ = Get-TimeZone
                            
                            # Set the timezone first
                            Set-TimeZone -Id $targetTimeZone -ErrorAction Stop
                            
                            # Set the date and time
                            Set-Date -Date $targetTime -ErrorAction Stop
                            
                            # Force time sync with domain controller
                            w32tm /resync /force | Out-Null
                            
                            $newTime = Get-Date
                            $newTZ = Get-TimeZone
                            
                            return @{
                                Success = $true
                                Computer = $env:COMPUTERNAME
                                OriginalTime = $originalTime.ToString('yyyy-MM-dd HH:mm:ss')
                                OriginalTimeZone = $originalTZ.Id
                                NewTime = $newTime.ToString('yyyy-MM-dd HH:mm:ss')
                                NewTimeZone = $newTZ.Id
                                TimeDifference = [math]::Round(($targetTime - $originalTime).TotalMinutes, 2)
                            }
                        }
                        catch {
                            return @{
                                Success = $false
                                Computer = $env:COMPUTERNAME
                                Error = $_.Exception.Message
                            }
                        }
                    } -ErrorAction Stop
                    
                    $syncResults += $result
                    
                    if ($result.Success) {
                        $successCount++
                        Write-Host "  ✓ $pc time synced successfully" -ForegroundColor Green
                        Write-Host "    Before: $($result.OriginalTime) ($($result.OriginalTimeZone))" -ForegroundColor Gray
                        Write-Host "    After:  $($result.NewTime) ($($result.NewTimeZone))" -ForegroundColor Gray
                        if ([math]::Abs($result.TimeDifference) -gt 1) {
                            Write-Host "    Time adjusted by: $($result.TimeDifference) minutes" -ForegroundColor Yellow
                        }
                    } else {
                        $failCount++
                        Write-Host "  ✗ $pc time sync FAILED: $($result.Error)" -ForegroundColor Red
                    }
                } else {
                    $failCount++
                    Write-Host "  ✗ $pc is not in csitlab.local domain - SKIPPING" -ForegroundColor Red
                }
            }
        }
        catch {
            $failCount++
            Write-Host "  ✗ $pc is OFFLINE or unreachable" -ForegroundColor DarkGray
        }
    }
    
    # Summary Report
    Write-Host ""
    Write-Host "===== TIME SYNC SUMMARY =====" -ForegroundColor Cyan
    Write-Host "Total PCs processed: 35" -ForegroundColor White
    Write-Host "Successful syncs: $successCount" -ForegroundColor Green
    Write-Host "Failed syncs: $failCount" -ForegroundColor Red
    Write-Host ""
    
    if ($successCount -gt 0) {
        Write-Host "SUCCESSFULLY SYNCED PCs:" -ForegroundColor Green
        $successfulPCs = $syncResults | Where-Object { $_.Success -eq $true }
        foreach ($pc in $successfulPCs) {
            $timeDiff = if ([math]::Abs($pc.TimeDifference) -gt 1) { " (adjusted by $($pc.TimeDifference)min)" } else { "" }
            Write-Host "  $($pc.Computer) - $($pc.NewTime)$timeDiff" -ForegroundColor White
        }
        Write-Host ""
    }
    
    if ($failCount -gt 0) {
        Write-Host "FAILED SYNCS:" -ForegroundColor Red
        $failedPCs = $syncResults | Where-Object { $_.Success -eq $false }
        foreach ($pc in $failedPCs) {
            Write-Host "  $($pc.Computer) - $($pc.Error)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    Write-Host "Time synchronization completed!" -ForegroundColor Cyan
    Pause
}

function Export-MySQLDatabases {
    Write-Host "===== MYSQL DATABASE EXPORT (ALL PCs) =====" -ForegroundColor Cyan
    Write-Host "This will export all MySQL databases from PC-1 to PC-35" -ForegroundColor Yellow
    Write-Host ""
    
    # Prompt for MySQL credentials
    Write-Host "Enter MySQL credentials:" -ForegroundColor Green
    $mysqlUser = Read-Host "MySQL Username (e.g., root)"
    $mysqlPassSecure = Read-Host "MySQL Password" -AsSecureString
    $mysqlPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($mysqlPassSecure))
    
    # Create export folder with timestamp
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $exportFolder = Join-Path $scriptPath "MySQL-Exports-$timestamp"
    New-Item -ItemType Directory -Path $exportFolder -Force | Out-Null
    Write-Host "Export folder created: $exportFolder" -ForegroundColor Green
    Write-Host ""
    
    $targets = foreach ($i in 1..35) { "PC-$i" }
    $exportResults = @()
    $successCount = 0
    $failCount = 0
    $totalDatabases = 0
    
    foreach ($pc in $targets) {
        Write-Host "Exporting databases from $pc..." -ForegroundColor Gray
        try {
            if (Test-WSMan -ComputerName $pc -ErrorAction Stop) {
                # Check domain membership first
                $isDomainMember = Test-DomainMembership -ComputerName $pc
                
                if ($isDomainMember) {
                    $result = Invoke-Command -ComputerName $pc -Credential $cred -ArgumentList $mysqlUser, $mysqlPass -ScriptBlock {
                        param($user, $pass)
                        
                        try {
                            $results = @{
                                Success = $false
                                Computer = $env:COMPUTERNAME
                                Databases = @()
                                ExportedFiles = @()
                                Error = $null
                            }
                            
                            # Check if MySQL is installed
                            $mysqlPaths = @(
                                "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe",
                                "C:\Program Files\MySQL\MySQL Server 5.7\bin\mysql.exe",
                                "C:\Program Files (x86)\MySQL\MySQL Server 8.0\bin\mysql.exe",
                                "C:\Program Files (x86)\MySQL\MySQL Server 5.7\bin\mysql.exe",
                                "C:\xampp\mysql\bin\mysql.exe",
                                "C:\wamp64\bin\mysql\mysql8.0.27\bin\mysql.exe"
                            )
                            
                            $mysqlExe = $null
                            $mysqldumpExe = $null
                            
                            foreach ($path in $mysqlPaths) {
                                if (Test-Path $path) {
                                    $mysqlExe = $path
                                    $mysqldumpExe = $path -replace "mysql.exe", "mysqldump.exe"
                                    break
                                }
                            }
                            
                            if (-not $mysqlExe -or -not (Test-Path $mysqldumpExe)) {
                                throw "MySQL not found on this computer"
                            }
                            
                            # Create temporary export folder on remote PC
                            $tempExportPath = "C:\Temp\MySQL-Export-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                            New-Item -ItemType Directory -Path $tempExportPath -Force | Out-Null
                            
                            # Get list of databases
                            $dbListCmd = "& `"$mysqlExe`" -u$user -p$pass -e `"SHOW DATABASES;`" --batch --skip-column-names"
                            $databases = Invoke-Expression $dbListCmd 2>$null | Where-Object { 
                                $_ -and $_ -notmatch "information_schema|performance_schema|mysql|sys" 
                            }
                            
                            if ($databases) {
                                $results.Databases = $databases
                                
                                foreach ($db in $databases) {
                                    $exportFile = Join-Path $tempExportPath "$db-backup.sql"
                                    
                                    # Export database using mysqldump
                                    $dumpCmd = "& `"$mysqldumpExe`" -u$user -p$pass --databases $db --result-file=`"$exportFile`""
                                    Invoke-Expression $dumpCmd 2>$null
                                    
                                    if (Test-Path $exportFile) {
                                        $fileSize = (Get-Item $exportFile).Length
                                        $results.ExportedFiles += @{
                                            Database = $db
                                            FilePath = $exportFile
                                            FileSize = $fileSize
                                        }
                                    }
                                }
                                
                                $results.Success = $true
                                $results.TempFolder = $tempExportPath
                            } else {
                                throw "No databases found or unable to connect to MySQL"
                            }
                            
                            return $results
                        }
                        catch {
                            return @{
                                Success = $false
                                Computer = $env:COMPUTERNAME
                                Databases = @()
                                ExportedFiles = @()
                                Error = $_.Exception.Message
                            }
                        }
                    } -ErrorAction Stop
                    
                    if ($result.Success) {
                        $successCount++
                        $totalDatabases += $result.Databases.Count
                        
                        # Create PC-specific folder
                        $pcFolder = Join-Path $exportFolder $pc
                        New-Item -ItemType Directory -Path $pcFolder -Force | Out-Null
                        
                        # Copy files from remote PC to server
                        foreach ($exportedFile in $result.ExportedFiles) {
                            $remotePath = "\\$pc\C$" + ($exportedFile.FilePath -replace "C:", "")
                            $localPath = Join-Path $pcFolder (Split-Path $exportedFile.FilePath -Leaf)
                            
                            try {
                                Copy-Item -Path $remotePath -Destination $localPath -Force -ErrorAction Stop
                                $fileSizeKB = [math]::Round($exportedFile.FileSize / 1KB, 2)
                                Write-Host "  ✓ $($exportedFile.Database): $fileSizeKB KB" -ForegroundColor Green
                            }
                            catch {
                                Write-Host "  ✗ Failed to copy $($exportedFile.Database): $($_.Exception.Message)" -ForegroundColor Red
                            }
                        }
                        
                        # Clean up remote temporary folder
                        try {
                            $remoteTempPath = "\\$pc\C$" + ($result.TempFolder -replace "C:", "")
                            Remove-Item -Path $remoteTempPath -Recurse -Force -ErrorAction SilentlyContinue
                        } catch {}
                        
                        $exportResults += $result
                        Write-Host "  ✓ $pc`: Exported $($result.Databases.Count) databases" -ForegroundColor Green
                    } else {
                        $failCount++
                        Write-Host "  ✗ $pc`: FAILED - $($result.Error)" -ForegroundColor Red
                    }
                } else {
                    $failCount++
                    Write-Host "  ✗ $pc is not in csitlab.local domain - SKIPPING" -ForegroundColor Red
                }
            }
        }
        catch {
            $failCount++
            Write-Host "  ✗ $pc is OFFLINE or unreachable" -ForegroundColor DarkGray
        }
    }
    
    # Summary Report
    Write-Host ""
    Write-Host "===== MYSQL EXPORT SUMMARY =====" -ForegroundColor Cyan
    Write-Host "Total PCs processed: 35" -ForegroundColor White
    Write-Host "Successful exports: $successCount" -ForegroundColor Green
    Write-Host "Failed exports: $failCount" -ForegroundColor Red
    Write-Host "Total databases exported: $totalDatabases" -ForegroundColor Yellow
    Write-Host "Export location: $exportFolder" -ForegroundColor Cyan
    Write-Host ""
    
    if ($successCount -gt 0) {
        Write-Host "SUCCESSFULLY EXPORTED PCs:" -ForegroundColor Green
        foreach ($result in $exportResults) {
            if ($result.Success) {
                Write-Host "  $($result.Computer): $($result.Databases.Count) databases" -ForegroundColor White
                foreach ($db in $result.Databases) {
                    Write-Host "    - $db" -ForegroundColor Gray
                }
            }
        }
    }
    
    Write-Host ""
    Write-Host "MySQL database export completed!" -ForegroundColor Cyan
    Write-Host "All backups saved to: $exportFolder" -ForegroundColor Green
    Pause
}

function Show-BlockLists {
    Clear-Host
    Write-Host "===== CURRENT BLOCK LISTS =====" -ForegroundColor Cyan
    Write-Host "Total sites to block: $($blockedSites.Count)" -ForegroundColor Green
    Write-Host ""
    
    # Group sites by category based on file they came from
    $categories = @{
        "Social Media" = @()
        "Video Sites" = @()
        "Gaming Sites" = @()
        "AI Sites" = @()
        "Shopping & Entertainment" = @()
        "Other" = @()
    }
    
    # Re-read the files to categorize
    $blockFiles = Get-ChildItem -Path $blockListsFolder -Filter "*.txt" | Where-Object { $_.Name -ne "README.txt" -and $_.Name -ne "QUICK-REFERENCE.txt" -and $_.Name -ne "SITE-LIST.txt" }
    
    foreach ($file in $blockFiles) {
        $sites = Get-Content $file.FullName | Where-Object { 
            $_ -notmatch "^#" -and $_ -notmatch "^\s*$" 
        }
        
        $categoryName = switch ($file.BaseName) {
            "social-media" { "Social Media" }
            "video-sites" { "Video Sites" }
            "gaming-sites" { "Gaming Sites" }
            "ai-sites" { "AI Sites" }
            "shopping-entertainment" { "Shopping & Entertainment" }
            default { "Other" }
        }
        
        $categories[$categoryName] = $sites
        Write-Host "$categoryName ($($sites.Count) sites):" -ForegroundColor Yellow
        Write-Host "  File: $($file.Name)" -ForegroundColor Gray
        
        # Show first 5 sites as preview
        $preview = $sites | Select-Object -First 5
        foreach ($site in $preview) {
            Write-Host "    $site" -ForegroundColor White
        }
        if ($sites.Count -gt 5) {
            Write-Host "    ... and $($sites.Count - 5) more sites" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    Write-Host "Press any key to return to menu..."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Ask for credentials once (must have admin rights on all target PCs)
$cred = Get-Credential

# Load block lists from BlockLists folder
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$blockListsFolder = Join-Path $scriptPath "BlockLists"

Write-Host "===== DOMAIN-SPECIFIC WEB BLOCKING SYSTEM =====" -ForegroundColor Cyan
Write-Host "Target Domain: csitlab.local" -ForegroundColor Green
Write-Host "Loading block lists from: $blockListsFolder" -ForegroundColor Cyan

$blockedSites = @()
$blockListStats = @{}
$aiSitesOnly = @()

# Check if BlockLists folder exists
if (Test-Path $blockListsFolder) {
    # Load all .txt files from BlockLists folder (except README and reference files)
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
        
        # Load AI sites separately for AI-only blocking option
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
    
    # Fallback to basic list if folder doesn't exist
    $blockedSites = @(
        "www.google.com", "google.com",
        "www.facebook.com", "facebook.com",
        "www.youtube.com", "youtube.com",
        "www.twitter.com", "twitter.com"
    )
}

Write-Host ""
Write-Host "IMPORTANT: Blocking will only apply to PCs in the 'csitlab.local' domain!" -ForegroundColor Yellow
Write-Host ""

do {
    Show-Menu
    $choice = Read-Host "Enter your choice (1-20)"

    switch ($choice) {
        '1' {
            $targets = foreach ($i in 1..35) { "PC-$i" }
            foreach ($pc in $targets) {
                try {
                    if (Test-WSMan -ComputerName $pc -ErrorAction Stop) {
                        $result = Invoke-Command -ComputerName $pc -Credential $cred -ScriptBlock {
                            $date = Get-Date
                            $tz   = (Get-TimeZone).Id

                            # Extract the Source line properly
                            $srcLine = (w32tm /query /status | Select-String "Source").Line
                            $src = $srcLine -replace ".*Source:\s*", ""

                            if ($src -match "csitlab\.local") {
                                $srcDisplay = "Domain ($src)"
                            }
                            else {
                                $srcDisplay = $src
                            }

                            [PSCustomObject]@{
                                Computer = $env:COMPUTERNAME
                                DateTime = $date
                                TimeZone = $tz
                                Source   = $srcDisplay
                            }
                        }

                        Write-Host "$($result.Computer) is ONLINE" -ForegroundColor Green
                        Write-Host "   Date/Time : $($result.DateTime)"
                        Write-Host "   TimeZone  : $($result.TimeZone)"
                        Write-Host "   Source    : $($result.Source)"
                    }
                }
                catch {
                    Write-Host "$pc is OFFLINE or unreachable via WinRM" -ForegroundColor Red
                }
            }
            Pause
        }
        '2' {
            $pc = Read-Host "Enter the PC name (e.g., PC-1)"
            $targets = @($pc)
            $action = "Shutdown"
        }
        '3' {
            $start = Read-Host "Enter start number (e.g., 5)"
            $end   = Read-Host "Enter end number (e.g., 10)"
            $targets = foreach ($i in $start..$end) { "PC-$i" }
            $action = "Shutdown"
        }
        '4' {
            $targets = foreach ($i in 1..35) { "PC-$i" }
            $action = "Shutdown"
        }
        '5' {
            $pc = Read-Host "Enter the PC name (e.g., PC-1)"
            $targets = @($pc)
            $action = "Restart"
        }
        '6' {
            $start = Read-Host "Enter start number (e.g., 5)"
            $end   = Read-Host "Enter end number (e.g., 10)"
            $targets = foreach ($i in $start..$end) { "PC-$i" }
            $action = "Restart"
        }
        '7' {
            $targets = foreach ($i in 1..35) { "PC-$i" }
            $action = "Restart"
        }
        '8' {
            $pc = Read-Host "Enter the PC name (e.g., PC-1)"
            $targets = @($pc)
            $action = "BlockWeb"
        }
        '9' {
            $start = Read-Host "Enter start number (e.g., 5)"
            $end   = Read-Host "Enter end number (e.g., 10)"
            $targets = foreach ($i in $start..$end) { "PC-$i" }
            $action = "BlockWeb"
        }
        '10' {
            $targets = foreach ($i in 1..35) { "PC-$i" }
            $action = "BlockWeb"
        }
        '11' {
            $pc = Read-Host "Enter the PC name (e.g., PC-1)"
            $targets = @($pc)
            $action = "UnblockWeb"
        }
        '12' {
            $start = Read-Host "Enter start number (e.g., 5)"
            $end   = Read-Host "Enter end number (e.g., 10)"
            $targets = foreach ($i in $start..$end) { "PC-$i" }
            $action = "UnblockWeb"
        }
        '13' {
            $targets = foreach ($i in 1..35) { "PC-$i" }
            $action = "UnblockWeb"
        }
        '14' {
            Write-Host "Starting Deep Scan of all PCs..." -ForegroundColor Cyan
            Write-Host "Checking blocking status and domain membership..." -ForegroundColor Yellow
            Write-Host ""
            
            $targets = foreach ($i in 1..35) { "PC-$i" }
            $scanResults = @()
            
            foreach ($pc in $targets) {
                Write-Host "Scanning $pc..." -ForegroundColor Gray
                try {
                    if (Test-WSMan -ComputerName $pc -ErrorAction Stop) {
                        # Check domain membership first
                        $isDomainMember = Test-DomainMembership -ComputerName $pc
                        
                        if ($isDomainMember) {
                            $status = Get-BlockingStatus -ComputerName $pc
                            $scanResults += $status
                            
                            if ($status.HasBlocks) {
                                Write-Host "  $pc`: ONLINE, Domain Member, Blocking ACTIVE ($($status.BlockedEntries) entries)" -ForegroundColor Green
                            } else {
                                Write-Host "  $pc`: ONLINE, Domain Member, Blocking INACTIVE" -ForegroundColor Yellow
                            }
                        } else {
                            Write-Host "  $pc`: ONLINE, NOT in csitlab.local domain - SKIPPING" -ForegroundColor Red
                        }
                    }
                }
                catch {
                    Write-Host "  $pc`: OFFLINE or unreachable" -ForegroundColor DarkGray
                }
            }
            
            # Summary Report
            Write-Host ""
            Write-Host "===== DEEP SCAN SUMMARY =====" -ForegroundColor Cyan
            $onlineDomainPCs = $scanResults | Where-Object { $_.Domain -eq "csitlab.local" }
            $blockedPCs = $onlineDomainPCs | Where-Object { $_.HasBlocks -eq $true }
            $unblockedPCs = $onlineDomainPCs | Where-Object { $_.HasBlocks -eq $false }
            
            Write-Host "Total PCs scanned: 35" -ForegroundColor White
            Write-Host "Domain members online: $($onlineDomainPCs.Count)" -ForegroundColor White
            Write-Host "PCs with blocking active: $($blockedPCs.Count)" -ForegroundColor Green
            Write-Host "PCs with blocking inactive: $($unblockedPCs.Count)" -ForegroundColor Yellow
            
            if ($unblockedPCs.Count -gt 0) {
                Write-Host ""
                Write-Host "PCs needing block activation:" -ForegroundColor Yellow
                foreach ($pc in $unblockedPCs) {
                    Write-Host "  $($pc.Computer)" -ForegroundColor White
                }
            }
            
            Pause
        }
        '15' {
            Show-BlockLists
        }
        '16' {
            Sync-TimeToAllPCs
        }
        '17' {
            Write-Host "Starting backup hosts files cleanup on all PCs..." -ForegroundColor Cyan
            Write-Host "This will remove all hosts.backup-* files..." -ForegroundColor Yellow
            Write-Host ""
            
            $targets = foreach ($i in 1..35) { "PC-$i" }
            $cleanupResults = @()
            $successCount = 0
            $failCount = 0
            
            foreach ($pc in $targets) {
                Write-Host "Cleaning backup files on $pc..." -ForegroundColor Gray
                try {
                    if (Test-WSMan -ComputerName $pc -ErrorAction Stop) {
                        # Check domain membership first
                        $isDomainMember = Test-DomainMembership -ComputerName $pc
                        
                        if ($isDomainMember) {
                            $result = Invoke-Command -ComputerName $pc -Credential $cred -ScriptBlock {
                                try {
                                    $backupPath = "$env:SystemRoot\System32\drivers\etc"
                                    $backupFiles = Get-ChildItem -Path $backupPath -Filter "hosts.backup-*" -ErrorAction SilentlyContinue
                                    
                                    if ($backupFiles) {
                                        $backupCount = $backupFiles.Count
                                        $totalSize = ($backupFiles | Measure-Object -Property Length -Sum).Sum
                                        $backupFiles | Remove-Item -Force -ErrorAction SilentlyContinue
                                        
                                        return @{
                                            Success = $true
                                            Computer = $env:COMPUTERNAME
                                            FilesRemoved = $backupCount
                                            SpaceFreed = $totalSize
                                            Message = "Cleaned up $backupCount backup files ($([math]::Round($totalSize/1KB, 2)) KB freed)"
                                        }
                                    } else {
                                        return @{
                                            Success = $true
                                            Computer = $env:COMPUTERNAME
                                            FilesRemoved = 0
                                            SpaceFreed = 0
                                            Message = "No backup files found to clean up"
                                        }
                                    }
                                } catch {
                                    return @{
                                        Success = $false
                                        Computer = $env:COMPUTERNAME
                                        FilesRemoved = 0
                                        SpaceFreed = 0
                                        Message = "Error: $($_.Exception.Message)"
                                    }
                                }
                            } -ErrorAction Stop
                            
                            $cleanupResults += $result
                            
                            if ($result.Success) {
                                $successCount++
                                if ($result.FilesRemoved -gt 0) {
                                    Write-Host "  ✓ $pc`: $($result.Message)" -ForegroundColor Green
                                } else {
                                    Write-Host "  ✓ $pc`: $($result.Message)" -ForegroundColor Gray
                                }
                            } else {
                                $failCount++
                                Write-Host "  ✗ $pc`: $($result.Message)" -ForegroundColor Red
                            }
                        } else {
                            $failCount++
                            Write-Host "  ✗ $pc is not in csitlab.local domain - SKIPPING" -ForegroundColor Red
                        }
                    }
                } catch {
                    $failCount++
                    Write-Host "  ✗ $pc is OFFLINE or unreachable" -ForegroundColor DarkGray
                }
            }
            
            # Summary Report
            Write-Host ""
            Write-Host "===== CLEANUP SUMMARY =====" -ForegroundColor Cyan
            $successfulResults = $cleanupResults | Where-Object { $_.Success }
            $totalFilesRemoved = if ($successfulResults) { 
                ($successfulResults | Measure-Object -Property FilesRemoved -Sum -ErrorAction SilentlyContinue).Sum 
            } else { 0 }
            $totalSpaceFreed = if ($successfulResults) { 
                ($successfulResults | Measure-Object -Property SpaceFreed -Sum -ErrorAction SilentlyContinue).Sum 
            } else { 0 }
            
            # Handle null values
            if ($null -eq $totalFilesRemoved) { $totalFilesRemoved = 0 }
            if ($null -eq $totalSpaceFreed) { $totalSpaceFreed = 0 }
            
            Write-Host "Total PCs processed: 35" -ForegroundColor White
            Write-Host "Successful cleanups: $successCount" -ForegroundColor Green
            Write-Host "Failed cleanups: $failCount" -ForegroundColor Red
            Write-Host "Total backup files removed: $totalFilesRemoved" -ForegroundColor Yellow
            Write-Host "Total space freed: $([math]::Round($totalSpaceFreed/1KB, 2)) KB" -ForegroundColor Yellow
            
            if ($totalFilesRemoved -gt 0) {
                Write-Host ""
                Write-Host "PCs with files cleaned:" -ForegroundColor Green
                $cleanedPCs = $cleanupResults | Where-Object { $_.Success -and $_.FilesRemoved -gt 0 }
                foreach ($pc in $cleanedPCs) {
                    $spaceFreedKB = if ($pc.SpaceFreed) { [math]::Round($pc.SpaceFreed/1KB, 2) } else { 0 }
                    Write-Host "  $($pc.Computer): $($pc.FilesRemoved) files ($spaceFreedKB KB)" -ForegroundColor White
                }
            } else {
                Write-Host ""
                Write-Host "No backup files found on any PC to clean up." -ForegroundColor Gray
            }
            
            Write-Host ""
            Write-Host "Backup files cleanup completed!" -ForegroundColor Cyan
            Pause
        }
        '18' {
            Write-Host "===== AI SITES BLOCKING (ALL PCs) =====" -ForegroundColor Yellow
            Write-Host "This will block ONLY AI sites from ai-sites.txt ($($aiSitesOnly.Count) sites)" -ForegroundColor Cyan
            Write-Host "Other sites (social media, video, gaming, shopping) will remain accessible" -ForegroundColor Gray
            Write-Host ""
            
            $targets = foreach ($i in 1..35) { "PC-$i" }
            $action = "BlockAI"
        }
        '19' {
            Export-MySQLDatabases
        }
        '20' {
            continue  # Just clears and redraws menu
        }
        '21' {
            Write-Host "Exiting..." -ForegroundColor Yellow
            break
        }
        default {
            Write-Host "Invalid choice. Try again..." -ForegroundColor Red
            Pause
            continue
        }
    }

    if ($choice -in '2','3','4','5','6','7','8','9','10','11','12','13','18') {
        foreach ($pc in $targets) {
            Write-Host "Checking $pc ..." -ForegroundColor Cyan
            try {
                if (Test-WSMan -ComputerName $pc -ErrorAction Stop) {
                    # For blocking/unblocking operations, check domain membership first
                    if ($action -in @("BlockWeb", "UnblockWeb", "BlockAI")) {
                        $isDomainMember = Test-DomainMembership -ComputerName $pc
                        
                        if (-not $isDomainMember) {
                            Write-Host "$pc is not in csitlab.local domain - SKIPPING blocking operation" -ForegroundColor Red
                            continue
                        }
                        
                        Write-Host "$pc is in csitlab.local domain - proceeding with $action" -ForegroundColor Green
                    }
                    
                    if ($action -eq "Shutdown") {
                        Write-Host "Shutting down $pc via WinRM ..." -ForegroundColor Yellow
                        Invoke-Command -ComputerName $pc -Credential $cred -ScriptBlock {
                            Stop-Computer -Force
                        }
                        Write-Host "$pc shutdown command sent." -ForegroundColor Green
                    }
                    elseif ($action -eq "Restart") {
                        Write-Host "Restarting $pc via WinRM ..." -ForegroundColor Yellow
                        Invoke-Command -ComputerName $pc -Credential $cred -ScriptBlock {
                            Restart-Computer -Force
                        }
                        Write-Host "$pc restart command sent." -ForegroundColor Green
                    }
                    elseif ($action -eq "BlockWeb") {
                        Write-Host "Blocking web access on $pc (Domain: csitlab.local)..." -ForegroundColor Yellow
                        $result = Invoke-Command -ComputerName $pc -Credential $cred -ArgumentList (,$blockedSites) -ScriptBlock {
                            param($sites)
                            
                            try {
                                $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
                                $results = @()
                                
                                # Check if hosts file exists and is accessible
                                if (-not (Test-Path $hostsFile)) {
                                    throw "Hosts file not found at $hostsFile"
                                }
                                
                                # 1. HOSTS FILE BLOCKING
                                $results += "=== HOSTS FILE BLOCKING ==="
                                
                                # Backup hosts file with timestamp
                                $backupName = "$hostsFile.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                                Copy-Item $hostsFile $backupName -Force -ErrorAction Stop
                                $results += "Backup created: $backupName"
                                
                                # Read content with proper encoding and error handling
                                $content = @()
                                $retryCount = 0
                                $maxRetries = 3
                                
                                while ($retryCount -lt $maxRetries) {
                                    try {
                                        # Force release any file handles
                                        [System.GC]::Collect()
                                        [System.GC]::WaitForPendingFinalizers()
                                        
                                        # Read with specific encoding to avoid stream issues
                                        $content = Get-Content $hostsFile -Encoding UTF8 -ErrorAction Stop
                                        break
                                    }
                                    catch {
                                        $retryCount++
                                        if ($retryCount -eq $maxRetries) {
                                            throw "Failed to read hosts file after $maxRetries attempts: $($_.Exception.Message)"
                                        }
                                        Start-Sleep -Milliseconds 500
                                    }
                                }
                                
                                # Add blocking entries
                                $blockMarker = "# BLOCKED BY ADMIN - csitlab.local domain - $(Get-Date)"
                                
                                # Remove old blocks if they exist
                                $newContent = $content | Where-Object { 
                                    $_ -notmatch "BLOCKED BY ADMIN" -and 
                                    $_ -notmatch "127\.0\.0\.1\s+(www\.)?(facebook|youtube|twitter|instagram|tiktok|reddit|netflix|amazon|google)" 
                                }
                                
                                # Prepare block entries with multiple blocking IPs
                                $blockEntries = @()
                                $blockEntries += $blockMarker
                                $blockEntries += "# Total sites blocked: $($sites.Count)"
                                $blockEntries += "# Block applied on: $(Get-Date)"
                                $blockEntries += ""
                                
                                foreach ($site in $sites) {
                                    # Block with localhost
                                    $blockEntries += "127.0.0.1 $site"
                                    # Block with null route
                                    $blockEntries += "0.0.0.0 $site"
                                    # Block common www variants
                                    if (-not $site.StartsWith("www.")) {
                                        $blockEntries += "127.0.0.1 www.$site"
                                        $blockEntries += "0.0.0.0 www.$site"
                                    }
                                }
                                
                                $blockEntries += ""
                                $blockEntries += "# END BLOCKED BY ADMIN"
                                
                                # Combine content
                                $finalContent = $newContent + $blockEntries
                                
                                # Write with retry logic and proper encoding
                                $writeRetryCount = 0
                                while ($writeRetryCount -lt $maxRetries) {
                                    try {
                                        # Force release any file handles
                                        [System.GC]::Collect()
                                        [System.GC]::WaitForPendingFinalizers()
                                        
                                        # Use Out-File instead of Set-Content for better reliability
                                        $finalContent | Out-File -FilePath $hostsFile -Encoding UTF8 -Force -ErrorAction Stop
                                        break
                                    }
                                    catch {
                                        $writeRetryCount++
                                        if ($writeRetryCount -eq $maxRetries) {
                                            throw "Failed to write hosts file after $maxRetries attempts: $($_.Exception.Message)"
                                        }
                                        Start-Sleep -Milliseconds 500
                                    }
                                }
                                
                                $results += "Hosts file updated with $($sites.Count) sites"
                                
                                # 2. DNS CACHE FLUSHING (Multiple methods)
                                $results += "=== DNS FLUSHING ==="
                                try {
                                    # Flush DNS resolver cache
                                    ipconfig /flushdns | Out-Null
                                    $results += "DNS resolver cache flushed"
                                    
                                    # Clear DNS client cache
                                    Clear-DnsClientCache -ErrorAction SilentlyContinue
                                    $results += "DNS client cache cleared"
                                    
                                    # Stop and restart DNS client service
                                    Restart-Service -Name "Dnscache" -Force -ErrorAction SilentlyContinue
                                    $results += "DNS client service restarted"
                                }
                                catch {
                                    $results += "DNS flush warning: $($_.Exception.Message)"
                                }
                                
                                # 3. BROWSER CACHE CLEARING
                                $results += "=== BROWSER PREPARATIONS ==="
                                try {
                                    # Kill browser processes to force cache reload
                                    $browsers = @("chrome", "firefox", "msedge", "iexplore", "opera")
                                    foreach ($browser in $browsers) {
                                        $processes = Get-Process -Name $browser -ErrorAction SilentlyContinue
                                        if ($processes) {
                                            $processes | Stop-Process -Force -ErrorAction SilentlyContinue
                                            $results += "Killed $browser processes"
                                        }
                                    }
                                }
                                catch {
                                    $results += "Browser process management: $($_.Exception.Message)"
                                }
                                
                                # 4. WINDOWS FIREWALL RULES (Enhanced blocking)
                                $results += "=== FIREWALL BLOCKING ==="
                                try {
                                    # Create outbound firewall rules for major sites
                                    $majorSites = $sites | Where-Object { 
                                        $_ -match "(facebook|youtube|twitter|instagram|tiktok|netflix|google|amazon|reddit)" 
                                    } | Select-Object -First 20
                                    
                                    foreach ($site in $majorSites) {
                                        $ruleName = "CSITLAB-BLOCK-$($site.Replace('.', '-'))"
                                        
                                        # Remove existing rule if present
                                        Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
                                        
                                        # Create new blocking rule
                                        New-NetFirewallRule -DisplayName $ruleName -Direction Outbound -Protocol TCP -Action Block -RemoteAddress * -RemotePort 80,443 -Program "C:\Program Files\Google\Chrome\Application\chrome.exe" -ErrorAction SilentlyContinue
                                        New-NetFirewallRule -DisplayName "$ruleName-Firefox" -Direction Outbound -Protocol TCP -Action Block -RemoteAddress * -RemotePort 80,443 -Program "C:\Program Files\Mozilla Firefox\firefox.exe" -ErrorAction SilentlyContinue
                                    }
                                    $results += "Firewall rules created for $($majorSites.Count) major sites"
                                }
                                catch {
                                    $results += "Firewall rules warning: $($_.Exception.Message)"
                                }
                                
                                # 5. NETWORK ADAPTER DNS OVERRIDE
                                $results += "=== DNS SERVER OVERRIDE ==="
                                try {
                                    # Get active network adapters
                                    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Physical -eq $true }
                                    
                                    foreach ($adapter in $adapters) {
                                        # Set DNS to localhost (where we can control resolution)
                                        Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses "127.0.0.1", "8.8.8.8" -ErrorAction SilentlyContinue
                                        $results += "DNS override set for adapter: $($adapter.Name)"
                                    }
                                }
                                catch {
                                    $results += "DNS override warning: $($_.Exception.Message)"
                                }
                                
                                # 6. REGISTRY MODIFICATIONS (Proxy settings)
                                $results += "=== PROXY CONFIGURATION ==="
                                try {
                                    # Set IE/Edge proxy to block sites
                                    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
                                    Set-ItemProperty -Path $regPath -Name "ProxyEnable" -Value 0 -ErrorAction SilentlyContinue
                                    $results += "Proxy settings configured"
                                }
                                catch {
                                    $results += "Proxy config warning: $($_.Exception.Message)"
                                }
                                
                                # 7. WINDOWS COPILOT & AI SERVICE BLOCKING
                                $results += "=== WINDOWS AI SERVICES BLOCKING ==="
                                try {
                                    # Block AI service internet connections (keep apps installed but disable internet access)
                                    $results += "Blocking AI internet connections while preserving local applications..."
                                    
                                    # Disable Windows Copilot internet features (keep UI visible but non-functional)
                                    $copilotRegistryPaths = @(
                                        "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot",
                                        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
                                    )
                                    
                                    foreach ($regPath in $copilotRegistryPaths) {
                                        if (!(Test-Path $regPath)) {
                                            New-Item -Path $regPath -Force | Out-Null
                                        }
                                        
                                        # Disable internet connectivity for Copilot (keep local UI)
                                        Set-ItemProperty -Path $regPath -Name "DisableCopilotWebSearches" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                                        Set-ItemProperty -Path $regPath -Name "DisableCopilotCloudSync" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                                        Set-ItemProperty -Path $regPath -Name "AllowCopilotRuntime" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                                    }
                                    
                                    # Block AI features internet access in Edge (keep browser functional)
                                    $edgeRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
                                    if (!(Test-Path $edgeRegistryPath)) {
                                        New-Item -Path $edgeRegistryPath -Force | Out-Null
                                    }
                                    Set-ItemProperty -Path $edgeRegistryPath -Name "CopilotCDPEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                                    Set-ItemProperty -Path $edgeRegistryPath -Name "CopilotPageEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                                    Set-ItemProperty -Path $edgeRegistryPath -Name "HubsSidebarEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                                    Set-ItemProperty -Path $edgeRegistryPath -Name "AIAssistanceEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                                    
                                    # Block AI telemetry and cloud connections (keep OS functional)
                                    $privacyRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
                                    if (!(Test-Path $privacyRegistryPath)) {
                                        New-Item -Path $privacyRegistryPath -Force | Out-Null
                                    }
                                    Set-ItemProperty -Path $privacyRegistryPath -Name "AllowTelemetry" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                                    Set-ItemProperty -Path $privacyRegistryPath -Name "DisableOneSettingsDownloads" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                                    
                                    $results += "✓ Windows AI internet connections blocked (local apps preserved)"
                                } catch {
                                    $results += "⚠ Windows AI blocking warning: $($_.Exception.Message)"
                                }
                                
                                # 8. FIREWALL RULES FOR AI SERVICES
                                $results += "=== AI SERVICES FIREWALL BLOCKING ==="
                                try {
                                    # Block specific AI service executables from internet access
                                    $aiProcesses = @(
                                        "Microsoft.Copilot*",
                                        "copilot.exe",
                                        "MicrosoftCopilot.exe",
                                        "WindowsCopilotRuntime.exe",
                                        "CopilotService.exe"
                                    )
                                    
                                    foreach ($process in $aiProcesses) {
                                        $ruleName = "CSITLAB-AI-BLOCK-$($process.Replace('*', '').Replace('.exe', ''))"
                                        
                                        # Remove existing rule if present
                                        Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
                                        
                                        # Create outbound blocking rule for AI processes
                                        New-NetFirewallRule -DisplayName $ruleName -Direction Outbound -Protocol TCP -Action Block -Program "*$process*" -RemotePort 80,443 -ErrorAction SilentlyContinue
                                        New-NetFirewallRule -DisplayName "$ruleName-UDP" -Direction Outbound -Protocol UDP -Action Block -Program "*$process*" -ErrorAction SilentlyContinue
                                    }
                                    
                                    $results += "✓ AI service processes blocked from internet access"
                                } catch {
                                    $results += "⚠ AI firewall blocking warning: $($_.Exception.Message)"
                                }
                                
                                # 9. VS CODE AI EXTENSION INTERNET BLOCKING
                                $results += "=== VS CODE AI INTERNET BLOCKING ==="
                                try {
                                    # Block VS Code AI extensions from internet (keep extensions installed but non-functional)
                                    $vscodeSettingsPaths = @(
                                        "$env:USERPROFILE\AppData\Roaming\Code\User\settings.json",
                                        "$env:USERPROFILE\AppData\Roaming\Code - Insiders\User\settings.json"
                                    )
                                    
                                    foreach ($settingsPath in $vscodeSettingsPaths) {
                                        if (Test-Path $settingsPath) {
                                            try {
                                                $settings = Get-Content $settingsPath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
                                                if (!$settings) {
                                                    $settings = [PSCustomObject]@{}
                                                }
                                                
                                                # Disable AI features internet connectivity (keep extensions visible)
                                                $settings | Add-Member -NotePropertyName "github.copilot.enable" -NotePropertyValue $false -Force
                                                $settings | Add-Member -NotePropertyName "github.copilot.chat.enabled" -NotePropertyValue $false -Force
                                                $settings | Add-Member -NotePropertyName "github.copilot.inlineSuggest.enable" -NotePropertyValue $false -Force
                                                $settings | Add-Member -NotePropertyName "tabnine.experimentalAutoImports" -NotePropertyValue $false -Force
                                                $settings | Add-Member -NotePropertyName "codeium.enableCodeLens" -NotePropertyValue $false -Force
                                                $settings | Add-Member -NotePropertyName "codeium.enableSearch" -NotePropertyValue $false -Force
                                                $settings | Add-Member -NotePropertyName "codeium.enableSuggestionsWithArguments" -NotePropertyValue $false -Force
                                                $settings | Add-Member -NotePropertyName "aicommits.openaiApiKey" -NotePropertyValue "" -Force
                                                $settings | Add-Member -NotePropertyName "bito.enable" -NotePropertyValue $false -Force
                                                
                                                # Create offline mode settings
                                                $settings | Add-Member -NotePropertyName "http.proxy" -NotePropertyValue "http://127.0.0.1:0" -Force
                                                $settings | Add-Member -NotePropertyName "http.proxySupport" -NotePropertyValue "off" -Force
                                                
                                                $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -ErrorAction SilentlyContinue
                                            } catch {
                                                # Create basic settings file to disable AI
                                                $basicSettings = @{
                                                    "github.copilot.enable" = $false
                                                    "github.copilot.chat.enabled" = $false
                                                    "codeium.enableCodeLens" = $false
                                                    "tabnine.experimentalAutoImports" = $false
                                                }
                                                $basicSettings | ConvertTo-Json | Set-Content $settingsPath -ErrorAction SilentlyContinue
                                            }
                                        }
                                    }
                                    
                                    # Block VS Code processes from accessing AI domains
                                    $vscodeProcesses = @("Code.exe", "Code - Insiders.exe")
                                    foreach ($process in $vscodeProcesses) {
                                        $ruleName = "CSITLAB-VSCODE-AI-BLOCK-$($process.Replace('.exe', '').Replace(' ', '').Replace('-', ''))"
                                        Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
                                        
                                        # Block access to specific AI domains for VS Code
                                        New-NetFirewallRule -DisplayName $ruleName -Direction Outbound -Protocol TCP -Action Block -Program "*$process" -RemoteAddress "api.openai.com","*.github.com","copilot.github.com","api.tabnine.com","server.codeium.com" -ErrorAction SilentlyContinue
                                    }
                                    
                                    $results += "✓ VS Code AI internet access blocked (extensions preserved)"
                                } catch {
                                    $results += "⚠ VS Code AI blocking warning: $($_.Exception.Message)"
                                }
                                
                                # 10. OFFICE COPILOT INTERNET BLOCKING
                                $results += "=== OFFICE AI INTERNET BLOCKING ==="
                                try {
                                    # Disable Office AI internet connectivity (keep Office functional)
                                    $officeRegistryPaths = @(
                                        "HKCU:\Software\Policies\Microsoft\Office\16.0\Common\Privacy",
                                        "HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Common\Privacy",
                                        "HKCU:\Software\Policies\Microsoft\Office\Common\Privacy",
                                        "HKLM:\SOFTWARE\Policies\Microsoft\Office\Common\Privacy"
                                    )
                                    
                                    foreach ($regPath in $officeRegistryPaths) {
                                        if (!(Test-Path $regPath)) {
                                            New-Item -Path $regPath -Force | Out-Null
                                        }
                                        # Block cloud AI features but keep Office working
                                        Set-ItemProperty -Path $regPath -Name "DisableCopilot" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                                        Set-ItemProperty -Path $regPath -Name "ControllerConnectedServicesEnabled" -Value 2 -Type DWord -ErrorAction SilentlyContinue
                                        Set-ItemProperty -Path $regPath -Name "DownloadContentDisabled" -Value 2 -Type DWord -ErrorAction SilentlyContinue
                                        Set-ItemProperty -Path $regPath -Name "EnableAIFeatures" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                                    }
                                    
                                    # Block Office processes from AI domains
                                    $officeProcesses = @("WINWORD.EXE", "EXCEL.EXE", "POWERPNT.EXE", "OUTLOOK.EXE", "ONENOTE.EXE")
                                    foreach ($process in $officeProcesses) {
                                        $ruleName = "CSITLAB-OFFICE-AI-BLOCK-$($process.Replace('.EXE', ''))"
                                        Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
                                        
                                        # Block Office from accessing AI services
                                        New-NetFirewallRule -DisplayName $ruleName -Direction Outbound -Protocol TCP -Action Block -Program "*$process" -RemoteAddress "api.openai.com","copilot.microsoft.com","*.openai.com" -ErrorAction SilentlyContinue
                                    }
                                    
                                    $results += "✓ Office AI internet access blocked (Office apps preserved)"
                                } catch {
                                    $results += "⚠ Office AI blocking warning: $($_.Exception.Message)"
                                }
                                
                                # 11. VERIFICATION
                                $results += "=== VERIFICATION ==="
                                $testSites = @("facebook.com", "youtube.com", "google.com")
                                foreach ($testSite in $testSites) {
                                    try {
                                        $resolved = Resolve-DnsName -Name $testSite -ErrorAction SilentlyContinue
                                        if ($resolved -and $resolved.IPAddress -contains "127.0.0.1") {
                                            $results += "✓ $testSite blocked successfully"
                                        } else {
                                            $results += "⚠ $testSite may not be fully blocked"
                                        }
                                    }
                                    catch {
                                        $results += "✓ $testSite resolution blocked"
                                    }
                                }
                                
                                return @{
                                    Success = $true
                                    Message = "Multi-layer blocking applied successfully"
                                    SitesBlocked = $sites.Count
                                    Details = $results
                                }
                            }
                            catch {
                                return @{
                                    Success = $false
                                    Message = "Error: $($_.Exception.Message)"
                                    SitesBlocked = 0
                                    Details = @("ERROR: $($_.Exception.Message)")
                                }
                            }
                        } -ErrorAction Stop
                        
                        if ($result.Success) {
                            Write-Host "$pc ENHANCED web blocking applied successfully ($($result.SitesBlocked) sites)." -ForegroundColor Green
                            Write-Host "Blocking layers implemented:" -ForegroundColor Cyan
                            foreach ($detail in $result.Details) {
                                if ($detail.StartsWith("===")) {
                                    Write-Host "  $detail" -ForegroundColor Yellow
                                } elseif ($detail.StartsWith("✓")) {
                                    Write-Host "  $detail" -ForegroundColor Green
                                } elseif ($detail.StartsWith("⚠")) {
                                    Write-Host "  $detail" -ForegroundColor Yellow
                                } else {
                                    Write-Host "    $detail" -ForegroundColor Gray
                                }
                            }
                        } else {
                            Write-Host "$pc web blocking FAILED: $($result.Message)" -ForegroundColor Red
                            foreach ($detail in $result.Details) {
                                Write-Host "  $detail" -ForegroundColor Red
                            }
                        }
                    }
                    elseif ($action -eq "UnblockWeb") {
                        Write-Host "Unblocking web access on $pc (Domain: csitlab.local)..." -ForegroundColor Yellow
                        $result = Invoke-Command -ComputerName $pc -Credential $cred -ScriptBlock {
                            try {
                                $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
                                $results = @()
                                
                                # Check if hosts file exists and is accessible
                                if (-not (Test-Path $hostsFile)) {
                                    throw "Hosts file not found at $hostsFile"
                                }
                                
                                # 1. HOSTS FILE RESTORATION
                                $results += "=== HOSTS FILE RESTORATION ==="
                                
                                # Read content with proper encoding and error handling
                                $content = @()
                                $retryCount = 0
                                $maxRetries = 3
                                
                                while ($retryCount -lt $maxRetries) {
                                    try {
                                        # Force release any file handles
                                        [System.GC]::Collect()
                                        [System.GC]::WaitForPendingFinalizers()
                                        
                                        # Read with specific encoding to avoid stream issues
                                        $content = Get-Content $hostsFile -Encoding UTF8 -ErrorAction Stop
                                        break
                                    }
                                    catch {
                                        $retryCount++
                                        if ($retryCount -eq $maxRetries) {
                                            throw "Failed to read hosts file after $maxRetries attempts: $($_.Exception.Message)"
                                        }
                                        Start-Sleep -Milliseconds 500
                                    }
                                }
                                
                                # Remove ALL blocking entries
                                $originalCount = $content.Count
                                $newContent = $content | Where-Object { 
                                    $_ -notmatch "BLOCKED BY ADMIN" -and 
                                    $_ -notmatch "127\.0\.0\.1\s+" -and
                                    $_ -notmatch "0\.0\.0\.0\s+" -and
                                    $_ -notmatch "^# Total sites blocked:" -and
                                    $_ -notmatch "^# Block applied on:" -and
                                    $_ -notmatch "^# END BLOCKED BY ADMIN"
                                } | Where-Object {
                                    # Keep only localhost entry
                                    if ($_ -match "127\.0\.0\.1") {
                                        return $_ -match "127\.0\.0\.1\s+localhost"
                                    }
                                    return $true
                                }
                                
                                $removedEntries = $originalCount - $newContent.Count
                                
                                # Write with retry logic and proper encoding
                                $writeRetryCount = 0
                                while ($writeRetryCount -lt $maxRetries) {
                                    try {
                                        # Force release any file handles
                                        [System.GC]::Collect()
                                        [System.GC]::WaitForPendingFinalizers()
                                        
                                        # Use Out-File instead of Set-Content for better reliability
                                        $newContent | Out-File -FilePath $hostsFile -Encoding UTF8 -Force -ErrorAction Stop
                                        break
                                    }
                                    catch {
                                        $writeRetryCount++
                                        if ($writeRetryCount -eq $maxRetries) {
                                            throw "Failed to write hosts file after $maxRetries attempts: $($_.Exception.Message)"
                                        }
                                        Start-Sleep -Milliseconds 500
                                    }
                                }
                                
                                $results += "Hosts file cleaned: $removedEntries entries removed"
                                
                                # Clean up backup hosts files
                                try {
                                    $backupFiles = Get-ChildItem -Path "$env:SystemRoot\System32\drivers\etc" -Filter "hosts.backup-*" -ErrorAction SilentlyContinue
                                    if ($backupFiles) {
                                        $backupCount = $backupFiles.Count
                                        $totalSize = ($backupFiles | Measure-Object -Property Length -Sum).Sum
                                        $backupFiles | Remove-Item -Force -ErrorAction SilentlyContinue
                                        $results += "Cleaned up $backupCount backup hosts files ($([math]::Round($totalSize/1KB, 2)) KB freed)"
                                    } else {
                                        $results += "No backup hosts files found to clean up"
                                    }
                                    
                                    # Also clean up any temporary hosts files
                                    $tempFiles = Get-ChildItem -Path "$env:SystemRoot\System32\drivers\etc" -Filter "hosts.tmp*" -ErrorAction SilentlyContinue
                                    if ($tempFiles) {
                                        $tempFiles | Remove-Item -Force -ErrorAction SilentlyContinue
                                        $results += "Cleaned up $($tempFiles.Count) temporary hosts files"
                                    }
                                    
                                    # Clean up old .bak files if any
                                    $bakFiles = Get-ChildItem -Path "$env:SystemRoot\System32\drivers\etc" -Filter "hosts.bak*" -ErrorAction SilentlyContinue
                                    if ($bakFiles) {
                                        $bakFiles | Remove-Item -Force -ErrorAction SilentlyContinue
                                        $results += "Cleaned up $($bakFiles.Count) .bak hosts files"
                                    }
                                } catch {
                                    $results += "Backup cleanup warning: $($_.Exception.Message)"
                                }
                                
                                # 2. REMOVE FIREWALL RULES
                                $results += "=== FIREWALL RULES REMOVAL ==="
                                try {
                                    # Remove all CSITLAB blocking rules (web + AI services)
                                    $firewallRules = Get-NetFirewallRule -DisplayName "CSITLAB-*" -ErrorAction SilentlyContinue
                                    if ($firewallRules) {
                                        $firewallRules | Remove-NetFirewallRule -ErrorAction SilentlyContinue
                                        $results += "Removed $($firewallRules.Count) firewall blocking rules"
                                    } else {
                                        $results += "No firewall blocking rules found"
                                    }
                                }
                                catch {
                                    $results += "Firewall cleanup warning: $($_.Exception.Message)"
                                }
                                
                                # 3. RESTORE AI SERVICES INTERNET ACCESS
                                $results += "=== AI SERVICES RESTORATION ==="
                                try {
                                    # Restore Windows Copilot internet connectivity
                                    $copilotRegistryPaths = @(
                                        "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot",
                                        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
                                    )
                                    
                                    foreach ($regPath in $copilotRegistryPaths) {
                                        if (Test-Path $regPath) {
                                            # Re-enable internet connectivity for Copilot
                                            Remove-ItemProperty -Path $regPath -Name "DisableCopilotWebSearches" -ErrorAction SilentlyContinue
                                            Remove-ItemProperty -Path $regPath -Name "DisableCopilotCloudSync" -ErrorAction SilentlyContinue
                                            Remove-ItemProperty -Path $regPath -Name "AllowCopilotRuntime" -ErrorAction SilentlyContinue
                                        }
                                    }
                                    
                                    # Restore Edge AI features
                                    $edgeRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
                                    if (Test-Path $edgeRegistryPath) {
                                        Remove-ItemProperty -Path $edgeRegistryPath -Name "CopilotCDPEnabled" -ErrorAction SilentlyContinue
                                        Remove-ItemProperty -Path $edgeRegistryPath -Name "CopilotPageEnabled" -ErrorAction SilentlyContinue
                                        Remove-ItemProperty -Path $edgeRegistryPath -Name "HubsSidebarEnabled" -ErrorAction SilentlyContinue
                                        Remove-ItemProperty -Path $edgeRegistryPath -Name "AIAssistanceEnabled" -ErrorAction SilentlyContinue
                                    }
                                    
                                    # Restore Office AI features
                                    $officeRegistryPaths = @(
                                        "HKCU:\Software\Policies\Microsoft\Office\16.0\Common\Privacy",
                                        "HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Common\Privacy",
                                        "HKCU:\Software\Policies\Microsoft\Office\Common\Privacy",
                                        "HKLM:\SOFTWARE\Policies\Microsoft\Office\Common\Privacy"
                                    )
                                    
                                    foreach ($regPath in $officeRegistryPaths) {
                                        if (Test-Path $regPath) {
                                            Remove-ItemProperty -Path $regPath -Name "DisableCopilot" -ErrorAction SilentlyContinue
                                            Remove-ItemProperty -Path $regPath -Name "EnableAIFeatures" -ErrorAction SilentlyContinue
                                        }
                                    }
                                    
                                    $results += "✓ AI services internet access restored"
                                } catch {
                                    $results += "⚠ AI services restoration warning: $($_.Exception.Message)"
                                }
                                
                                # 4. RESTORE VS CODE AI FUNCTIONALITY
                                $results += "=== VS CODE AI RESTORATION ==="
                                try {
                                    # Restore VS Code AI settings
                                    $vscodeSettingsPaths = @(
                                        "$env:USERPROFILE\AppData\Roaming\Code\User\settings.json",
                                        "$env:USERPROFILE\AppData\Roaming\Code - Insiders\User\settings.json"
                                    )
                                    
                                    foreach ($settingsPath in $vscodeSettingsPaths) {
                                        if (Test-Path $settingsPath) {
                                            try {
                                                $settings = Get-Content $settingsPath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
                                                if ($settings) {
                                                    # Re-enable AI features
                                                    $settings | Add-Member -NotePropertyName "github.copilot.enable" -NotePropertyValue $true -Force
                                                    $settings | Add-Member -NotePropertyName "github.copilot.chat.enabled" -NotePropertyValue $true -Force
                                                    $settings | Add-Member -NotePropertyName "github.copilot.inlineSuggest.enable" -NotePropertyValue $true -Force
                                                    $settings | Add-Member -NotePropertyName "codeium.enableCodeLens" -NotePropertyValue $true -Force
                                                    $settings | Add-Member -NotePropertyName "codeium.enableSearch" -NotePropertyValue $true -Force
                                                    $settings | Add-Member -NotePropertyName "bito.enable" -NotePropertyValue $true -Force
                                                    
                                                    # Remove offline mode restrictions
                                                    if ($settings.PSObject.Properties["http.proxy"]) {
                                                        $settings.PSObject.Properties.Remove("http.proxy")
                                                    }
                                                    if ($settings.PSObject.Properties["http.proxySupport"]) {
                                                        $settings.PSObject.Properties.Remove("http.proxySupport")
                                                    }
                                                    
                                                    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -ErrorAction SilentlyContinue
                                                }
                                            } catch {
                                                # Ignore JSON parsing errors
                                            }
                                        }
                                    }
                                    
                                    $results += "✓ VS Code AI functionality restored"
                                } catch {
                                    $results += "⚠ VS Code AI restoration warning: $($_.Exception.Message)"
                                }
                                
                                # 5. RESTORE DNS SETTINGS
                                $results += "=== DNS SETTINGS RESTORATION ==="
                                try {
                                    # Reset DNS to automatic (DHCP)
                                    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Physical -eq $true }
                                    
                                    foreach ($adapter in $adapters) {
                                        # Reset to DHCP DNS
                                        Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue
                                        $results += "DNS reset to automatic for adapter: $($adapter.Name)"
                                    }
                                }
                                catch {
                                    $results += "DNS reset warning: $($_.Exception.Message)"
                                }
                                
                                # 6. DNS CACHE FLUSHING
                                $results += "=== DNS CACHE CLEARING ==="
                                try {
                                    # Flush DNS resolver cache
                                    ipconfig /flushdns | Out-Null
                                    $results += "DNS resolver cache flushed"
                                    
                                    # Clear DNS client cache
                                    Clear-DnsClientCache -ErrorAction SilentlyContinue
                                    $results += "DNS client cache cleared"
                                    
                                    # Restart DNS client service
                                    Restart-Service -Name "Dnscache" -Force -ErrorAction SilentlyContinue
                                    $results += "DNS client service restarted"
                                }
                                catch {
                                    $results += "DNS flush warning: $($_.Exception.Message)"
                                }
                                
                                # 7. VERIFICATION
                                $results += "=== VERIFICATION ==="
                                $testSites = @("google.com", "facebook.com", "youtube.com")
                                foreach ($testSite in $testSites) {
                                    try {
                                        $resolved = Resolve-DnsName -Name $testSite -ErrorAction SilentlyContinue
                                        if ($resolved -and $resolved.IPAddress -notcontains "127.0.0.1") {
                                            $results += "✓ $testSite accessible (unblocked)"
                                        } else {
                                            $results += "⚠ $testSite may still be blocked"
                                        }
                                    }
                                    catch {
                                        $results += "? $testSite resolution status unknown"
                                    }
                                }
                                
                                return @{
                                    Success = $true
                                    Message = "Multi-layer unblocking completed"
                                    EntriesRemoved = $removedEntries
                                    Details = $results
                                }
                            }
                            catch {
                                return @{
                                    Success = $false
                                    Message = "Error: $($_.Exception.Message)"
                                    EntriesRemoved = 0
                                    Details = @("ERROR: $($_.Exception.Message)")
                                }
                            }
                        } -ErrorAction Stop
                        
                        if ($result.Success) {
                            Write-Host "$pc ENHANCED web unblocking completed successfully ($($result.EntriesRemoved) entries removed)." -ForegroundColor Green
                            Write-Host "Unblocking actions performed:" -ForegroundColor Cyan
                            foreach ($detail in $result.Details) {
                                if ($detail.StartsWith("===")) {
                                    Write-Host "  $detail" -ForegroundColor Yellow
                                } elseif ($detail.StartsWith("✓")) {
                                    Write-Host "  $detail" -ForegroundColor Green
                                } elseif ($detail.StartsWith("⚠")) {
                                    Write-Host "  $detail" -ForegroundColor Yellow
                                } else {
                                    Write-Host "    $detail" -ForegroundColor Gray
                                }
                            }
                        } else {
                            Write-Host "$pc web unblocking FAILED: $($result.Message)" -ForegroundColor Red
                            foreach ($detail in $result.Details) {
                                Write-Host "  $detail" -ForegroundColor Red
                            }
                        }
                    }
                    elseif ($action -eq "BlockAI") {
                        Write-Host "Blocking AI sites ONLY on $pc (Domain: csitlab.local)..." -ForegroundColor Yellow
                        $result = Invoke-Command -ComputerName $pc -Credential $cred -ArgumentList (,$aiSitesOnly) -ScriptBlock {
                            param($sites)
                            
                            try {
                                $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
                                $results = @()
                                
                                # Check if hosts file exists and is accessible
                                if (-not (Test-Path $hostsFile)) {
                                    throw "Hosts file not found at $hostsFile"
                                }
                                
                                # HOSTS FILE BLOCKING (AI SITES ONLY)
                                $results += "=== AI SITES BLOCKING ==="
                                
                                # Backup hosts file with timestamp
                                $backupName = "$hostsFile.backup-AI-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                                Copy-Item $hostsFile $backupName -Force -ErrorAction Stop
                                $results += "Backup created: $backupName"
                                
                                # Read content with proper encoding and error handling
                                $content = @()
                                $retryCount = 0
                                $maxRetries = 3
                                
                                while ($retryCount -lt $maxRetries) {
                                    try {
                                        # Force release any file handles
                                        [System.GC]::Collect()
                                        [System.GC]::WaitForPendingFinalizers()
                                        
                                        # Read with specific encoding to avoid stream issues
                                        $content = Get-Content $hostsFile -Encoding UTF8 -ErrorAction Stop
                                        break
                                    }
                                    catch {
                                        $retryCount++
                                        if ($retryCount -eq $maxRetries) {
                                            throw "Failed to read hosts file after $maxRetries attempts: $($_.Exception.Message)"
                                        }
                                        Start-Sleep -Milliseconds 500
                                    }
                                }
                                
                                # Add AI blocking entries
                                $blockMarker = "# BLOCKED BY ADMIN - AI SITES ONLY - csitlab.local domain - $(Get-Date)"
                                
                                # Remove old AI blocks if they exist
                                $newContent = $content | Where-Object { 
                                    $_ -notmatch "BLOCKED BY ADMIN - AI SITES ONLY"
                                }
                                
                                # Prepare AI block entries
                                $blockEntries = @()
                                $blockEntries += $blockMarker
                                $blockEntries += "# Total AI sites blocked: $($sites.Count)"
                                $blockEntries += "# Block applied on: $(Get-Date)"
                                $blockEntries += ""
                                
                                foreach ($site in $sites) {
                                    # Block with localhost
                                    $blockEntries += "127.0.0.1 $site"
                                    # Block with null route
                                    $blockEntries += "0.0.0.0 $site"
                                    # Block common www variants
                                    if (-not $site.StartsWith("www.")) {
                                        $blockEntries += "127.0.0.1 www.$site"
                                        $blockEntries += "0.0.0.0 www.$site"
                                    }
                                }
                                
                                $blockEntries += ""
                                $blockEntries += "# END BLOCKED BY ADMIN - AI SITES ONLY"
                                
                                # Combine content
                                $finalContent = $newContent + $blockEntries
                                
                                # Write with retry logic and proper encoding
                                $writeRetryCount = 0
                                while ($writeRetryCount -lt $maxRetries) {
                                    try {
                                        # Force release any file handles
                                        [System.GC]::Collect()
                                        [System.GC]::WaitForPendingFinalizers()
                                        
                                        # Use Out-File instead of Set-Content for better reliability
                                        $finalContent | Out-File -FilePath $hostsFile -Encoding UTF8 -Force -ErrorAction Stop
                                        break
                                    }
                                    catch {
                                        $writeRetryCount++
                                        if ($writeRetryCount -eq $maxRetries) {
                                            throw "Failed to write hosts file after $maxRetries attempts: $($_.Exception.Message)"
                                        }
                                        Start-Sleep -Milliseconds 500
                                    }
                                }
                                
                                $results += "Hosts file updated with $($sites.Count) AI sites"
                                
                                # DNS CACHE FLUSHING
                                $results += "=== DNS FLUSHING ==="
                                try {
                                    ipconfig /flushdns | Out-Null
                                    $results += "DNS resolver cache flushed"
                                    
                                    Clear-DnsClientCache -ErrorAction SilentlyContinue
                                    $results += "DNS client cache cleared"
                                    
                                    Restart-Service -Name "Dnscache" -Force -ErrorAction SilentlyContinue
                                    $results += "DNS client service restarted"
                                }
                                catch {
                                    $results += "DNS flush warning: $($_.Exception.Message)"
                                }
                                
                                # VERIFICATION
                                $results += "=== VERIFICATION ==="
                                $testSites = @("openai.com", "claude.ai", "gemini.google.com")
                                foreach ($testSite in $testSites) {
                                    try {
                                        $resolved = Resolve-DnsName -Name $testSite -ErrorAction SilentlyContinue
                                        if ($resolved -and $resolved.IPAddress -contains "127.0.0.1") {
                                            $results += "✓ $testSite blocked successfully"
                                        } else {
                                            $results += "⚠ $testSite may not be fully blocked"
                                        }
                                    }
                                    catch {
                                        $results += "✓ $testSite resolution blocked"
                                    }
                                }
                                
                                return @{
                                    Success = $true
                                    Message = "AI sites blocking applied successfully"
                                    SitesBlocked = $sites.Count
                                    Details = $results
                                }
                            }
                            catch {
                                return @{
                                    Success = $false
                                    Message = "Error: $($_.Exception.Message)"
                                    SitesBlocked = 0
                                    Details = @("ERROR: $($_.Exception.Message)")
                                }
                            }
                        } -ErrorAction Stop
                        
                        if ($result.Success) {
                            Write-Host "$pc AI sites blocking applied successfully ($($result.SitesBlocked) sites)." -ForegroundColor Green
                            Write-Host "Blocking actions performed:" -ForegroundColor Cyan
                            foreach ($detail in $result.Details) {
                                if ($detail.StartsWith("===")) {
                                    Write-Host "  $detail" -ForegroundColor Yellow
                                } elseif ($detail.StartsWith("✓")) {
                                    Write-Host "  $detail" -ForegroundColor Green
                                } elseif ($detail.StartsWith("⚠")) {
                                    Write-Host "  $detail" -ForegroundColor Yellow
                                } else {
                                    Write-Host "    $detail" -ForegroundColor Gray
                                }
                            }
                        } else {
                            Write-Host "$pc AI sites blocking FAILED: $($result.Message)" -ForegroundColor Red
                            foreach ($detail in $result.Details) {
                                Write-Host "  $detail" -ForegroundColor Red
                            }
                        }
                    }
                }
            }
            catch {
                Write-Host "$pc is offline or unreachable via WinRM. Error: $_" -ForegroundColor DarkGray
            }
        }
        Pause
    }

} while ($choice -ne '21')
