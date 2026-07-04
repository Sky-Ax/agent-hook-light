package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

func appendRotatingJSONL(path string, record hookLogRecord, maxBytes int64, backups int) error {
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return err
	}

	line, err := json.Marshal(record)
	if err != nil {
		return err
	}
	line = append(line, '\n')

	if maxBytes > 0 {
		if info, err := os.Stat(path); err == nil && info.Size()+int64(len(line)) > maxBytes {
			if err := rotateLog(path, backups); err != nil {
				return err
			}
		}
	}

	file, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer file.Close()

	_, err = file.Write(line)
	return err
}

func rotateLog(path string, backups int) error {
	if backups <= 0 {
		return os.Remove(path)
	}

	oldest := fmt.Sprintf("%s.%d", path, backups)
	_ = os.Remove(oldest)

	for i := backups - 1; i >= 1; i-- {
		src := fmt.Sprintf("%s.%d", path, i)
		dst := fmt.Sprintf("%s.%d", path, i+1)
		if fileExists(src) {
			_ = os.Remove(dst)
			if err := os.Rename(src, dst); err != nil {
				return err
			}
		}
	}

	first := path + ".1"
	_ = os.Remove(first)
	return os.Rename(path, first)
}
