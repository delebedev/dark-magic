package player

import (
	"github.com/gravestench/dark-magic/internal/game/simulation"
	d2save "github.com/gravestench/dark-magic/internal/mod/d2legacy/adapter/save"
)

// CharacterState carries only owner-private durable mechanics needed when a self-hosted client leaves.
// Presentation item rows omit modifiers and generation facts and cannot reconstruct possessions.
type CharacterState struct {
	Inventory              *d2save.Inventory   `json:"inventory,omitempty"`
	Progression            *d2save.Progression `json:"progression,omitempty"`
	DefenseBeforeEquipment *int64              `json:"defense_before_equipment,omitempty"`
	Vitality               *int64              `json:"vitality,omitempty"`
	Death                  *d2save.Death       `json:"death,omitempty"`
}

func projectCharacterState(playerID string, checkpoint simulation.Checkpoint) (*CharacterState, error) {
	identities, _ := findComponent(*checkpoint.Snapshot, "d2legacy.player.identity")
	entity, _, found := findString(identities, "player", playerID)
	if !found {
		return nil, nil
	}
	death := durableFields(*checkpoint.Snapshot, "d2legacy.player.death", entity)
	character := d2save.Character{Stats: &d2save.Stats{}, Hardcore: boolField(death, "hardcore")}
	if err := projectPossessions(playerID, checkpoint, &character); err != nil {
		return nil, err
	}
	state := &CharacterState{Inventory: character.Inventory, Progression: character.Progression, Death: character.Death}
	if combat := durableFields(*checkpoint.Snapshot, "d2legacy.player.combat_stats", entity); combat["base_defense"].Int != nil {
		value := intField(combat, "base_defense")
		state.DefenseBeforeEquipment = &value
	}
	if progression := durableFields(*checkpoint.Snapshot, "d2legacy.player.stamina_progression", entity); progression["base_vitality"].Int != nil {
		value := intField(progression, "base_vitality")
		state.Vitality = &value
	}
	return state, nil
}

// MergePrivateCharacter accepts the final authenticated owner view after its HUD identity is checked.
func MergePrivateCharacter(baseline d2save.Character, hud HUD, private PrivateView) (d2save.Character, error) {
	if private.Version != PrivateViewVersion || private.Tick != hud.Tick {
		return d2save.Character{}, ErrClientView
	}
	result, err := MergeCharacter(baseline, hud)
	if err != nil {
		return d2save.Character{}, err
	}
	if state := private.Character; state != nil {
		if err := validateCharacterState(state); err != nil {
			return d2save.Character{}, err
		}
		if state.Inventory != nil {
			result.Inventory = state.Inventory
		}
		if state.Progression != nil {
			result.Progression = state.Progression
		}
		result.Death = state.Death
		if state.DefenseBeforeEquipment != nil {
			result.Stats.Defense = int(*state.DefenseBeforeEquipment) - result.Stats.Dexterity/4
			if result.Stats.Defense < 0 {
				result.Stats.Defense = 0
			}
		}
		if state.Vitality != nil {
			result.Stats.Vitality = int(*state.Vitality)
		}
	}
	if err := d2save.ValidateCharacterContent(result); err != nil {
		return d2save.Character{}, ErrClientView
	}
	return cloneDurableCharacter(result), nil
}

func validateCharacterState(state *CharacterState) error {
	if state == nil {
		return nil
	}
	if state.DefenseBeforeEquipment != nil && (*state.DefenseBeforeEquipment < 0 || *state.DefenseBeforeEquipment > 2147483647) ||
		state.Vitality != nil && (*state.Vitality < 0 || *state.Vitality > 2147483647) {
		return ErrClientView
	}
	hardcore := state.Death != nil && state.Death.Hardcore
	if err := d2save.ValidateCharacterContent(d2save.Character{Inventory: state.Inventory, Progression: state.Progression, Death: state.Death, Hardcore: hardcore}); err != nil {
		return ErrClientView
	}
	return nil
}

// CloneCharacterState preserves defensive ownership across network snapshots.
func CloneCharacterState(state *CharacterState) *CharacterState {
	if state == nil {
		return nil
	}
	character := cloneDurableCharacter(d2save.Character{Inventory: state.Inventory, Progression: state.Progression, Death: state.Death})
	result := &CharacterState{Inventory: character.Inventory, Progression: character.Progression, Death: character.Death}
	if state.DefenseBeforeEquipment != nil {
		value := *state.DefenseBeforeEquipment
		result.DefenseBeforeEquipment = &value
	}
	if state.Vitality != nil {
		value := *state.Vitality
		result.Vitality = &value
	}
	return result
}
