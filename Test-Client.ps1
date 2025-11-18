# Manual Client Tester - Run this ON the target PC to diagnose issues
param(
    [string]$ServerIP = "192.168.2.45",
    [int]$ServerPort = 8888
)

Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "  PC Monitor Client - Manual Test" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

$clientPath = "C:\ProgramData\PCMonitor\PCMonitorClient.exe"

# Check 1: Files exist
Write-Host "[1/6] Checking client files..." -ForegroundColor Yellow
if (Test-Path $clientPath) {
    Write-Host "  ✓ PCMonitorClient.exe found" -ForegroundColor Green
    $size = [math]::Round((Get-Item $clientPath).Length / 1KB, 2)
    Write-Host "    Size: $size KB" -ForegroundColor Gray
} else {
    Write-Host "  ✗ Client not found at: $clientPath" -ForegroundColor Red
    exit 1
}

# Check 2: Dependencies
Write-Host "`n[2/6] Checking dependencies..." -ForegroundColor Yellow
$dllPath = "C:\ProgramData\PCMonitor\Newtonsoft.Json.dll"
if (Test-Path $dllPath) {
    Write-Host "  ✓ Newtonsoft.Json.dll found" -ForegroundColor Green
} else {
    Write-Host "  ✗ Missing dependency: Newtonsoft.Json.dll" -ForegroundColor Red
}

# Check 3: .NET Framework
Write-Host "`n[3/6] Checking .NET Framework..." -ForegroundColor Yellow
try {
    $netVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction Stop).Version
    Write-Host "  ✓ .NET Framework $netVersion installed" -ForegroundColor Green
    
    if ($netVersion -lt "4.8") {
        Write-Host "  ⚠ Warning: .NET 4.8.1 recommended, found $netVersion" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠ Could not detect .NET version" -ForegroundColor Yellow
}

# Check 4: Network connectivity to server
Write-Host "`n[4/6] Testing connection to server..." -ForegroundColor Yellow
try {
    $connection = Test-NetConnection -ComputerName $ServerIP -Port $ServerPort -WarningAction SilentlyContinue
    if ($connection.TcpTestSucceeded) {
        Write-Host "  ✓ Server is reachable at ${ServerIP}:${ServerPort}" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Cannot connect to ${ServerIP}:${ServerPort}" -ForegroundColor Red
        Write-Host "    Make sure the monitoring server is running!" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠ Could not test connection: $_" -ForegroundColor Yellow
}

# Check 5: Stop existing process if running
Write-Host "`n[5/6] Checking for running instances..." -ForegroundColor Yellow
$existing = Get-Process -Name "PCMonitorClient" -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "  ⚠ Client already running (PID: $($existing.Id))" -ForegroundColor Yellow
    Write-Host "    Stopping existing process..." -ForegroundColor Gray
    Stop-Process -Name "PCMonitorClient" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# Check 6: Try to run the client
Write-Host "`n[6/6] Starting client..." -ForegroundColor Yellow
Write-Host "  Command: $clientPath $ServerIP $ServerPort" -ForegroundColor Gray

try {
    # Start the process and capture any immediate errors
    $process = Start-Process -FilePath $clientPath `
                            -ArgumentList "$ServerIP $ServerPort" `
                            -WindowStyle Hidden `
                            -PassThru `
                            -ErrorAction Stop
    
    Write-Host "  ✓ Process started (PID: $($process.Id))" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Waiting 5 seconds to check if it's still running..." -ForegroundColor Gray
    Start-Sleep -Seconds 5
    
    # Check if still running
    $stillRunning = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
    
    if ($stillRunning) {
        Write-Host "  ✓ Client is RUNNING successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Process Info:" -ForegroundColor Cyan
        $stillRunning | Select-Object ProcessName, Id, @{N="Memory (MB)";E={[math]::Round($_.WorkingSet64/1MB,2)}} | Format-Table -AutoSize
        
        Write-Host "  Check the monitoring dashboard - this PC should appear within 10 seconds!" -ForegroundColor Yellow
    } else {
        Write-Host "  ✗ Client CRASHED after starting!" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Checking Event Viewer for errors..." -ForegroundColor Yellow
        
        # Check application event log for recent errors
        $errors = Get-WinEvent -LogName Application -MaxEvents 10 -ErrorAction SilentlyContinue | 
                  Where-Object { $_.TimeCreated -gt (Get-Date).AddMinutes(-2) -and $_.LevelDisplayName -eq "Error" }
        
        if ($errors) {
            Write-Host "  Recent errors found:" -ForegroundColor Red
            $errors | Select-Object TimeCreated, ProviderName, Message | Format-List
        } else {
            Write-Host "  No recent errors in Event Viewer" -ForegroundColor Gray
        }
        
        Write-Host "`n  Possible causes:" -ForegroundColor Yellow
        Write-Host "    1. Missing .NET Framework 4.8.1" -ForegroundColor Gray
        Write-Host "    2. Server is not running or not reachable" -ForegroundColor Gray
        Write-Host "    3. Corrupted files - try redeploying" -ForegroundColor Gray
        Write-Host "    4. Antivirus blocking the client" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ✗ Failed to start: $_" -ForegroundColor Red
}

Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "  Test Complete" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""
