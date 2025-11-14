# Lab Monitoring Functions
# Functions for monitoring student activities in computer lab

function Start-BrowserSearchMonitor {
    param(
        [Parameter(Mandatory=$false)]
        [array]$Targets,
        [int]$RefreshInterval = 5
    )
    
    # Set default targets if not provided
    if (-not $Targets) {
        $Targets = 1..35 | ForEach-Object { "PC-$_" }
    }
    
    # Search log tracking
    $searchLog = @()
    $scanCount = 0
    $startTime = Get-Date
    
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "  REAL-TIME BROWSER SEARCH MONITOR          " -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Monitoring: $($Targets.Count) PCs" -ForegroundColor White
    Write-Host "Refresh Interval: $RefreshInterval seconds" -ForegroundColor White
    Write-Host "Domain: $script:targetDomain" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Tracking browser activity and search queries..." -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to stop monitoring and save log..." -ForegroundColor Yellow
    Write-Host ""
    Start-Sleep -Seconds 2
    
    try {
        while ($true) {
            $scanCount++
            $currentTime = Get-Date
            $elapsed = $currentTime - $startTime
            
            Clear-Host
            
            # Header
            Write-Host "=============================================" -ForegroundColor Cyan
            Write-Host "  BROWSER SEARCH MONITOR - SCAN #$scanCount" -ForegroundColor Cyan
            Write-Host "=============================================" -ForegroundColor Cyan
            Write-Host "Time: $($currentTime.ToString('HH:mm:ss')) | Elapsed: $($elapsed.ToString('hh\:mm\:ss')) | Interval: ${RefreshInterval}s" -ForegroundColor White
            Write-Host "Press Ctrl+C to stop and save log" -ForegroundColor Yellow
            Write-Host "=============================================" -ForegroundColor Cyan
            Write-Host ""
            
            $onlineCount = 0
            $newSearches = 0
            
            foreach ($pc in $Targets) {
                try {
                    if (Test-WSMan -ComputerName $pc -ErrorAction SilentlyContinue) {
                        $isDomainMember = Test-DomainMembership -ComputerName $pc
                        
                        if ($isDomainMember) {
                            $browserData = Invoke-Command -ComputerName $pc -Credential $script:cred -ScriptBlock {
                                # Get logged in user
                                $loggedUser = (Get-WmiObject -Class Win32_ComputerSystem).UserName
                                
                                # First, get ALL browser processes for debugging
                                $allBrowserProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object { 
                                    $_.Name -match 'chrome|firefox|msedge|MicrosoftEdge|iexplore|opera|brave'
                                }
                                
                                # Get all browser processes with window titles
                                # Edge can be "msedge" or "MicrosoftEdge", Chrome is "chrome", Firefox is "firefox"
                                $allBrowserWindows = $allBrowserProcs | Where-Object { 
                                    ($_.MainWindowTitle -ne $null) -and
                                    ($_.MainWindowTitle.Trim() -ne "") -and
                                    ($_.MainWindowTitle -notmatch '^New Tab$|^about:blank|^Untitled|^$|^Settings|^Downloads|^Extensions|^DevTools|^Task Manager')
                                } | Select-Object Name, MainWindowTitle, @{
                                    Name='Memory(MB)';
                                    Expression={[math]::Round($_.WorkingSet64/1MB, 2)}
                                }
                                
                                # Group by MainWindowTitle to get unique tabs (Chrome/Edge create multiple processes per tab)
                                $browsers = $allBrowserWindows | Group-Object MainWindowTitle | ForEach-Object {
                                    # For each unique page title, take the one with highest memory (main process)
                                    $_.Group | Sort-Object 'Memory(MB)' -Descending | Select-Object -First 1
                                }
                                
                                [PSCustomObject]@{
                                    Computer = $env:COMPUTERNAME
                                    LoggedInUser = if ($loggedUser) { $loggedUser } else { "No user" }
                                    BrowserTabs = $browsers
                                    TabCount = $browsers.Count
                                    TotalBrowserProcs = $allBrowserProcs.Count
                                }
                            } -ErrorAction Stop
                            
                            $onlineCount++
                            
                            # Debug: Show browser detection info
                            if ($browserData.TabCount -eq 0 -and $browserData.LoggedInUser -ne "No user") {
                                if ($browserData.TotalBrowserProcs -gt 0) {
                                    Write-Host "  ℹ️  $pc - User: $($browserData.LoggedInUser) - $($browserData.TotalBrowserProcs) browser(s) running but no valid tabs detected" -ForegroundColor Yellow
                                } else {
                                    Write-Host "  ℹ️  $pc - User: $($browserData.LoggedInUser) - No browser processes detected" -ForegroundColor DarkGray
                                }
                            }
                            
                            if ($browserData.LoggedInUser -ne "No user" -and $browserData.TabCount -gt 0) {
                                foreach ($tab in $browserData.BrowserTabs) {
                                    $logEntry = [PSCustomObject]@{
                                        Timestamp = $currentTime
                                        PC = $pc
                                        User = $browserData.LoggedInUser
                                        Browser = $tab.Name
                                        PageTitle = $tab.MainWindowTitle
                                        Memory = $tab.'Memory(MB)'
                                    }
                                    
                                    # Check if this is a new search/page (not in last 5 entries)
                                    $recentEntries = $searchLog | Select-Object -Last 5
                                    $isDuplicate = $recentEntries | Where-Object {
                                        $_.PC -eq $logEntry.PC -and 
                                        $_.PageTitle -eq $logEntry.PageTitle
                                    }
                                    
                                    if (-not $isDuplicate) {
                                        $searchLog += $logEntry
                                        $newSearches++
                                        
                                        # Display new search in real-time
                                        $timestamp = $logEntry.Timestamp.ToString('HH:mm:ss')
                                        $browserShort = $logEntry.Browser -replace 'chrome', 'Chrome' -replace 'firefox', 'Firefox' -replace 'msedge|MicrosoftEdge', 'Edge' -replace 'iexplore', 'IE' -replace 'opera', 'Opera' -replace 'brave', 'Brave'
                                        
                                        # Color code based on content
                                        $color = "Cyan"
                                        $titleLower = $logEntry.PageTitle.ToLower()
                                        
                                        # Check for AI sites (expanded patterns)
                                        if ($titleLower -match 'chatgpt|openai|claude|bard|copilot|gemini|perplexity|chat\.openai|character\.ai|ai chat|artificial intelligence') {
                                            $color = "Red"
                                            $marker = "🤖 AI"
                                        }
                                        # Check for social media (expanded patterns to catch searches)
                                        elseif ($titleLower -match 'facebook|instagram|twitter|tiktok|snapchat|reddit|fb\.com|ig |insta |tweet|snap|social media|pinterest|tumblr|linkedin') {
                                            $color = "Yellow"
                                            $marker = "📱 Social"
                                        }
                                        # Check for video sites
                                        elseif ($titleLower -match 'youtube|netflix|twitch|vimeo|yt |watch video|streaming|video player') {
                                            $color = "Magenta"
                                            $marker = "🎬 Video"
                                        }
                                        # Check for gaming
                                        elseif ($titleLower -match 'roblox|minecraft|steam|game|play|gaming|genshin|valorant|league of legends|fortnite') {
                                            $color = "DarkYellow"
                                            $marker = "🎮 Game"
                                        }
                                        # Check for educational content
                                        elseif ($titleLower -match 'stackoverflow|github|mdn|w3schools|tutorial|learn|documentation|docs|education|study|programming|code') {
                                            $color = "Green"
                                            $marker = "📚 Study"
                                        }
                                        # Check for shopping/entertainment
                                        elseif ($titleLower -match 'shop|buy|amazon|ebay|lazada|shopee|shopping|cart|checkout|entertainment') {
                                            $color = "DarkMagenta"
                                            $marker = "🛒 Shop"
                                        }
                                        else {
                                            $marker = "🌐 Web"
                                        }
                                        
                                        Write-Host "[$timestamp] $marker " -ForegroundColor $color -NoNewline
                                        Write-Host "$($logEntry.PC) - " -ForegroundColor White -NoNewline
                                        Write-Host "$($logEntry.User) " -ForegroundColor Gray -NoNewline
                                        Write-Host "[$browserShort]" -ForegroundColor DarkCyan -NoNewline
                                        Write-Host " $($logEntry.PageTitle)" -ForegroundColor $color
                                    }
                                }
                            }
                        }
                    }
                }
                catch {
                    # Silently continue on errors
                }
            }
            
            # Display summary every 5 scans or if new searches found
            if ($scanCount % 5 -eq 0 -or $newSearches -gt 0) {
                Write-Host ""
                Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray
                Write-Host "Summary: Online: $onlineCount/$($Targets.Count) | " -NoNewline -ForegroundColor Gray
                Write-Host "Total Logs: $($searchLog.Count) | " -NoNewline -ForegroundColor Gray
                Write-Host "New This Scan: $newSearches" -ForegroundColor $(if ($newSearches -gt 0) { "Green" } else { "Gray" })
                Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray
                Write-Host ""
            }
            
            # Countdown
            for ($i = $RefreshInterval; $i -gt 0; $i--) {
                $currentElapsed = (Get-Date) - $startTime
                Write-Host "`rNext scan in $i seconds... | Elapsed: $($currentElapsed.ToString('hh\:mm\:ss')) | Logs: $($searchLog.Count)" -ForegroundColor Yellow -NoNewline
                Start-Sleep -Seconds 1
            }
            Write-Host ""
        }
    }
    catch [System.Management.Automation.PipelineStoppedException] {
        # Ctrl+C pressed - save log
        Write-Host ""
        Write-Host ""
        Write-Host "=============================================" -ForegroundColor Yellow
        Write-Host "  MONITORING STOPPED - SAVING LOG...        " -ForegroundColor Yellow
        Write-Host "=============================================" -ForegroundColor Yellow
        Write-Host ""
        
        if ($searchLog.Count -gt 0) {
            # Create Reports directory
            $reportPath = Join-Path $script:scriptPath "Reports"
            if (-not (Test-Path $reportPath)) {
                New-Item -Path $reportPath -ItemType Directory | Out-Null
            }
            
            $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
            $logFile = Join-Path $reportPath "BrowserSearchLog_$timestamp.csv"
            $summaryFile = Join-Path $reportPath "BrowserSearchSummary_$timestamp.txt"
            
            # Export detailed CSV
            $searchLog | Export-Csv -Path $logFile -NoTypeInformation -Encoding UTF8
            Write-Host "✓ Detailed log saved: $logFile" -ForegroundColor Green
            
            # Generate summary report
            $summary = @"
==================================================
BROWSER SEARCH MONITORING REPORT
==================================================
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Domain: $script:targetDomain
Monitoring Duration: $($elapsed.ToString('hh\:mm\:ss'))
Total Scans: $scanCount
Total Logs: $($searchLog.Count)

==================================================
ACTIVITY BY PC
==================================================

"@
            
            $pcGroups = $searchLog | Group-Object -Property PC | Sort-Object Count -Descending
            foreach ($group in $pcGroups) {
                $summary += "`n$($group.Name) - $($group.Count) page views`n"
                $summary += "  User(s): $(($group.Group.User | Select-Object -Unique) -join ', ')`n"
                $summary += "  Top Pages:`n"
                $topPages = $group.Group | Group-Object PageTitle | Sort-Object Count -Descending | Select-Object -First 5
                foreach ($page in $topPages) {
                    $summary += "    - $($page.Name) ($($page.Count)x)`n"
                }
            }
            
            $summary += "`n`n"
            $summary += "==================================================`n"
            $summary += "ACTIVITY BY USER`n"
            $summary += "==================================================`n`n"
            
            $userGroups = $searchLog | Where-Object { $_.User -ne "No user" } | Group-Object -Property User | Sort-Object Count -Descending
            foreach ($group in $userGroups) {
                $summary += "`n$($group.Name) - $($group.Count) page views`n"
                $summary += "  PC(s): $(($group.Group.PC | Select-Object -Unique) -join ', ')`n"
                $summary += "  Browsers: $(($group.Group.Browser | Select-Object -Unique) -join ', ')`n"
            }
            
            $summary += "`n`n"
            $summary += "==================================================`n"
            $summary += "CATEGORY BREAKDOWN`n"
            $summary += "==================================================`n`n"
            
            $aiSites = $searchLog | Where-Object { $_.PageTitle -match 'chatgpt|openai|claude|bard|copilot|gemini|perplexity|chat\.openai|character\.ai|ai chat|artificial intelligence' }
            $socialSites = $searchLog | Where-Object { $_.PageTitle -match 'facebook|instagram|twitter|tiktok|snapchat|reddit|fb\.com|ig |insta |tweet|snap|social media|pinterest|tumblr|linkedin' }
            $videoSites = $searchLog | Where-Object { $_.PageTitle -match 'youtube|netflix|twitch|vimeo|yt |watch video|streaming|video player' }
            $gamingSites = $searchLog | Where-Object { $_.PageTitle -match 'roblox|minecraft|steam|game|play|gaming|genshin|valorant|league of legends|fortnite' }
            $studySites = $searchLog | Where-Object { $_.PageTitle -match 'stackoverflow|github|mdn|w3schools|tutorial|learn|documentation|docs|education|study|programming|code' }
            $shopSites = $searchLog | Where-Object { $_.PageTitle -match 'shop|buy|amazon|ebay|lazada|shopee|shopping|cart|checkout|entertainment' }
            
            $summary += "🤖 AI Sites: $($aiSites.Count)`n"
            $summary += "📱 Social Media: $($socialSites.Count)`n"
            $summary += "🎬 Video Sites: $($videoSites.Count)`n"
            $summary += "🎮 Gaming Sites: $($gamingSites.Count)`n"
            $summary += "📚 Educational: $($studySites.Count)`n"
            $summary += "🛒 Shopping: $($shopSites.Count)`n"
            $summary += "🌐 Other: $($searchLog.Count - $aiSites.Count - $socialSites.Count - $videoSites.Count - $gamingSites.Count - $studySites.Count - $shopSites.Count)`n"
            
            $summary | Out-File -FilePath $summaryFile -Encoding UTF8
            Write-Host "✓ Summary report saved: $summaryFile" -ForegroundColor Green
            
            Write-Host ""
            Write-Host "Session Statistics:" -ForegroundColor Cyan
            Write-Host "  Duration: $($elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor White
            Write-Host "  Total Logs: $($searchLog.Count)" -ForegroundColor White
            Write-Host "  Unique PCs: $(($searchLog | Select-Object -ExpandProperty PC -Unique).Count)" -ForegroundColor White
            Write-Host "  Unique Users: $(($searchLog | Where-Object { $_.User -ne 'No user' } | Select-Object -ExpandProperty User -Unique).Count)" -ForegroundColor White
            Write-Host ""
            Write-Host "Category Breakdown:" -ForegroundColor Cyan
            Write-Host "  🤖 AI Sites: $($aiSites.Count)" -ForegroundColor $(if ($aiSites.Count -gt 0) { "Red" } else { "Gray" })
            Write-Host "  📱 Social Media: $($socialSites.Count)" -ForegroundColor $(if ($socialSites.Count -gt 0) { "Yellow" } else { "Gray" })
            Write-Host "  🎬 Video Sites: $($videoSites.Count)" -ForegroundColor $(if ($videoSites.Count -gt 0) { "Magenta" } else { "Gray" })
            Write-Host "  🎮 Gaming: $($gamingSites.Count)" -ForegroundColor $(if ($gamingSites.Count -gt 0) { "DarkYellow" } else { "Gray" })
            Write-Host "  📚 Educational: $($studySites.Count)" -ForegroundColor $(if ($studySites.Count -gt 0) { "Green" } else { "Gray" })
            Write-Host "  🛒 Shopping: $($shopSites.Count)" -ForegroundColor $(if ($shopSites.Count -gt 0) { "DarkMagenta" } else { "Gray" })
            Write-Host ""
        } else {
            Write-Host "No search activity logged during this session." -ForegroundColor Yellow
        }
        
        Write-Host "Press any key to return to menu..." -ForegroundColor Cyan
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    catch {
        Write-Host ""
        Write-Host "Error during monitoring: $($_.Exception.Message)" -ForegroundColor Red
        Pause
    }
}

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
    
    # Suspicious websites (not for class use)
    $suspiciousWebsites = @(
        # Social Media
        'facebook.com', 'fb.com', 'instagram.com', 'twitter.com', 'x.com', 'tiktok.com',
        'snapchat.com', 'reddit.com', 'pinterest.com', 'linkedin.com', 'tumblr.com',
        # Video Sites
        'youtube.com', 'youtu.be', 'netflix.com', 'twitch.tv', 'vimeo.com', 
        'dailymotion.com', 'hulu.com', 'disneyplus.com',
        # AI Sites (ChatGPT, etc)
        'chat.openai.com', 'chatgpt.com', 'bard.google.com', 'claude.ai', 
        'anthropic.com', 'you.com', 'perplexity.ai', 'character.ai',
        # Gaming
        'roblox.com', 'minecraft.net', 'steam.com', 'epicgames.com', 
        'ea.com', 'activision.com', 'riot.com', 'valorant.com',
        # Shopping/Entertainment
        'amazon.com', 'ebay.com', 'shopee.com', 'lazada.com', 'alibaba.com',
        'zalora.com', 'shein.com', 'spotify.com', 'soundcloud.com'
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
                        param($showAll, $suspicious, $productive, $suspiciousUrls)
                        
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
                        
                        # Check for suspicious websites in browser windows
                        $suspiciousWebsitesFound = @()
                        $browserProcesses = Get-Process | Where-Object { 
                            $_.Name -match 'chrome|firefox|msedge|iexplore|opera|brave' -and 
                            $_.MainWindowTitle -ne ""
                        }
                        
                        foreach ($browser in $browserProcesses) {
                            $windowTitle = $browser.MainWindowTitle.ToLower()
                            foreach ($url in $suspiciousUrls) {
                                if ($windowTitle -like "*$url*") {
                                    $suspiciousWebsitesFound += [PSCustomObject]@{
                                        Browser = $browser.Name
                                        Website = $url
                                        WindowTitle = $browser.MainWindowTitle
                                        BrowserPID = $browser.Id
                                    }
                                    break
                                }
                            }
                        }
                        
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
                            SuspiciousWebsites = $suspiciousWebsitesFound.Count
                            SuspiciousWebsitesList = $suspiciousWebsitesFound
                            CPUUsage = $cpu
                            MemoryUsage = $memUsage
                            AllProcesses = $processes
                            SuspiciousProcesses = $suspicious
                            ProductiveProcesses = $productive
                        }
                    } -ArgumentList $ShowAllProcesses, $suspiciousApps, $productiveApps, $suspiciousWebsites -ErrorAction Stop
                    
                    $activityResults += $pcActivity
                    $onlineCount++
                    
                    # Display summary
                    $userInfo = if ($pcActivity.LoggedInUser -ne "No user logged in") { 
                        $pcActivity.LoggedInUser 
                    } else { 
                        "No user" 
                    }
                    
                    if ($pcActivity.SuspiciousApps -gt 0 -or $pcActivity.SuspiciousWebsites -gt 0) {
                        $alertMsg = "Suspicious: "
                        if ($pcActivity.SuspiciousApps -gt 0) { $alertMsg += "$($pcActivity.SuspiciousApps) apps " }
                        if ($pcActivity.SuspiciousWebsites -gt 0) { $alertMsg += "$($pcActivity.SuspiciousWebsites) websites" }
                        Write-Host "  ⚠️  $pc - User: $userInfo - $alertMsg" -ForegroundColor Red
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
            
            if ($result.SuspiciousApps -gt 0 -or $result.SuspiciousWebsites -gt 0) {
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
                    
                    if ($pcResult.SuspiciousWebsites -gt 0) {
                        Write-Host "🌐 SUSPICIOUS WEBSITES DETECTED:" -ForegroundColor Red
                        Write-Host "-------------------------------------------" -ForegroundColor DarkGray
                        foreach ($web in $pcResult.SuspiciousWebsitesList) {
                            Write-Host "  - $($web.Website)" -ForegroundColor Red
                            Write-Host "    Browser: $($web.Browser) (PID: $($web.BrowserPID))" -ForegroundColor DarkRed
                            Write-Host "    Tab: $($web.WindowTitle)" -ForegroundColor DarkRed
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
                        
                        if ($pcResult.SuspiciousProcesses.Count -gt 0) {
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
                        
                        if ($pcResult.SuspiciousWebsites -gt 0) {
                            Write-Host "Suspicious Websites Detected:" -ForegroundColor Red
                            Write-Host "-------------------------------------------" -ForegroundColor DarkGray
                            
                            foreach ($web in $pcResult.SuspiciousWebsitesList) {
                                Write-Host "  🌐 $($web.Website)" -ForegroundColor Red
                                Write-Host "      Browser: $($web.Browser) (PID: $($web.BrowserPID))" -ForegroundColor DarkRed
                                Write-Host "      Tab Title: $($web.WindowTitle)" -ForegroundColor DarkRed
                                Write-Host ""
                            }
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

function Start-RealtimeMonitor {
    param(
        [Parameter(Mandatory=$false)]
        [array]$Targets,
        [int]$RefreshInterval = 10
    )
    
    # Set default targets if not provided
    if (-not $Targets) {
        $Targets = 1..35 | ForEach-Object { "PC-$_" }
    }
    
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
    
    # Suspicious websites (not for class use)
    $suspiciousWebsites = @(
        # Social Media
        'facebook.com', 'fb.com', 'instagram.com', 'twitter.com', 'x.com', 'tiktok.com',
        'snapchat.com', 'reddit.com', 'pinterest.com', 'linkedin.com', 'tumblr.com',
        # Video Sites
        'youtube.com', 'youtu.be', 'netflix.com', 'twitch.tv', 'vimeo.com', 
        'dailymotion.com', 'hulu.com', 'disneyplus.com',
        # AI Sites (ChatGPT, etc)
        'chat.openai.com', 'chatgpt.com', 'bard.google.com', 'claude.ai', 
        'anthropic.com', 'you.com', 'perplexity.ai', 'character.ai',
        # Gaming
        'roblox.com', 'minecraft.net', 'steam.com', 'epicgames.com', 
        'ea.com', 'activision.com', 'riot.com', 'valorant.com',
        # Shopping/Entertainment
        'amazon.com', 'ebay.com', 'shopee.com', 'lazada.com', 'alibaba.com',
        'zalora.com', 'shein.com', 'spotify.com', 'soundcloud.com'
    )
    
    # Alert tracking
    $alertHistory = @{}
    $scanCount = 0
    $startTime = Get-Date
    
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "   REAL-TIME STUDENT ACTIVITY MONITOR       " -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Monitoring: $($Targets.Count) PCs" -ForegroundColor White
    Write-Host "Refresh Interval: $RefreshInterval seconds" -ForegroundColor White
    Write-Host "Domain: $script:targetDomain" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Press Ctrl+C to stop monitoring..." -ForegroundColor Yellow
    Write-Host ""
    Start-Sleep -Seconds 2
    
    try {
        while ($true) {
            $scanCount++
            
            Clear-Host
            
            # Calculate elapsed time at start of scan
            $currentTime = Get-Date
            $elapsed = $currentTime - $startTime
            
            # Header
            Write-Host "=============================================" -ForegroundColor Cyan
            Write-Host "   REAL-TIME MONITOR - SCAN #$scanCount" -ForegroundColor Cyan
            Write-Host "=============================================" -ForegroundColor Cyan
            Write-Host "Time: $(Get-Date -Format 'HH:mm:ss') | Elapsed: $($elapsed.ToString('hh\:mm\:ss')) | Interval: ${RefreshInterval}s" -ForegroundColor White
            Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
            Write-Host "=============================================" -ForegroundColor Cyan
            Write-Host ""
            
            $activityResults = @()
            $onlineCount = 0
            $suspiciousCount = 0
            $newAlerts = @()
            
            foreach ($pc in $Targets) {
                try {
                    if (Test-WSMan -ComputerName $pc -ErrorAction SilentlyContinue) {
                        $isDomainMember = Test-DomainMembership -ComputerName $pc
                        
                        if ($isDomainMember) {
                            $pcActivity = Invoke-Command -ComputerName $pc -Credential $script:cred -ScriptBlock {
                                param($suspicious, $productive, $suspiciousUrls)
                                
                                # Get logged in user
                                $loggedUser = (Get-WmiObject -Class Win32_ComputerSystem).UserName
                                
                                # Get running processes
                                $processes = Get-Process | Where-Object { 
                                    $_.MainWindowTitle -ne "" 
                                } | Select-Object Name, Id, @{
                                    Name='Memory(MB)'; 
                                    Expression={[math]::Round($_.WorkingSet64/1MB, 2)}
                                }, MainWindowTitle
                                
                                # Categorize processes
                                $suspiciousProcs = $processes | Where-Object { 
                                    $processName = $_.Name.ToLower()
                                    $found = $false
                                    foreach ($sus in $suspicious) {
                                        if ($processName -like "*$sus*") {
                                            $found = $true
                                            break
                                        }
                                    }
                                    $found
                                }
                                
                                $productiveProcs = $processes | Where-Object { 
                                    $processName = $_.Name.ToLower()
                                    $found = $false
                                    foreach ($prod in $productive) {
                                        if ($processName -like "*$prod*") {
                                            $found = $true
                                            break
                                        }
                                    }
                                    $found
                                }
                                
                                # Check for suspicious websites in browser windows
                                $suspiciousWebsitesFound = @()
                                $browserProcesses = Get-Process | Where-Object { 
                                    $_.Name -match 'chrome|firefox|msedge|iexplore|opera|brave' -and 
                                    $_.MainWindowTitle -ne ""
                                }
                                
                                foreach ($browser in $browserProcesses) {
                                    $windowTitle = $browser.MainWindowTitle.ToLower()
                                    foreach ($url in $suspiciousUrls) {
                                        if ($windowTitle -like "*$url*") {
                                            $suspiciousWebsitesFound += [PSCustomObject]@{
                                                Browser = $browser.Name
                                                Website = $url
                                                WindowTitle = $browser.MainWindowTitle
                                                BrowserPID = $browser.Id
                                            }
                                            break
                                        }
                                    }
                                }
                                
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
                                    $activeWindow = ""
                                    $activeProcess = "Unknown"
                                }
                                
                                # Get CPU/Memory
                                try {
                                    $cpu = (Get-WmiObject Win32_Processor -ErrorAction Stop).LoadPercentage
                                } catch {
                                    $cpu = 0
                                }
                                
                                try {
                                    $mem = Get-WmiObject Win32_OperatingSystem -ErrorAction Stop
                                    $memUsage = [math]::Round((($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / $mem.TotalVisibleMemorySize) * 100, 2)
                                } catch {
                                    $memUsage = 0
                                }
                                
                                [PSCustomObject]@{
                                    Computer = $env:COMPUTERNAME
                                    LoggedInUser = if ($loggedUser) { $loggedUser } else { "No user" }
                                    ActiveWindow = $activeWindow
                                    ActiveProcess = $activeProcess
                                    SuspiciousApps = $suspiciousProcs.Count
                                    SuspiciousProcesses = $suspiciousProcs
                                    ProductiveApps = $productiveProcs.Count
                                    ProductiveProcesses = $productiveProcs
                                    SuspiciousWebsites = $suspiciousWebsitesFound.Count
                                    SuspiciousWebsitesList = $suspiciousWebsitesFound
                                    CPUUsage = $cpu
                                    MemoryUsage = $memUsage
                                }
                            } -ArgumentList $suspiciousApps, $productiveApps, $suspiciousWebsites -ErrorAction Stop
                            
                            $activityResults += $pcActivity
                            $onlineCount++
                            
                            # Check for suspicious activity
                            if ($pcActivity.SuspiciousApps -gt 0 -or $pcActivity.SuspiciousWebsites -gt 0) {
                                $suspiciousCount++
                                
                                # Check if this is a new alert (apps)
                                if ($pcActivity.SuspiciousApps -gt 0) {
                                    $alertKey = "$pc-APP-$($pcActivity.SuspiciousProcesses[0].Name)"
                                    if (-not $alertHistory.ContainsKey($alertKey)) {
                                        $alertHistory[$alertKey] = Get-Date
                                        $newAlerts += [PSCustomObject]@{
                                            PC = $pc
                                            User = $pcActivity.LoggedInUser
                                            Type = "App"
                                            Name = $pcActivity.SuspiciousProcesses[0].Name
                                            Details = $pcActivity.ActiveWindow
                                        }
                                    }
                                }
                                
                                # Check if this is a new alert (websites)
                                if ($pcActivity.SuspiciousWebsites -gt 0) {
                                    $alertKey = "$pc-WEB-$($pcActivity.SuspiciousWebsitesList[0].Website)"
                                    if (-not $alertHistory.ContainsKey($alertKey)) {
                                        $alertHistory[$alertKey] = Get-Date
                                        $newAlerts += [PSCustomObject]@{
                                            PC = $pc
                                            User = $pcActivity.LoggedInUser
                                            Type = "Website"
                                            Name = $pcActivity.SuspiciousWebsitesList[0].Website
                                            Details = $pcActivity.SuspiciousWebsitesList[0].WindowTitle
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                catch {
                    # Silently continue on errors during real-time monitoring
                }
            }
            
            # Display summary statistics
            Write-Host "SUMMARY:" -ForegroundColor Cyan
            Write-Host "  Online: $onlineCount / $($Targets.Count)" -ForegroundColor White
            Write-Host "  Suspicious Activity: " -NoNewline
            if ($suspiciousCount -gt 0) {
                Write-Host "$suspiciousCount PCs" -ForegroundColor Red
            } else {
                Write-Host "None ✓" -ForegroundColor Green
            }
            Write-Host "  Total Alerts This Session: $($alertHistory.Count)" -ForegroundColor Yellow
            Write-Host ""
            
            # Display new alerts if any
            if ($newAlerts.Count -gt 0) {
                Write-Host "🚨 NEW ALERTS DETECTED! 🚨" -ForegroundColor Red -BackgroundColor Yellow
                Write-Host ""
                foreach ($alert in $newAlerts) {
                    Write-Host "  ⚠️  $($alert.PC) - $($alert.User)" -ForegroundColor Red
                    if ($alert.Type -eq "App") {
                        Write-Host "     Suspicious App: $($alert.Name)" -ForegroundColor Red
                    } else {
                        Write-Host "     Suspicious Website: $($alert.Name)" -ForegroundColor Red
                    }
                    if ($alert.Details) {
                        Write-Host "     Details: $($alert.Details)" -ForegroundColor DarkRed
                    }
                    Write-Host ""
                }
            }
            
            # Display real-time table
            if ($activityResults.Count -gt 0) {
                # Sort: suspicious first, then by PC name
                $sortedResults = $activityResults | Sort-Object @{
                    Expression = { $_.SuspiciousApps }
                    Descending = $true
                }, Computer
                
                Write-Host "PC Name       | User              | Active Process      | CPU% | RAM% | Status" -ForegroundColor Yellow
                Write-Host "------------- | ----------------- | ------------------- | ---- | ---- | ------" -ForegroundColor DarkGray
                
                foreach ($result in $sortedResults) {
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
                    
                    # Safe string conversion for CPU and Memory
                    $cpuValue = if ($null -ne $result.CPUUsage) { $result.CPUUsage } else { 0 }
                    $memValue = if ($null -ne $result.MemoryUsage) { $result.MemoryUsage } else { 0 }
                    $cpu = $cpuValue.ToString().PadRight(4)
                    $mem = $memValue.ToString().PadRight(4)
                    
                    if ($result.SuspiciousApps -gt 0) {
                        $status = "⚠️ ALERT"
                        # Flash red background for suspicious activity
                        Write-Host "$pcName | $user | $process | $cpu | $mem | $status" -ForegroundColor White -BackgroundColor Red
                        
                        # Show what suspicious apps they're using
                        foreach ($susProc in $result.SuspiciousProcesses) {
                            $appInfo = "Suspicious: $($susProc.Name)"
                            if ($susProc.MainWindowTitle) {
                                $appInfo += " - $($susProc.MainWindowTitle)"
                            }
                            Write-Host "              └─> $appInfo" -ForegroundColor Red
                        }
                    } elseif ($result.LoggedInUser -eq "No user") {
                        $status = "Idle"
                        Write-Host "$pcName | $user | $process | $cpu | $mem | $status" -ForegroundColor DarkGray
                    } else {
                        $status = "Active"
                        Write-Host "$pcName | $user | $process | $cpu | $mem | $status" -ForegroundColor Cyan
                        
                        # Show what they're actively using
                        if ($result.ActiveWindow) {
                            Write-Host "              └─> Using: $($result.ActiveWindow)" -ForegroundColor Gray
                        }
                        
                        # Show productive apps if any
                        if ($result.ProductiveApps -gt 0 -and $result.ProductiveProcesses.Count -gt 0) {
                            $prodApps = ($result.ProductiveProcesses | Select-Object -First 2 -ExpandProperty Name) -join ', '
                            Write-Host "              └─> Apps: $prodApps" -ForegroundColor Green
                        }
                    }
                }
            }
            
            Write-Host ""
            Write-Host "=============================================" -ForegroundColor Cyan
            
            # Countdown with screen refresh every second
            for ($i = $RefreshInterval; $i -gt 0; $i--) {
                # Calculate current elapsed time
                $currentElapsed = (Get-Date) - $startTime
                $elapsedStr = $currentElapsed.ToString('hh\:mm\:ss')
                
                # Show countdown status
                Write-Host "`rNext scan in $i seconds... | Total Elapsed: $elapsedStr | Press Ctrl+C to stop" -ForegroundColor Yellow -NoNewline
                
                # Sleep for 1 second
                Start-Sleep -Seconds 1
            }
            
            Write-Host ""  # New line after countdown completes
        }
    }
    catch [System.Management.Automation.PipelineStoppedException] {
        # Ctrl+C was pressed
        Write-Host ""
        Write-Host ""
        Write-Host "=============================================" -ForegroundColor Yellow
        Write-Host "   MONITORING STOPPED BY USER (Ctrl+C)      " -ForegroundColor Yellow
        Write-Host "=============================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Session Summary:" -ForegroundColor Cyan
        Write-Host "  Total Scans: $scanCount" -ForegroundColor White
        Write-Host "  Duration: $($elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor White
        Write-Host "  Total Alerts: $($alertHistory.Count)" -ForegroundColor $(if ($alertHistory.Count -gt 0) { "Red" } else { "Green" })
        Write-Host ""
        
        if ($alertHistory.Count -gt 0) {
            Write-Host "Alert History:" -ForegroundColor Red
            Write-Host "-------------------------------------------" -ForegroundColor DarkGray
            $alertHistory.Keys | ForEach-Object {
                $parts = $_ -split '-'
                $alertTime = $alertHistory[$_]
                $alertType = if ($parts[1] -eq "APP") { "App" } else { "Web" }
                Write-Host "  $($alertTime.ToString('HH:mm:ss')) - $($parts[0]) - [$alertType] $($parts[2])" -ForegroundColor Yellow
            }
            Write-Host ""
        }
        
        Write-Host "Press any key to return to menu..." -ForegroundColor Cyan
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    catch {
        Write-Host ""
        Write-Host "Error during monitoring: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Pause
    }
}

