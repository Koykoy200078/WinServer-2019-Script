# Web Blocking Functions
# Functions for blocking and unblocking web access on domain PCs

function Invoke-WebBlocking {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Targets,
        [Parameter(Mandatory=$true)]
        [array]$BlockedSites
    )
    
    foreach ($pc in $Targets) {
        Write-Host "Checking $pc ..." -ForegroundColor Cyan
        try {
            if (Test-WSMan -ComputerName $pc -ErrorAction Stop) {
                # Check domain membership first
                $isDomainMember = Test-DomainMembership -ComputerName $pc
                
                if (-not $isDomainMember) {
                    Write-Host "$pc is not in $script:targetDomain domain - SKIPPING blocking operation" -ForegroundColor Red
                    continue
                }
                
                Write-Host "$pc is in $script:targetDomain domain - proceeding with blocking" -ForegroundColor Green
                Write-Host "Blocking web access on $pc (Domain: $script:targetDomain)..." -ForegroundColor Yellow
                
                $result = Invoke-Command -ComputerName $pc -Credential $script:cred -ArgumentList (,$BlockedSites) -ScriptBlock {
                    param($sites)
                    
                    try {
                        $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
                        $results = @()
                        
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
                                [System.GC]::Collect()
                                [System.GC]::WaitForPendingFinalizers()
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
                        $blockMarker = "# BLOCKED BY ADMIN - $using:targetDomain domain - $(Get-Date)"
                        
                        # Remove old blocks if they exist
                        $newContent = $content | Where-Object { 
                            $_ -notmatch "BLOCKED BY ADMIN" -and 
                            $_ -notmatch "127\.0\.0\.1\s+(www\.)?(facebook|youtube|twitter|instagram|tiktok|reddit|netflix|amazon|google)" 
                        }
                        
                        # Prepare block entries
                        $blockEntries = @()
                        $blockEntries += $blockMarker
                        $blockEntries += "# Total sites blocked: $($sites.Count)"
                        $blockEntries += "# Block applied on: $(Get-Date)"
                        $blockEntries += ""
                        
                        foreach ($site in $sites) {
                            $blockEntries += "127.0.0.1 $site"
                            $blockEntries += "0.0.0.0 $site"
                            if (-not $site.StartsWith("www.")) {
                                $blockEntries += "127.0.0.1 www.$site"
                                $blockEntries += "0.0.0.0 www.$site"
                            }
                        }
                        
                        $blockEntries += ""
                        $blockEntries += "# END BLOCKED BY ADMIN"
                        
                        # Combine and write
                        $finalContent = $newContent + $blockEntries
                        
                        $writeRetryCount = 0
                        while ($writeRetryCount -lt $maxRetries) {
                            try {
                                [System.GC]::Collect()
                                [System.GC]::WaitForPendingFinalizers()
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
                        
                        # 2. DNS CACHE FLUSHING
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
                        
                        # 3. BROWSER CACHE CLEARING
                        $results += "=== BROWSER PREPARATIONS ==="
                        try {
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
                        
                        # 4. VERIFICATION
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
        }
        catch {
            Write-Host "$pc is offline or unreachable via WinRM. Error: $_" -ForegroundColor DarkGray
        }
    }
    Pause
}

function Invoke-WebUnblocking {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Targets
    )
    
    foreach ($pc in $Targets) {
        Write-Host "Checking $pc ..." -ForegroundColor Cyan
        try {
            if (Test-WSMan -ComputerName $pc -ErrorAction Stop) {
                $isDomainMember = Test-DomainMembership -ComputerName $pc
                
                if (-not $isDomainMember) {
                    Write-Host "$pc is not in $script:targetDomain domain - SKIPPING unblocking operation" -ForegroundColor Red
                    continue
                }
                
                Write-Host "$pc is in $script:targetDomain domain - proceeding with unblocking" -ForegroundColor Green
                Write-Host "Unblocking web access on $pc (Domain: $script:targetDomain)..." -ForegroundColor Yellow
                
                $result = Invoke-Command -ComputerName $pc -Credential $script:cred -ScriptBlock {
                    try {
                        $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
                        $results = @()
                        
                        if (-not (Test-Path $hostsFile)) {
                            throw "Hosts file not found at $hostsFile"
                        }
                        
                        # 1. HOSTS FILE RESTORATION
                        $results += "=== HOSTS FILE RESTORATION ==="
                        
                        $content = @()
                        $retryCount = 0
                        $maxRetries = 3
                        
                        while ($retryCount -lt $maxRetries) {
                            try {
                                [System.GC]::Collect()
                                [System.GC]::WaitForPendingFinalizers()
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
                            if ($_ -match "127\.0\.0\.1") {
                                return $_ -match "127\.0\.0\.1\s+localhost"
                            }
                            return $true
                        }
                        
                        $removedEntries = $originalCount - $newContent.Count
                        
                        $writeRetryCount = 0
                        while ($writeRetryCount -lt $maxRetries) {
                            try {
                                [System.GC]::Collect()
                                [System.GC]::WaitForPendingFinalizers()
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
                            }
                        } catch {
                            $results += "Backup cleanup warning: $($_.Exception.Message)"
                        }
                        
                        # 2. DNS CACHE FLUSHING
                        $results += "=== DNS CACHE CLEARING ==="
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
                        
                        # 3. VERIFICATION
                        $results += "=== VERIFICATION ==="
                        $testSites = @("google.com", "facebook.com", "youtube.com")
                        foreach ($testSite in $testSites) {
                            try {
                                $resolved = Resolve-DnsName -Name $testSite -ErrorAction SilentlyContinue
                                if ($resolved -and $resolved.IPAddress -notcontains "127.0.0.1") {
                                    $results += "✓ $testSite unblocked successfully"
                                } else {
                                    $results += "⚠ $testSite may still be blocked"
                                }
                            }
                            catch {
                                $results += "⚠ $testSite DNS check failed"
                            }
                        }
                        
                        return @{
                            Success = $true
                            Message = "Web unblocking completed successfully"
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
                }
            }
        }
        catch {
            Write-Host "$pc is offline or unreachable via WinRM. Error: $_" -ForegroundColor DarkGray
        }
    }
    Pause
}

function Invoke-AIBlocking {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Targets,
        [Parameter(Mandatory=$true)]
        [array]$AISites
    )
    
    foreach ($pc in $Targets) {
        Write-Host "Checking $pc ..." -ForegroundColor Cyan
        try {
            if (Test-WSMan -ComputerName $pc -ErrorAction Stop) {
                $isDomainMember = Test-DomainMembership -ComputerName $pc
                
                if (-not $isDomainMember) {
                    Write-Host "$pc is not in $script:targetDomain domain - SKIPPING AI blocking operation" -ForegroundColor Red
                    continue
                }
                
                Write-Host "$pc is in $script:targetDomain domain - proceeding with AI blocking" -ForegroundColor Green
                Write-Host "Blocking AI sites ONLY on $pc (Domain: $script:targetDomain)..." -ForegroundColor Yellow
                
                $result = Invoke-Command -ComputerName $pc -Credential $script:cred -ArgumentList (,$AISites) -ScriptBlock {
                    param($sites)
                    
                    try {
                        $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
                        $results = @()
                        
                        if (-not (Test-Path $hostsFile)) {
                            throw "Hosts file not found at $hostsFile"
                        }
                        
                        $results += "=== AI SITES BLOCKING ==="
                        
                        # Backup hosts file
                        $backupName = "$hostsFile.backup-AI-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                        Copy-Item $hostsFile $backupName -Force -ErrorAction Stop
                        $results += "Backup created: $backupName"
                        
                        # Read content
                        $content = @()
                        $retryCount = 0
                        $maxRetries = 3
                        
                        while ($retryCount -lt $maxRetries) {
                            try {
                                [System.GC]::Collect()
                                [System.GC]::WaitForPendingFinalizers()
                                $content = Get-Content $hostsFile -Encoding UTF8 -ErrorAction Stop
                                break
                            }
                            catch {
                                $retryCount++
                                if ($retryCount -eq $maxRetries) {
                                    throw "Failed to read hosts file after $maxRetries attempts"
                                }
                                Start-Sleep -Milliseconds 500
                            }
                        }
                        
                        # Remove old AI blocks
                        $blockMarker = "# BLOCKED BY ADMIN - AI SITES ONLY - $using:targetDomain domain - $(Get-Date)"
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
                            $blockEntries += "127.0.0.1 $site"
                            $blockEntries += "0.0.0.0 $site"
                            if (-not $site.StartsWith("www.")) {
                                $blockEntries += "127.0.0.1 www.$site"
                                $blockEntries += "0.0.0.0 www.$site"
                            }
                        }
                        
                        $blockEntries += ""
                        $blockEntries += "# END BLOCKED BY ADMIN - AI SITES ONLY"
                        
                        # Combine and write
                        $finalContent = $newContent + $blockEntries
                        
                        $writeRetryCount = 0
                        while ($writeRetryCount -lt $maxRetries) {
                            try {
                                [System.GC]::Collect()
                                [System.GC]::WaitForPendingFinalizers()
                                $finalContent | Out-File -FilePath $hostsFile -Encoding UTF8 -Force -ErrorAction Stop
                                break
                            }
                            catch {
                                $writeRetryCount++
                                if ($writeRetryCount -eq $maxRetries) {
                                    throw "Failed to write hosts file after $maxRetries attempts"
                                }
                                Start-Sleep -Milliseconds 500
                            }
                        }
                        
                        $results += "Hosts file updated with $($sites.Count) AI sites"
                        
                        # DNS FLUSHING
                        $results += "=== DNS FLUSHING ==="
                        try {
                            ipconfig /flushdns | Out-Null
                            $results += "DNS resolver cache flushed"
                            Clear-DnsClientCache -ErrorAction SilentlyContinue
                            $results += "DNS client cache cleared"
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
                }
            }
        }
        catch {
            Write-Host "$pc is offline or unreachable via WinRM. Error: $_" -ForegroundColor DarkGray
        }
    }
    Pause
}

function Show-BlockLists {
    param(
        [Parameter(Mandatory=$true)]
        [array]$BlockedSites,
        [Parameter(Mandatory=$true)]
        [string]$BlockListsFolder
    )
    
    Clear-Host
    Write-Host "===== CURRENT BLOCK LISTS =====" -ForegroundColor Cyan
    Write-Host "Total sites to block: $($BlockedSites.Count)" -ForegroundColor Green
    Write-Host ""
    
    $blockFiles = Get-ChildItem -Path $BlockListsFolder -Filter "*.txt" | Where-Object { 
        $_.Name -notin @("README.txt", "QUICK-REFERENCE.txt", "SITE-LIST.txt") 
    }
    
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
        
        Write-Host "$categoryName ($($sites.Count) sites):" -ForegroundColor Yellow
        Write-Host "  File: $($file.Name)" -ForegroundColor Gray
        
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

Export-ModuleMember -Function Invoke-WebBlocking, Invoke-WebUnblocking, Invoke-AIBlocking, Show-BlockLists
