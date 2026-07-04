package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func runHook(args []string, stdin io.Reader, now time.Time) error {
	cfg, err := parseHookFlags(args)
	if err != nil {
		return err
	}

	if cfg.statusPath == "" || cfg.logPath == "" {
		root, err := findProjectRoot()
		if err != nil {
			return err
		}
		if cfg.statusPath == "" {
			cfg.statusPath = filepath.Join(root, "data", "codex-status.json")
		}
		if cfg.logPath == "" {
			cfg.logPath = filepath.Join(root, "data", "codex-hook-log.jsonl")
		}
	}

	input, err := readAllText(stdin)
	if err != nil {
		return err
	}

	event := parseHookInput(input)
	status := mapHookStatus(event)
	eventName := pickEventName(event)
	updatedAt := formatLocalTime(now)
	updatedAtISO := now.UTC().Format(time.RFC3339Nano)

	session := sessionStatus{
		Provider:     "codex",
		State:        status.State,
		Color:        status.Color,
		Reason:       status.Reason,
		Event:        eventName,
		SessionID:    event.SessionID,
		ToolName:     event.ToolName,
		Cwd:          event.Cwd,
		UpdatedAt:    updatedAt,
		UpdatedAtISO: updatedAtISO,
	}

	if cfg.logEnabled {
		record := hookLogRecord{
			Time:      updatedAt,
			TimeISO:   updatedAtISO,
			Provider:  "codex",
			Event:     eventName,
			SessionID: event.SessionID,
			ToolName:  event.ToolName,
			Cwd:       event.Cwd,
			Status:    status,
		}
		if event.ParseError != "" {
			record.Error = event.ParseError
		}
		if os.Getenv("CODEX_HOOK_LOG_RAW") == "1" {
			if event.Raw != nil {
				record.Raw = event.Raw
			} else if event.RawInput != "" {
				record.Raw = event.RawInput
			}
		}
		if err := appendRotatingJSONL(cfg.logPath, record, cfg.maxBytes, cfg.backups); err != nil {
			return err
		}
	}

	return writeHookStatus(cfg.statusPath, event, session)
}

func parseHookFlags(args []string) (hookConfig, error) {
	cfg := hookConfig{
		maxBytes:   envInt64("AI_HOOK_LOG_MAX_BYTES", 10*1024*1024),
		backups:    envInt("AI_HOOK_LOG_BACKUPS", 5),
		logEnabled: os.Getenv("AI_HOOK_DISABLE_LOG") != "1",
	}

	flags := flag.NewFlagSet("hook", flag.ContinueOnError)
	flags.StringVar(&cfg.statusPath, "status", "", "Codex status JSON path. Default: <project>\\data\\codex-status.json")
	flags.StringVar(&cfg.logPath, "log", "", "Codex hook JSONL log path. Default: <project>\\data\\codex-hook-log.jsonl")
	flags.Int64Var(&cfg.maxBytes, "log-max-bytes", cfg.maxBytes, "Maximum hook log size before rotation")
	flags.IntVar(&cfg.backups, "log-backups", cfg.backups, "Number of rotated hook logs to keep")
	if err := flags.Parse(args); err != nil {
		return cfg, err
	}

	if cfg.maxBytes < 0 {
		cfg.maxBytes = 0
	}
	if cfg.backups < 0 {
		cfg.backups = 0
	}
	return cfg, nil
}

func readAllText(reader io.Reader) (string, error) {
	var builder strings.Builder
	scanner := bufio.NewScanner(reader)
	buffer := make([]byte, 0, 64*1024)
	scanner.Buffer(buffer, 10*1024*1024)
	for scanner.Scan() {
		builder.WriteString(scanner.Text())
		builder.WriteByte('\n')
	}
	if err := scanner.Err(); err != nil {
		return "", err
	}
	return builder.String(), nil
}

func parseHookInput(input string) codexEvent {
	if strings.TrimSpace(input) == "" {
		return codexEvent{HookEventName: "EmptyInput"}
	}

	var event codexEvent
	if err := json.Unmarshal([]byte(input), &event); err != nil {
		return codexEvent{
			HookEventName: "ParseError",
			ParseError:    err.Error(),
			RawInput:      input,
		}
	}
	var raw map[string]any
	if err := json.Unmarshal([]byte(input), &raw); err == nil {
		event.Raw = raw
	}
	return event
}

func pickEventName(event codexEvent) string {
	for _, value := range []string{event.HookEventName, event.EventName, event.Event, event.Type} {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return "unknown"
}

func mapHookStatus(event codexEvent) hookStatus {
	name := pickEventName(event)

	switch name {
	case "ParseError":
		return hookStatus{State: "attention", Color: "red", Reason: "parse_error"}
	case "EmptyInput":
		return hookStatus{State: "idle", Color: "gray", Reason: "empty_input"}
	case "PermissionRequest":
		return hookStatus{State: "attention", Color: "red", Reason: "permission_required"}
	case "Stop":
		return hookStatus{State: "idle", Color: "green", Reason: "stopped"}
	case "UserPromptSubmit", "PreToolUse", "PostToolUse", "SubagentStop":
		return hookStatus{State: "working", Color: "yellow", Reason: name}
	default:
		return hookStatus{State: "working", Color: "yellow", Reason: name}
	}
}

func writeHookStatus(path string, event codexEvent, session sessionStatus) error {
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return err
	}

	current := statusFile{}
	if content, err := os.ReadFile(path); err == nil && len(strings.TrimSpace(string(content))) > 0 {
		_ = json.Unmarshal(content, &current)
	}
	if current.Sessions == nil {
		current.Sessions = map[string]sessionStatus{}
	}
	current.Sessions[sessionKey(event)] = session

	next := statusFile{
		Provider:     session.Provider,
		State:        session.State,
		Color:        session.Color,
		Reason:       session.Reason,
		Event:        session.Event,
		SessionID:    session.SessionID,
		ToolName:     session.ToolName,
		Cwd:          session.Cwd,
		UpdatedAt:    session.UpdatedAt,
		UpdatedAtISO: session.UpdatedAtISO,
		Sessions:     current.Sessions,
	}

	content, err := json.MarshalIndent(next, "", "  ")
	if err != nil {
		return err
	}
	content = append(content, '\n')
	return os.WriteFile(path, content, 0644)
}

func sessionKey(event codexEvent) string {
	if strings.TrimSpace(event.SessionID) == "" {
		return "__unknown"
	}
	return event.SessionID
}
