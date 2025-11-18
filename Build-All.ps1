<#
.SYNOPSIS
    Build and package the monitoring system for deployment
.DESCRIPTION
    Builds both server and client applications and creates a standalone deployment package
#>

param(
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"

# Colors
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput "`n========================================" "Cyan"
Write-ColorOutput "  Building Monitoring System" "Cyan"
Write-ColorOutput "========================================`n" "Cyan"

# Find MSBuild
$msbuildPath = "C:\Program Files\Microsoft Visual Studio\18\Professional\MSBuild\Current\Bin\MSBuild.exe"
if (-not (Test-Path $msbuildPath)) {
    $msbuildPath = "C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe"
}
if (-not (Test-Path $msbuildPath)) {
    $msbuildPath = "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
}
if (-not (Test-Path $msbuildPath)) {
    Write-ColorOutput "❌ MSBuild not found!" "Red"
    Write-ColorOutput "   Please install Visual Studio 2022" "Yellow"
    exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

# Build Server
Write-ColorOutput "🔨 Building Server Application..." "Yellow"
Push-Location $ProjectRoot
try {
    & $msbuildPath "WinServer2019.csproj" /p:Configuration=Release /t:Rebuild /v:minimal /nologo
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✓ Server build successful!" "Green"
    } else {
        throw "Server build failed"
    }
} catch {
    Write-ColorOutput "❌ Server build failed: $_" "Red"
    Pop-Location
    exit 1
}
Pop-Location

# Build Client
Write-ColorOutput "`n🔨 Building Client Application..." "Yellow"
Push-Location (Join-Path $ProjectRoot "PCMonitorClient")
try {
    & $msbuildPath "PCMonitorClient.csproj" /p:Configuration=Release /t:Rebuild /v:minimal /nologo
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✓ Client build successful!" "Green"
    } else {
        throw "Client build failed"
    }
} catch {
    Write-ColorOutput "❌ Client build failed: $_" "Red"
    Pop-Location
    exit 1
}
Pop-Location

# Create deployment package
Write-ColorOutput "`n📦 Creating deployment package..." "Yellow"
$packageDir = Join-Path $ProjectRoot "DeploymentPackage"

if (Test-Path $packageDir) {
    Remove-Item $packageDir -Recurse -Force
}
New-Item -ItemType Directory -Path $packageDir -Force | Out-Null

# Copy server files
$serverDir = Join-Path $packageDir "Server"
New-Item -ItemType Directory -Path $serverDir -Force | Out-Null
Copy-Item -Path (Join-Path $ProjectRoot "bin\Release\*") -Destination $serverDir -Recurse -Force
Write-ColorOutput "  ✓ Server files copied" "Green"

# Copy client files
$clientDir = Join-Path $packageDir "Client"
New-Item -ItemType Directory -Path $clientDir -Force | Out-Null
Copy-Item -Path (Join-Path $ProjectRoot "PCMonitorClient\bin\Release\*") -Destination $clientDir -Recurse -Force
Write-ColorOutput "  ✓ Client files copied" "Green"

# Copy deployment scripts
$scriptsDir = Join-Path $packageDir "Scripts"
New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
Copy-Item -Path (Join-Path $ScriptDir "Deploy-Standalone.ps1") -Destination $scriptsDir -Force
Copy-Item -Path (Join-Path $ProjectRoot "Deploy-MonitoringClient.ps1") -Destination $scriptsDir -Force -ErrorAction SilentlyContinue
Write-ColorOutput "  ✓ Deployment scripts copied" "Green"

# Create README
$readmePath = Join-Path $packageDir "DEPLOYMENT-README.md"
$readmeContent = @"
# PC Monitoring System - Deployment Package

## 🎯 Quick Start

### For Domain Networks:
``````powershell
# Navigate to Scripts folder
cd Scripts

# Deploy to PCs 1-35 in domain
.\Deploy-MonitoringClient.ps1 -ServerIP "192.168.2.45" -StartPC 1 -EndPC 35
``````

### For Standalone (Non-Domain) Networks:
``````powershell
# Navigate to Scripts folder
cd Scripts

# Create list of target PCs
`$targetPCs = @(
    "192.168.2.101",
    "192.168.2.102",
    "192.168.2.103"
)

# Deploy to standalone PCs
.\Deploy-Standalone.ps1 -ServerIP "192.168.2.45" -TargetPCs `$targetPCs -Username "Administrator"
``````

## 📁 Package Contents

- **Server/** - Server application (WinServer2019.exe)
- **Client/** - Silent monitoring client (PCMonitorClient.exe)
- **Scripts/** - Deployment automation scripts

## 🚀 Usage

1. **Start the Server:**
   - Run `Server\WinServer2019.exe`
   - Click **📊 Live Monitoring** button
   - Click **Start Monitoring Server**

2. **Deploy Clients:**
   - Use deployment script (see Quick Start above)
   - Clients will auto-start on PC boot

3. **View Screens:**
   - Connected PCs appear in dashboard
   - **Double-click any PC** to view their screen in real-time!
   - Or click the "👁 View" button

## 🎥 Screen Viewing Features

- **Real-time screen capture** every 1 second
- **Compressed images** (30% quality) to minimize bandwidth
- **Resized display** (50% scale) for performance
- See exactly what users are doing!

## 🔧 Configuration

Default settings:
- Server Port: **8888**
- Update Interval: **2 seconds**
- Screenshot Quality: **30%** (adjustable in code)

## 🔥 Firewall Rules

Automatically configured by deployment script:
- **Server:** Inbound TCP port 8888
- **Clients:** Outbound TCP to server

## ⚠️ Requirements

- **Server:** Windows Server 2016+ or Windows 10+
- **Clients:** Windows 10+ with .NET Framework 4.8.1
- **Network:** TCP port 8888 open between server and clients
- **Permissions:** Administrator rights on all machines

## 📊 What's Monitored

- Active window title and application
- CPU and memory usage
- Running processes
- Activity history (last 20 actions)
- **Real-time screen view** 🎥

## 🛠️ Troubleshooting

**Clients not connecting?**
1. Check firewall rules on both server and clients
2. Verify server IP is correct in client config
3. Test connectivity: `Test-NetConnection -ComputerName <ServerIP> -Port 8888`

**Screen not showing?**
1. Ensure client has latest version
2. Check network bandwidth (screenshots are compressed but still use ~50-100KB/sec)
3. Verify no antivirus blocking screen capture

**Client not starting?**
1. Check scheduled task: `Get-ScheduledTask -TaskName "PCMonitorClient"`
2. Run manually to see errors: `C:\ProgramData\PCMonitor\PCMonitorClient.exe`
3. Check event viewer for application errors

## 📝 Uninstall

To remove from a client:
``````powershell
Invoke-Command -ComputerName PC-1 -ScriptBlock {
    # Stop process
    Get-Process -Name "PCMonitorClient" -ErrorAction SilentlyContinue | Stop-Process -Force
    
    # Remove scheduled task
    Unregister-ScheduledTask -TaskName "PCMonitorClient" -Confirm:`$false
    
    # Remove files
    Remove-Item "C:\ProgramData\PCMonitor" -Recurse -Force
}
``````

## 🔒 Privacy Notice

This system captures and transmits:
- Application usage data
- System resource metrics
- **Screen images in real-time**

Ensure compliance with your organization's policies and inform users as required.

---
Built with ❤️ for Windows Server 2019 Lab Management
"@

Set-Content -Path $readmePath -Value $readmeContent -Encoding UTF8
Write-ColorOutput "  ✓ README created" "Green"

# Show package info
Write-ColorOutput "`n========================================" "Cyan"
Write-ColorOutput "  Build Complete!" "Cyan"
Write-ColorOutput "========================================" "Cyan"

$serverExe = Join-Path $serverDir "WinServer2019.exe"
$clientExe = Join-Path $clientDir "PCMonitorClient.exe"

if (Test-Path $serverExe) {
    $serverSize = [math]::Round((Get-Item $serverExe).Length / 1KB, 2)
    Write-ColorOutput "✓ Server: $serverSize KB" "Green"
}

if (Test-Path $clientExe) {
    $clientSize = [math]::Round((Get-Item $clientExe).Length / 1KB, 2)
    Write-ColorOutput "✓ Client: $clientSize KB" "Green"
}

Write-ColorOutput "`n📦 Package Location:" "Cyan"
Write-ColorOutput "   $packageDir" "White"

Write-ColorOutput "`n📋 Next Steps:" "Yellow"
Write-ColorOutput "1. Review DEPLOYMENT-README.md in the package" "White"
Write-ColorOutput "2. Copy package to deployment server" "White"
Write-ColorOutput "3. Run appropriate deployment script" "White"
Write-ColorOutput "4. Start monitoring!" "White"

Write-ColorOutput "`n✓ Build and packaging complete!`n" "Green"
