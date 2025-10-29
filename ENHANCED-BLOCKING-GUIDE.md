# Enhanced Domain-Specific Web Blocking System

## Overview
This enhanced PowerShell script provides comprehensive web blocking capabilities specifically designed for the **csitlab.local** domain. The system uses host file modifications to block access to categorized websites while ensuring domain security and providing detailed monitoring capabilities.

## Key Features

### 🔒 Domain-Specific Security
- **Only blocks within csitlab.local domain** - External machines are automatically skipped
- Domain membership verification before any blocking operations
- Enhanced security markers in host files with timestamps

### 📋 Comprehensive Block Lists
The system includes 4 main categories with hundreds of sites:

1. **Social Media** (100+ sites)
   - Facebook, Instagram, Twitter/X, TikTok, LinkedIn, Discord, etc.
   - Includes CDN and API endpoints

2. **Video Sites** (80+ sites)
   - YouTube, Netflix, Hulu, Disney+, Twitch, etc.
   - Streaming platforms and video sharing sites

3. **Gaming Sites** (120+ sites)
   - Steam, Epic Games, online browser games, console gaming
   - Game launchers, communities, and platforms

4. **AI Sites** (70+ sites)
   - ChatGPT, Claude, Bard/Gemini, image generators
   - AI writing tools, code assistants, and research platforms

### 🔍 Deep Scanning & Monitoring
- **Option 14**: Deep scan all PCs for blocking status
- Domain membership verification
- Detailed reporting on blocked/unblocked PCs
- Host file analysis and statistics

### 📊 Block List Management
- **Option 15**: View all current block lists with statistics
- Categorized display with site counts
- Preview of blocked sites by category
- Real-time loading from BlockLists folder

## Menu Options

### Standard Operations (1-13)
- PC status checking, shutdown, restart operations
- Web blocking/unblocking with domain verification

### Enhanced Features
- **14. Deep Scan** - Comprehensive blocking status analysis
- **15. View Current Block Lists** - Display all categories and statistics
- **16. Clear screen** - Menu refresh
- **17. Exit** - Clean exit

## File Structure
```
Scripts/
├── Main.ps1                           # Enhanced main script
├── ENHANCED-BLOCKING-GUIDE.md         # This documentation
└── BlockLists/
    ├── social-media.txt               # Social media sites (100+ entries)
    ├── video-sites.txt                # Video streaming (80+ entries)
    ├── gaming-sites.txt               # Gaming platforms (120+ entries)
    ├── ai-sites.txt                   # AI/ChatBot sites (70+ entries)
    ├── shopping-entertainment.txt     # Shopping & entertainment
    └── other block list files...
```

## Security Features

### Domain Verification
```powershell
# Automatic domain checking before blocking operations
$isDomainMember = Test-DomainMembership -ComputerName $pc
if (-not $isDomainMember) {
    Write-Host "$pc is not in csitlab.local domain - SKIPPING" -ForegroundColor Red
    continue
}
```

### Enhanced Host File Management
- Timestamped backups: `hosts.backup-20251002-143020`
- Detailed block markers with date/time stamps
- Site count tracking in host files
- Clean removal without affecting other entries

### Block Entry Example
```
# BLOCKED BY ADMIN - csitlab.local domain - 10/02/2025 2:30:20 PM
# Total sites blocked: 370
# Block applied on: 10/02/2025 2:30:20 PM

127.0.0.1 facebook.com
127.0.0.1 www.facebook.com
127.0.0.1 instagram.com
... (370+ entries)

# END BLOCKED BY ADMIN
```

## Usage Instructions

### Initial Setup
1. Ensure you have administrative credentials for all target PCs
2. Verify PCs are domain members of `csitlab.local`
3. Run the script with appropriate permissions

### Deep Scanning Workflow
1. Run the script and select option **14**
2. The system will:
   - Check all PCs (PC-1 to PC-35)
   - Verify domain membership
   - Analyze blocking status
   - Generate comprehensive report

### Block List Management
1. Select option **15** to view current lists
2. Review categories and site counts
3. All lists load automatically from BlockLists folder
4. Categories include social media, video, gaming, and AI sites

### Blocking Operations
1. Select blocking option (8, 9, or 10)
2. System verifies domain membership first
3. Only csitlab.local machines are processed
4. Comprehensive blocking applied with all categories

## Sample Output

### Deep Scan Results
```
===== DEEP SCAN SUMMARY =====
Total PCs scanned: 35
Domain members online: 28
PCs with blocking active: 25
PCs with blocking inactive: 3

PCs needing block activation:
  PC-12
  PC-23
  PC-31
```

### Block List Summary
```
BLOCK LIST SUMMARY:
  social-media: 105 sites
  video-sites: 83 sites
  gaming-sites: 127 sites
  ai-sites: 74 sites
  TOTAL SITES TO BLOCK: 389
```

## Technical Details

### Prerequisites
- PowerShell 5.1 or higher
- WinRM enabled on target machines
- Administrative credentials for domain PCs
- Network connectivity to csitlab.local domain

### Host File Locations
- Windows: `%SystemRoot%\System32\drivers\etc\hosts`
- Automatic backup before modifications
- DNS cache flush after changes

### Error Handling
- Offline PC detection and reporting
- Domain membership validation
- WinRM connectivity verification
- Graceful error reporting

## Maintenance

### Adding New Sites
1. Edit appropriate .txt files in BlockLists folder
2. Follow existing format (one site per line)
3. Use # for comments
4. Restart script to reload lists

### Backup Management
- Automatic timestamped backups created
- Manual backup recommended before major changes
- Host file restoration from backups if needed

## Security Notes

⚠️ **Important Security Considerations:**
- Only affects csitlab.local domain members
- Requires administrative privileges
- Creates audit trail with timestamps
- Reversible blocking with clean unblock option
- Does not affect non-domain machines

## Support & Troubleshooting

### Common Issues
1. **"Not in domain" messages**: Verify PC is joined to csitlab.local
2. **WinRM errors**: Check WinRM service and firewall
3. **Permission denied**: Ensure administrative credentials
4. **Sites not blocked**: Verify DNS cache flush and browser restart

### Log Files
- Host file backups serve as change logs
- PowerShell execution logs available
- Deep scan results provide status history

---

**Last Updated**: October 2, 2025  
**Version**: 2.0 Enhanced Domain-Specific Blocking  
**Target Domain**: csitlab.local