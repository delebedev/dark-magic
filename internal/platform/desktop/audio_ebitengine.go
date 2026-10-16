//go:build ebitengine

package desktop

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"log/slog"

	ebitaudio "github.com/hajimehoshi/ebiten/v2/audio"
	"github.com/hajimehoshi/ebiten/v2/audio/wav"

	"github.com/gravestench/dark-magic/internal/audio"
)

const ebitAudioRate = 48000

type ebitAudioPlayer interface {
	Play()
	IsPlaying() bool
	SetVolume(float64)
	Close() error
}

type ebitVoice struct {
	player ebitAudioPlayer
	pan    *stereoPanReader
}

type ebitAudioBackend struct {
	mixer     *audio.Mixer
	logger    *slog.Logger
	voices    map[audio.SoundID]ebitVoice
	finished  []audio.SoundID
	newPlayer func(io.Reader) (ebitAudioPlayer, error)
}

func newEbitAudioBackend(mixer *audio.Mixer, logger *slog.Logger) *ebitAudioBackend {
	return &ebitAudioBackend{
		mixer: mixer, logger: logger, voices: make(map[audio.SoundID]ebitVoice),
		newPlayer: func(source io.Reader) (ebitAudioPlayer, error) {
			context := ebitaudio.CurrentContext()
			if context == nil {
				context = ebitaudio.NewContext(ebitAudioRate)
			}
			return context.NewPlayer(source)
		},
	}
}

func (b *ebitAudioBackend) Apply(command audio.Command) error {
	voice, exists := b.voices[command.ID]
	switch command.Kind {
	case "play":
		if exists {
			return fmt.Errorf("ebitengine audio: duplicate sound %v", command.ID)
		}
		if err := b.play(command); err != nil {
			// Permanent asset errors must not hold the mixer's retry queue ahead of valid cues.
			b.logger.Error("playing Ebitengine sound", "sound", command.ID, "error", err)
			b.finished = append(b.finished, command.ID)
		}
	case "volume":
		if exists {
			voice.player.SetVolume(float64(command.Volume))
		}
	case "pan":
		if exists {
			voice.pan.setPan(command.Pan)
		}
	case "stop":
		if exists {
			b.stop(command.ID, voice)
		}
	case "pcm-open", "pcm-write":
		// shortcut: cinematic PCM retains the muted adapter behavior until its playback clock is implemented.
	default:
		return fmt.Errorf("ebitengine audio: unknown command %q", command.Kind)
	}
	return nil
}

func (b *ebitAudioBackend) play(command audio.Command) error {
	if command.Format != ".wav" {
		return fmt.Errorf("unsupported audio format %q", command.Format)
	}
	if err := validateWAVPayload(command.Data); err != nil {
		return err
	}
	context := ebitaudio.CurrentContext()
	rate := ebitAudioRate
	if context != nil {
		rate = context.SampleRate()
	}
	decoded, err := wav.DecodeWithSampleRate(rate, bytes.NewReader(command.Data))
	if err != nil {
		return err
	}
	var source io.Reader = decoded
	if command.Loop {
		if decoded.Length() == 0 {
			return fmt.Errorf("cannot loop an empty WAV")
		}
		source = ebitaudio.NewInfiniteLoop(decoded, decoded.Length())
	}
	pan := &stereoPanReader{source: source}
	pan.setPan(command.Pan)
	player, err := b.newPlayer(pan)
	if err != nil {
		return err
	}
	player.SetVolume(float64(command.Volume))
	player.Play()
	b.voices[command.ID] = ebitVoice{player: player, pan: pan}
	return nil
}

// validateWAVPayload bounds decoder allocations and rejects incomplete frames before a loop can retry EOF forever.
func validateWAVPayload(data []byte) error {
	if len(data) < 12 || string(data[:4]) != "RIFF" || string(data[8:12]) != "WAVE" {
		return fmt.Errorf("invalid WAV header")
	}
	end := int64(binary.LittleEndian.Uint32(data[4:])) + 8
	if end < 12 || end > int64(len(data)) {
		return fmt.Errorf("incomplete WAV container")
	}
	frameBytes := int64(0)
	for offset := int64(12); offset+8 <= end; {
		size := int64(binary.LittleEndian.Uint32(data[offset+4:]))
		next := offset + 8 + size
		if next > end {
			return fmt.Errorf("incomplete WAV chunk")
		}
		kind := string(data[offset : offset+4])
		// shortcut: reject odd header chunks until the pinned WAV decoder handles RIFF padding.
		if kind != "data" && size%2 != 0 {
			return fmt.Errorf("odd WAV header chunks are unsupported")
		}
		switch kind {
		case "fmt ":
			if size < 16 || binary.LittleEndian.Uint32(data[offset+12:]) == 0 {
				return fmt.Errorf("invalid WAV format or sample rate")
			}
			channels := binary.LittleEndian.Uint16(data[offset+10:])
			bits := binary.LittleEndian.Uint16(data[offset+22:])
			frameBytes = int64(channels) * int64(bits/8)
		case "data":
			if frameBytes == 0 || size%frameBytes != 0 {
				return fmt.Errorf("incomplete WAV sample frame")
			}
			return nil
		}
		offset = next + size%2
	}
	return fmt.Errorf("WAV data chunk is missing")
}

func (b *ebitAudioBackend) stop(id audio.SoundID, voice ebitVoice) {
	if err := voice.player.Close(); err != nil {
		b.logger.Error("closing Ebitengine sound", "sound", id, "error", err)
	}
	delete(b.voices, id)
}

// update releases mixer slots outside Drain, which holds the mixer lock while applying commands.
func (b *ebitAudioBackend) update() {
	for id, voice := range b.voices {
		if !voice.player.IsPlaying() {
			b.stop(id, voice)
			b.finished = append(b.finished, id)
		}
	}
	for _, id := range b.finished {
		b.mixer.Release(id)
	}
	b.finished = nil
}

func (b *ebitAudioBackend) close() {
	for id, voice := range b.voices {
		b.stop(id, voice)
		b.mixer.Release(id)
	}
	for _, id := range b.finished {
		b.mixer.Release(id)
	}
	b.finished = nil
}
