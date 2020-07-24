AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )

ENT.PrintName = "TTT Tripmine Laser Dummy"
ENT.Spawnable = false

function ENT:Initialize()
    self:DrawShadow(false)
    self:SetCustomCollisionCheck(true)
end

function ENT:SetupDataTables()
    self:NetworkVar("Float", 1, "Size")
    self:NetworkVarNotify("Size", self.SizeNotify)
end

function ENT:Touch(ent)
    local class = ent:GetClass()

    if IsValid(self.tripmine) && !self.tripmine.Activated && ent:IsPlayer() && !(
        class:find("static")
        || class:find("door")
        || class:find("tripmine")
    ) then
        local tr = self.tripmine:GetLaserTrace()

        if tr && (tr.Entity == ent) then
            self.tripmine:Trigger(ent)
        end
    end
end

local hitbox_radius = 0.5

function ENT:__SetSize(newSize)
    self.Mins = Vector(-hitbox_radius, -hitbox_radius, 0       )
    self.Maxs = Vector( hitbox_radius,  hitbox_radius, newSize )

	self:SetCollisionBounds(self.Mins, self.Maxs)

    if self:PhysicsInitBox(self.Mins, self.Maxs) then
        self:SetSolid(SOLID_VPHYSICS)
        self:PhysWake()

        self:EnableCustomCollisions(true)

        local phys = self:GetPhysicsObject()
        phys:EnableMotion(false)

        self:SetSolidFlags( bit.bor( FSOLID_TRIGGER, FSOLID_USE_TRIGGER_BOUNDS, FSOLID_NOT_SOLID ) )
    end
end

function ENT:SizeNotify(name, old, new)
    if name == "Size" then
        self:__SetSize(new)
    end
end

function ENT:Think()
    if SERVER then
        if not IsValid(self.tripmine) then
            self:Remove()
        end
    end
end

function ENT:Draw()
end
