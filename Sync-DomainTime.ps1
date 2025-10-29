# Time Synchronization Script for Domain PCs
# Syncs server time/date/timezone to all PCs (PC-1 to PC-35)

param(
    [PSCredential]$Credential,
    [string[]]$TargetPCs = @(),
    [switch]$TestMode
)

Write-Host "===== DOMAIN TIME SYNCHRONIZATION UTILITY =====" -ForegroundColor Cyan
Write-Host "Target Domain: csitlab.local" -ForegroundColor Green
Write-Host ""

# Get credentials if not provided
if (-not $Credential) {
    $Credential = Get-Credential -Message "Enter admin credentials for domain PCs"
}

# Set target PCs
if ($TargetPCs.Count -eq 0) {
    $TargetPCs = foreach ($i in 1..35) { "PC-$i" }
}

# Domain membership check function
function Test-DomainMembership {
    param([string]$ComputerName, [PSCredential]$Cred)
    
    try {
        $result = Invoke-Command -ComputerName $ComputerName -Credential $Cred -ScriptBlock {
            $domain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
            return $domain
        } -ErrorAction Stop
        
        return $result -eq "csitlab.local"
    }
    catch {
        return $false
    }
}

# Get server's current time and timezone info
$serverTime = Get-Date
$serverTimeZone = Get-TimeZone

Write-Host "SERVER TIME INFORMATION:" -ForegroundColor Yellow
Write-Host "  Current Date/Time: $($serverTime.ToString('dddd, MMMM dd, yyyy HH:mm:ss'))" -ForegroundColor White
Write-Host "  Timezone ID: $($serverTimeZone.Id)" -ForegroundColor White
Write-Host "  Display Name: $($serverTimeZone.DisplayName)" -ForegroundColor White
Write-Host "  UTC Offset: $($serverTimeZone.BaseUtcOffset)" -ForegroundColor White
Write-Host ""

if ($TestMode) {
    Write-Host "TEST MODE: Will show what would be changed without making actual changes" -ForegroundColor Yellow
    Write-Host ""
}

# Initialize counters
$syncResults = @()
$successCount = 0
$failCount = 0
$skippedCount = 0

Write-Host "Starting time synchronization process..." -ForegroundColor Cyan
Write-Host ""

foreach ($pc in $TargetPCs) {
    Write-Host "Processing $pc..." -ForegroundColor Gray
    
    try {
        # Test WinRM connectivity
        if (Test-WSMan -ComputerName $pc -ErrorAction Stop) {
            # Check domain membership
            $isDomainMember = Test-DomainMembership -ComputerName $pc -Cred $Credential
            
            if ($isDomainMember) {
                # Perform time sync
                $result = Invoke-Command -ComputerName $pc -Credential $Credential -ArgumentList $serverTime, $serverTimeZone.Id, $TestMode -ScriptBlock {
                    param($targetTime, $targetTimeZone, $isTestMode)
                    
                    try {
                        $originalTime = Get-Date
                        $originalTZ = Get-TimeZone
                        
                        # Calculate time difference
                        $timeDiff = ($targetTime - $originalTime).TotalMinutes
                        $timeZoneChanged = $originalTZ.Id -ne $targetTimeZone
                        
                        if ($isTestMode) {
                            return @{
                                Success = $true
                                Computer = $env:COMPUTERNAME
                                OriginalTime = $originalTime.ToString('yyyy-MM-dd HH:mm:ss')
                                OriginalTimeZone = $originalTZ.Id
                                TargetTime = $targetTime.ToString('yyyy-MM-dd HH:mm:ss')
                                TargetTimeZone = $targetTimeZone
                                TimeDifference = [math]::Round($timeDiff, 2)
                                TimeZoneWillChange = $timeZoneChanged
                                TestMode = $true
                            }
                        }
                        
                        # Actually make the changes
                        $changes = @()
                        
                        # Set timezone if different
                        if ($timeZoneChanged) {
                            Set-TimeZone -Id $targetTimeZone -ErrorAction Stop
                            $changes += "Timezone changed from '$($originalTZ.Id)' to '$targetTimeZone'"
                        }
                        
                        # Set date/time if difference > 30 seconds
                        if ([math]::Abs($timeDiff) -gt 0.5) {
                            Set-Date -Date $targetTime -ErrorAction Stop
                            $changes += "Time adjusted by $([math]::Round($timeDiff, 2)) minutes"
                        }
                        
                        # Force domain time sync
                        try {
                            w32tm /resync /force | Out-Null
                            $changes += "Domain time sync forced"
                        }
                        catch {
                            $changes += "Domain time sync failed (non-critical)"
                        }
                        
                        $newTime = Get-Date
                        $newTZ = Get-TimeZone
                        
                        return @{
                            Success = $true
                            Computer = $env:COMPUTERNAME
                            OriginalTime = $originalTime.ToString('yyyy-MM-dd HH:mm:ss')
                            OriginalTimeZone = $originalTZ.Id
                            NewTime = $newTime.ToString('yyyy-MM-dd HH:mm:ss')
                            NewTimeZone = $newTZ.Id
                            TimeDifference = [math]::Round($timeDiff, 2)
                            Changes = $changes
                            TestMode = $false
                        }
                    }
                    catch {
                        return @{
                            Success = $false
                            Computer = $env:COMPUTERNAME
                            Error = $_.Exception.Message
                            TestMode = $isTestMode
                        }
                    }
                } -ErrorAction Stop
                
                $syncResults += $result
                
                if ($result.Success) {
                    $successCount++
                    if ($TestMode) {
                        Write-Host "  ✓ $pc (TEST): Would sync successfully" -ForegroundColor Green
                        Write-Host "    Current: $($result.OriginalTime) ($($result.OriginalTimeZone))" -ForegroundColor Gray
                        Write-Host "    Target:  $($result.TargetTime) ($($result.TargetTimeZone))" -ForegroundColor Gray
                        if ([math]::Abs($result.TimeDifference) -gt 0.5) {
                            Write-Host "    Time difference: $($result.TimeDifference) minutes" -ForegroundColor Yellow
                        }
                        if ($result.TimeZoneWillChange) {
                            Write-Host "    Timezone will change: $($result.OriginalTimeZone) → $($result.TargetTimeZone)" -ForegroundColor Yellow
                        }
                    } else {
                        Write-Host "  ✓ $pc synced successfully" -ForegroundColor Green
                        Write-Host "    Before: $($result.OriginalTime) ($($result.OriginalTimeZone))" -ForegroundColor Gray
                        Write-Host "    After:  $($result.NewTime) ($($result.NewTimeZone))" -ForegroundColor Gray
                        if ($result.Changes.Count -gt 0) {
                            foreach ($change in $result.Changes) {
                                Write-Host "    • $change" -ForegroundColor Cyan
                            }
                        }
                    }
                } else {
                    $failCount++
                    Write-Host "  ✗ $pc time sync FAILED: $($result.Error)" -ForegroundColor Red
                }
            } else {
                $skippedCount++
                Write-Host "  ⚠ $pc is not in csitlab.local domain - SKIPPED" -ForegroundColor Yellow
            }
        }
    }
    catch {
        $failCount++
        Write-Host "  ✗ $pc is OFFLINE or unreachable: $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

# Summary Report
Write-Host ""
Write-Host "===== TIME SYNCHRONIZATION SUMMARY =====" -ForegroundColor Cyan
Write-Host "Total PCs processed: $($TargetPCs.Count)" -ForegroundColor White
Write-Host "Successful syncs: $successCount" -ForegroundColor Green
Write-Host "Failed syncs: $failCount" -ForegroundColor Red
Write-Host "Skipped (non-domain): $skippedCount" -ForegroundColor Yellow
Write-Host ""

if ($TestMode) {
    Write-Host "TEST MODE RESULTS:" -ForegroundColor Yellow
    Write-Host "No actual changes were made. Run without -TestMode to apply changes." -ForegroundColor Gray
    Write-Host ""
}

# Detailed results
if ($successCount -gt 0) {
    Write-Host "DETAILED RESULTS:" -ForegroundColor Cyan
    $successfulPCs = $syncResults | Where-Object { $_.Success -eq $true }
    
    foreach ($pc in $successfulPCs) {
        if ($TestMode) {
            $timeDiff = if ([math]::Abs($pc.TimeDifference) -gt 0.5) { " (${$pc.TimeDifference}min diff)" } else { " (in sync)" }
            $tzChange = if ($pc.TimeZoneWillChange) { " [TZ change needed]" } else { "" }
            Write-Host "  $($pc.Computer): $($pc.OriginalTime)$timeDiff$tzChange" -ForegroundColor White
        } else {
            $changes = if ($pc.Changes.Count -gt 0) { " - " + ($pc.Changes -join ", ") } else { " - No changes needed" }
            Write-Host "  $($pc.Computer): $($pc.NewTime)$changes" -ForegroundColor White
        }
    }
    Write-Host ""
}

if ($failCount -gt 0) {
    Write-Host "FAILED SYNCS:" -ForegroundColor Red
    $failedPCs = $syncResults | Where-Object { $_.Success -eq $false }
    foreach ($pc in $failedPCs) {
        Write-Host "  $($pc.Computer): $($pc.Error)" -ForegroundColor Gray
    }
    Write-Host ""
}

# Recommendations
Write-Host "RECOMMENDATIONS:" -ForegroundColor Yellow
Write-Host "• Run this script during maintenance windows" -ForegroundColor White
Write-Host "• Use -TestMode first to preview changes" -ForegroundColor White
Write-Host "• Consider setting up NTP time sync in Group Policy" -ForegroundColor White
Write-Host "• Monitor time drift regularly" -ForegroundColor White
Write-Host ""

if (-not $TestMode -and $successCount -gt 0) {
    Write-Host "Time synchronization completed successfully!" -ForegroundColor Green
} elseif ($TestMode) {
    Write-Host "Test completed. Use without -TestMode to apply changes." -ForegroundColor Cyan
} else {
    Write-Host "No PCs were synchronized." -ForegroundColor Red
}