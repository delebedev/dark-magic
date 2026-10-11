package player

import gameecs "github.com/gravestench/dark-magic/internal/game/ecs"

// ItemInspectionView contains item contributions, never character or skill totals.
type ItemInspectionView struct {
	Identified bool            `json:"identified"`
	Status     string          `json:"status"`
	Damage     *ItemDamageView `json:"damage,omitempty"`
	Defense    *int64          `json:"defense,omitempty"`
}

type ItemDamageView struct {
	MinRaw int64 `json:"min_raw"`
	MaxRaw int64 `json:"max_raw"`
}

func projectItemInspection(snapshot gameecs.Snapshot, entity uint64) *ItemInspectionView {
	fields := durableFields(snapshot, "d2legacy.item.inspection", entity)
	if len(fields) == 0 {
		identity := durableFields(snapshot, "d2legacy.item.identity", entity)
		return &ItemInspectionView{Identified: boolField(identity, "identified"), Status: "missing_facts"}
	}
	view := &ItemInspectionView{Identified: boolField(fields, "identified"), Status: stringField(fields, "status")}
	if view.Identified && boolField(fields, "damage_known") {
		view.Damage = &ItemDamageView{MinRaw: intField(fields, "damage_min_raw"), MaxRaw: intField(fields, "damage_max_raw")}
	}
	if view.Identified && boolField(fields, "defense_known") {
		value := intField(fields, "defense")
		view.Defense = &value
	}
	return view
}

func validateItemInspection(view *ItemInspectionView) bool {
	if view == nil {
		return true
	}
	switch view.Status {
	case "complete", "partial", "unidentified", "missing_facts":
	default:
		return false
	}
	if !view.Identified && (view.Damage != nil || view.Defense != nil) {
		return false
	}
	if !view.Identified && view.Status != "unidentified" && view.Status != "missing_facts" {
		return false
	}
	if view.Status == "missing_facts" && (view.Damage != nil || view.Defense != nil) {
		return false
	}
	if view.Status == "unidentified" && view.Identified {
		return false
	}
	if damage := view.Damage; damage != nil && (damage.MinRaw < 0 || damage.MaxRaw < damage.MinRaw || damage.MaxRaw > 1<<40) {
		return false
	}
	return view.Defense == nil || *view.Defense >= 0 && *view.Defense <= 1<<40
}
