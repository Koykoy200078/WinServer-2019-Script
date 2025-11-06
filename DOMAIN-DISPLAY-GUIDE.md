# Domain Display and Selection Guide

## Visual Domain Indicators

The system now uses **color-coded domain display** to help you quickly identify your domain configuration:

### 🟢 Green = Default Domain (csitlab.local)

When the detected or selected domain matches the default `csitlab.local`, it's displayed in **GREEN**.

### 🔴 Red = Different Domain

When using a different domain, it's displayed in **RED** to indicate it differs from the default.

## Startup Sequence

### Step 1: Domain Detection & Display

```
=============================================
     DOMAIN CONFIGURATION
=============================================

Detected Domain: csitlab.local
  ✓ Matches default domain

Default Domain: csitlab.local

Options:
  1. Use detected domain: csitlab.local
  2. Use default domain: csitlab.local
  3. Enter custom domain

Select option (1-3) [Press Enter for detected domain]:
```

### Step 2: Credential Entry

```
===== DOMAIN-SPECIFIC WEB BLOCKING SYSTEM =====
Active Domain: csitlab.local  (GREEN if default, RED if different)

Please enter admin credentials for domain PCs:
```

### Step 3: Menu Display

```
=============================================
     PC MANAGEMENT SYSTEM - MAIN MENU
=============================================
Active Domain: csitlab.local  (GREEN if default, RED if different)
=============================================
```

## Example Scenarios

### Scenario 1: Default Domain Detected (GREEN)

```
Detected Domain: csitlab.local ✓ (GREEN)
  ✓ Matches default domain

Default Domain: csitlab.local

[Press Enter to use detected domain]

Active Domain: csitlab.local (GREEN in menu)
```

### Scenario 2: Different Domain Detected (RED)

```
Detected Domain: contoso.local (RED)
  ✗ Different from default domain (csitlab.local)

Default Domain: csitlab.local

Options:
  1. Use detected domain: contoso.local
  2. Use default domain: csitlab.local
  3. Enter custom domain

Select option (1-3):
```

**If you select option 1:**

```
Active Domain: contoso.local (RED in menu)
```

**If you select option 2:**

```
Active Domain: csitlab.local (GREEN in menu)
```

### Scenario 3: Not Domain-Joined (RED)

```
Detected Domain: Not domain-joined (WORKGROUP) (RED)

Default Domain: csitlab.local

Options:
  1. Use detected domain: Not domain-joined (WORKGROUP)
  2. Use default domain: csitlab.local
  3. Enter custom domain

[Automatically uses default if you press Enter]

Active Domain: csitlab.local (GREEN in menu)
```

### Scenario 4: Custom Domain Entry (RED)

```
Select option: 3
Enter domain name: mydomain.local

Using custom domain: mydomain.local

Active Domain: mydomain.local (RED in menu)
```

## Color Coding Logic

### GREEN Display Conditions:

- ✅ Domain exactly matches "csitlab.local"
- ✅ Indicates default/expected configuration

### RED Display Conditions:

- ❌ Domain is different from "csitlab.local"
- ❌ Domain is "WORKGROUP" or unable to detect
- ❌ Custom domain entered

## Quick Reference

| Displayed Text                  | Color    | Meaning                                   |
| ------------------------------- | -------- | ----------------------------------------- |
| `csitlab.local`                 | 🟢 GREEN | Default domain - all good!                |
| `contoso.local`                 | 🔴 RED   | Different domain - verify this is correct |
| `Not domain-joined (WORKGROUP)` | 🔴 RED   | Not in a domain                           |
| `Unable to detect`              | 🔴 RED   | Detection error                           |
| Any custom domain               | 🔴 RED   | Non-default configuration                 |

## Benefits

### ✅ Visual Confirmation

- Quick glance shows if you're using the default domain
- Color coding eliminates ambiguity

### ✅ Flexibility

- Can use detected domain
- Can override with default
- Can enter custom domain

### ✅ Error Prevention

- Red warning when using non-default domain
- Helps avoid targeting wrong domain

### ✅ Always Visible

- Domain shown at startup
- Domain shown in menu header
- Always know which domain is active

## Usage Tips

### Tip 1: Quick Start (Default Domain)

```
[Press Enter] → Uses detected domain automatically
```

### Tip 2: Force Default Domain

```
Select option: 2 → Always uses csitlab.local
```

### Tip 3: Custom Domain

```
Select option: 3 → Enter any domain name
```

### Tip 4: Verify Before Operations

Check the menu header - the domain is shown in color:

- 🟢 Green = Safe to proceed with default
- 🔴 Red = Double-check you're targeting the right domain

## Menu Header Reference

Every time you see the menu, the domain is displayed:

```
=============================================
     PC MANAGEMENT SYSTEM - MAIN MENU
=============================================
Active Domain: [domain-name] (GREEN or RED)
=============================================
```

This ensures you **always know** which domain you're working with!

---

**Pro Tip**: If you see RED, it doesn't mean wrong - it just means "not the default". Make sure it's the domain you intend to manage!
