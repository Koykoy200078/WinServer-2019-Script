# Real-Time Monitor - Quick Reference

## 🔴 NEW FEATURE: Live Continuous Monitoring with Ctrl+C Support

### Menu Location
**Option 26** - LAB MONITORING Section

### What's Different from Regular Monitor (Option 25)?

| Feature | Regular Monitor (25) | Real-Time Monitor (26) |
|---------|---------------------|------------------------|
| Mode | One-time scan | Continuous scanning |
| Refresh | Manual | Auto (5-60 seconds) |
| Alerts | View after scan | Immediate visual alerts |
| Stop | Automatic | Ctrl+C anytime |
| Color Warnings | Yes | **RED BACKGROUND** |
| Alert History | No | Yes, tracked |
| New Alerts | No | **Highlighted** |

## 🎯 Key Features

### 1. **Continuous Auto-Refresh**
- Scans every 10 seconds (default)
- Customizable: 5-60 seconds
- Screen auto-clears each refresh
- Shows scan count and elapsed time

### 2. **Visual Alerts - RED WARNINGS**
```
PC Name       | User              | Active Process      | CPU% | RAM% | Status
------------- | ----------------- | ------------------- | ---- | ---- | ------
PC-16         | DOMAIN\student16  | steam               | 45   | 68   | ⚠️ ALERT
              └─> Suspicious: steam
```
**Suspicious PCs shown with RED BACKGROUND!**

### 3. **New Alert Detection**
```
🚨 NEW ALERTS DETECTED! 🚨

  ⚠️  PC-16 - DOMAIN\student16
     App: Steam
     Window: Steam - Playing Counter-Strike
```

### 4. **Ctrl+C to Stop**
Press Ctrl+C anytime to safely exit and see session summary:
```
=============================================
   MONITORING STOPPED BY USER (Ctrl+C)
=============================================

Session Summary:
  Total Scans: 15
  Duration: 00:02:30
  Total Alerts: 3

Alert History:
-------------------------------------------
  14:35:22 - PC-16 - steam
  14:35:42 - PC-22 - discord
  14:36:15 - PC-8 - roblox
```

### 5. **Alert Tracking**
- Remembers all alerts during session
- Shows timestamp of first detection
- Prevents duplicate warnings

## 📊 Display Format

### Header (Updates Every Scan)
```
=============================================
   REAL-TIME MONITOR - SCAN #15
=============================================
Time: 14:37:45 | Elapsed: 00:02:30 | Next refresh: 10s
Press Ctrl+C to stop
=============================================
```

### Summary Statistics
```
SUMMARY:
  Online: 32 / 35
  Suspicious Activity: 3 PCs          ← RED if > 0
  Total Alerts This Session: 5
```

### Live Table (Auto-sorted)
- **RED BACKGROUND**: PCs with suspicious apps (sorted first)
- **Cyan**: Normal active PCs
- **Gray**: Idle PCs (no user logged in)

## 🚀 Usage

### Quick Start - Monitor All PCs
```
Menu → 26 → 1

[Monitoring starts, refreshes every 10 seconds]
[Press Ctrl+C when done]
```

### Monitor Specific Section
```
Menu → 26 → 3
Start: 1
End: 15

[Monitors PC-1 to PC-15 continuously]
[Press Ctrl+C to stop]
```

### Custom Refresh Rate
```
Menu → 26 → 4
Interval: 5

[Faster scanning every 5 seconds]
[Press Ctrl+C to stop]
```

## 🎓 Teacher Use Cases

### Use Case 1: During Exam (Strict Monitoring)
```
Start: Before exam begins
Menu → 26 → 1
Interval: 5 seconds (quick detection)

Watch for RED alerts
Any suspicious app = immediate action
Ctrl+C after exam ends
```

**Benefits:**
- Immediate detection of cheating tools
- RED alerts impossible to miss
- Complete session history
- 5-second refresh catches quick violations

### Use Case 2: During Class (Moderate Monitoring)
```
Start: During lab work
Menu → 26 → 1
Interval: 10 seconds (default)

Monitor for gaming/chat apps
Allow some flexibility
Ctrl+C at end of class
```

**Benefits:**
- Balance between monitoring and privacy
- Catch persistent gaming
- Don't interrupt for brief distractions
- Session summary for records

### Use Case 3: Free Time (Light Monitoring)
```
Start: Study hall / free period
Menu → 26 → 3
Range: 1-20 (active section)
Interval: 30 seconds

Just awareness, not enforcement
Ctrl+C when period ends
```

**Benefits:**
- Less intrusive
- Still catch major violations
- Students know they're monitored
- Resource-efficient

### Use Case 4: Targeted Monitoring
```
Situation: Specific students suspected of gaming
Menu → 26 → 2
PC: PC-15

[Watch one PC intensely]
[Press Ctrl+C when evidence gathered]
```

## ⚠️ Alert Response Guide

### 🔴 Critical (During Exams)
```
Alert: Steam, Roblox, Discord, etc.
Action: IMMEDIATE
1. Note the PC and student
2. Keep monitoring (don't stop)
3. Investigate after collecting evidence
4. Document in session summary
```

### 🟡 Warning (During Class)
```
Alert: Spotify, YouTube (if blocked)
Action: DELAYED
1. Note first occurrence
2. If persists for 2+ scans, warn student
3. Continue monitoring
4. Review session summary
```

### 🟢 Info (Free Time)
```
Alert: Entertainment apps
Action: AWARENESS ONLY
1. Note for trends
2. No immediate action
3. Use for future planning
```

## 💡 Pro Tips

### Tip 1: **Two-Monitor Setup**
```
Keep real-time monitor on second screen
Work on main screen
Glance for RED alerts
Don't need to actively watch
```

### Tip 2: **Strategic Timing**
```
Start monitoring BEFORE announcing it
Catch existing violations
Then inform class monitoring is active
Gaming usually stops immediately
```

### Tip 3: **Custom Intervals**
```
Exam: 5 seconds (strict)
Class: 10 seconds (balanced)
Free time: 30 seconds (relaxed)
End of day: 60 seconds (low priority)
```

### Tip 4: **Alert History as Evidence**
```
Don't stop immediately on violations
Let it run to build evidence
Session summary = timestamped proof
Shows duration and frequency
```

### Tip 5: **Range Monitoring**
```
Lab layout:
  PC 1-15: Front section
  PC 16-30: Back section
  PC 31-35: Corner stations

Monitor sections separately
Focus on problem areas
```

## 🔧 Technical Details

### Screen Updates
- **Full clear** every refresh
- **No scrolling** - fixed display
- **Sorted** - suspicious first
- **Color coded** - instant recognition

### Performance
- Default 10s = ~360 scans/hour
- 5s interval = ~720 scans/hour
- Minimal network impact
- CPU: <5% on server

### Network Traffic
- Per PC: ~2KB per scan
- 35 PCs @ 10s: ~7KB/s
- Very light bandwidth usage
- No performance impact

### Alert Detection
- Checks against 15+ suspicious apps
- Case-insensitive matching
- Partial name matching
- Process name detection

## 🆚 When to Use Each Monitor

### Use Regular Monitor (Option 25) When:
- ✅ One-time check needed
- ✅ Want detailed process lists
- ✅ Need to export report
- ✅ Investigating specific issue
- ✅ End-of-day summary

### Use Real-Time Monitor (Option 26) When:
- ✅ During exams (strict oversight)
- ✅ During class (continuous awareness)
- ✅ Catching violations in real-time
- ✅ Need immediate alerts
- ✅ Want session history
- ✅ Monitoring for extended period

## ⌨️ Keyboard Controls

| Key | Action |
|-----|--------|
| Ctrl+C | Stop monitoring immediately |
| (Auto) | Screen refreshes automatically |

**Note:** Cannot pause - only stop. Restart monitoring to continue.

## 📝 Session Summary (After Ctrl+C)

```
=============================================
   MONITORING STOPPED BY USER (Ctrl+C)
=============================================

Session Summary:
  Total Scans: 45              ← How many refreshes
  Duration: 00:07:30           ← Total monitoring time
  Total Alerts: 7              ← Unique violations

Alert History:
-------------------------------------------
  14:30:15 - PC-16 - steam     ← Timestamp, PC, App
  14:31:22 - PC-22 - discord
  14:32:45 - PC-8 - roblox
  14:33:12 - PC-16 - fortnite  ← Same PC, new app
  14:35:30 - PC-11 - spotify
  14:36:45 - PC-22 - twitch
  14:37:50 - PC-5 - netflix

Press any key to return to menu...
```

## 🎯 Best Practices

### Before Class Starts
1. Start monitoring 5 minutes before
2. Check all PCs are online
3. Verify no gaming apps running
4. Announce monitoring is active

### During Class
1. Keep monitor visible
2. Watch for RED backgrounds
3. Don't over-react to single alerts
4. Document persistent violations

### After Class
1. Press Ctrl+C to stop
2. Review session summary
3. Note any concerns
4. Save/screenshot if needed

### Weekly Review
1. Track alert trends
2. Identify problem PCs/students
3. Adjust policies as needed
4. Share summaries with admin

## 🔒 Privacy & Ethics

### Do:
- ✅ Inform students monitoring is active
- ✅ Use for educational purposes
- ✅ Document violations properly
- ✅ Respect privacy during breaks

### Don't:
- ❌ Monitor during lunch/breaks
- ❌ Share student data unnecessarily
- ❌ Use for personal curiosity
- ❌ Monitor without announcement

## 🐛 Troubleshooting

### Monitor stops immediately
- Check domain connectivity
- Verify credentials are valid
- Ensure WinRM is enabled

### No alerts showing up
- Check suspicious app list
- Verify app names match
- Apps might be minimized

### Screen flickers/jumps
- Normal - refreshing display
- Reduce refresh interval
- Close other programs

### High CPU usage
- Reduce number of PCs
- Increase refresh interval
- Check server resources

---

## Quick Command Reference

| Task | Command |
|------|---------|
| Start monitoring all | 26 → 1 |
| Monitor specific PC | 26 → 2 |
| Monitor range | 26 → 3 |
| Custom interval | 26 → 4 |
| Stop monitoring | Ctrl+C |

---

**Perfect for:** Real-time exam monitoring, class oversight, violation detection, immediate alerts, session tracking

**Key advantage:** **RED BACKGROUND ALERTS** make violations impossible to miss!
