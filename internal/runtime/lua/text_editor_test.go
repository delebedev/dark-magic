package modruntime

import "testing"

func TestTextEditor(t *testing.T) {
	var request TextEditRequest
	editor := NewTextEditor(func(value TextEditRequest) { request = value })
	id, err := editor.Begin("hé", "Character name", false)
	if err != nil || request.ID != id || request.Value != "hé" {
		t.Fatalf("request=%+v error=%v", request, err)
	}
	if _, err := editor.Begin("other", "other", false); err == nil {
		t.Fatal("replaced active edit")
	}
	if err := editor.Complete(id+1, "wrong", true); err == nil {
		t.Fatal("accepted stale completion")
	}
	if done, _, _ := editor.Result(id); done {
		t.Fatal("completed before native response")
	}
	if err := editor.Complete(id, "Náme", true); err != nil {
		t.Fatal(err)
	}
	if done, accepted, value := editor.Result(id); !done || !accepted || value != "Náme" {
		t.Fatalf("result=%v/%v/%q", done, accepted, value)
	}
	if done, _, _ := editor.Result(id); done {
		t.Fatal("replayed completion")
	}
	id, err = editor.Begin("unchanged", "Name", false)
	if err != nil {
		t.Fatal(err)
	}
	if err := editor.Complete(id, "discarded", false); err != nil {
		t.Fatal(err)
	}
	if done, accepted, value := editor.Result(id); !done || accepted || value != "" {
		t.Fatal("cancel retained replacement")
	}
}
