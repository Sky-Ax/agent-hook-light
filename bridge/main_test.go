package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestRunHookWritesStatusAndRedactedLog(t *testing.T) {
	dir := t.TempDir()
	statusPath := filepath.Join(dir, "codex-status.json")
	logPath := filepath.Join(dir, "codex-hook-log.jsonl")
	input := `{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt":"secret prompt","cwd":"E:\\ai\\ai-hook"}`
	now := time.Date(2026, 7, 4, 17, 50, 0, 0, time.UTC)

	err := runHook([]string{"-status", statusPath, "-log", logPath}, strings.NewReader(input), now)
	if err != nil {
		t.Fatalf("runHook failed: %v", err)
	}

	var status statusFile
	readJSONFile(t, statusPath, &status)
	if status.State != "working" {
		t.Fatalf("state = %q, want working", status.State)
	}
	if status.Sessions["s1"].State != "working" {
		t.Fatalf("session state = %q, want working", status.Sessions["s1"].State)
	}

	logContent, err := os.ReadFile(logPath)
	if err != nil {
		t.Fatalf("read log: %v", err)
	}
	if strings.Contains(string(logContent), "secret prompt") {
		t.Fatalf("log should not contain raw prompt: %s", logContent)
	}
}

func TestRunHookMapsParseErrorToAttention(t *testing.T) {
	dir := t.TempDir()
	statusPath := filepath.Join(dir, "codex-status.json")
	logPath := filepath.Join(dir, "codex-hook-log.jsonl")

	err := runHook([]string{"-status", statusPath, "-log", logPath}, strings.NewReader("{bad json"), time.Now())
	if err != nil {
		t.Fatalf("runHook failed: %v", err)
	}

	var status statusFile
	readJSONFile(t, statusPath, &status)
	if status.State != "attention" {
		t.Fatalf("state = %q, want attention", status.State)
	}
	if status.Color != "red" {
		t.Fatalf("color = %q, want red", status.Color)
	}
}

func TestAppendRotatingJSONL(t *testing.T) {
	dir := t.TempDir()
	logPath := filepath.Join(dir, "codex-hook-log.jsonl")
	record := hookLogRecord{
		Time:     "2026-07-04 17:50:00",
		TimeISO:  "2026-07-04T09:50:00Z",
		Provider: "codex",
		Event:    "PreToolUse",
		Status:   hookStatus{State: "working", Color: "yellow", Reason: "PreToolUse"},
	}

	for i := 0; i < 3; i++ {
		if err := appendRotatingJSONL(logPath, record, 120, 2); err != nil {
			t.Fatalf("appendRotatingJSONL failed: %v", err)
		}
	}

	if _, err := os.Stat(logPath); err != nil {
		t.Fatalf("current log missing: %v", err)
	}
	if _, err := os.Stat(logPath + ".1"); err != nil {
		t.Fatalf("rotated log missing: %v", err)
	}
}

func readJSONFile(t *testing.T, path string, value any) {
	t.Helper()

	content, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	if err := json.Unmarshal(content, value); err != nil {
		t.Fatalf("parse %s: %v", path, err)
	}
}
