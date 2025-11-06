# PC Management System - Modular Architecture

## Overview
This PC Management System has been refactored into a modular architecture for better organization, maintainability, and scalability.

## Project Structure

```
WinServer-2019-Script/
│
├── Main.ps1                    # Main entry point - orchestrates all operations
├── Main.ps1.backup             # Backup of original monolithic script
├── Sync-DomainTime.ps1         # Standalone time sync utility
│
├── Functions/                  # Modular function libraries
│   ├── Helpers.ps1             # Helper functions (domain checks, status)
│   ├── PC-Management.ps1       # PC operations (shutdown, restart, status)
│   ├── Web-Blocking.ps1        # Web blocking/unblocking operations
│   └── Utilities.ps1           # Utility functions (time sync, cleanup, MySQL)
│
├── BlockLists/                 # Website blocking lists
│   ├── ai-sites.txt
│   ├── gaming-sites.txt
│   ├── search-engines.txt
│   ├── shopping-entertainment.txt
│   ├── social-media.txt
│   ├── video-sites.txt
│   ├── View-BlockLists.ps1
│   ├── README.txt
│   └── QUICK-REFERENCE.txt
│
└── Documentation/              # Reference guides
    ├── AI-BLOCKING-QUICK-START.txt
    ├── AI-BLOCKING-SUMMARY.txt
    ├── AI-ONLY-BLOCKING-GUIDE.txt
    ├── BACKUP-CLEANUP-FEATURE.txt
    ├── CONSOLE-COMMANDS-REFERENCE.txt
    ├── ENHANCED-BLOCKING-GUIDE.md
    └── WEB-BLOCKING-GUIDE.txt
```

## Module Descriptions

### Main.ps1
- **Purpose**: Entry point and menu orchestration
- **Responsibilities**:
  - Load all function modules
  - Display categorized menu
  - Load block lists
  - Handle user input and route to appropriate functions
  - Manage credentials

### Functions/Helpers.ps1
- **Test-DomainMembership**: Check if PC is in csitlab.local domain
- **Get-BlockingStatus**: Check current blocking status on a PC

### Functions/PC-Management.ps1
- **Get-AllPCStatus**: Get status of all PCs (online/offline, time, timezone)
- **Invoke-PCShutdown**: Shutdown single or multiple PCs
- **Invoke-PCRestart**: Restart single or multiple PCs
- **Invoke-DeepScan**: Deep scan of all PCs for blocking status

### Functions/Web-Blocking.ps1
- **Invoke-WebBlocking**: Block web access on PCs (hosts file + DNS + firewall)
- **Invoke-WebUnblocking**: Remove web blocking from PCs
- **Invoke-AIBlocking**: Block AI sites only (preserves other sites)
- **Show-BlockLists**: Display current block lists with categorization

### Functions/Utilities.ps1
- **Sync-TimeToAllPCs**: Synchronize time/date/timezone from server to all PCs
- **Invoke-BackupCleanup**: Clean up old backup hosts files
- **Export-MySQLDatabases**: Export MySQL databases from remote PCs

## Menu Categories

### 🟢 PC MANAGEMENT (Options 1-7)
- PC status checking
- Shutdown operations (single, range, all)
- Restart operations (single, range, all)

### 🟡 WEB BLOCKING (Options 8-16)
- Web access blocking (single, range, all)
- Web access unblocking (single, range, all)
- Deep scan for blocking status
- View block lists
- AI-only blocking

### 🟣 UTILITIES (Options 17-21)
- Time synchronization
- Backup file cleanup
- MySQL database export

### ⚫ SYSTEM (Options 22-23)
- Clear screen
- Exit

## Benefits of Modular Architecture

1. **Maintainability**: Easy to locate and update specific functions
2. **Reusability**: Functions can be imported and used in other scripts
3. **Scalability**: Easy to add new features in appropriate modules
4. **Testing**: Individual modules can be tested independently
5. **Collaboration**: Multiple developers can work on different modules
6. **Organization**: Clear separation of concerns

## Usage

### Running the Main Script
```powershell
cd d:\Projects\WinServer-2019-Script
.\Main.ps1
```

### Importing Specific Modules
```powershell
# Import only the helpers
Import-Module .\Functions\Helpers.ps1

# Import web blocking functions
Import-Module .\Functions\Web-Blocking.ps1

# Use a specific function
Test-DomainMembership -ComputerName "PC-1"
```

### Adding New Functions

1. **Determine the appropriate module** based on function category
2. **Add the function** to the module file
3. **Export the function** using `Export-ModuleMember`
4. **Update Main.ps1** to call the new function

Example:
```powershell
# In Functions/PC-Management.ps1
function Get-PCHardwareInfo {
    param([array]$Targets)
    # Function implementation
}

Export-ModuleMember -Function Get-AllPCStatus, Invoke-PCShutdown, Invoke-PCRestart, Invoke-DeepScan, Get-PCHardwareInfo
```

## Requirements

- **PowerShell 5.1** or higher
- **Administrator credentials** for target PCs
- **Windows Remote Management (WinRM)** enabled on target PCs
- **Domain**: All operations target csitlab.local domain
- **Target PCs**: PC-1 through PC-35

## Domain Restrictions

All operations **ONLY** affect PCs that are members of the **csitlab.local** domain. 
PCs not in this domain will be automatically skipped with a warning message.

## Notes

- Original monolithic script is backed up as `Main.ps1.backup`
- All modules use `$script:` scope for shared variables (credentials, paths)
- Functions include error handling and informative output
- Domain membership is verified before executing operations
- Block lists are loaded from the `BlockLists` folder at startup

## Troubleshooting

If you encounter module loading errors:
```powershell
# Ensure execution policy allows scripts
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Force reload all modules
Import-Module .\Functions\Helpers.ps1 -Force
Import-Module .\Functions\PC-Management.ps1 -Force
Import-Module .\Functions\Web-Blocking.ps1 -Force
Import-Module .\Functions\Utilities.ps1 -Force
```

## Version History

- **v2.0** - Modular architecture implementation
  - Separated functions into categorized modules
  - Improved menu organization
  - Enhanced code maintainability

- **v1.0** - Original monolithic script
  - All functions in single Main.ps1 file
  - Backed up as Main.ps1.backup
