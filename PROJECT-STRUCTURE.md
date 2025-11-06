# Project Structure Visualization

## File Organization

```
📁 WinServer-2019-Script/
│
├── 📄 Main.ps1 (NEW - Modular Entry Point)
│   └── Imports and orchestrates all modules
│
├── 📄 Main.ps1.backup (Original monolithic script)
│
├── 📄 Sync-DomainTime.ps1 (Standalone utility)
│
├── 📁 Functions/ (NEW - Modular Function Library)
│   │
│   ├── 📄 Helpers.ps1
│   │   ├── Test-DomainMembership()
│   │   └── Get-BlockingStatus()
│   │
│   ├── 📄 PC-Management.ps1
│   │   ├── Get-AllPCStatus()
│   │   ├── Invoke-PCShutdown()
│   │   ├── Invoke-PCRestart()
│   │   └── Invoke-DeepScan()
│   │
│   ├── 📄 Web-Blocking.ps1
│   │   ├── Invoke-WebBlocking()
│   │   ├── Invoke-WebUnblocking()
│   │   ├── Invoke-AIBlocking()
│   │   └── Show-BlockLists()
│   │
│   └── 📄 Utilities.ps1
│       ├── Sync-TimeToAllPCs()
│       ├── Invoke-BackupCleanup()
│       └── Export-MySQLDatabases()
│
├── 📁 BlockLists/
│   ├── 📄 ai-sites.txt
│   ├── 📄 gaming-sites.txt
│   ├── 📄 search-engines.txt
│   ├── 📄 shopping-entertainment.txt
│   ├── 📄 social-media.txt
│   ├── 📄 video-sites.txt
│   ├── 📄 View-BlockLists.ps1
│   ├── 📄 README.txt
│   ├── 📄 QUICK-REFERENCE.txt
│   └── 📄 SITE-LIST.txt
│
└── 📁 Documentation/
    ├── 📄 AI-BLOCKING-QUICK-START.txt
    ├── 📄 AI-BLOCKING-SUMMARY.txt
    ├── 📄 AI-ONLY-BLOCKING-GUIDE.txt
    ├── 📄 BACKUP-CLEANUP-FEATURE.txt
    ├── 📄 CONSOLE-COMMANDS-REFERENCE.txt
    ├── 📄 ENHANCED-BLOCKING-GUIDE.md
    ├── 📄 WEB-BLOCKING-GUIDE.txt
    └── 📄 README-MODULAR.md (NEW - Architecture docs)
```

## Execution Flow

```
┌─────────────────────────────────────────────────────────┐
│                      Main.ps1                           │
│  (Entry Point - Loads modules, displays menu)           │
└─────────────────────────────────────────────────────────┘
                           │
                           ├─ Import Modules
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  Helpers     │  │PC-Management │  │Web-Blocking  │
│  .ps1        │  │.ps1          │  │.ps1          │
└──────────────┘  └──────────────┘  └──────────────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                           ▼
                  ┌──────────────┐
                  │  Utilities   │
                  │  .ps1        │
                  └──────────────┘
```

## Menu Structure

```
╔═══════════════════════════════════════════════════════╗
║       PC MANAGEMENT SYSTEM - MAIN MENU                ║
╠═══════════════════════════════════════════════════════╣
║                                                       ║
║ █ PC MANAGEMENT (Green)                              ║
║   ├─ 1-7: Status, Shutdown, Restart operations       ║
║   └─ Module: PC-Management.ps1                       ║
║                                                       ║
║ █ WEB BLOCKING (Yellow)                              ║
║   ├─ 8-16: Blocking, Unblocking, AI-only, Scan       ║
║   └─ Module: Web-Blocking.ps1                        ║
║                                                       ║
║ █ UTILITIES (Magenta)                                ║
║   ├─ 17-21: Time sync, Cleanup, MySQL export         ║
║   └─ Module: Utilities.ps1                           ║
║                                                       ║
║ █ SYSTEM (Gray)                                      ║
║   └─ 22-23: Clear screen, Exit                       ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
```

## Function Call Flow Example

```
User selects Option 10: "Block Web/DNS access on ALL PCs"
│
├─ Main.ps1 receives choice '10'
│
├─ Main.ps1 creates target array: PC-1 to PC-35
│
├─ Main.ps1 calls: Invoke-WebBlocking -Targets $targets -BlockedSites $blockedSites
│
├─ Web-Blocking.ps1 executes Invoke-WebBlocking()
│   │
│   ├─ For each PC in targets:
│   │   │
│   │   ├─ Test-WSMan (check if PC is online)
│   │   │
│   │   ├─ Call Helpers.ps1: Test-DomainMembership()
│   │   │   └─ Returns true if PC in csitlab.local
│   │   │
│   │   ├─ If domain member:
│   │   │   │
│   │   │   ├─ Invoke-Command to remote PC
│   │   │   │
│   │   │   ├─ Modify hosts file
│   │   │   ├─ Flush DNS cache
│   │   │   ├─ Kill browser processes
│   │   │   └─ Verify blocking
│   │   │
│   │   └─ Display results
│   │
│   └─ Show summary report
│
└─ Return to menu
```

## Module Dependencies

```
Main.ps1
   │
   ├── requires → Helpers.ps1 (base module, no dependencies)
   │
   ├── requires → PC-Management.ps1
   │   └── depends on → Helpers.ps1 (Test-DomainMembership, Get-BlockingStatus)
   │
   ├── requires → Web-Blocking.ps1
   │   └── depends on → Helpers.ps1 (Test-DomainMembership)
   │
   └── requires → Utilities.ps1
       └── depends on → Helpers.ps1 (Test-DomainMembership)
```

## Benefits Visualization

```
┌─────────────────────────────────────────────────────────┐
│           BEFORE (Monolithic)                           │
├─────────────────────────────────────────────────────────┤
│  Main.ps1 (1839 lines)                                  │
│  ├─ All functions mixed together                        │
│  ├─ Hard to navigate                                    │
│  ├─ Difficult to maintain                               │
│  └─ Single point of failure                             │
└─────────────────────────────────────────────────────────┘
                           │
                           │ REFACTORED
                           ▼
┌─────────────────────────────────────────────────────────┐
│           AFTER (Modular)                               │
├─────────────────────────────────────────────────────────┤
│  Main.ps1 (240 lines) - Orchestration only              │
│                                                          │
│  Functions/                                              │
│  ├─ Helpers.ps1 (100 lines) - Core utilities            │
│  ├─ PC-Management.ps1 (180 lines) - PC operations       │
│  ├─ Web-Blocking.ps1 (600 lines) - Blocking logic       │
│  └─ Utilities.ps1 (500 lines) - Additional tools        │
│                                                          │
│  ✅ Organized by functionality                          │
│  ✅ Easy to navigate and find code                      │
│  ✅ Simple to maintain and update                       │
│  ✅ Reusable modules                                    │
│  ✅ Independent testing possible                        │
└─────────────────────────────────────────────────────────┘
```
