SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = -1

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Automatic = false

SWEP.ViewModel = Model( "models/weapons/c_greatsword.mdl" )
SWEP.WorldModel = Model( "models/aoc_weapon/w_flamberge.mdl" )
SWEP.ViewModelFOV = 100
-- SWEP.ShowWorldModel = false
SWEP.UseHands = true

--CUSTOM SWEP FIELDS--
SWEP.Name = "base"
SWEP.ThrustDamage = 10
SWEP.SwingDamage = 25 -- 35
SWEP.Range = 48 -- 36
SWEP.Lunge = 40 -- (u/s)
SWEP.Release = 0.002 -- how fast angle degree ticks, swep.release*swep.angle for time taken swinging 
SWEP.Windup = (2/3)
SWEP.Recovery = (2/3)
SWEP.TurnCap = 200 -- 150
SWEP.AngleStrike = 230 -- 235 -- Should deprecate this into sequence duration multiplier or something, this field is temporary
SWEP.Cleave = true
SWEP.GlanceAngles = -1 --8 -- Temporary anti-backswing
SWEP.StaminaDrain = 9
SWEP.FeintDrain = 7

--INTERNAL SWEP FIELDS--
SWEP.m_iState = STATE_IDLE -- sv/cl
SWEP.m_iAnim = ANIM_NONE -- sv/cl
SWEP.m_iQueuedAnim = ANIM_NONE -- sv
SWEP.m_bRiposting = false -- sv/cl
SWEP.m_bFlip = false -- sv/cl
SWEP.m_tFilter = {} -- sv

SWEP.m_flPrevState = 0.0
SWEP.m_flPrevParry = 0.0
SWEP.m_flPrevRiposte = 0.0
SWEP.m_flNextAttack = 0.0
SWEP.m_flPrevFeint = 0.0

SWEP.m_flCycle = 0.0
SWEP.m_flWeight = 0.0
SWEP.m_flWeightRecovery = 0.0

SWEP.slashtag = 0 -- might get deprecated
SWEP.m_soundRelease = {"vo/npc/male01/pain04", "vo/npc/male01/pain03"} -- might get deprecated

if CLIENT then
	SWEP.m_tCurTimeBank = {
		[STATE_IDLE] = 0.0,
		[STATE_PARRY] = 0.0,
		[STATE_WINDUP] = 0.0,
		[STATE_ATTACK] = 0.0,
	}
end

--TODO/BUG--------------------------
--[[
	BUG: Being outside the map boundaries will make your ActiveWeapon nil
	BUG: Should update bone vars upon new pmodel, now it's using render hook...
	BUG: Dying during a flip state causes it to last even during new spawn
	TODO: Merge DamageSimple and Flinch?
	TODO: Proper integration for lag comp
	TODO: Red parry message (prediction support first though)
	GAMEIDEAS: Chain riposting(1vx) multiplies your weapon damage, ...
	STUDYTHIS: What makes bindings different from hard-coded methods like PrimaryAttack, ...
	NETFIX: Move everything to SetDT because of better prediction, ...
	MOVEMENT REWORK: chase mechanic, ...
	CLEANUP: Move weapon internal vars into player, Microopt swings/thinks, Skip object constructs, IsValid checks, ...
--]]
------------------------------------

-- Here so it disables the annoying clicking sound
function SWEP:PrimaryAttack()
end