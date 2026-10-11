package clientapp

import playeradapter "github.com/gravestench/dark-magic/internal/mod/d2legacy/adapter/player"

func remoteItemInspection(view *playeradapter.ItemInspectionView) map[string]any {
	values := map[string]any{"identified": false, "status": "missing_facts", "damage_known": false,
		"damage_min_raw": int64(0), "damage_max_raw": int64(0), "defense_known": false, "defense": int64(0)}
	if view == nil {
		return values
	}
	values["identified"], values["status"] = view.Identified, view.Status
	if view.Damage != nil {
		values["damage_known"], values["damage_min_raw"], values["damage_max_raw"] = true, view.Damage.MinRaw, view.Damage.MaxRaw
	}
	if view.Defense != nil {
		values["defense_known"], values["defense"] = true, *view.Defense
	}
	return values
}
