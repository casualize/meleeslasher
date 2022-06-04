SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = -1

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Automatic = false

SWEP.ViewModel = ""--"models/aoc_weapon/v_longsword.mdl"
SWEP.WorldModel = "models/aoc_weapon/w_sword_01.mdl"
SWEP.ShowWorldModel = false

--CUSTOM SWEP VARIABLES--
SWEP.Name = "base"
SWEP.ThrustDamage = 10
SWEP.SwingDamage = 25--35
SWEP.Range = 36
SWEP.Lunge = 40--(u/s)
SWEP.Release = 0.002 -- how fast angle degree ticks, swep.release*swep.angle for time taken swinging 
SWEP.Windup = (2/3)
SWEP.RiposteMulti = (2/3) -- swep.windup*swep.ripostemulti
SWEP.Recovery = (2/3)
SWEP.TurnCap = 150
SWEP.AngleStrike = 235
SWEP.AngleStrikeOffset = 45
SWEP.Cleave = true
SWEP.GlanceAngles = 8
SWEP.StaminaDrain = 9
SWEP.FeintDrain = 7
SWEP.Model = "models/aoc_weapon/w_sword_01.mdl"

SWEP.ParryAnim = "revolver"
SWEP.IdleAnim = "melee2"
SWEP.WindupAnim = "melee2"

--INTERNAL SWEP VARIABLES--
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
SWEP.m_soundRelease = {"vo/npc/male01/pain04","vo/npc/male01/pain03"} -- might get deprecated

--TO DO/ISSUES-----------------------------
--new mechanic ideas: punish for feeding ripostes in 1vx? ur dmg doubles if u parry twice, thrice etc.
--Player_Anim performance fix, use returns for boneanglemanip instead, maybe use different hook?
--FIX CL INIT!!! maybe its the include issue.......
--slighten the tracer amount, make it attached to FrameTime()?
--flipside anims!!!?! HOW!?!
--isvalid checks
--more complex bot
--use lerp, math.ease libs
--microoptimize swings/thinks
--optimize object construction(skip vectors,angle construction etc)
--weird "stun lock" with thrusts, look into cooldowns or the attack itself
--DISCLAIMER: bindings != PrimaryAttack or etc, those are more complicated, should research this
--net library is NOT predicted = awful gameplay, use setdt instead
--hands model for FP
--clamp ALL curtime() anims
--rework movement (chase mechanic)
--research animation system
--lua_run_cl hook.Add("Tick","a",function() print(LocalPlayer():GetActiveWeapon().m_iState) end)
--lua_run hook.Add("Tick","a",function() print(Player(N):GetActiveWeapon().m_iState) end)
------------------------------------

function SWEP:Initialize()
	self:SetHoldType(self.IdleAnim)
end


function SWEP:PrimaryAttack()
	--if CLIENT then return end -- we put this in here because it gets rid of the annoying clicking sound...
	--self:m_fWindup(ANIM_STRIKE,false)
end

function SWEP:SecondaryAttack()
	if CLIENT then return end
	self:Parry()
end