# Agent Hook Light Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the project-facing identity from Agent Status Light to Agent Hook Light while preserving existing launcher behavior and saved COM port configuration.

**Architecture:** Keep `start.cmd` as the root beginner entry point. Rename the internal launcher script to `bin/agent-hook-light.ps1`, update UI/documentation strings to `Agent Hook Light`, move runtime config to `data\agent-hook-light.config.json`, and read/migrate legacy `data\agent-status-light.config.json` when present.

**Tech Stack:** Windows batch, PowerShell, Go bridge executable, existing PowerShell tests.

---

### Task 1: Test New Identity And Legacy Config Migration

**Files:**
- Modify: `test/launcher.test.ps1`

- [ ] **Step 1: Update test launcher path and temp prefix**

Use `bin\agent-hook-light.ps1` and a temp prefix of `agent-hook-light-launcher-`.

- [ ] **Step 2: Add a legacy config migration assertion**

Create a legacy `agent-status-light.config.json` containing `COM5`, call `Get-SavedSerialPort` with the new config path and legacy config path, and assert it returns `COM5` and creates `agent-hook-light.config.json`.

### Task 2: Rename Launcher Implementation

**Files:**
- Move: `bin/agent-status-light.ps1` to `bin/agent-hook-light.ps1`
- Modify: `start.cmd`

- [ ] **Step 1: Rename script and update UI strings**

Change UI header and error text to `Agent Hook Light`.

- [ ] **Step 2: Rename config file with migration**

Use `agent-hook-light.config.json` as the primary config and `agent-status-light.config.json` as a legacy fallback.

- [ ] **Step 3: Preserve UTF-8 BOM**

Keep the PowerShell launcher encoded as UTF-8 with BOM for Windows PowerShell 5.1.

### Task 3: Documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-07-05-unified-launcher.md`

- [ ] **Step 1: Update project name and structure**

Replace user-facing `Agent Status Light` with `Agent Hook Light` and update launcher script/config references.

### Task 4: Verification

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\launcher.test.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\install.test.ps1
cd bridge
go test ./...
cmd.exe /c "echo. | start.cmd -NoRun"
```
