# Deployment Verification Script
param(
    [string]$PCName = "PC-1.csitlab.local"
)

Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "  Deployment Verification" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "Checking: $PCName`n" -ForegroundColor Yellow

# Check 1: File Share Access
Write-Host "[1/5] Checking file share access..." -ForegroundColor Yellow
$sharePath = "\\$PCName\C$\ProgramData\PCMonitor"
try {
    if (Test-Path $sharePath) {
        $files = Get-ChildItem $sharePath -ErrorAction Stop
        Write-Host "  ✓ Files found on $PCName" -ForegroundColor Green
        $files | Select-Object Name, @{N="Size (KB)";E={[math]::Round($_.Length/1KB,2)}} | Format-Table -AutoSize
    } else {
        Write-Host "  ✗ Folder does not exist: $sharePath" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Cannot access: $_" -ForegroundColor Red
}

# Check 2: Test Network Connectivity
Write-Host "`n[2/5] Testing network connectivity..." -ForegroundColor Yellow
try {
    $ping = Test-Connection -ComputerName $PCName -Count 1 -Quiet
    if ($ping) {
        Write-Host "  ✓ PC is online (ping successful)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ PC is offline (ping failed)" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Cannot ping: $_" -ForegroundColor Red
}

# Check 3: Test WinRM
Write-Host "`n[3/5] Testing WinRM connection..." -ForegroundColor Yellow
try {
    $wsMan = Test-WSMan -ComputerName $PCName -ErrorAction Stop
    Write-Host "  ✓ WinRM is working" -ForegroundColor Green
} catch {
    Write-Host "  ✗ WinRM not available: $_" -ForegroundColor Red
    Write-Host "  ℹ To enable WinRM on the remote PC:" -ForegroundColor Yellow
    Write-Host "    1. Log into $PCName" -ForegroundColor Gray
    Write-Host "    2. Open PowerShell as Administrator" -ForegroundColor Gray
    Write-Host "    3. Run: Enable-PSRemoting -Force" -ForegroundColor Gray
}

# Check 4: Try to get process list
Write-Host "`n[4/5] Checking if client is running..." -ForegroundColor Yellow
try {
    $process = Invoke-Command -ComputerName $PCName -ScriptBlock {
        Get-Process -Name "PCMonitorClient" -ErrorAction SilentlyContinue
    } -ErrorAction Stop
    
    if ($process) {
        Write-Host "  ✓ PCMonitorClient.exe is RUNNING" -ForegroundColor Green
        $process | Select-Object ProcessName, Id, @{N="Memory (MB)";E={[math]::Round($_.WorkingSet64/1MB,2)}} | Format-Table
    } else {
        Write-Host "  ✗ PCMonitorClient.exe is NOT running" -ForegroundColor Red
        Write-Host "  ℹ Try starting it manually:" -ForegroundColor Yellow
        Write-Host "    C:\ProgramData\PCMonitor\PCMonitorClient.exe" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ✗ Cannot check process: $_" -ForegroundColor Red
}

# Check 5: Check scheduled task
Write-Host "`n[5/5] Checking scheduled task..." -ForegroundColor Yellow
try {
    $task = Invoke-Command -ComputerName $PCName -ScriptBlock {
        Get-ScheduledTask -TaskName "PCMonitorClient" -ErrorAction SilentlyContinue
    } -ErrorAction Stop
    
    if ($task) {
        Write-Host "  ✓ Scheduled task exists" -ForegroundColor Green
        Write-Host "    State: $($task.State)" -ForegroundColor Gray
        
        # Try to start the task
        Write-Host "`n  Attempting to start the client..." -ForegroundColor Yellow
        Invoke-Command -ComputerName $PCName -ScriptBlock {
            Start-ScheduledTask -TaskName "PCMonitorClient"
        } -ErrorAction Stop
        
        Start-Sleep -Seconds 3
        
        # Check if running now
        $process = Invoke-Command -ComputerName $PCName -ScriptBlock {
            Get-Process -Name "PCMonitorClient" -ErrorAction SilentlyContinue
        }
        
        if ($process) {
            Write-Host "  ✓ Client started successfully!" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ Task ran but process not found" -ForegroundColor Yellow
            Write-Host "  ℹ Check Event Viewer on $PCName for errors" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ✗ Scheduled task does not exist" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Cannot check scheduled task: $_" -ForegroundColor Red
}

# Summary
Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "  Verification Complete" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

Write-Host "`nQuick Fixes:" -ForegroundColor Yellow
Write-Host "  1. If WinRM failed: Enable-PSRemoting -Force (on remote PC)" -ForegroundColor White
Write-Host "  2. If files missing: Re-run deployment script" -ForegroundColor White
Write-Host "  3. If process not running: Start scheduled task manually" -ForegroundColor White
Write-Host "  4. Check server is listening on port 8888" -ForegroundColor White
Write-Host ""
