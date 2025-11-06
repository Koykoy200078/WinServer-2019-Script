# Lab Monitoring Functions
# Functions for monitoring student activities in computer lab

function Get-StudentActivity {
    param(
        [Parameter(Mandatory=$false)]
        [array]$Targets,
        [switch]$ShowAllProcesses,
        [switch]$ExportToFile
    )
    
    # Set default targets if not provided
    if (-not $Targets) {
        $Targets = 1..35 | ForEach-Object { "PC-$_" }
    }
    
    Write-Host "===== STUDENT ACTIVITY MONITOR =====" -ForegroundColor Cyan
    Write-Host "Scanning $($Targets.Count) PCs for student activity..." -ForegroundColor Yellow
    Write-Host "Target Domain: $script:targetDomain" -ForegroundColor Cyan
    Write-Host ""
    
    # Common student applications to highlight
    $suspiciousApps = @(
        'steam', 'discord', 'spotify', 'telegram', 'whatsapp', 'messenger',
        'roblox', 'minecraft', 'fortnite', 'valorant', 'genshin',
        'utorrent', 'bittorrent', 'netflix', 'twitch', 'tiktok'
    )
    
    $productiveApps = @(
        'chrome', 'firefox', 'edge', 'word', 'excel', 'powerpoint',
        'notepad', 'code', 'visual studio', 'mysql', 'xampp', 'python',
        'java', 'eclipse', 'netbeans', 'androidstudio'
    )
    
    $activityResults = @()
    $onlineCount = 0
    $suspiciousCount = 0
    
    foreach ($pc in $Targets) {
        Write-Host "Checking $pc..." -ForegroundColor Gray
        
        try {
            if (Test-WSMan -ComputerName $pc -ErrorAction Stop) {
                $isDomainMember = Test-DomainMembership -ComputerName $pc
                
                if ($isDomainMember) {
                    $pcActivity = Invoke-Command -ComputerName $pc -Credential $script:cred -ScriptBlock {
                        param($showAll, $suspicious, $productive)
                        
                        # Get logged in user
                        $loggedUser = (Get-WmiObject -Class Win32_ComputerSystem).UserName
                        
                        # Get all running processes with details
                        $processes = Get-Process | Where-Object { 
                            $_.MainWindowTitle -ne "" -or $showAll 
                        } | Select-Object Name, Id, @{
                            Name='Memory(MB)'; 
                            Expression={[math]::Round($_.WorkingSet64/1MB, 2)}
                        }, @{
                            Name='CPU(%)'; 
                            Expression={[math]::Round($_.CPU, 2)}
                        }, MainWindowTitle, StartTime
                        
                        # Categorize processes
                        $suspicious = $processes | Where-Object { 
                            $processName = $_.Name.ToLower()
                            $suspicious | ForEach-Object { 
                                if ($processName -like "*$_*") { return $true }
                            }
                        }
                        
                        $productive = $processes | Where-Object { 
                            $processName = $_.Name.ToLower()
                            $productive | ForEach-Object { 
                                if ($processName -like "*$_*") { return $true }
                            }
                        }
                        
                        # Get system info
                        $cpu = (Get-WmiObject Win32_Processor).LoadPercentage
                        $mem = Get-WmiObject Win32_OperatingSystem
                        $memUsage = [math]::Round((($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / $mem.TotalVisibleMemorySize) * 100, 2)
                        
                        # Get active window
                        Add-Type @"
                            using System;
                            using System.Runtime.InteropServices;
                            using System.Text;
                            public class Win32 {
                                [DllImport("user32.dll")]
                                public static extern IntPtr GetForegroundWindow();
                                
                                [DllImport("user32.dll")]
                                public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
                                
                                [DllImport("user32.dll")]
                                public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
                            }
"@
                        
                        $activeWindow = ""
                        $activeProcess = ""
                        try {
                            $hwnd = [Win32]::GetForegroundWindow()
                            $title = New-Object System.Text.StringBuilder 256
                            [void][Win32]::GetWindowText($hwnd, $title, 256)
                            $activeWindow = $title.ToString()
                            
                            $procId = 0
                            [void][Win32]::GetWindowThreadProcessId($hwnd, [ref]$procId)
                            if ($procId -gt 0) {
                                $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
                                if ($proc) {
                                    $activeProcess = $proc.ProcessName
                                }
                            }
                        } catch {
                            $activeWindow = "Unable to detect"
                            $activeProcess = "Unknown"
                        }
                        
                        [PSCustomObject]@{
                            Computer = $env:COMPUTERNAME
                            LoggedInUser = if ($loggedUser) { $loggedUser } else { "No user logged in" }
                            ActiveWindow = $activeWindow
                            ActiveProcess = $activeProcess
                            TotalProcesses = $processes.Count
                            SuspiciousApps = $suspicious.Count
                            ProductiveApps = $productive.Count
                            CPUUsage = $cpu
                            MemoryUsage = $memUsage
                            AllProcesses = $processes
                            SuspiciousProcesses = $suspicious
                            ProductiveProcesses = $productive
                        }
                    } -ArgumentList $ShowAllProcesses, $suspiciousApps, $productiveApps -ErrorAction Stop
                    
                    $activityResults += $pcActivity
                    $onlineCount++
                    
                    # Display summary
                    $userInfo = if ($pcActivity.LoggedInUser -ne "No user logged in") { 
                        $pcActivity.LoggedInUser 
                    } else { 
                        "No user" 
                    }
                    
                    if ($pcActivity.SuspiciousApps -gt 0) {
                        Write-Host "  ⚠️  $pc - User: $userInfo - Suspicious: $($pcActivity.SuspiciousApps) apps" -ForegroundColor Red
                        $suspiciousCount++
                    } elseif ($pcActivity.LoggedInUser -ne "No user logged in") {
                        Write-Host "  ✓ $pc - User: $userInfo - Active: $($pcActivity.ActiveProcess)" -ForegroundColor Green
                    } else {
                        Write-Host "  ○ $pc - Idle (no user)" -ForegroundColor DarkGray
                    }
                } else {
                    Write-Host "  ⊗ $pc - Not in $script:targetDomain domain" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  ✗ $pc - Offline" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "  ✗ $pc - Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "     ACTIVITY SUMMARY                        " -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Online PCs: $onlineCount / $($Targets.Count)" -ForegroundColor White
    Write-Host "PCs with Suspicious Activity: $suspiciousCount" -ForegroundColor $(if ($suspiciousCount -gt 0) { "Red" } else { "Green" })
    Write-Host ""
    
    # Display detailed table
    if ($activityResults.Count -gt 0) {
        Write-Host "PC Name       | User              | Active Process      | CPU% | RAM% | Status" -ForegroundColor Yellow
        Write-Host "------------- | ----------------- | ------------------- | ---- | ---- | ------" -ForegroundColor DarkGray
        
        foreach ($result in $activityResults) {
            $pcName = $result.Computer.PadRight(13)
            $user = if ($result.LoggedInUser.Length -gt 17) { 
                $result.LoggedInUser.Substring(0, 14) + "..." 
            } else { 
                $result.LoggedInUser.PadRight(17) 
            }
            $process = if ($result.ActiveProcess.Length -gt 19) { 
                $result.ActiveProcess.Substring(0, 16) + "..." 
            } else { 
                $result.ActiveProcess.PadRight(19) 
            }
            $cpu = $result.CPUUsage.ToString().PadRight(4)
            $mem = $result.MemoryUsage.ToString().PadRight(4)
            
            if ($result.SuspiciousApps -gt 0) {
                $status = "⚠️ ALERT"
                Write-Host "$pcName | $user | $process | $cpu | $mem | $status" -ForegroundColor Red
            } elseif ($result.LoggedInUser -eq "No user logged in") {
                $status = "Idle"
                Write-Host "$pcName | $user | $process | $cpu | $mem | $status" -ForegroundColor DarkGray
            } else {
                $status = "Active"
                Write-Host "$pcName | $user | $process | $cpu | $mem | $status" -ForegroundColor Cyan
            }
        }
    }
    
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Detailed view options
    $viewDetails = Read-Host "View detailed information? (y/n)"
    
    if ($viewDetails -eq 'y' -or $viewDetails -eq 'Y') {
        Write-Host ""
        Write-Host "Options:" -ForegroundColor Yellow
        Write-Host "  1. View specific PC details"
        Write-Host "  2. View all PCs with suspicious activity"
        Write-Host "  3. View all active PCs (with logged in users)"
        Write-Host "  4. View running processes on all PCs"
        Write-Host ""
        
        $detailChoice = Read-Host "Select option (1-4)"
        
        switch ($detailChoice) {
            '1' {
                $pcToView = Read-Host "Enter PC name (e.g., PC-1)"
                $pcResult = $activityResults | Where-Object { $_.Computer -eq $pcToView }
                
                if ($pcResult) {
                    Write-Host ""
                    Write-Host "===== DETAILED ACTIVITY: $($pcResult.Computer) =====" -ForegroundColor Cyan
                    Write-Host "Logged In User: $($pcResult.LoggedInUser)" -ForegroundColor White
                    Write-Host "Active Window: $($pcResult.ActiveWindow)" -ForegroundColor Yellow
                    Write-Host "Active Process: $($pcResult.ActiveProcess)" -ForegroundColor Yellow
                    Write-Host "CPU Usage: $($pcResult.CPUUsage)%" -ForegroundColor White
                    Write-Host "Memory Usage: $($pcResult.MemoryUsage)%" -ForegroundColor White
                    Write-Host ""
                    
                    if ($pcResult.SuspiciousProcesses.Count -gt 0) {
                        Write-Host "⚠️  SUSPICIOUS APPLICATIONS:" -ForegroundColor Red
                        Write-Host "-------------------------------------------" -ForegroundColor DarkGray
                        foreach ($proc in $pcResult.SuspiciousProcesses) {
                            Write-Host "  - $($proc.Name) (PID: $($proc.Id)) - Memory: $($proc.'Memory(MB)') MB" -ForegroundColor Red
                            if ($proc.MainWindowTitle) {
                                Write-Host "    Window: $($proc.MainWindowTitle)" -ForegroundColor DarkRed
                            }
                        }
                        Write-Host ""
                    }
                    
                    if ($pcResult.ProductiveProcesses.Count -gt 0) {
                        Write-Host "✓ PRODUCTIVE APPLICATIONS:" -ForegroundColor Green
                        Write-Host "-------------------------------------------" -ForegroundColor DarkGray
                        foreach ($proc in $pcResult.ProductiveProcesses) {
                            Write-Host "  - $($proc.Name) (PID: $($proc.Id)) - Memory: $($proc.'Memory(MB)') MB" -ForegroundColor Green
                            if ($proc.MainWindowTitle) {
                                Write-Host "    Window: $($proc.MainWindowTitle)" -ForegroundColor DarkGreen
                            }
                        }
                        Write-Host ""
                    }
                    
                    Write-Host "ALL RUNNING PROCESSES (with windows):" -ForegroundColor Cyan
                    Write-Host "-------------------------------------------" -ForegroundColor DarkGray
                    $pcResult.AllProcesses | Where-Object { $_.MainWindowTitle -ne "" } | 
                        Format-Table Name, Id, 'Memory(MB)', MainWindowTitle -AutoSize | Out-String | Write-Host
                    
                } else {
                    Write-Host "PC not found in results" -ForegroundColor Red
                }
            }
            '2' {
                $suspiciousPCs = $activityResults | Where-Object { $_.SuspiciousApps -gt 0 }
                
                if ($suspiciousPCs.Count -eq 0) {
                    Write-Host ""
                    Write-Host "✓ No suspicious activity detected!" -ForegroundColor Green
                    Write-Host ""
                } else {
                    foreach ($pcResult in $suspiciousPCs) {
                        Write-Host ""
                        Write-Host "===== ⚠️  ALERT: $($pcResult.Computer) =====" -ForegroundColor Red
                        Write-Host "User: $($pcResult.LoggedInUser)" -ForegroundColor Yellow
                        Write-Host "Current Activity: $($pcResult.ActiveWindow)" -ForegroundColor Yellow
                        Write-Host ""
                        Write-Host "Suspicious Applications Found:" -ForegroundColor Red
                        Write-Host "-------------------------------------------" -ForegroundColor DarkGray
                        
                        foreach ($proc in $pcResult.SuspiciousProcesses) {
                            Write-Host "  ⚠️  $($proc.Name)" -ForegroundColor Red
                            Write-Host "      PID: $($proc.Id) | Memory: $($proc.'Memory(MB)') MB" -ForegroundColor DarkRed
                            if ($proc.MainWindowTitle) {
                                Write-Host "      Window: $($proc.MainWindowTitle)" -ForegroundColor DarkRed
                            }
                            if ($proc.StartTime) {
                                Write-Host "      Started: $($proc.StartTime)" -ForegroundColor DarkRed
                            }
                            Write-Host ""
                        }
                    }
                }
            }
            '3' {
                $activePCs = $activityResults | Where-Object { $_.LoggedInUser -ne "No user logged in" }
                
                foreach ($pcResult in $activePCs) {
                    Write-Host ""
                    Write-Host "===== $($pcResult.Computer) =====" -ForegroundColor Cyan
                    Write-Host "User: $($pcResult.LoggedInUser)" -ForegroundColor White
                    Write-Host "Active: $($pcResult.ActiveProcess) - $($pcResult.ActiveWindow)" -ForegroundColor Yellow
                    Write-Host "Resources: CPU $($pcResult.CPUUsage)% | RAM $($pcResult.MemoryUsage)%" -ForegroundColor Gray
                    Write-Host "Processes: Total $($pcResult.TotalProcesses) | Productive $($pcResult.ProductiveApps) | Suspicious $($pcResult.SuspiciousApps)" -ForegroundColor White
                }
            }
            '4' {
                foreach ($pcResult in $activityResults) {
                    Write-Host ""
                    Write-Host "===== PROCESSES: $($pcResult.Computer) =====" -ForegroundColor Cyan
                    Write-Host "User: $($pcResult.LoggedInUser)" -ForegroundColor White
                    Write-Host ""
                    
                    if ($pcResult.AllProcesses.Count -gt 0) {
                        $pcResult.AllProcesses | 
                            Sort-Object -Property 'Memory(MB)' -Descending | 
                            Select-Object -First 10 | 
                            Format-Table Name, Id, 'Memory(MB)', 'CPU(%)', MainWindowTitle -AutoSize | 
                            Out-String | Write-Host
                    } else {
                        Write-Host "No processes found" -ForegroundColor DarkGray
                    }
                }
            }
        }
    }
    
    # Export option
    if ($ExportToFile) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $exportPath = Join-Path $script:scriptPath "Reports"
        
        if (-not (Test-Path $exportPath)) {
            New-Item -Path $exportPath -ItemType Directory | Out-Null
        }
        
        $reportFile = Join-Path $exportPath "StudentActivity_$timestamp.txt"
        
        $reportContent = @"
==================================================
STUDENT ACTIVITY REPORT
==================================================
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Domain: $script:targetDomain
Total PCs Scanned: $($Targets.Count)
Online PCs: $onlineCount
PCs with Suspicious Activity: $suspiciousCount

==================================================
DETAILED RESULTS
==================================================

"@
        
        foreach ($result in $activityResults) {
            $reportContent += "`n----- $($result.Computer) -----`n"
            $reportContent += "User: $($result.LoggedInUser)`n"
            $reportContent += "Active: $($result.ActiveProcess) - $($result.ActiveWindow)`n"
            $reportContent += "CPU: $($result.CPUUsage)% | RAM: $($result.MemoryUsage)%`n"
            $reportContent += "Total Processes: $($result.TotalProcesses)`n"
            $reportContent += "Suspicious Apps: $($result.SuspiciousApps)`n"
            $reportContent += "Productive Apps: $($result.ProductiveApps)`n"
            
            if ($result.SuspiciousProcesses.Count -gt 0) {
                $reportContent += "`nSUSPICIOUS APPLICATIONS:`n"
                foreach ($proc in $result.SuspiciousProcesses) {
                    $reportContent += "  - $($proc.Name) (PID: $($proc.Id)) - $($proc.'Memory(MB)') MB`n"
                }
            }
            $reportContent += "`n"
        }
        
        $reportContent | Out-File -FilePath $reportFile -Encoding UTF8
        Write-Host ""
        Write-Host "Report exported to: $reportFile" -ForegroundColor Green
    }
    
    Write-Host ""
    Pause
}
