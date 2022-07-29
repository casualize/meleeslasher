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
SWEP.WorldModel = Model( "models/weapons/w_greatsword.mdl" )
SWEP.ViewModelFOV = 100
-- SWEP.ShowWorldModel = false
SWEP.UseHands = true

--CUSTOM SWEP FIELDS--
SWEP.Name = "base"
SWEP.ThrustDamage = 10
SWEP.SwingDamage = 25 -- 35
SWEP.Range = 64 -- 36
SWEP.Lunge = 40 -- (u/s)
SWEP.Release = 0.002 -- how fast angle degree ticks, swep.release*swep.angle for time taken swinging 
SWEP.Windup = (2/3)
SWEP.RiposteMulti = (2/3) -- Used to multiply windup on riposte
SWEP.Recovery = (2/3)
SWEP.TurnCap = 200 -- 150
SWEP.AngleStrike = 235
SWEP.AngleStrikeOffset = 45
SWEP.Cleave = true
SWEP.GlanceAngles = -1 --8 -- Temporary anti-backswing
SWEP.StaminaDrain = 9
SWEP.FeintDrain = 7
SWEP.Model = "models/aoc_weapon/w_sword_01.mdl" -- For CSENT anims

SWEP.ParryAnim = "revolver"
SWEP.IdleAnim = "melee2"
SWEP.WindupAnim = "melee2"

--INTERNAL SWEP FIELDS--
SWEP.m_iState = STATE_IDLE -- sv/cl
SWEP.m_iAnim = ANIM_NONE -- sv
SWEP.m_iQueuedAnim = ANIM_NONE -- sv
SWEP.m_bRiposting = false
SWEP.m_bFlip = false -- sv/cl
SWEP.m_iFlip = 1 -- cl
SWEP.m_flWindupFinal = SWEP.Windup
SWEP.m_tFilter = {} -- sv

SWEP.m_flPrevParry = 0.0
SWEP.m_flPrevRecovery = 0.0
SWEP.m_flPrevFlinch = 0.0
SWEP.m_flPrevState = 0.0

SWEP.slashtag = 0 -- might get deprecated
SWEP.m_soundRelease = {"vo/npc/male01/pain04", "vo/npc/male01/pain03"} -- might get deprecated

--TODO/BUG--------------------------
--[[
	BUG: If u feint late on strike windup then when switching to thrust it will mess up 1 of the bones for it
	BUG: Being outside the map boundaries will make your ActiveWeapon nil
	BUG: Should update bone vars upon new pmodel, now it's using render hook...
	BUG: Dying during a flip state causes it to last even during new spawn
	BIG: Emote system, AnimRestartGestures, overwrite *_anm.mdl
	TODO: Merge DamageSimple and Flinch?
	TODO: Bandaid fix to IK (for enablematrix issue): manipulate left hand's bones to the right one when flipped attack
	TODO: Proper integration for lag comp
	TODO: Red parry message (prediction support first though)
	GAMEIDEAS: Chain riposting(1vx) multiplies your weapon damage, ...
	STUDYTHIS: What makes bindings different from hard-coded methods like PrimaryAttack, ...
	NETFIX: Move everything to SetDT because of better prediction, ...
	MOVEMENT REWORK: chase mechanic, ...
	CLEANUP: Move weapon internal vars into player, Microopt swings/thinks, Skip object constructs, IsValid checks, ...
--]]
------------------------------------
function SWEP:Initialize()
	self:SetHoldType(self.IdleAnim)
end

function SWEP:PrimaryAttack()
	--if CLIENT then return end -- Gets rid of the clicking sound
	--self:m_fWindup(ANIM_STRIKE,false)
end

function SWEP:SecondaryAttack()
	if CLIENT then return end
	self:Parry()
end