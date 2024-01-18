SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = -1

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Automatic = false

SWEP.WorldModel = Model("models/aoc_weapon/w_flamberge.mdl")

-- CUSTOM SWEP FIELDS
SWEP.Name = "base"
SWEP.ThrustDamage = 10
SWEP.SwingDamage = 25
SWEP.Range = 44
SWEP.HandleRange = 8
SWEP.Lunge = 40 -- (u/s)
SWEP.Release = 0.002
SWEP.Windup = (2/3) -- Setting this to different values jaepardize animations completely, definitely need a rewrite
SWEP.Recovery = (2/3)
SWEP.TurnCap = 200
SWEP.AngleStrike = 200 -- This SHOULD be 235, however animations don't finish correctly on clientside. Rewrite this to sequence duration multiplier? Animations seem smoother if tick speed is higher.
SWEP.Cleave = true
SWEP.GlanceAngles = -1 --8 -- Temporary anti-backswing, no idea if this still does something
SWEP.StaminaDrain = 9
SWEP.FeintDrain = 7

-- INTERNAL SWEP FIELDS
SWEP.m_iState = STATE_IDLE -- sv/cl
SWEP.m_iAnim = ANIM_NONE -- sv/cl
SWEP.m_iQueuedAnim = ANIM_NONE -- sv
SWEP.m_bRiposting = false -- sv/cl
SWEP.m_bFlip = false -- sv/cl
SWEP.m_tFilter = {} -- sv
SWEP.m_tPos = {} -- cl

SWEP.m_flPrevState = 0.0
SWEP.m_flPrevParry = 0.0
SWEP.m_flPrevRiposte = 0.0
SWEP.m_flNextAttack = 0.0
SWEP.m_flPrevFeint = 0.0

SWEP.m_flCycle = 0.0
SWEP.m_flWeight = 0.0

SWEP.slashtag = 0 -- might get deprecated
SWEP.m_soundRelease = {"vo/npc/male01/pain04", "vo/npc/male01/pain03"} -- might get deprecated

-- Emptying this function disables the annoying clicking sound
function SWEP:PrimaryAttack() end