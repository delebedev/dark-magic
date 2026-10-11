package save

import (
	"fmt"
	"math"
	"strings"
)

// ValidateCharacterContent bounds optional portable state before it becomes authority.
func ValidateCharacterContent(character Character) error {
	invalid := func(reason string) error { return fmt.Errorf("%w: %s", ErrProfile, reason) }
	if inventory := character.Inventory; inventory != nil {
		dimensions := []int64{inventory.InventoryWidth, inventory.InventoryHeight, inventory.StashWidth,
			inventory.StashHeight, inventory.CubeWidth, inventory.CubeHeight, inventory.VendorWidth, inventory.VendorHeight}
		for _, dimension := range dimensions {
			if dimension < 0 || dimension > 16 {
				return invalid("inventory dimensions exceed bounds")
			}
		}
		if len(inventory.Items) > 256 || inventory.BeltCapacity < 0 || inventory.BeltCapacity > 16 ||
			inventory.ActiveWeaponSet < 0 || inventory.ActiveWeaponSet > 1 || inventory.CarriedGold < 0 || inventory.CarriedGold > 2147483647 || inventory.StashedGold < 0 || inventory.StashedGold > 2147483647 {
			return invalid("inventory layout exceeds bounds")
		}
		ids := make(map[string]bool)
		for _, item := range inventory.Items {
			if item.ID == "" || len(item.ID) > 128 || item.Code == "" || len(item.Code) > 64 || ids[item.ID] || item.Width < 1 || item.Height < 1 ||
				item.Width > 16 || item.Height > 16 || item.X < 0 || item.X > 16 || item.Y < 0 || item.Y > 16 || item.Page != 0 ||
				item.WeaponSet < 0 || item.WeaponSet > 1 || item.BeltSlot < 0 || item.BeltSlot >= 16 {
				return invalid("invalid or duplicate durable item")
			}
			ids[item.ID] = true
			for _, text := range []string{item.ID, item.Code, item.ItemTypes, item.BodySlots, item.AppliedServices,
				item.Slot, item.InventoryDC6, item.WorldDC6, item.Composite, item.WeaponClass, item.MeleeWeaponClass} {
				if len(text) > 512 || strings.ContainsRune(text, 0) {
					return invalid("item text exceeds bounds")
				}
			}
			if math.IsNaN(item.MeleeRange) || math.IsInf(item.MeleeRange, 0) || item.MeleeRange < 0 || item.MeleeRange > 64 ||
				item.PhysicalMin < 0 || item.PhysicalMax < item.PhysicalMin || item.Defense < 0 || item.BaseCost < 0 ||
				len(item.StatModifiers) > 128 {
				return invalid("item mechanics exceed bounds")
			}
			for _, value := range []int64{item.MaterialFlags, item.BaseCost, item.PhysicalMin, item.PhysicalMax,
				item.AttackRating, item.AttackRate, item.Defense, item.BaseDefenseMax, item.SpeedPenalty} {
				if value < math.MinInt32 || value > math.MaxInt32 {
					return invalid("item number exceeds authority bounds")
				}
			}
			var width, height int64
			switch item.Container {
			case "inventory":
				width, height = inventory.InventoryWidth, inventory.InventoryHeight
			case "stash":
				width, height = inventory.StashWidth, inventory.StashHeight
			case "cube":
				width, height = inventory.CubeWidth, inventory.CubeHeight
			case "equipment", "hireling":
				if !strings.Contains(","+item.BodySlots+",", ","+item.Slot+",") || item.Slot == "" ||
					(item.Slot != "rarm" && item.Slot != "larm" || item.Container == "hireling") && item.WeaponSet != 0 {
					return invalid("item cannot occupy durable body slot")
				}
			case "quest_service":
				if item.Slot == "" {
					return invalid("durable named slot is missing")
				}
			case "belt":
				if !item.BeltEligible || item.BeltSlot >= inventory.BeltCapacity {
					return invalid("invalid durable belt slot")
				}
			case "held":
			default:
				return invalid("world and vendor items are not durable possessions")
			}
			if width != 0 || height != 0 || item.Container == "inventory" || item.Container == "stash" || item.Container == "cube" {
				if item.X+item.Width > width || item.Y+item.Height > height {
					return invalid("durable item exceeds grid")
				}
			}
			if generated := item.Generation; generated != nil {
				if len(generated.Quality) > 32 || generated.Level < 0 || generated.Level > 255 || len(generated.Facts) > 65536 {
					return invalid("item generation exceeds bounds")
				}
			}
			modifierIDs := make(map[string]bool)
			for _, modifier := range item.StatModifiers {
				key := fmt.Sprintf("%s:%d:%s", modifier.SourceKind, modifier.Order, modifier.SourceID)
				if modifierIDs[key] || modifier.Order < 0 || modifier.Order > math.MaxInt32 || modifier.Value < math.MinInt32 || modifier.Value > math.MaxInt32 || len(modifier.SourceID) > 128 || len(modifier.SourceKind) > 64 ||
					len(modifier.Stat) > 128 || modifier.Operation != "add" && modifier.Operation != "percent" {
					return invalid("invalid durable stat modifier")
				}
				modifierIDs[key] = true
			}
		}
		for index, item := range inventory.Items {
			for _, other := range inventory.Items[:index] {
				if item.Container != other.Container {
					continue
				}
				occupied := false
				switch item.Container {
				case "inventory", "stash", "cube":
					occupied = item.X < other.X+other.Width && other.X < item.X+item.Width &&
						item.Y < other.Y+other.Height && other.Y < item.Y+item.Height
				case "belt":
					occupied = item.BeltSlot == other.BeltSlot
				case "held":
					occupied = true
				default:
					occupied = item.Slot == other.Slot && (item.Container != "equipment" ||
						item.Slot != "rarm" && item.Slot != "larm" || item.WeaponSet == other.WeaponSet)
				}
				if occupied {
					return invalid("durable item placement is occupied")
				}
			}
		}
	}
	if progression := character.Progression; progression != nil {
		if progression.UnspentSkillPoints < 0 || progression.UnspentSkillPoints > 1000000 ||
			progression.HighestCompletedDifficulty < -1 || progression.HighestCompletedDifficulty > 2 || len(progression.Skills) > 512 {
			return invalid("progression exceeds bounds")
		}
		ids := make(map[int64]bool)
		for _, skill := range progression.Skills {
			if skill.SkillID < 0 || skill.SkillID > 4095 || skill.Level < 1 || skill.Level > 255 || ids[skill.SkillID] {
				return invalid("invalid or duplicate durable skill")
			}
			ids[skill.SkillID] = true
		}
		if len(ids) > 0 && (!ids[progression.LeftSkill] || !ids[progression.RightSkill]) {
			return invalid("selected skill is not learned")
		}
		if quest := progression.Quest; quest != nil {
			if quest.QuestID < 1 || quest.QuestID > 64 || quest.Stage < 0 || quest.Stage > 255 || quest.Rewarded && !quest.Completed {
				return invalid("invalid durable quest")
			}
		}
	}
	return nil
}
