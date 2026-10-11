package player

import (
	"sort"

	gameecs "github.com/gravestench/dark-magic/internal/game/ecs"
	"github.com/gravestench/dark-magic/internal/game/simulation"
	d2save "github.com/gravestench/dark-magic/internal/mod/d2legacy/adapter/save"
)

// projectPossessions reads mechanical facts from authority, never a presentation mirror.
func projectPossessions(playerID string, checkpoint simulation.Checkpoint, result *d2save.Character) error {
	snapshot := *checkpoint.Snapshot
	identities, _ := findComponent(snapshot, "d2legacy.player.identity")
	entity, _, present := findString(identities, "player", playerID)
	if !present {
		return ErrHUDPlayer
	}
	layouts, found := findComponent(snapshot, "d2legacy.items.layout")
	if found {
		if layoutEntity, fields, present := findString(layouts, "owner", playerID); present {
			inventory := &d2save.Inventory{Items: []d2save.Item{},
				InventoryWidth:  intField(fields, "inventory_width"),
				InventoryHeight: intField(fields, "inventory_height"),
				StashWidth:      intField(fields, "stash_width"),
				StashHeight:     intField(fields, "stash_height"),
				CubeWidth:       intField(fields, "cube_width"),
				CubeHeight:      intField(fields, "cube_height"),
				BeltCapacity:    intField(fields, "belt_capacity"),
				ActiveWeaponSet: intField(fields, "active_weapon_set"),
				VendorWidth:     intField(fields, "vendor_width"),
				VendorHeight:    intField(fields, "vendor_height"),
				CarriedGold:     intField(fields, "carried_gold"),
				StashedGold:     intField(fields, "stashed_gold"),
			}
			identities, _ := findComponent(snapshot, "d2legacy.item.identity")
			for _, instance := range identities.Instances {
				identity, present := findInstance(identities, instance.Entity)
				if !present || entityField(identity, "owner") != layoutEntity {
					continue
				}
				placement := durableFields(snapshot, "d2legacy.item.placement", instance.Entity)
				container := stringField(placement, "container")
				if container == "world" || container == "vendor" {
					continue
				}
				inventory.Items = append(inventory.Items, durableItem(snapshot, instance.Entity, identity, placement))
			}
			sort.Slice(inventory.Items, func(i, j int) bool { return inventory.Items[i].ID < inventory.Items[j].ID })
			corpses, _ := findComponent(snapshot, "d2legacy.player.corpse")
			for _, instance := range corpses.Instances {
				fields, _ := findInstance(corpses, instance.Entity)
				if entityField(fields, "owner") == entity {
					inventory.Corpses = append(inventory.Corpses, d2save.Corpse{ID: stringField(fields, "id")})
				}
			}
			sort.Slice(inventory.Corpses, func(i, j int) bool { return inventory.Corpses[i].ID < inventory.Corpses[j].ID })
			result.Inventory = inventory
		}
	}
	result.Death = nil
	if death := durableFields(snapshot, "d2legacy.player.death", entity); len(death) > 0 {
		result.Death = &d2save.Death{Hardcore: boolField(death, "hardcore"), CapacityExhausted: stringField(death, "stage") == "capacity_exhausted"}
	}
	progress := durableFields(snapshot, "d2legacy.player.progress", entity)
	difficulty := durableFields(snapshot, "d2legacy.player.difficulty", entity)
	highest := int64(-1)
	if len(difficulty) > 0 {
		highest = intField(difficulty, "highest_completed")
	}
	assignment := durableFields(snapshot, "d2legacy.player.skill_assignment", entity)
	progression := &d2save.Progression{
		UnspentSkillPoints:         intField(progress, "unspent_skill_points"),
		HighestCompletedDifficulty: highest,
		LeftSkill:                  intField(assignment, "left"), RightSkill: intField(assignment, "right"),
		Skills: []d2save.LearnedSkill{},
	}
	learned, _ := findComponent(snapshot, "d2legacy.player.learned_skill")
	for _, instance := range learned.Instances {
		fields, present := findInstance(learned, instance.Entity)
		if !present || entityField(fields, "owner") != entity {
			continue
		}
		level := intField(fields, "level")
		hard := durableFields(snapshot, "d2legacy.player.skill_hard_level", instance.Entity)
		if len(hard) > 0 {
			level = intField(hard, "level")
		}
		progression.Skills = append(progression.Skills, d2save.LearnedSkill{SkillID: intField(fields, "skill_id"), Level: level})
	}
	sort.Slice(progression.Skills, func(i, j int) bool { return progression.Skills[i].SkillID < progression.Skills[j].SkillID })
	if quest := durableFields(snapshot, "d2legacy.quest.progress", entity); len(quest) > 0 {
		progression.Quest = &d2save.Quest{QuestID: intField(quest, "quest_id"), Stage: intField(quest, "stage"),
			Completed: boolField(quest, "completed"), Rewarded: boolField(quest, "rewarded")}
	}
	result.Progression = progression
	if vitality := durableFields(snapshot, "d2legacy.player.stamina_progression", entity); len(vitality) > 0 {
		result.Stats.Vitality = int(intField(vitality, "base_vitality"))
	}
	combat := durableFields(snapshot, "d2legacy.player.combat_stats", entity)
	if _, found := combat["base_defense"]; found {
		// Admission adds dexterity and equipment again, so persist only the base armor contribution.
		result.Stats.Defense = int(intField(combat, "base_defense")) - result.Stats.Dexterity/4
		if result.Stats.Defense < 0 {
			result.Stats.Defense = 0
		}
	}
	return d2save.ValidateCharacterContent(*result)
}

func durableFields(snapshot gameecs.Snapshot, name string, entity uint64) map[string]gameecs.ValueSnapshot {
	component, _ := findComponent(snapshot, name)
	fields, _ := findInstance(component, entity)
	return fields
}

func durableItem(snapshot gameecs.Snapshot, entity uint64, identity, placement map[string]gameecs.ValueSnapshot) d2save.Item {
	presentation := durableFields(snapshot, "d2legacy.item.presentation", entity)
	melee := durableFields(snapshot, "d2legacy.item.melee", entity)
	armor := durableFields(snapshot, "d2legacy.item.armor", entity)
	item := d2save.Item{
		ID:               stringField(identity, "id"),
		Code:             stringField(identity, "code"),
		ItemTypes:        stringField(identity, "item_types"),
		BodySlots:        stringField(identity, "body_slots"),
		AppliedServices:  stringField(identity, "applied_services"),
		Width:            intField(identity, "width"),
		Height:           intField(identity, "height"),
		MaterialFlags:    intField(identity, "material_flags"),
		BaseCost:         intField(identity, "base_cost"),
		Identified:       boolField(identity, "identified"),
		BeltEligible:     boolField(identity, "belt_eligible"),
		Container:        stringField(placement, "container"),
		Slot:             stringField(placement, "slot"),
		X:                intField(placement, "x"),
		Y:                intField(placement, "y"),
		BeltSlot:         intField(placement, "belt_slot"),
		WeaponSet:        intField(placement, "weapon_set"),
		Page:             intField(placement, "page"),
		InventoryDC6:     stringField(presentation, "inventory_dc6"),
		WorldDC6:         stringField(presentation, "world_dc6"),
		Composite:        stringField(presentation, "composite"),
		WeaponClass:      stringField(presentation, "weapon_class"),
		WorldAnimated:    boolField(presentation, "world_animated"),
		PhysicalMin:      intField(melee, "physical_min"),
		PhysicalMax:      intField(melee, "physical_max"),
		AttackRating:     intField(melee, "attack_rating"),
		AttackRate:       intField(melee, "attack_rate"),
		Defense:          intField(armor, "defense"),
		BaseDefenseMax:   intField(armor, "base_defense_max"),
		SpeedPenalty:     intField(armor, "speed_penalty"),
		MeleeRange:       floatField(melee, "range"),
		MeleeWeaponClass: stringField(melee, "weapon_class"),
	}
	if corpse := durableFields(snapshot, "d2legacy.item.corpse", entity); len(corpse) > 0 {
		item.CorpseID = stringField(corpse, "id")
	}
	if facts := durableFields(snapshot, "d2legacy.item.generation", entity); len(facts) > 0 {
		item.Generation = &d2save.ItemGeneration{Quality: stringField(facts, "quality"), Level: intField(facts, "level"), Facts: stringField(facts, "facts")}
	}
	modifiers, _ := findComponent(snapshot, "d2legacy.item.stat_modifier")
	for _, instance := range modifiers.Instances {
		fields, present := findInstance(modifiers, instance.Entity)
		if !present || entityField(fields, "item") != entity {
			continue
		}
		item.StatModifiers = append(item.StatModifiers, d2save.ItemModifier{
			SourceID: stringField(fields, "source_id"), SourceKind: stringField(fields, "source_kind"),
			Stat: stringField(fields, "stat"), Operation: stringField(fields, "operation"), Value: intField(fields, "value"), Order: intField(fields, "order"),
		})
	}
	sort.Slice(item.StatModifiers, func(i, j int) bool {
		a, b := item.StatModifiers[i], item.StatModifiers[j]
		if a.Order != b.Order {
			return a.Order < b.Order
		}
		if a.SourceKind != b.SourceKind {
			return a.SourceKind < b.SourceKind
		}
		return a.SourceID < b.SourceID
	})
	return item
}
