package modruntime

import (
	"errors"
	"sync"
	"unicode/utf8"
)

// TextEditRequest is copied to the platform editor; Lua retains field ownership.
type TextEditRequest struct {
	ID           int64
	Value, Title string
	Secure       bool
}

type TextEditor struct {
	mu                       sync.Mutex
	present                  func(TextEditRequest)
	serial                   int64
	pending, ready, accepted bool
	value                    string
}

func NewTextEditor(present func(TextEditRequest)) *TextEditor { return &TextEditor{present: present} }

func (e *TextEditor) Begin(value, title string, secure bool) (int64, error) {
	if e == nil || e.present == nil {
		return 0, nil
	}
	if len(value) > 16384 || len(title) > 1024 || !utf8.ValidString(value) || !utf8.ValidString(title) {
		return 0, errors.New("invalid native text edit")
	}
	e.mu.Lock()
	if e.pending {
		e.mu.Unlock()
		return 0, errors.New("a text edit is already pending")
	}
	e.serial++
	request := TextEditRequest{ID: e.serial, Value: value, Title: title, Secure: secure}
	e.pending, e.ready, e.value = true, false, ""
	e.mu.Unlock()
	e.present(request)
	return request.ID, nil
}

func (e *TextEditor) Complete(id int64, value string, accepted bool) error {
	if e == nil {
		return errors.New("native text editing is unavailable")
	}
	if len(value) > 16384 || !utf8.ValidString(value) {
		return errors.New("invalid native text result")
	}
	e.mu.Lock()
	defer e.mu.Unlock()
	if !e.pending || e.ready || id != e.serial {
		return errors.New("stale native text result")
	}
	e.ready, e.accepted = true, accepted
	if accepted {
		e.value = value
	}
	return nil
}

func (e *TextEditor) Result(id int64) (bool, bool, string) {
	if e == nil {
		return false, false, ""
	}
	e.mu.Lock()
	defer e.mu.Unlock()
	if id != e.serial || !e.ready {
		return false, false, ""
	}
	value, accepted := e.value, e.accepted
	e.pending, e.ready, e.value = false, false, ""
	return true, accepted, value
}
