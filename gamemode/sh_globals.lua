--DT keys
WEP_STATE = 0
WEP_ANIM = 1

--weapon states. to keep in mind, some conditions use >= !
STATE_IDLE = 0
STATE_PARRY = 1
STATE_WINDUP = 2
STATE_RECOVERY = 3
STATE_ATTACK = 4

DEF_STATE = {
	[STATE_IDLE] = "STATE_IDLE",
	[STATE_PARRY] = "STATE_PARRY",
	[STATE_WINDUP] = "STATE_WINDUP",
	[STATE_RECOVERY] = "STATE_RECOVERY",
	[STATE_ATTACK] = "STATE_ATTACK"
}

--this can be used for recovery and windup anim! also for STATE_ATTACK states
ANIM_SKIP = 0
ANIM_NONE = 1
ANIM_STRIKE = 2
ANIM_UPPERCUT = 3
ANIM_UNDERCUT = 4
ANIM_THRUST = 5

DEF_ANIM = {
	[ANIM_SKIP] = "ANIM_SKIP",
	[ANIM_NONE] = "ANIM_NONE",
	[ANIM_STRIKE] = "ANIM_STRIKE",
	[ANIM_UPPERCUT] = "ANIM_UPPERCUT",
	[ANIM_UNDERCUT] = "ANIM_UNDERCUT",
	[ANIM_THRUST] = "ANIM_THRUST"
}

GAME_MVSPEED = 100