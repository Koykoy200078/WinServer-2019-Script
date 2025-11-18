# Remote Client Diagnostics - Run this from the server to diagnose remote PC
param(
    [string]$PCName = "PC-1.csitlab.local",
    [string]$ServerIP = "192.168.2.45",
    [int]$ServerPort = 8888
)

Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "  Remote Client Diagnostics" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "Target PC: $PCName" -ForegroundColor Yellow
Write-Host ""

try {
    # Run comprehensive diagnostics on remote PC
    $results = Invoke-Command -ComputerName $PCName -ArgumentList $ServerIP, $ServerPort -ScriptBlock {
        param($ServerIP, $ServerPort)
        
        $diagnostics = @{
            PCName = $env:COMPUTERNAME
            FilesExist = $false
            ClientRunning = $false
            TaskExists = $false
            TaskState = "Unknown"
            CanReachServer = $false
            DotNetVersion = "Unknown"
            LastError = $null
        }
        
        # Check files
        if (Test-Path "C:\ProgramData\PCMonitor\PCMonitorClient.exe") {
            $diagnostics.FilesExist = $true
        }
        
        # Check if running
        $process = Get-Process -Name "PCMonitorClient" -ErrorAction SilentlyContinue
        if ($process) {
            $diagnostics.ClientRunning = $true
        }
        
        # Check scheduled task
        $task = Get-ScheduledTask -TaskName "PCMonitorClient" -ErrorAction SilentlyContinue
        if ($task) {
            $diagnostics.TaskExists = $true
            $diagnostics.TaskState = $task.State
        }
        
        # Check network
        try {
            $connection = Test-NetConnection -ComputerName $ServerIP -Port $ServerPort -WarningAction SilentlyContinue -ErrorAction Stop
            $diagnostics.CanReachServer = $connection.TcpTestSucceeded
        } catch {
            $diagnostics.CanReachServer = $false
        }
        
        # Check .NET version
        try {
            $diagnostics.DotNetVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction Stop).Version
        } catch {
            $diagnostics.DotNetVersion = "Not Found"
        }
        
        # Check recent errors
        $errors = Get-WinEvent -LogName Application -MaxEvents 5 -ErrorAction SilentlyContinue | 
                  Where-Object { 
                      $_.TimeCreated -gt (Get-Date).AddHours(-1) -and 
                      $_.LevelDisplayName -eq "Error" -and
                      $_.Message -like "*PCMonitor*"
                  }
        
        if ($errors) {
            $diagnostics.LastError = $errors[0].Message
        }
        
        # Try to start the client manually
        Write-Host "`n  Attempting to start client..." -ForegroundColor Yellow
        
        try {
            # Kill any existing process
            Get-Process -Name "PCMonitorClient" -ErrorAction SilentlyContinue | Stop-Process -Force
            Start-Sleep -Seconds 1
            
            # Start new process
            $proc = Start-Process -FilePath "C:\ProgramData\PCMonitor\PCMonitorClient.exe" `
                                 -ArgumentList "$ServerIP $ServerPort" `
                                 -WindowStyle Hidden `
                                 -PassThru
            
            Start-Sleep -Seconds 3
            
            # Check if still running
            $stillRunning = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
            if ($stillRunning) {
                $diagnostics.ClientRunning = $true
                Write-Host "  ✓ Client started successfully!" -ForegroundColor Green
            } else {
                Write-Host "  ✗ Client crashed after starting" -ForegroundColor Red
            }
        } catch {
            Write-Host "  ✗ Failed to start: $_" -ForegroundColor Red
        }
        
        return $diagnostics
    }
    
    # Display results
    Write-Host "`n=======================================" -ForegroundColor Cyan
    Write-Host "  Diagnostic Results" -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
    
    $status = if ($results.ClientRunning) { "RUNNING" } else { "NOT RUNNING" }
    $color = if ($results.ClientRunning) { "Green" } else { "Red" }
    
    Write-Host "`nStatus: " -NoNewline
    Write-Host $status -ForegroundColor $color
    
    Write-Host "`nChecks:" -ForegroundColor Yellow
    Write-Host "  Files Deployed: " -NoNewline
    Write-Host $(if ($results.FilesExist) { "✓" } else { "✗" }) -ForegroundColor $(if ($results.FilesExist) { "Green" } else { "Red" })
    
    Write-Host "  Client Running: " -NoNewline
    Write-Host $(if ($results.ClientRunning) { "✓" } else { "✗" }) -ForegroundColor $(if ($results.ClientRunning) { "Green" } else { "Red" })
    
    Write-Host "  Task Exists: " -NoNewline
    Write-Host $(if ($results.TaskExists) { "✓ (State: $($results.TaskState))" } else { "✗" }) -ForegroundColor $(if ($results.TaskExists) { "Green" } else { "Red" })
    
    Write-Host "  Can Reach Server: " -NoNewline
    Write-Host $(if ($results.CanReachServer) { "✓" } else { "✗" }) -ForegroundColor $(if ($results.CanReachServer) { "Green" } else { "Red" })
    
    Write-Host "  .NET Version: " -NoNewline
    Write-Host $results.DotNetVersion -ForegroundColor Gray
    
    if ($results.LastError) {
        Write-Host "`nRecent Error:" -ForegroundColor Red
        Write-Host "  $($results.LastError)" -ForegroundColor Gray
    }
    
    # Recommendations
    Write-Host "`n=======================================" -ForegroundColor Cyan
    Write-Host "  Recommendations" -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
    
    if (-not $results.ClientRunning) {
        Write-Host "`n⚠ Client is not running. Possible causes:" -ForegroundColor Yellow
        
        if (-not $results.FilesExist) {
            Write-Host "  1. Files not deployed - Run deployment script again" -ForegroundColor White
        }
        
        if (-not $results.CanReachServer) {
            Write-Host "  2. Cannot reach server - Check:" -ForegroundColor White
            Write-Host "     • Is monitoring server running?" -ForegroundColor Gray
            Write-Host "     • Is port 8888 open on server firewall?" -ForegroundColor Gray
            Write-Host "     • Network connectivity between PCs?" -ForegroundColor Gray
        }
        
        if ($results.DotNetVersion -eq "Not Found" -or [version]$results.DotNetVersion -lt [version]"4.8") {
            Write-Host "  3. Install .NET Framework 4.8.1" -ForegroundColor White
            Write-Host "     Download: https://dotnet.microsoft.com/download/dotnet-framework/net481" -ForegroundColor Gray
        }
        
        Write-Host "  4. Check antivirus - it might be blocking PCMonitorClient.exe" -ForegroundColor White
        Write-Host "  5. Try running client manually on $PCName" -ForegroundColor White
        Write-Host "     C:\ProgramData\PCMonitor\PCMonitorClient.exe" -ForegroundColor Gray
    } else {
        Write-Host "`n✓ Client is running!" -ForegroundColor Green
        Write-Host "  Check the monitoring dashboard - PC should appear within 10 seconds" -ForegroundColor Yellow
    }
    
    Write-Host ""
    
} catch {
    Write-Host "`n✗ Failed to connect to $PCName" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Gray
    Write-Host "`n  Make sure:" -ForegroundColor Yellow
    Write-Host "    1. PC is online and reachable" -ForegroundColor White
    Write-Host "    2. WinRM is enabled: Enable-PSRemoting -Force" -ForegroundColor White
    Write-Host "    3. You have admin rights on the remote PC" -ForegroundColor White
    Write-Host ""
}
