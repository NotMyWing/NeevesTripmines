AddCSLuaFile()

if CLIENT then
	ENT.Icon = "vgui/ttt/icon_tripmine"
	ENT.PrintName = "tripmine_name"

	ENT.TargetIDHint = {
		name = "tripmine_name"
	};
end

ENT.Type = "anim"
ENT.Model = Model("models/weapons/w_slam.mdl")

ENT.CanUseKey = true
ENT.CanHavePrints = true

local cvarLaserLength = CreateConVar(
	"ttt_tripmine_laserlength"
	, 512
	, bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED)
	, "Defines the trip mine laser length"
)

local cvarTripMineDamage = CreateConVar(
	"ttt_tripmine_damage"
	, 260
	, bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED)
	, "Defines the trip mine damage"
)

local cvarTripMineBlastRadius = CreateConVar(
	"ttt_tripmine_blastradius"
	, 260
	, bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED)
	, "Defines the trip mine explosion range"
)

local cvarActivationTime = CreateConVar(
	"ttt_tripmine_activationtime"
	, 0.25
	, bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED)
	, "Defines the trip mine activation time"
)

function ENT:Draw()
	local ang = self:GetAngles()

	local matrix = Matrix()
	matrix:Scale(Vector(0.75, 0.75, 0.25))
	matrix:Translate(Vector(0, 0, -6))
	self:EnableMatrix("RenderMultiply", matrix)
	self:DrawModel()

	if (!self.Enabled) then
		return
	end
end

function ENT:Initialize()
	self:SetModel(self.Model)

	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)

	if SERVER then
		self:SetUseType(SIMPLE_USE)
		self:SetMaxHealth(10)
	end
	self:SetHealth(10)
	self.fingerprints = { self.Owner }

	timer.Simple(2, function()
		self.Enabled = true
	end)
end

function ENT:UseOverride(user)
	if IsValid(user)
		&& user:IsPlayer()
		&& (user:IsActiveTraitor() || user == self.Owner)
	then
		self:Remove()

		local wep = user:Give("weapon_ttt_tripmine")
		if IsValid(wep) then
			wep.fingerprints = wep.fingerprints || {}
			table.Add(wep.fingerprints, self.fingerprints || {})
		end
	end
end

local zapsound = Sound("npc/assassin/ball_zap1.wav")

function ENT:OnTakeDamage(dmginfo)
	if dmginfo:GetInflictor() == self
		|| dmginfo:GetAttacker() == self
	then
		return
	end

	self:TakePhysicsDamage(dmginfo)

	self:SetHealth(self:Health() - dmginfo:GetDamage())
	if self:Health() <= 0 then
		self:Remove()

		local effect = EffectData()
		effect:SetOrigin(self:GetPos())
		util.Effect("cball_explode", effect)

		sound.Play(zapsound, self:GetPos())

		if (IsValid(self:GetOwner())) then
			LANG.Msg(self:GetOwner(), "tripmine_broken")
		end
	end
end

function ENT:Think()
	if SERVER then
		self:NextThink(CurTime())
		if self.Enabled then
			local ang = self:GetAngles()
			local pos = self:GetPos()
				+ ang:Forward() * -2.0
				+ ang:Up() * -1.33

			local trLine = util.TraceLine {
				start 			= pos
				, endpos 		= pos + ang:Up() * cvarLaserLength:GetFloat() || 512
				, mask 			= MASK_SOLID
				, filter 		= self
				, ignoreworld	= false
			}

			local dist = trLine.StartPos:Distance(trLine.HitPos)
			local tr = util.TraceHull {
				start 			= pos
				, endpos 		= pos + ang:Up() * dist
				, maxs 			= ang:Forward() *  4 + ang:Right() *  4
				, mins 			= ang:Forward() * -4 + ang:Right() * -4
				, mask 			= MASK_SOLID
				, filter 		= self
			}

			local ent = tr.Entity
			if !IsValid(ent) then
				return
			end

			local class = ent:GetClass()

			if !self.Activated
				&& ent:IsPlayer()
				&& !(
					class:find("static")
					|| class:find("door")
					|| class:find("tripmine")
				)
			then
				self.Activated = true
				self:EmitSound("weapons/grenade/tick1.wav", 150, 100, 1)

				timer.Simple(cvarActivationTime:GetFloat() || 0.25, function()
					if !IsValid(self) then
						return
					end

					local pos = self:GetPos()
					local effect = EffectData()
					local radius = cvarTripMineBlastRadius:GetFloat() || 260
					local dmg = cvarTripMineDamage:GetFloat() || 260

					effect:SetStart(pos)
					effect:SetOrigin(pos)
					effect:SetScale(radius * 0.3)
					effect:SetRadius(radius)
					effect:SetMagnitude(dmg)

					local owner = self:GetOwner()
					if ent:IsPlayer() && ent:GetTraitor() then
						owner = ent
					end

					util.Effect("Explosion", effect, true, true)
					util.BlastDamage(self, owner, pos, radius, dmg)
					self:Remove()
				end)
			end
		end
	end
	return true
end

if CLIENT then
	local laser = Material("sprites/bluelaser1")
	local beamColor = Color(255, 0, 0, 92)

	hook.Add("PreDrawTranslucentRenderables", "Neeve Claymores Lasers", function()
		for k, v in pairs(ents.GetAll()) do
			if v.Enabled 
				&& v:GetClass() == "ttt_tripmine"
			then
				local ang = v:GetAngles()
				local pos = v:GetPos() + ang:Forward() * -2.0 + ang:Up() * -1.3
				local tr = util.TraceLine {
					start = pos
					, endpos = pos + ang:Up() * cvarLaserLength:GetFloat() || 512
					, filter = v
					, mask = MASK_SOLID
					, ignoreworld = false
				}

				render.SetMaterial(laser)
				render.StartBeam(2)
					render.AddBeam(tr.StartPos, 2.5, 2, beamColor)
					render.AddBeam(tr.HitPos, 2.5, 3, beamColor)
				render.EndBeam()
			end
		end
	end)

	local clay_mat = Material("vgui/ttt/echoslam")
	local clay_col = Color(255, 255, 255, 255)

	local hOffset = Vector(0, 0, 12)
	local minDistance = 384

	hook.Add("PostDrawTranslucentRenderables", "Neeve Claymores Indicators", function()
		local client = LocalPlayer()

		render.SetMaterial(clay_mat)
		for k, v in pairs(ents.GetAll()) do
			if v:GetClass() == "ttt_tripmine" && client:GetTraitor() then
				local ang = v:GetAngles()
				local pos = v:GetPos()
					+ ang:Forward() * -2.0 
					+ ang:Up() * -1.3
					
				local tr = util.TraceLine {
					start = pos
					, endpos = pos + ang:Up() * cvarLaserLength:GetFloat() || 512
					, filter = v
					, mask = MASK_SOLID
					, ignoreworld = false
				}
				
				local distance = (tr.StartPos):Distance(tr.HitPos)
				local dV = client:GetPos() - tr.StartPos
				local v = math.Clamp(dV:Dot(tr.Normal), 0, distance) * tr.Normal

				distance = (tr.StartPos + v):Distance(client:GetPos())

				if (distance <= minDistance) then
					local alpha = math.min(1, 1 - (distance / minDistance) + 0.25)

					dir = client:GetForward() * -1

					clay_col.a = 255 * alpha
					render.DrawQuadEasy(tr.StartPos + v, dir, 12, 12, clay_col, 180)
				end
			end
		end
	end)
end