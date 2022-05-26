include("sh_globals.lua")
include("player_movement/shared.lua")

-- Useful macros for the 3 file system
function INC_SERVER()
	AddCSLuaFile("shared.lua")
	AddCSLuaFile("cl_init.lua")
	include("shared.lua")
end

function INC_CLIENT()
	include("shared.lua")
end
INC_CLIENT_NO_SHARED = INC_CLIENT

function INC_SERVER_NO_SHARED()
	AddCSLuaFile("cl_init.lua")
end

function INC_SERVER_NO_CLIENT()
	AddCSLuaFile("shared.lua")
end
--[[
function GM:PrecacheParticleSystems()
	game.AddParticles( "particles/vehicle.pcf" )
	PrecacheParticleSystem( "Exhaust" )
end

function GM:Initialize()
	self:PrecacheParticleSystems()
end
]]