--DT keys
WEP_STATE = 0
WEP_ANIM = 1

-- Weapon states, to keep in mind, some conditions use >=
STATE_IDLE = 0
STATE_PARRY = 1
STATE_WINDUP = 2
STATE_RECOVERY = 3
STATE_ATTACK = 4

-- Used for windup, recovery and attack anims
ANIM_SKIP = 0
ANIM_NONE = 1
ANIM_STRIKE = 2
ANIM_UPPERCUT = 3
ANIM_UNDERCUT = 4
ANIM_THRUST = 5

-- Used for debugging
DEF_ANIM = {
	[ANIM_SKIP] = "anim_skip",
	[ANIM_NONE] = "anim_none",
	[ANIM_STRIKE] = "anim_strike",
	[ANIM_UPPERCUT] = "anim_uppercut",
	[ANIM_UNDERCUT] = "anim_undercut",
	[ANIM_THRUST] = "anim_thrust"
}
DEF_STATE = {
	[STATE_IDLE] = "state_idle",
	[STATE_PARRY] = "state_parry",
	[STATE_WINDUP] = "state_windup",
	[STATE_RECOVERY] = "state_recovery",
	[STATE_ATTACK] = "state_attack"
}

GAME_MVSPEED = 100