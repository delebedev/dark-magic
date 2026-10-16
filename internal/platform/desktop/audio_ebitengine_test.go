//go:build ebitengine

package desktop

import (
	"bytes"
	"encoding/binary"
	"io"
	"log/slog"
	"testing"
	"time"

	"github.com/gravestench/dark-magic/internal/audio"
)

type testAudioPlayer struct {
	source  io.Reader
	playing bool
	volume  float64
	closed  int
}

func (p *testAudioPlayer) Play()               { p.playing = true }
func (p *testAudioPlayer) IsPlaying() bool     { return p.playing }
func (p *testAudioPlayer) SetVolume(v float64) { p.volume = v }
func (p *testAudioPlayer) Close() error        { p.closed++; p.playing = false; return nil }

func testWAV() []byte {
	var result bytes.Buffer
	result.WriteString("RIFF")
	_ = binary.Write(&result, binary.LittleEndian, uint32(40))
	result.WriteString("WAVEfmt ")
	for _, v := range []any{uint32(16), uint16(1), uint16(2), uint32(48000), uint32(192000), uint16(4), uint16(16)} {
		_ = binary.Write(&result, binary.LittleEndian, v)
	}
	result.WriteString("data")
	_ = binary.Write(&result, binary.LittleEndian, uint32(4))
	result.Write([]byte{0xe8, 3, 0xe8, 3})
	return result.Bytes()
}

func testEbitAudio(mixer *audio.Mixer) (*ebitAudioBackend, *[]*testAudioPlayer) {
	backend := newEbitAudioBackend(mixer, slog.New(slog.NewTextHandler(io.Discard, nil)))
	players := []*testAudioPlayer{}
	backend.newPlayer = func(source io.Reader) (ebitAudioPlayer, error) {
		player := &testAudioPlayer{source: source}
		players = append(players, player)
		return player, nil
	}
	return backend, &players
}

func TestEbitAudioControlsAndLoop(t *testing.T) {
	var mixer audio.Mixer
	backend, players := testEbitAudio(&mixer)
	id, err := mixer.PlayWithOptions(".wav", testWAV(), audio.PlayOptions{Bus: "music", Volume: 1, Loop: true, Stream: true, Group: "frontend"})
	if err != nil {
		t.Fatal(err)
	}
	if err := mixer.Drain(backend); err != nil {
		t.Fatal(err)
	}
	player := (*players)[0]
	if !player.playing {
		t.Fatal("player did not start")
	}
	if err := mixer.SetPan(id, 1); err != nil {
		t.Fatal(err)
	}
	if err := mixer.Fade(id, 0, 100*time.Millisecond); err != nil {
		t.Fatal(err)
	}
	mixer.Advance(50 * time.Millisecond)
	if err := mixer.Drain(backend); err != nil {
		t.Fatal(err)
	}
	if player.volume != .5 {
		t.Fatalf("volume %v", player.volume)
	}
	data := make([]byte, 16)
	if _, err := io.ReadFull(player.source, data); err != nil {
		t.Fatal(err)
	}
	for offset := 0; offset < len(data); offset += 4 {
		if binary.LittleEndian.Uint16(data[offset:]) != 0 || binary.LittleEndian.Uint16(data[offset+2:]) != 1000 {
			t.Fatalf("loop/pan output %v", data)
		}
	}
	if err := mixer.StopGroup("frontend"); err != nil {
		t.Fatal(err)
	}
	if err := mixer.Drain(backend); err != nil {
		t.Fatal(err)
	}
	backend.close()
	if player.closed != 1 || len(backend.voices) != 0 {
		t.Fatalf("close count=%d voices=%d", player.closed, len(backend.voices))
	}
}

func TestEbitAudioCompletionIsBoundedAndBadAssetDoesNotBlock(t *testing.T) {
	var mixer audio.Mixer
	backend, players := testEbitAudio(&mixer)
	if _, err := mixer.Play(".wav", []byte("broken")); err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 1000; i++ {
		if _, err := mixer.Play(".wav", testWAV()); err != nil {
			t.Fatal(err)
		}
		if err := mixer.Drain(backend); err != nil {
			t.Fatal(err)
		}
		player := (*players)[len(*players)-1]
		if data, err := io.ReadAll(player.source); err != nil || len(data) != 4 {
			t.Fatalf("decoded length=%d err=%v", len(data), err)
		}
		player.playing = false
		backend.update()
		if err := mixer.Drain(backend); err != nil {
			t.Fatal(err)
		}
		if player.closed != 1 {
			t.Fatalf("close count %d", player.closed)
		}
	}
	stats := mixer.Diagnostics()
	if stats.Active != 0 || stats.Pending != 0 || stats.Slots > 2 || len(backend.voices) != 0 {
		t.Fatalf("stats %+v voices=%d", stats, len(backend.voices))
	}
}

func TestEbitAudioRejectsTruncatedLoopsBeforeCreatingPlayer(t *testing.T) {
	truncated := testWAV()[:44]
	oversizedChunk := testWAV()
	binary.LittleEndian.PutUint32(oversizedChunk[16:], ^uint32(0))
	zeroRate := testWAV()
	binary.LittleEndian.PutUint32(zeroRate[24:], 0)
	partialFrame := testWAV()[:47]
	binary.LittleEndian.PutUint32(partialFrame[4:], 39)
	binary.LittleEndian.PutUint32(partialFrame[40:], 3)
	padded := append([]byte{}, testWAV()[:12]...)
	padded = append(padded, 'J', 'U', 'N', 'K', 1, 0, 0, 0, 0, 0)
	padded = append(padded, testWAV()[12:]...)
	binary.LittleEndian.PutUint32(padded[4:], uint32(len(padded)-8))
	for _, bad := range [][]byte{truncated, oversizedChunk, zeroRate, partialFrame, padded} {
		var mixer audio.Mixer
		backend, players := testEbitAudio(&mixer)
		if _, err := mixer.PlayWithOptions(".wav", bad, audio.PlayOptions{Volume: 1, Loop: true}); err != nil {
			t.Fatal(err)
		}
		if _, err := mixer.Play(".wav", testWAV()); err != nil {
			t.Fatal(err)
		}
		if err := mixer.Drain(backend); err != nil {
			t.Fatal(err)
		}
		if len(*players) != 1 {
			t.Fatalf("invalid WAV reached player: count=%d", len(*players))
		}
		backend.update()
		if mixer.Diagnostics().Active != 1 {
			t.Fatal("failed sound was not retired")
		}
		backend.close()
	}
}

func TestEbitAudioPCMDoesNotBlockSoundsAndCloseReleases(t *testing.T) {
	var mixer audio.Mixer
	backend, _ := testEbitAudio(&mixer)
	pcm, err := mixer.OpenPCMStream(22050, 1)
	if err != nil {
		t.Fatal(err)
	}
	if err := mixer.WritePCM(pcm, []byte{0, 0}); err != nil {
		t.Fatal(err)
	}
	id, err := mixer.Play(".wav", testWAV())
	if err != nil {
		t.Fatal(err)
	}
	if err := mixer.Drain(backend); err != nil {
		t.Fatal(err)
	}
	if len(backend.voices) != 1 {
		t.Fatalf("voices %d", len(backend.voices))
	}
	if _, ok := mixer.PCMTime(pcm); ok {
		t.Fatal("muted PCM reported a device clock")
	}
	backend.close()
	if mixer.Active(id) {
		t.Fatal("closed sound remains active")
	}
	if err := mixer.Stop(pcm); err != nil {
		t.Fatal(err)
	}
	if err := mixer.Drain(backend); err != nil {
		t.Fatal(err)
	}
}
