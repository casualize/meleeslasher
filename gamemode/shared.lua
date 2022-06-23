-- Useful macros for the 3 file system
function INC_SERVER()
	AddCSLuaFile("shared.lua")
	AddCSLuaFile("cl_init.lua")
	include("shared.lua")
end
function INC_CLIENT()
	print('ddd')
	include("shared.lua")
end

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