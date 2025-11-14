# Utility Functions
# Functions for time synchronization, cleanup, and MySQL database exports

function Sync-TimeToAllPCs {
    Write-Host "===== TIME/DATE/TIMEZONE SYNCHRONIZATION =====" -ForegroundColor Cyan
    Write-Host "Syncing server time to all domain PCs..." -ForegroundColor Yellow
    Write-Host "Target Domain: $script:targetDomain" -ForegroundColor Cyan
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
                $isDomainMember = Test-DomainMembership -ComputerName $pc
                
                if ($isDomainMember) {
                    $result = Invoke-Command -ComputerName $pc -Credential $script:cred -ArgumentList $serverTime, $serverTimeZone.Id -ScriptBlock {
                        param($targetTime, $targetTimeZone)
                        
                        try {
                            $originalTime = Get-Date
                            $originalTZ = Get-TimeZone
                            
                            Set-TimeZone -Id $targetTimeZone -ErrorAction Stop
                            Set-Date -Date $targetTime -ErrorAction Stop
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
                    Write-Host "  ✗ $pc is not in $script:targetDomain domain - SKIPPING" -ForegroundColor Red
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

function Invoke-BackupCleanup {
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
                $isDomainMember = Test-DomainMembership -ComputerName $pc
                
                if ($isDomainMember) {
                    $result = Invoke-Command -ComputerName $pc -Credential $script:cred -ScriptBlock {
                        try {
                            $hostsPath = "$env:SystemRoot\System32\drivers\etc"
                            $backupFiles = Get-ChildItem -Path $hostsPath -Filter "hosts.backup-*" -ErrorAction SilentlyContinue
                            
                            if ($backupFiles) {
                                $fileCount = $backupFiles.Count
                                $totalSize = ($backupFiles | Measure-Object -Property Length -Sum).Sum
                                $backupFiles | Remove-Item -Force -ErrorAction Stop
                                
                                return @{
                                    Success = $true
                                    Computer = $env:COMPUTERNAME
                                    FilesRemoved = $fileCount
                                    SpaceFreed = $totalSize
                                    Message = "Removed $fileCount backup files ($([math]::Round($totalSize/1KB, 2)) KB freed)"
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
                                Message = $_.Exception.Message
                            }
                        }
                    } -ErrorAction Stop
                    
                    $cleanupResults += $result
                    
                    if ($result.Success) {
                        $successCount++
                        if ($result.FilesRemoved -gt 0) {
                            Write-Host "  ✓ $pc`: $($result.Message)" -ForegroundColor Green
                        } else {
                            Write-Host "  ○ $pc`: $($result.Message)" -ForegroundColor Gray
                        }
                    } else {
                        $failCount++
                        Write-Host "  ✗ $pc`: $($result.Message)" -ForegroundColor Red
                    }
                } else {
                    $failCount++
                    Write-Host "  ✗ $pc is not in $script:targetDomain domain - SKIPPING" -ForegroundColor Red
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

function Export-MySQLDatabases {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Targets,
        [Parameter(Mandatory=$false)]
        [string]$ExportType = "ALL",
        [Parameter(Mandatory=$true)]
        [string]$ScriptPath
    )
    
    Write-Host "===== MYSQL DATABASE EXPORT ($ExportType) =====" -ForegroundColor Cyan
    if ($Targets.Count -eq 1) {
        Write-Host "Exporting MySQL databases from: $($Targets[0])" -ForegroundColor Yellow
    } else {
        Write-Host "Exporting MySQL databases from $($Targets.Count) PCs" -ForegroundColor Yellow
    }
    Write-Host ""
    
    # Prompt for MySQL credentials
    Write-Host "Enter MySQL credentials:" -ForegroundColor Green
    $mysqlUser = Read-Host "MySQL Username (e.g., root)"
    $mysqlPassSecure = Read-Host "MySQL Password" -AsSecureString
    $mysqlPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($mysqlPassSecure))
    
    # Create export folder with timestamp
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $exportFolder = Join-Path $ScriptPath "MySQL-Exports-$timestamp"
    New-Item -ItemType Directory -Path $exportFolder -Force | Out-Null
    Write-Host "Export folder created: $exportFolder" -ForegroundColor Green
    Write-Host ""
    
    $exportResults = @()
    $successCount = 0
    $failCount = 0
    $totalDatabases = 0
    
    foreach ($pc in $Targets) {
        Write-Host "Exporting databases from $pc..." -ForegroundColor Gray
        try {
            if (Test-WSMan -ComputerName $pc -ErrorAction Stop) {
                $isDomainMember = Test-DomainMembership -ComputerName $pc
                
                if ($isDomainMember) {
                    $result = Invoke-Command -ComputerName $pc -Credential $script:cred -ArgumentList $mysqlUser, $mysqlPass -ScriptBlock {
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
                            
                            # Create temporary export folder
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
                        
                        # Copy files from remote PC
                        foreach ($exportedFile in $result.ExportedFiles) {
                            $localPath = Join-Path $pcFolder (Split-Path $exportedFile.FilePath -Leaf)
                            
                            try {
                                $fileContent = Invoke-Command -ComputerName $pc -Credential $script:cred -ArgumentList $exportedFile.FilePath -ScriptBlock {
                                    param($filePath)
                                    if (Test-Path $filePath) {
                                        return Get-Content -Path $filePath -Raw -Encoding UTF8
                                    }
                                    return $null
                                } -ErrorAction Stop
                                
                                if ($fileContent) {
                                    $fileContent | Out-File -FilePath $localPath -Encoding UTF8 -Force
                                    $fileSizeKB = [math]::Round($exportedFile.FileSize / 1KB, 2)
                                    Write-Host "  ✓ $($exportedFile.Database): $fileSizeKB KB" -ForegroundColor Green
                                } else {
                                    Write-Host "  ✗ Failed to copy $($exportedFile.Database): File not found or empty" -ForegroundColor Red
                                }
                            }
                            catch {
                                Write-Host "  ✗ Failed to copy $($exportedFile.Database): $($_.Exception.Message)" -ForegroundColor Red
                            }
                        }
                        
                        # Clean up remote temporary folder
                        try {
                            Invoke-Command -ComputerName $pc -Credential $script:cred -ArgumentList $result.TempFolder -ScriptBlock {
                                param($tempFolder)
                                if (Test-Path $tempFolder) {
                                    Remove-Item -Path $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
                                }
                            } -ErrorAction SilentlyContinue
                        } catch {}
                        
                        $exportResults += $result
                        Write-Host "  ✓ $pc`: Exported $($result.Databases.Count) databases" -ForegroundColor Green
                    } else {
                        $failCount++
                        Write-Host "  ✗ $pc`: FAILED - $($result.Error)" -ForegroundColor Red
                    }
                } else {
                    $failCount++
                    Write-Host "  ✗ $pc is not in $script:targetDomain domain - SKIPPING" -ForegroundColor Red
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
    Write-Host "Total PCs processed: $($Targets.Count)" -ForegroundColor White
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

function Show-AllHostsFiles {
    Write-Host "===== VIEW ALL PC HOSTS FILES =====" -ForegroundColor Cyan
    Write-Host "Retrieving hosts files from all domain PCs..." -ForegroundColor Yellow
    Write-Host "Target Domain: $script:targetDomain" -ForegroundColor Cyan
    Write-Host ""
    
    $targets = foreach ($i in 1..35) { "PC-$i" }
    $hostsResults = @()
    
    foreach ($pc in $targets) {
        Write-Host "Checking $pc..." -ForegroundColor Gray
        try {
            if (Test-WSMan -ComputerName $pc -ErrorAction Stop) {
                $isDomainMember = Test-DomainMembership -ComputerName $pc
                
                if ($isDomainMember) {
                    $hostsContent = Invoke-Command -ComputerName $pc -Credential $script:cred -ScriptBlock {
                        $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
                        
                        if (Test-Path $hostsFile) {
                            $content = Get-Content $hostsFile
                            $totalLines = $content.Count
                            
                            # Count blocked sites (lines starting with 127.0.0.1 or 0.0.0.0, excluding localhost)
                            $blockedEntries = $content | Where-Object { 
                                ($_ -match "^127\.0\.0\.1\s+" -or $_ -match "^0\.0\.0\.0\s+") -and 
                                $_ -notmatch "localhost" 
                            }
                            
                            # Get marker line if exists
                            $markerLine = $content | Where-Object { $_ -match "BLOCKED BY" }
                            
                            [PSCustomObject]@{
                                Computer = $env:COMPUTERNAME
                                Exists = $true
                                TotalLines = $totalLines
                                BlockedEntries = $blockedEntries.Count
                                HasMarker = ($null -ne $markerLine)
                                MarkerText = if ($markerLine) { $markerLine } else { "No marker" }
                                Content = $content
                            }
                        } else {
                            [PSCustomObject]@{
                                Computer = $env:COMPUTERNAME
                                Exists = $false
                                TotalLines = 0
                                BlockedEntries = 0
                                HasMarker = $false
                                MarkerText = "File not found"
                                Content = @()
                            }
                        }
                    } -ErrorAction Stop
                    
                    $hostsResults += $hostsContent
                    
                    if ($hostsContent.Exists) {
                        Write-Host "  ✓ Retrieved: $($hostsContent.TotalLines) lines, $($hostsContent.BlockedEntries) blocked entries" -ForegroundColor Green
                    } else {
                        Write-Host "  ✗ Hosts file not found" -ForegroundColor Red
                    }
                } else {
                    Write-Host "  ⊗ Not in $script:targetDomain domain - SKIPPED" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  ✗ Offline or unreachable" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "     HOSTS FILES SUMMARY                    " -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    
    $retrievedCount = ($hostsResults | Where-Object { $_.Exists }).Count
    Write-Host "Successfully retrieved: $retrievedCount hosts files" -ForegroundColor Green
    Write-Host ""
    
    # Display summary table
    Write-Host "PC Name       | Status    | Lines | Blocked | Marker" -ForegroundColor Yellow
    Write-Host "------------- | --------- | ----- | ------- | ------" -ForegroundColor DarkGray
    
    foreach ($result in $hostsResults) {
        $pcName = $result.Computer.PadRight(13)
        $status = if ($result.Exists) { "Found".PadRight(9) } else { "Missing".PadRight(9) }
        $lines = $result.TotalLines.ToString().PadRight(5)
        $blocked = $result.BlockedEntries.ToString().PadRight(7)
        $marker = if ($result.HasMarker) { "Yes" } else { "No" }
        
        if ($result.Exists) {
            if ($result.BlockedEntries -gt 0) {
                Write-Host "$pcName | $status | $lines | $blocked | $marker" -ForegroundColor Cyan
            } else {
                Write-Host "$pcName | $status | $lines | $blocked | $marker" -ForegroundColor White
            }
        } else {
            Write-Host "$pcName | $status | $lines | $blocked | $marker" -ForegroundColor DarkGray
        }
    }
    
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Ask if user wants to see detailed content
    $viewDetails = Read-Host "Do you want to view detailed hosts file content? (y/n)"
    
    if ($viewDetails -eq 'y' -or $viewDetails -eq 'Y') {
        Write-Host ""
        
        # Ask which PC or all
        Write-Host "Options:" -ForegroundColor Yellow
        Write-Host "  1. View specific PC"
        Write-Host "  2. View all PCs with blocked entries"
        Write-Host "  3. View all PCs (including empty)"
        Write-Host ""
        
        $detailChoice = Read-Host "Select option (1-3)"
        
        switch ($detailChoice) {
            '1' {
                $pcToView = Read-Host "Enter PC name (e.g., PC-1)"
                $pcResult = $hostsResults | Where-Object { $_.Computer -eq $pcToView }
                
                if ($pcResult) {
                    Write-Host ""
                    Write-Host "===== HOSTS FILE: $($pcResult.Computer) =====" -ForegroundColor Cyan
                    Write-Host "Total Lines: $($pcResult.TotalLines)" -ForegroundColor White
                    Write-Host "Blocked Entries: $($pcResult.BlockedEntries)" -ForegroundColor White
                    Write-Host "Marker: $($pcResult.MarkerText)" -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "Content:" -ForegroundColor Green
                    Write-Host "-------------------------------------------" -ForegroundColor DarkGray
                    
                    if ($pcResult.Content -and $pcResult.Content.Count -gt 0) {
                        foreach ($line in $pcResult.Content) {
                            if ($line -match "^#") {
                                Write-Host $line -ForegroundColor DarkGreen
                            } elseif ($line -match "^127\.0\.0\.1\s+" -or $line -match "^0\.0\.0\.0\s+") {
                                if ($line -match "localhost") {
                                    Write-Host $line -ForegroundColor Gray
                                } else {
                                    Write-Host $line -ForegroundColor Yellow
                                }
                            } elseif ([string]::IsNullOrWhiteSpace($line)) {
                                Write-Host ""
                            } else {
                                Write-Host $line -ForegroundColor White
                            }
                        }
                    } else {
                        Write-Host "(Empty file or no content)" -ForegroundColor DarkGray
                    }
                    Write-Host "-------------------------------------------" -ForegroundColor DarkGray
                } else {
                    Write-Host "PC not found in results" -ForegroundColor Red
                }
            }
            '2' {
                $pcsWithBlocks = $hostsResults | Where-Object { $_.BlockedEntries -gt 0 }
                
                if ($pcsWithBlocks.Count -eq 0) {
                    Write-Host ""
                    Write-Host "No PCs found with blocked entries." -ForegroundColor Yellow
                    Write-Host ""
                } else {
                    foreach ($pcResult in $pcsWithBlocks) {
                        Write-Host ""
                        Write-Host "===== HOSTS FILE: $($pcResult.Computer) =====" -ForegroundColor Cyan
                        Write-Host "Total Lines: $($pcResult.TotalLines)" -ForegroundColor White
                        Write-Host "Blocked Entries: $($pcResult.BlockedEntries)" -ForegroundColor Yellow
                        Write-Host "Marker: $($pcResult.MarkerText)" -ForegroundColor Green
                        Write-Host ""
                        
                        # Show only blocked entries
                        Write-Host "Blocked Entries Only:" -ForegroundColor Yellow
                        Write-Host "-------------------------------------------" -ForegroundColor DarkGray
                        
                        if ($pcResult.Content -and $pcResult.Content.Count -gt 0) {
                            $blockedLines = $pcResult.Content | Where-Object { 
                                ($_ -match "^127\.0\.0\.1\s+" -or $_ -match "^0\.0\.0\.0\s+") -and 
                                $_ -notmatch "localhost" 
                            }
                            
                            if ($blockedLines) {
                                foreach ($line in $blockedLines) {
                                    Write-Host $line -ForegroundColor Yellow
                                }
                            } else {
                                Write-Host "(No blocked entries found)" -ForegroundColor DarkGray
                            }
                        } else {
                            Write-Host "(No content available)" -ForegroundColor DarkGray
                        }
                        Write-Host "-------------------------------------------" -ForegroundColor DarkGray
                    }
                }
            }
            '3' {
                foreach ($pcResult in $hostsResults) {
                    # Skip if no content exists
                    if (-not $pcResult.Exists) {
                        Write-Host ""
                        Write-Host "===== HOSTS FILE: $($pcResult.Computer) =====" -ForegroundColor Red
                        Write-Host "Status: File not found or PC offline" -ForegroundColor Red
                        Write-Host "-------------------------------------------" -ForegroundColor DarkGray
                        continue
                    }
                    
                    Write-Host ""
                    Write-Host "===== HOSTS FILE: $($pcResult.Computer) =====" -ForegroundColor Cyan
                    Write-Host "Total Lines: $($pcResult.TotalLines)" -ForegroundColor White
                    Write-Host "Blocked Entries: $($pcResult.BlockedEntries)" -ForegroundColor White
                    Write-Host "Marker: $($pcResult.MarkerText)" -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "Content:" -ForegroundColor Green
                    Write-Host "-------------------------------------------" -ForegroundColor DarkGray
                    
                    if ($pcResult.Content -and $pcResult.Content.Count -gt 0) {
                        foreach ($line in $pcResult.Content) {
                            if ($line -match "^#") {
                                Write-Host $line -ForegroundColor DarkGreen
                            } elseif ($line -match "^127\.0\.0\.1\s+" -or $line -match "^0\.0\.0\.0\s+") {
                                if ($line -match "localhost") {
                                    Write-Host $line -ForegroundColor Gray
                                } else {
                                    Write-Host $line -ForegroundColor Yellow
                                }
                            } elseif ([string]::IsNullOrWhiteSpace($line)) {
                                Write-Host ""
                            } else {
                                Write-Host $line -ForegroundColor White
                            }
                        }
                    } else {
                        Write-Host "(Empty file)" -ForegroundColor DarkGray
                    }
                    Write-Host "-------------------------------------------" -ForegroundColor DarkGray
                }
            }
        }
    }
    
    Write-Host ""
    Pause
}

function Test-AndroidJavaEnvironment {
    Write-Host "===== ANDROID & JAVA ENVIRONMENT CHECK =====" -ForegroundColor Cyan
    Write-Host "Checking ANDROID_HOME and JAVA_HOME on all domain PCs..." -ForegroundColor Yellow
    Write-Host "Target Domain: $script:targetDomain" -ForegroundColor Cyan
    Write-Host ""
    
    $targets = foreach ($i in 1..35) { "PC-$i" }
    $results = @()
    
    foreach ($pc in $targets) {
        Write-Host "Checking $pc..." -ForegroundColor Gray
        try {
            if (Test-WSMan -ComputerName $pc -ErrorAction Stop) {
                $isDomainMember = Test-DomainMembership -ComputerName $pc
                
                if ($isDomainMember) {
                    $result = Invoke-Command -ComputerName $pc -Credential $script:cred -ScriptBlock {
                        $report = @{
                            Computer = $env:COMPUTERNAME
                            AndroidHomeExists = $false
                            AndroidHomeValue = ""
                            AndroidHomeValid = $false
                            AndroidPathExists = $false
                            JavaHomeExists = $false
                            JavaHomeValue = ""
                            JavaHomeValid = $false
                            Fixed = $false
                            Errors = @()
                        }
                        
                        # Check ANDROID_HOME
                        $androidHome = [System.Environment]::GetEnvironmentVariable("ANDROID_HOME", "Machine")
                        if ($androidHome) {
                            $report.AndroidHomeExists = $true
                            $report.AndroidHomeValue = $androidHome
                            
                            # Check if it's the expected unexpanded path
                            $expectedPath = "%LOCALAPPDATA%\Android\Sdk"
                            if ($androidHome -eq $expectedPath) {
                                $report.AndroidHomeValid = $true
                            } else {
                                # Expand environment variables and check if path exists
                                $expandedPath = [System.Environment]::ExpandEnvironmentVariables($androidHome)
                                
                                # Get current domain username
                                $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
                                $username = $currentUser.Split('\')[-1]
                                
                                # Check if expanded path uses correct username
                                $correctExpandedPath = "C:\Users\$username\AppData\Local\Android\Sdk"
                                
                                if (Test-Path $expandedPath) {
                                    # Valid if path exists AND uses correct username
                                    if ($expandedPath -eq $correctExpandedPath -or $androidHome -eq $expectedPath) {
                                        $report.AndroidHomeValid = $true
                                    } else {
                                        # Path exists but uses wrong username (e.g., PC-6 instead of pc6)
                                        $report.AndroidHomeValid = $false
                                    }
                                }
                            }
                        }
                        
                        # Check if platform-tools in Path
                        $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
                        $platformTools = "%LOCALAPPDATA%\Android\Sdk\platform-tools"
                        
                        # Get current domain username for validation
                        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
                        $username = $currentUser.Split('\')[-1]
                        $correctPlatformPath = "C:\Users\$username\AppData\Local\Android\Sdk\platform-tools"
                        
                        # Check if platform-tools exists in Path
                        if ($machinePath -like "*$platformTools*") {
                            # Using unexpanded format - VALID
                            $report.AndroidPathExists = $true
                        } else {
                            # Check if using expanded path
                            if ($machinePath -like "*$correctPlatformPath*") {
                                # Uses expanded path with correct username - should convert to unexpanded
                                $report.AndroidPathExists = $false
                            } elseif ($machinePath -match "C:\\Users\\[^\\]+\\AppData\\Local\\Android\\Sdk\\platform-tools") {
                                # Uses expanded path with wrong username
                                $report.AndroidPathExists = $false
                            } else {
                                # Not in path at all
                                $report.AndroidPathExists = $false
                            }
                        }
                        
                        # Check JAVA_HOME
                        $javaHome = [System.Environment]::GetEnvironmentVariable("JAVA_HOME", "Machine")
                        if ($javaHome) {
                            $report.JavaHomeExists = $true
                            $report.JavaHomeValue = $javaHome
                            
                            # Expand and check if valid
                            $expandedJavaPath = [System.Environment]::ExpandEnvironmentVariables($javaHome)
                            if (Test-Path $expandedJavaPath) {
                                # Check if bin folder exists with java.exe
                                $javaBin = Join-Path $expandedJavaPath "bin\java.exe"
                                if (Test-Path $javaBin) {
                                    $report.JavaHomeValid = $true
                                }
                            }
                        }
                        
                        return $report
                    }
                    
                    $results += $result
                    
                    # Display status
                    Write-Host "  $($result.Computer):" -ForegroundColor White
                    
                    # ANDROID_HOME status
                    if ($result.AndroidHomeValid) {
                        Write-Host "    ANDROID_HOME: " -NoNewline
                        Write-Host "VALID" -ForegroundColor Green
                        # Convert expanded path to unexpanded format for display
                        $displayPath = $result.AndroidHomeValue
                        if ($displayPath -match "C:\\Users\\[^\\]+\\AppData\\Local\\Android\\Sdk") {
                            $displayPath = "%LOCALAPPDATA%\Android\Sdk"
                        }
                        Write-Host "      Path: $displayPath" -ForegroundColor Gray
                    } elseif ($result.AndroidHomeExists) {
                        Write-Host "    ANDROID_HOME: " -NoNewline
                        Write-Host "INVALID PATH" -ForegroundColor Red
                        $displayPath = $result.AndroidHomeValue
                        if ($displayPath -match "C:\\Users\\[^\\]+\\AppData\\Local\\Android\\Sdk") {
                            $displayPath = "%LOCALAPPDATA%\Android\Sdk"
                        }
                        Write-Host "      Path: $displayPath" -ForegroundColor Gray
                    } else {
                        Write-Host "    ANDROID_HOME: " -NoNewline
                        Write-Host "NOT SET" -ForegroundColor Yellow
                    }
                    
                    # Platform-tools in Path
                    if ($result.AndroidPathExists) {
                        Write-Host "    Platform-tools: " -NoNewline
                        Write-Host "IN PATH" -ForegroundColor Green
                    } else {
                        Write-Host "    Platform-tools: " -NoNewline
                        Write-Host "NOT IN PATH" -ForegroundColor Yellow
                    }
                    
                    # JAVA_HOME status
                    if ($result.JavaHomeValid) {
                        Write-Host "    JAVA_HOME: " -NoNewline
                        Write-Host "VALID" -ForegroundColor Green
                        Write-Host "      Path: $($result.JavaHomeValue)" -ForegroundColor Gray
                    } elseif ($result.JavaHomeExists) {
                        Write-Host "    JAVA_HOME: " -NoNewline
                        Write-Host "INVALID PATH" -ForegroundColor Red
                        Write-Host "      Path: $($result.JavaHomeValue)" -ForegroundColor Gray
                    } else {
                        Write-Host "    JAVA_HOME: " -NoNewline
                        Write-Host "NOT SET" -ForegroundColor Yellow
                    }
                    
                } else {
                    Write-Host "  $pc`: NOT in $script:targetDomain domain - SKIPPING" -ForegroundColor Red
                }
            }
        }
        catch {
            Write-Host "  $pc`: OFFLINE or unreachable" -ForegroundColor DarkGray
        }
    }
    
    # Summary
    Write-Host ""
    Write-Host "===== SUMMARY =====" -ForegroundColor Cyan
    $needsAndroidFix = $results | Where-Object { -not $_.AndroidHomeValid -or -not $_.AndroidPathExists }
    $needsJavaFix = $results | Where-Object { -not $_.JavaHomeValid }
    
    Write-Host "Total PCs checked: $($results.Count)" -ForegroundColor White
    Write-Host "ANDROID_HOME issues: $($needsAndroidFix.Count)" -ForegroundColor $(if ($needsAndroidFix.Count -gt 0) { "Yellow" } else { "Green" })
    Write-Host "JAVA_HOME issues: $($needsJavaFix.Count)" -ForegroundColor $(if ($needsJavaFix.Count -gt 0) { "Yellow" } else { "Green" })
    
    if ($needsAndroidFix.Count -gt 0 -or $needsJavaFix.Count -gt 0) {
        Write-Host ""
        Write-Host "Do you want to fix the issues? (Y/N)" -ForegroundColor Yellow
        $fix = Read-Host
        
        if ($fix -eq 'Y' -or $fix -eq 'y') {
            Write-Host ""
            Write-Host "Fixing environment variables..." -ForegroundColor Cyan
            
            foreach ($result in $results) {
                $needsFix = (-not $result.AndroidHomeValid) -or (-not $result.AndroidPathExists) -or (-not $result.JavaHomeValid)
                
                if ($needsFix) {
                    Write-Host "Fixing $($result.Computer)..." -ForegroundColor Yellow
                    
                    try {
                        Invoke-Command -ComputerName $result.Computer -Credential $script:cred -ScriptBlock {
                            param($fixAndroid, $fixAndroidPath, $fixJava)
                            
                            $fixed = $false
                            
                            # Check if current ANDROID_HOME is using expanded path with wrong username
                            $currentAndroidHome = [System.Environment]::GetEnvironmentVariable("ANDROID_HOME", "Machine")
                            $needsAndroidFix = $fixAndroid
                            
                            # If ANDROID_HOME has expanded path with computer name instead of domain username
                            if ($currentAndroidHome -match "C:\\Users\\[^\\]+\\AppData\\Local\\Android\\Sdk") {
                                $needsAndroidFix = $true
                            }
                            
                            # Fix ANDROID_HOME (always use unexpanded format)
                            if ($needsAndroidFix) {
                                $androidSdkPath = "%LOCALAPPDATA%\Android\Sdk"
                                [System.Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidSdkPath, "Machine")
                                Write-Host "  Set ANDROID_HOME to: $androidSdkPath"
                                $fixed = $true
                            }
                            
                            # Check if Path contains expanded Android path with wrong username
                            $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
                            $needsPathFix = $fixAndroidPath
                            
                            if ($currentPath -match "C:\\Users\\[^\\]+\\AppData\\Local\\Android\\Sdk\\platform-tools") {
                                $needsPathFix = $true
                            }
                            
                            # Fix platform-tools in Path (always use unexpanded format)
                            if ($needsPathFix) {
                                $platformToolsPath = "%LOCALAPPDATA%\Android\Sdk\platform-tools"
                                
                                # Remove all Android paths (both expanded and unexpanded formats)
                                $pathArray = $currentPath -split ";" | Where-Object { 
                                    $_ -notlike "*Android\Sdk\platform-tools*" -and 
                                    $_ -ne $platformToolsPath -and
                                    $_ -notmatch "C:\\Users\\[^\\]+\\AppData\\Local\\Android\\Sdk\\platform-tools"
                                }
                                
                                # Add new path with unexpanded format
                                $newPath = ($pathArray + $platformToolsPath) -join ";"
                                [System.Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
                                Write-Host "  Set platform-tools Path to: $platformToolsPath"
                                $fixed = $true
                            }
                            
                            # Note about JAVA_HOME - we can't auto-fix without knowing Java location
                            if ($fixJava) {
                                Write-Host "  JAVA_HOME needs manual verification - checking common locations..."
                                
                                # Check common Java locations
                                $commonJavaPaths = @(
                                    "C:\Program Files\Java\jdk-*",
                                    "C:\Program Files\Java\jre-*",
                                    "C:\Program Files (x86)\Java\jdk-*",
                                    "C:\Program Files (x86)\Java\jre-*",
                                    "C:\Program Files\Microsoft\jdk-*",
                                    "C:\Program Files\Eclipse Adoptium\jdk-*"
                                )
                                
                                $foundJava = $null
                                foreach ($pattern in $commonJavaPaths) {
                                    $javaDir = Get-ChildItem -Path ($pattern -replace "\\jdk-\*", "") -Filter "jdk-*" -Directory -ErrorAction SilentlyContinue | 
                                        Sort-Object Name -Descending | 
                                        Select-Object -First 1
                                    
                                    if ($javaDir -and (Test-Path (Join-Path $javaDir.FullName "bin\java.exe"))) {
                                        $foundJava = $javaDir.FullName
                                        break
                                    }
                                }
                                
                                if ($foundJava) {
                                    [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $foundJava, "Machine")
                                    Write-Host "  Set JAVA_HOME to: $foundJava"
                                    $fixed = $true
                                } else {
                                    Write-Host "  WARNING: Could not find Java installation automatically" -ForegroundColor Red
                                }
                            }
                            
                            return $fixed
                            
                        } -ArgumentList (-not $result.AndroidHomeValid), (-not $result.AndroidPathExists), (-not $result.JavaHomeValid)
                        
                        Write-Host "  $($result.Computer) - FIXED" -ForegroundColor Green
                        
                    } catch {
                        Write-Host "  $($result.Computer) - FAILED: $_" -ForegroundColor Red
                    }
                }
            }
            
            Write-Host ""
            Write-Host "Environment variables updated!" -ForegroundColor Green
            Write-Host "NOTE: PCs may need to restart for changes to take effect." -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Pause
}
