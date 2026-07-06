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
	if status.State != "thinking" {
		t.Fatalf("state = %q, want thinking", status.State)
	}
	if status.Sessions["s1"].State != "thinking" {
		t.Fatalf("session state = %q, want thinking", status.Sessions["s1"].State)
	}

	logContent, err := os.ReadFile(logPath)
	if err != nil {
		t.Fatalf("read log: %v", err)
	}
	if strings.Contains(string(logContent), "secret prompt") {
		t.Fatalf("log should not contain raw prompt: %s", logContent)
	}
}

func TestRunHookMapsParseErrorToError(t *testing.T) {
	dir := t.TempDir()
	statusPath := filepath.Join(dir, "codex-status.json")
	logPath := filepath.Join(dir, "codex-hook-log.jsonl")

	err := runHook([]string{"-status", statusPath, "-log", logPath}, strings.NewReader("{bad json"), time.Now())
	if err != nil {
		t.Fatalf("runHook failed: %v", err)
	}

	var status statusFile
	readJSONFile(t, statusPath, &status)
	if status.State != "error" {
		t.Fatalf("state = %q, want error", status.State)
	}
	if status.Color != "red" {
		t.Fatalf("color = %q, want red", status.Color)
	}
}

func TestMapHookStatusUsesExpandedStatusVocabulary(t *testing.T) {
	tests := []struct {
		name      string
		event     codexEvent
		wantState string
		wantColor string
	}{
		{
			name:      "prompt submit maps to thinking",
			event:     codexEvent{HookEventName: "UserPromptSubmit"},
			wantState: "thinking",
			wantColor: "blue",
		},
		{
			name:      "pre tool use maps to working",
			event:     codexEvent{HookEventName: "PreToolUse"},
			wantState: "working",
			wantColor: "yellow",
		},
		{
			name:      "post tool use maps back to thinking",
			event:     codexEvent{HookEventName: "PostToolUse"},
			wantState: "thinking",
			wantColor: "blue",
		},
		{
			name:      "permission request maps to waiting",
			event:     codexEvent{HookEventName: "PermissionRequest"},
			wantState: "waiting",
			wantColor: "purple",
		},
		{
			name:      "stop maps to success",
			event:     codexEvent{HookEventName: "Stop"},
			wantState: "success",
			wantColor: "green",
		},
		{
			name:      "parse error maps to error",
			event:     codexEvent{HookEventName: "ParseError"},
			wantState: "error",
			wantColor: "red",
		},
		{
			name:      "unknown event maps to unknown",
			event:     codexEvent{HookEventName: "UnexpectedEvent"},
			wantState: "unknown",
			wantColor: "blue",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := mapHookStatus(tt.event)
			if got.State != tt.wantState {
				t.Fatalf("state = %q, want %q", got.State, tt.wantState)
			}
			if got.Color != tt.wantColor {
				t.Fatalf("color = %q, want %q", got.Color, tt.wantColor)
			}
		})
	}
}

func TestWriteHookStatusKeepsWaitingSessionAsGlobalStatus(t *testing.T) {
	dir := t.TempDir()
	statusPath := filepath.Join(dir, "codex-status.json")
	logPath := filepath.Join(dir, "codex-hook-log.jsonl")

	waitingAt := time.Date(2026, 7, 6, 16, 40, 17, 0, time.UTC)
	err := runHook(
		[]string{"-status", statusPath, "-log", logPath},
		strings.NewReader(`{"hook_event_name":"PermissionRequest","session_id":"waiting-session","cwd":"E:\\ai\\ai-hook"}`),
		waitingAt,
	)
	if err != nil {
		t.Fatalf("runHook waiting failed: %v", err)
	}

	stoppedAt := time.Date(2026, 7, 6, 16, 42, 40, 0, time.UTC)
	err = runHook(
		[]string{"-status", statusPath, "-log", logPath},
		strings.NewReader(`{"hook_event_name":"Stop","session_id":"stopped-session","cwd":"E:\\ai\\ai-hook"}`),
		stoppedAt,
	)
	if err != nil {
		t.Fatalf("runHook stop failed: %v", err)
	}

	var status statusFile
	readJSONFile(t, statusPath, &status)
	if status.State != "waiting" {
		t.Fatalf("global state = %q, want waiting", status.State)
	}
	if status.SessionID != "waiting-session" {
		t.Fatalf("global session_id = %q, want waiting-session", status.SessionID)
	}
	if status.Sessions["stopped-session"].State != "success" {
		t.Fatalf("stopped session state = %q, want success", status.Sessions["stopped-session"].State)
	}
}

func TestNormalizeStateAllowsExpandedStatusVocabulary(t *testing.T) {
	tests := map[string]string{
		"idle":      "idle",
		"thinking":  "thinking",
		"working":   "working",
		"waiting":   "waiting",
		"success":   "success",
		"error":     "error",
		"unknown":   "unknown",
		"attention": "error",
		" done ":    "success",
		"FAILED":    "error",
		"nonsense":  "unknown",
	}

	for input, want := range tests {
		if got := normalizeState(input); got != want {
			t.Fatalf("normalizeState(%q) = %q, want %q", input, got, want)
		}
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
