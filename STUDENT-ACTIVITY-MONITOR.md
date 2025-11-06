# Student Activity Monitor - Quick Reference

## Menu Location
**Option 25** - LAB MONITORING Section

## What It Does
Real-time monitoring of student activities across all 35 PCs in your computer lab:
- See who's logged in
- Track active applications
- Detect unauthorized/gaming software
- Monitor system resources (CPU/RAM)
- View current window/activity

## Features

### 🎯 **Automatic Detection**
- **Suspicious Apps**: Games, chat apps, torrents (highlighted in RED)
  - Steam, Discord, Spotify, Telegram, WhatsApp
  - Roblox, Minecraft, Fortnite, Valorant
  - uTorrent, Netflix, Twitch, TikTok

- **Productive Apps**: Educational software (highlighted in GREEN)
  - Browsers: Chrome, Firefox, Edge
  - Office: Word, Excel, PowerPoint
  - Dev Tools: VS Code, Python, Java, MySQL

### 📊 **Information Displayed**

#### Quick Summary View:
```
PC Name       | User              | Active Process      | CPU% | RAM% | Status
------------- | ----------------- | ------------------- | ---- | ---- | ------
PC-1          | DOMAIN\student01  | chrome              | 15   | 45   | Active
PC-2          | DOMAIN\student02  | steam               | 45   | 68   | ⚠️ ALERT
PC-3          | No user logged in | explorer            | 2    | 12   | Idle
```

#### Detailed View Options:
1. **Specific PC Details**
   - Full process list
   - Window titles
   - Memory usage per app
   - Categorized apps

2. **Suspicious Activity Report**
   - Only shows PCs with games/unauthorized apps
   - Process details (PID, memory, start time)
   - Current window title

3. **All Active PCs**
   - List all PCs with logged in users
   - Current activity
   - Resource usage

4. **All Running Processes**
   - Top 10 processes by memory
   - Complete process list

## Usage

### Option 1: Monitor ALL PCs
```
Enter your choice (1-25): 25
Select option (1-4): 1

[Scans all 35 PCs and shows activity summary]
```

### Option 2: Monitor Specific PC
```
Enter your choice (1-25): 25
Select option (1-4): 2
Enter PC name: PC-15

[Shows detailed activity for PC-15 only]
```

### Option 3: Monitor Range
```
Enter your choice (1-25): 25
Select option (1-4): 3
Enter start number: 10
Enter end number: 20

[Monitors PC-10 through PC-20]
```

### Option 4: Monitor & Export Report
```
Enter your choice (1-25): 25
Select option (1-4): 4

[Monitors all PCs and saves report to Reports/ folder]
Report saved: Reports/StudentActivity_2025-11-06_14-30-45.txt
```

## Color Coding

### Summary Table:
- 🔴 **Red**: PC has suspicious/gaming apps running
- 🔵 **Cyan**: PC is active with normal apps
- ⚫ **Gray**: PC is idle (no user logged in)

### Detailed View:
- 🔴 **Red**: Suspicious/unauthorized apps
- 🟢 **Green**: Productive/educational apps
- 🟡 **Yellow**: Active window/process
- ⚪ **White**: General information

## Example Scenarios

### Scenario 1: During Class
```
Teacher wants to check if students are following along:

Option 25 → Option 1 (Monitor ALL)

Results:
✓ PC-1 to PC-15: Running Visual Studio Code (GREEN)
⚠️ PC-16: Running Steam (RED ALERT)
✓ PC-17 to PC-30: Running Chrome with assignment
○ PC-31 to PC-35: Idle (students absent)
```

**Action**: Check PC-16 in detail, warn student

### Scenario 2: Exam Time
```
Ensure no cheating/unauthorized tools:

Option 25 → Option 1 → View details → Option 2 (Suspicious only)

Results:
⚠️ PC-8: WhatsApp running
⚠️ PC-22: Discord running

No PCs found with suspicious activity ✓
```

**Action**: If alerts found, investigate immediately

### Scenario 3: End of Day Report
```
Generate activity log for admin:

Option 25 → Option 4 (Export report)

Report includes:
- Login times
- Applications used
- Suspicious activity summary
- Resource usage statistics
```

### Scenario 4: Troubleshoot Slow PC
```
Student reports PC-12 is slow:

Option 25 → Option 2
Enter PC name: PC-12

Shows:
- Chrome using 2.5 GB RAM
- 45 tabs open
- CPU at 95%
```

**Action**: Close unnecessary tabs, restart browser

## Report Export

### Location:
`D:\Projects\WinServer-2019-Script\Reports\`

### Filename Format:
`StudentActivity_YYYY-MM-DD_HH-MM-SS.txt`

### Report Contains:
```
==================================================
STUDENT ACTIVITY REPORT
==================================================
Generated: 2025-11-06 14:30:45
Domain: csitlab.local
Total PCs Scanned: 35
Online PCs: 32
PCs with Suspicious Activity: 3

----- PC-1 -----
User: CSITLAB\student01
Active: chrome - Google Classroom
CPU: 15% | RAM: 45%
Total Processes: 87
Suspicious Apps: 0
Productive Apps: 3

----- PC-16 -----
User: CSITLAB\student16
Active: Steam - Playing Games
CPU: 65% | RAM: 78%
Total Processes: 102
Suspicious Apps: 1
Productive Apps: 0

SUSPICIOUS APPLICATIONS:
  - Steam (PID: 4532) - 1250 MB
```

## Best Practices

### 1. Regular Monitoring
- Check at start of each class
- Random checks during class
- End-of-day summary

### 2. Response to Alerts
🔴 **High Priority** (During Exams):
- Immediately check suspicious PCs
- Remote lock if needed
- Document violations

🟡 **Medium Priority** (During Class):
- Note the student
- Verbal warning
- Continue monitoring

🟢 **Low Priority** (Free Time):
- Informational only
- Track trends

### 3. Privacy Considerations
- Inform students monitoring is active
- Use for educational purposes only
- Respect privacy during breaks

### 4. Performance Tips
- Monitor specific range during class (not all 35)
- Use export for historical records
- Run full scans during breaks

## Troubleshooting

### "PC offline" errors
- Check if PC is powered on
- Verify network connection
- Ensure WinRM is enabled

### "Access Denied"
- Verify admin credentials
- Check domain membership
- Ensure proper permissions

### No suspicious apps detected when you see them
- App names may differ from detection list
- Use "View all processes" option
- Check window titles

### Slow scanning
- Normal for 35 PCs (1-3 minutes)
- Monitor smaller ranges for speed
- Close other network-intensive tasks

## Tips for Teachers

💡 **Tip 1**: Start of Class Check
```
Quick scan to see attendance:
Option 25 → 1 → No details needed
Look for "No user logged in" to find absent students
```

💡 **Tip 2**: During Lab Work
```
Monitor specific lab section:
Option 25 → 3
Range: 1-15 (if teaching Section A)
```

💡 **Tip 3**: Gaming Detection
```
After break time:
Option 25 → 1 → y → 2 (Suspicious only)
Catches students who didn't close games
```

💡 **Tip 4**: Daily Reports
```
End of each day:
Option 25 → 4 (Export)
Keep for weekly review/compliance
```

💡 **Tip 5**: Resource Hogs
```
If lab is slow:
Option 25 → 1 → y → 4 (All processes)
Find PCs using too much RAM/CPU
```

## Integration with Other Features

### Combined Workflows:

**Workflow 1**: Catch Gaming During Class
```
1. Option 25 - Monitor (find gaming PCs)
2. Option 8/9 - Block web on those PCs
3. Send message to student (future feature)
```

**Workflow 2**: Pre-Exam Setup
```
1. Option 25 - Check all PCs clean
2. Option 10 - Block all web access
3. Option 25 - Monitor during exam
4. Option 13 - Unblock after exam
```

**Workflow 3**: End of Day Maintenance
```
1. Option 25 - Export daily report
2. Option 18 - Cleanup backup files
3. Option 4 - Shutdown all PCs
```

---

## Quick Command Reference

| Task | Menu Path |
|------|-----------|
| Monitor all PCs | 25 → 1 |
| Check specific PC | 25 → 2 → Enter PC name |
| Monitor range | 25 → 3 → Enter range |
| Save report | 25 → 4 |
| View suspicious | 25 → 1 → y → 2 |
| View processes | 25 → 1 → y → 4 |

---

**Perfect for**: Class monitoring, attendance tracking, gaming detection, resource monitoring, compliance reporting

**Update frequency**: Run as needed (real-time snapshot)
