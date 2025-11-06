# PC Management Functions
# Functions for managing PC status, shutdown, and restart operations

function Get-AllPCStatus {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Targets
    )
    
    foreach ($pc in $Targets) {
        try {
            if (Test-WSMan -ComputerName $pc -ErrorAction Stop) {
                $result = Invoke-Command -ComputerName $pc -Credential $script:cred -ScriptBlock {
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

function Invoke-PCShutdown {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Targets
    )
    
    foreach ($pc in $Targets) {
        Write-Host "Checking $pc ..." -ForegroundColor Cyan
        try {
            if (Test-WSMan -ComputerName $pc -ErrorAction Stop) {
                Write-Host "Shutting down $pc via WinRM ..." -ForegroundColor Yellow
                Invoke-Command -ComputerName $pc -Credential $script:cred -ScriptBlock {
                    Stop-Computer -Force
                }
                Write-Host "$pc shutdown command sent." -ForegroundColor Green
            }
        }
        catch {
            Write-Host "$pc is offline or unreachable via WinRM. Error: $_" -ForegroundColor DarkGray
        }
    }
    Pause
}

function Invoke-PCRestart {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Targets
    )
    
    foreach ($pc in $Targets) {
        Write-Host "Checking $pc ..." -ForegroundColor Cyan
        try {
            if (Test-WSMan -ComputerName $pc -ErrorAction Stop) {
                Write-Host "Restarting $pc via WinRM ..." -ForegroundColor Yellow
                Invoke-Command -ComputerName $pc -Credential $script:cred -ScriptBlock {
                    Restart-Computer -Force
                }
                Write-Host "$pc restart command sent." -ForegroundColor Green
            }
        }
        catch {
            Write-Host "$pc is offline or unreachable via WinRM. Error: $_" -ForegroundColor DarkGray
        }
    }
    Pause
}

function Invoke-DeepScan {
    Write-Host "Starting Deep Scan of all PCs..." -ForegroundColor Cyan
    Write-Host "Checking blocking status and domain membership..." -ForegroundColor Yellow
    Write-Host "Target Domain: $script:targetDomain" -ForegroundColor Cyan
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
                    Write-Host "  $pc`: ONLINE, NOT in $script:targetDomain domain - SKIPPING" -ForegroundColor Red
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
    $onlineDomainPCs = $scanResults | Where-Object { $_.Domain -eq $script:targetDomain }
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
