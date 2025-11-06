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
