# Helper Functions
# Common utility functions used across modules

function Test-DomainMembership {
    param(
        [string]$ComputerName,
        [string]$TargetDomain = $script:targetDomain
    )
    
    try {
        $result = Invoke-Command -ComputerName $ComputerName -Credential $script:cred -ScriptBlock {
            $domain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
            return $domain
        } -ErrorAction Stop
        
        return $result -eq $TargetDomain
    }
    catch {
        return $false
    }
}

function Get-BlockingStatus {
    param([string]$ComputerName)
    
    try {
        $result = Invoke-Command -ComputerName $ComputerName -Credential $script:cred -ScriptBlock {
            try {
                $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
                
                if (-not (Test-Path $hostsFile)) {
                    throw "Hosts file not found"
                }
                
                # Read content with proper encoding and error handling
                $content = @()
                $retryCount = 0
                $maxRetries = 3
                
                while ($retryCount -lt $maxRetries) {
                    try {
                        # Force release any file handles
                        [System.GC]::Collect()
                        [System.GC]::WaitForPendingFinalizers()
                        
                        # Read with specific encoding to avoid stream issues
                        $content = Get-Content $hostsFile -Encoding UTF8 -ErrorAction Stop
                        break
                    }
                    catch {
                        $retryCount++
                        if ($retryCount -eq $maxRetries) {
                            throw "Failed to read hosts file after $maxRetries attempts"
                        }
                        Start-Sleep -Milliseconds 200
                    }
                }
                
                $blockedCount = ($content | Where-Object { $_ -match "BLOCKED BY ADMIN" }).Count
                $totalLines = $content.Count
                $hasBlocks = ($content | Where-Object { $_ -match "127\.0\.0\.1.*\.(com|net|org)" }).Count -gt 0
                
                return [PSCustomObject]@{
                    Computer = $env:COMPUTERNAME
                    HasBlocks = $hasBlocks
                    BlockedEntries = $blockedCount
                    TotalHostsLines = $totalLines
                    Domain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
                    Status = "SUCCESS"
                }
            }
            catch {
                return [PSCustomObject]@{
                    Computer = $env:COMPUTERNAME
                    HasBlocks = "ERROR"
                    BlockedEntries = "N/A"
                    TotalHostsLines = "N/A"
                    Domain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
                    Status = "ERROR"
                    ErrorMessage = $_.Exception.Message
                }
            }
        } -ErrorAction Stop
        
        return $result
    }
    catch {
        return [PSCustomObject]@{
            Computer = $ComputerName
            HasBlocks = "ERROR"
            BlockedEntries = "N/A"
            TotalHostsLines = "N/A"
            Domain = "N/A"
            Status = "CONNECTION_ERROR"
            ErrorMessage = $_.Exception.Message
        }
    }
}
