-- DT keys (unused)
WEP_STATE = 0
WEP_ANIM = 1

-- Weapon states, to keep in mind, some conditions use >=
STATE_IDLE = 1
STATE_PARRY = 2
STATE_WINDUP = 3
STATE_RECOVERY = 4
STATE_ATTACK = 5

-- Used for windup, recovery and attack anims, the enums must start as 1 because table indices start at 1
ANIM_NONE = 1
ANIM_STRIKE = 2
ANIM_UPPERCUT = 3
ANIM_UNDERCUT = 4
ANIM_THRUST = 5

-- Used for slash calculations, constants
CALC_SLASH = {
	[ANIM_NONE] = {nil, nil},
	[ANIM_STRIKE] = {-1, 90},
	[ANIM_UPPERCUT] = {-1, 45},
	[ANIM_UNDERCUT] = {1, -45},
	[ANIM_THRUST] = {nil, nil}
}

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
	[STATE_RECOVERY] = "state_recovery",
	[STATE_ATTACK] = "state_attack"
}

-- Used for displaying emotes
DEF_EMOTE = {
	"gesture_agree",
	"gesture_bow",
	"gesture_becon",
	"gesture_disagree",
	"gesture_salute",
	"gesture_wave",
	"gesture_item_drop",
	"gesture_item_give",
	"gesture_item_place",
	"gesture_item_throw",
	"gesture_signal_forward",
	"gesture_signal_halt",
	"gesture_signal_group"
}

-- Other globals
GAME_MVSPEED = 100