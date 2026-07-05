package main

import (
	"time"

	"go.bug.st/serial"
)

type statusFile struct {
	Provider     string                   `json:"provider,omitempty"`
	State        string                   `json:"state"`
	Color        string                   `json:"color"`
	Reason       string                   `json:"reason,omitempty"`
	Event        string                   `json:"event"`
	SessionID    string                   `json:"session_id,omitempty"`
	ToolName     string                   `json:"tool_name,omitempty"`
	Cwd          string                   `json:"cwd,omitempty"`
	UpdatedAt    string                   `json:"updatedAt,omitempty"`
	UpdatedAtISO string                   `json:"updatedAtIso,omitempty"`
	Sessions     map[string]sessionStatus `json:"sessions,omitempty"`
}

type bridgeConfig struct {
	statusPath   string
	portName     string
	baudRate     int
	interval     time.Duration
	openDelay    time.Duration
	writeTimeout time.Duration
	once         bool
	dryRun       bool
	listPorts    bool
	openSerial   func(portName string, baudRate int) (serial.Port, error)
}

type hookConfig struct {
	statusPath string
	logPath    string
	maxBytes   int64
	backups    int
	logEnabled bool
}

type codexEvent struct {
	HookEventName string         `json:"hook_event_name,omitempty"`
	EventName     string         `json:"event_name,omitempty"`
	Event         string         `json:"event,omitempty"`
	Type          string         `json:"type,omitempty"`
	SessionID     string         `json:"session_id,omitempty"`
	ToolName      string         `json:"tool_name,omitempty"`
	Cwd           string         `json:"cwd,omitempty"`
	ParseError    string         `json:"parse_error,omitempty"`
	RawInput      string         `json:"raw_input,omitempty"`
	Raw           map[string]any `json:"-"`
}

type hookStatus struct {
	State  string `json:"state"`
	Color  string `json:"color"`
	Reason string `json:"reason"`
}

type sessionStatus struct {
	Provider     string `json:"provider"`
	State        string `json:"state"`
	Color        string `json:"color"`
	Reason       string `json:"reason"`
	Event        string `json:"event"`
	SessionID    string `json:"session_id,omitempty"`
	ToolName     string `json:"tool_name,omitempty"`
	Cwd          string `json:"cwd,omitempty"`
	UpdatedAt    string `json:"updatedAt"`
	UpdatedAtISO string `json:"updatedAtIso"`
}

type hookLogRecord struct {
	Time      string     `json:"time"`
	TimeISO   string     `json:"time_iso"`
	Provider  string     `json:"provider"`
	Event     string     `json:"event"`
	SessionID string     `json:"session_id,omitempty"`
	ToolName  string     `json:"tool_name,omitempty"`
	Cwd       string     `json:"cwd,omitempty"`
	Status    hookStatus `json:"status"`
	Error     string     `json:"error,omitempty"`
	Raw       any        `json:"raw,omitempty"`
}
