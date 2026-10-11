package save

// Inventory contains portable item facts, never runtime entity references or ground loot.
type Inventory struct {
	InventoryWidth  int64    `json:"inventory_width"`
	InventoryHeight int64    `json:"inventory_height"`
	StashWidth      int64    `json:"stash_width"`
	StashHeight     int64    `json:"stash_height"`
	CubeWidth       int64    `json:"cube_width"`
	CubeHeight      int64    `json:"cube_height"`
	BeltCapacity    int64    `json:"belt_capacity"`
	ActiveWeaponSet int64    `json:"active_weapon_set"`
	VendorWidth     int64    `json:"vendor_width"`
	VendorHeight    int64    `json:"vendor_height"`
	CarriedGold     int64    `json:"carried_gold"`
	StashedGold     int64    `json:"stashed_gold"`
	Items           []Item   `json:"items"`
	Corpses         []Corpse `json:"corpses,omitempty"`
}

type Corpse struct {
	ID string `json:"id"`
}

// Death retains consequences already committed, without persisting a session tick.
type Death struct {
	Hardcore          bool `json:"hardcore"`
	CapacityExhausted bool `json:"capacity_exhausted,omitempty"`
}

type Item struct {
	ID               string          `json:"id"`
	CorpseID         string          `json:"corpse_id,omitempty"`
	Code             string          `json:"code"`
	ItemTypes        string          `json:"item_types"`
	BodySlots        string          `json:"body_slots"`
	AppliedServices  string          `json:"applied_services"`
	Container        string          `json:"container"`
	Slot             string          `json:"slot"`
	InventoryDC6     string          `json:"inventory_dc6"`
	WorldDC6         string          `json:"world_dc6"`
	Composite        string          `json:"composite"`
	WeaponClass      string          `json:"weapon_class"`
	MeleeWeaponClass string          `json:"melee_weapon_class"`
	Width            int64           `json:"width"`
	Height           int64           `json:"height"`
	MaterialFlags    int64           `json:"material_flags"`
	BaseCost         int64           `json:"base_cost"`
	X                int64           `json:"x"`
	Y                int64           `json:"y"`
	BeltSlot         int64           `json:"belt_slot"`
	WeaponSet        int64           `json:"weapon_set"`
	Page             int64           `json:"page"`
	PhysicalMin      int64           `json:"physical_min"`
	PhysicalMax      int64           `json:"physical_max"`
	AttackRating     int64           `json:"attack_rating"`
	AttackRate       int64           `json:"attack_rate"`
	Defense          int64           `json:"defense"`
	BaseDefenseMax   int64           `json:"base_defense_max"`
	SpeedPenalty     int64           `json:"speed_penalty"`
	Identified       bool            `json:"identified"`
	BeltEligible     bool            `json:"belt_eligible"`
	WorldAnimated    bool            `json:"world_animated"`
	MeleeRange       float64         `json:"melee_range"`
	Generation       *ItemGeneration `json:"generation,omitempty"`
	StatModifiers    []ItemModifier  `json:"stat_modifiers,omitempty"`
}

type ItemGeneration struct {
	Quality string `json:"quality"`
	Level   int64  `json:"level"`
	Facts   string `json:"facts"`
}

type ItemModifier struct {
	SourceID   string `json:"source_id"`
	SourceKind string `json:"source_kind"`
	Stat       string `json:"stat"`
	Operation  string `json:"operation"`
	Value      int64  `json:"value"`
	Order      int64  `json:"order"`
}

// Progression retains player choices and rewards across fresh game sessions.
type Progression struct {
	UnspentSkillPoints         int64          `json:"unspent_skill_points"`
	HighestCompletedDifficulty int64          `json:"highest_completed_difficulty"`
	LeftSkill                  int64          `json:"left_skill"`
	RightSkill                 int64          `json:"right_skill"`
	Skills                     []LearnedSkill `json:"skills"`
	Quest                      *Quest         `json:"quest,omitempty"`
}

type LearnedSkill struct {
	SkillID int64 `json:"skill_id"`
	Level   int64 `json:"level"`
}

type Quest struct {
	QuestID   int64 `json:"quest_id"`
	Stage     int64 `json:"stage"`
	Completed bool  `json:"completed"`
	Rewarded  bool  `json:"rewarded"`
}
