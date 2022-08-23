-- Weapon states
STATE_IDLE = 1
STATE_PARRY = 2
STATE_WINDUP = 3
STATE_ATTACK = 4

-- Used for windup, recovery and attack anims, the enums must start as 1 because table indices start at 1
ANIM_NONE = 1
ANIM_STRIKE = 2
ANIM_UPPERCUT = 3
ANIM_UNDERCUT = 4
ANIM_THRUST = 5
ANIM_KICK = 6 -- one day...

-- Used for bindings
OTHER_FEINT = 1

-- Used for debugging
DBG_NCALLS = 0
DBG_ANIM = {
	[ANIM_NONE] = "anim_none",
	[ANIM_STRIKE] = "anim_strike",
	[ANIM_UPPERCUT] = "anim_uppercut",
	[ANIM_UNDERCUT] = "anim_undercut",
	[ANIM_THRUST] = "anim_thrust"
}
DBG_STATE = {
	[STATE_IDLE] = "state_idle",
	[STATE_PARRY] = "state_parry",
	[STATE_WINDUP] = "state_windup",
	[STATE_ATTACK] = "state_attack"
}

-- Used for displaying emotes
DEF_EMOTE = {
	"gesture_agree",
	"gesture_disagree",
	"gesture_cheer",
	"gesture_becon",
	"gesture_salute",
	"gesture_wave",
	"gesture_signal_forward",
	"gesture_signal_halt",
	"gesture_signal_group",
	"gesture_bow",
	"gesture_item_drop",
	"gesture_item_give",
	"gesture_item_place",
	"gesture_item_throw",
}

-- Define the custom gestures set from *_anm.mdl, the mdl had to be overriden to save the hassle (can't just do another animation mdl without $includemodel'ing every pmdl eitherway)
DEF_ANM_SEQUENCES = {
	[STATE_IDLE] = {nil},
	[STATE_PARRY] = {"ms_parry"},
	[STATE_WINDUP] = {
		[ANIM_NONE] = nil,
		[ANIM_STRIKE] = "ms_strike",
		[ANIM_UPPERCUT] = "ms_uppercut",
		[ANIM_UNDERCUT] = "ms_undercut",
		[ANIM_THRUST] = "ms_thrust"
	},
	[STATE_ATTACK] = {
		[ANIM_NONE] = nil,
		[ANIM_STRIKE] = "ms_strike",
		[ANIM_UPPERCUT] = "ms_uppercut",
		[ANIM_UNDERCUT] = "ms_undercut",
		[ANIM_THRUST] = "ms_thrust"
	}
}

-- Other globals
GAME_MVSPEED = 100
GAME_NTEAMS = 4
GAME_TEAMCTABLE = {
	[1] = Color(150, 0, 0),
	[2] = Color(0, 11, 170),
	[3] = Color(0, 201, 50),
	[4] = Color(207, 187, 0)
}