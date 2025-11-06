# Hosts File Viewer Guide

## Overview

The **View All PC Hosts Files** feature (Option 19) allows you to retrieve and view the hosts files from all domain PCs in one operation. This is useful for auditing, verification, and troubleshooting web blocking configurations.

## Menu Location

```
█ UTILITIES
  17. Sync Time/Date/Timezone to ALL PCs from Server
  18. Clean up backup hosts files on ALL PCs
  19. View all PC hosts files          ← NEW FEATURE
  20. Export MySQL Database from a single PC
  21. Export MySQL Databases from a range of PCs
  22. Export MySQL Databases from ALL PCs
```

## How It Works

### Step 1: Retrieve Hosts Files

When you select option 19, the system will:

1. Connect to each PC (PC-1 through PC-35)
2. Verify domain membership
3. Retrieve the hosts file from `C:\Windows\System32\drivers\etc\hosts`
4. Analyze the content for:
   - Total number of lines
   - Number of blocked entries (127.0.0.1 or 0.0.0.0 entries)
   - Presence of blocking marker comments
   - Full file content

### Step 2: Summary Display

You'll see a summary table like this:

```
=============================================
     HOSTS FILES SUMMARY
=============================================

Successfully retrieved: 15 hosts files

PC Name       | Status    | Lines | Blocked | Marker
------------- | --------- | ----- | ------- | ------
PC-1          | Found     | 145   | 120     | Yes
PC-2          | Found     | 145   | 120     | Yes
PC-3          | Found     | 25    | 0       | No
PC-4          | Missing   | 0     | 0       | No
PC-5          | Found     | 145   | 120     | Yes
...
```

**Legend:**

- **Status**: Whether the hosts file exists
- **Lines**: Total number of lines in the file
- **Blocked**: Number of site blocking entries
- **Marker**: Whether the file contains a "BLOCKED BY" comment marker

**Color Coding:**

- 🔵 **Cyan**: PCs with blocked entries
- ⚪ **White**: PCs with hosts file but no blocks
- ⚫ **Dark Gray**: PCs with missing hosts file

### Step 3: View Detailed Content (Optional)

After the summary, you'll be asked:

```
Do you want to view detailed hosts file content? (y/n)
```

If you answer **Y**, you get three options:

#### Option 1: View Specific PC

```
Options:
  1. View specific PC
  2. View all PCs with blocked entries
  3. View all PCs (including empty)

Select option (1-3): 1
Enter PC name (e.g., PC-1): PC-5
```

**Output:**

```
===== HOSTS FILE: PC-5 =====
Total Lines: 145
Blocked Entries: 120
Marker: # BLOCKED BY csitlab.local

Content:
-------------------------------------------
# Copyright (c) 1993-2009 Microsoft Corp.
127.0.0.1       localhost
::1             localhost

# BLOCKED BY csitlab.local
127.0.0.1       www.facebook.com
127.0.0.1       facebook.com
127.0.0.1       www.youtube.com
...
-------------------------------------------
```

**Color Coding in Content:**

- 🟢 **Dark Green**: Comment lines (starting with #)
- 🟡 **Yellow**: Blocked site entries
- ⚪ **Gray**: Standard localhost entries
- ⚪ **White**: Other entries

#### Option 2: View PCs with Blocked Entries Only

```
Select option (1-3): 2
```

Shows detailed blocked entries for all PCs that have active blocking:

```
===== HOSTS FILE: PC-1 =====
Total Lines: 145
Blocked Entries: 120
Marker: # BLOCKED BY csitlab.local

Blocked Entries Only:
-------------------------------------------
127.0.0.1       www.facebook.com
127.0.0.1       facebook.com
127.0.0.1       www.youtube.com
127.0.0.1       youtube.com
...
-------------------------------------------

===== HOSTS FILE: PC-2 =====
...
```

#### Option 3: View All PCs

```
Select option (1-3): 3
```

Shows complete hosts file content for **all** PCs, including those without blocking.

## Use Cases

### 1. Verification After Blocking

After running web blocking on all PCs, use this feature to verify:

- Which PCs successfully received the blocking rules
- How many sites are blocked on each PC
- Whether the blocking markers are present

### 2. Audit and Compliance

Check which PCs have:

- Active web blocking
- Custom hosts file modifications
- Missing or corrupted hosts files

### 3. Troubleshooting

If a PC isn't blocking sites properly:

1. View its hosts file
2. Check if blocked entries exist
3. Verify the marker is present
4. Compare with working PCs

### 4. Cleanup Verification

After running cleanup (option 18), verify:

- No backup files remain
- Hosts files are in clean state
- Only intended blocks remain

### 5. Pre-Unblock Check

Before unblocking, see exactly what will be removed:

- View current blocked entries
- Count total blocks per PC
- Identify which PCs need unblocking

## Examples

### Example 1: Quick Check

```
Enter your choice (1-24): 19

Checking PC-1...
  ✓ Retrieved: 145 lines, 120 blocked entries
Checking PC-2...
  ✓ Retrieved: 145 lines, 120 blocked entries
...

Do you want to view detailed hosts file content? (y/n): n
```

_Result: Quick summary only, no detailed viewing_

### Example 2: Verify Specific PC

```
Enter your choice (1-24): 19
[Summary displayed]

Do you want to view detailed hosts file content? (y/n): y

Options:
  1. View specific PC
  2. View all PCs with blocked entries
  3. View all PCs (including empty)

Select option (1-3): 1
Enter PC name (e.g., PC-1): PC-10

===== HOSTS FILE: PC-10 =====
Total Lines: 25
Blocked Entries: 0
Marker: No marker

Content:
-------------------------------------------
# Copyright (c) 1993-2009 Microsoft Corp.
127.0.0.1       localhost
::1             localhost
-------------------------------------------
```

_Result: PC-10 has no blocking active_

### Example 3: Audit All Blocked PCs

```
Enter your choice (1-24): 19
[Summary displayed]

Do you want to view detailed hosts file content? (y/n): y

Options:
  1. View specific PC
  2. View all PCs with blocked entries
  3. View all PCs (including empty)

Select option (1-3): 2

[Shows all PCs with active blocking and their blocked entries]
```

_Result: See which PCs have blocking and what's blocked_

## Performance Notes

- **Retrieval Time**: ~2-5 seconds per PC
- **Total Time**: Approximately 1-3 minutes for all 35 PCs
- **Network Usage**: Minimal (only text files)
- **Requirements**: WinRM must be enabled, PCs must be online and in domain

## Limitations

1. **Domain PCs Only**: Skips PCs not in the target domain
2. **Online PCs Only**: Cannot retrieve from offline/unreachable PCs
3. **Read-Only**: This feature only views files, doesn't modify them
4. **No Export**: Content is displayed on screen, not saved to file

## Tips

### Tip 1: Save Output to File

You can save the console output:

1. Right-click PowerShell window title
2. Edit → Select All
3. Press Enter to copy
4. Paste into a text editor

### Tip 2: Combine with Other Features

Workflow example:

1. Option 10 - Block all PCs
2. Option 19 - View all hosts files (verify blocking)
3. Option 14 - Deep scan (verify functionality)
4. Option 13 - Unblock all PCs
5. Option 19 - View all hosts files (verify cleanup)

### Tip 3: Regular Audits

Run this weekly to:

- Ensure blocking is maintained
- Detect unauthorized changes
- Verify consistency across PCs

### Tip 4: Focus on Problem PCs

Use Option 1 (view specific PC) when:

- A user reports blocking issues
- A PC isn't blocking properly
- Need to verify a specific configuration

## Comparison with Deep Scan (Option 14)

| Feature                    | View Hosts Files (19) | Deep Scan (14) |
| -------------------------- | --------------------- | -------------- |
| Shows hosts file content   | ✅ Yes                | ❌ No          |
| Shows actual blocked sites | ✅ Yes                | ✅ Yes         |
| Shows firewall rules       | ❌ No                 | ✅ Yes         |
| Shows DNS cache            | ❌ No                 | ✅ Yes         |
| Full file content          | ✅ Yes                | ❌ No          |
| Export capability          | ❌ No                 | ❌ No          |

**Use Both For**: Complete visibility into blocking configuration

## Security Considerations

- Requires admin credentials for remote access
- Read-only operation - cannot modify files
- Only accesses system hosts file
- Respects domain membership verification

---

**Quick Reference:**

- Menu: Option **19**
- Function: `Show-AllHostsFiles`
- Module: `Functions/Utilities.ps1`
- Retrieves: All PC hosts files from domain
- Display: Summary table + optional detailed view
