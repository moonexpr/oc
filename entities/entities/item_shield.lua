AddCSLuaFile()

ENT.Base = "item_pickup_base"

ENT.PrintName = "Personal Shield"
ENT.Spawnable = false
ENT.AdminSpawnable = false

ENT.PickupModel = "models/Player/w_helmet.mdl"

-- The FGD only calls it a "Player Shield Device"; the wiki says "A shield can last
-- up to 50 seconds" and that it "will block all oncoming attacks".
local SHIELD_SECONDS = 50

function ENT:OnPickup(ply)
	ply:SetNWFloat("oc_shield_until", CurTime() + SHIELD_SECONDS)
	ply:ChatPrint("Shield on for " .. SHIELD_SECONDS .. " seconds.")

	return true
end

if SERVER then
	-- a shielded player takes no damage
	hook.Add("EntityTakeDamage", "oc_item_shield", function(target, dmginfo)
		if target:IsPlayer() and target:GetNWFloat("oc_shield_until", 0) > CurTime() then
			return true
		end
	end)

	hook.Add("PlayerDeath", "oc_item_shield", function(ply)
		ply:SetNWFloat("oc_shield_until", 0)
	end)
end
