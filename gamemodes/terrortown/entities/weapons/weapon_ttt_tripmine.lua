AddCSLuaFile()

game.AddAmmoType({
    name = "neeve_tripmines"
})

SWEP.HoldType              = "normal"

if CLIENT then
    SWEP.PrintName         = "tripmine_name"
    SWEP.Slot              = 6

    SWEP.ViewModelFlip     = false
    SWEP.ViewModelFOV      = 10
    SWEP.DrawCrosshair     = false

    SWEP.EquipMenuData = {
        type = "item_weapon",
        desc = "tripmine_desc"
    };

    SWEP.Icon              = "vgui/ttt/icon_tripmine"
end

SWEP.Base                  = "weapon_tttbase"

SWEP.ViewModel             = "models/weapons/v_crowbar.mdl"
SWEP.WorldModel            = "models/weapons/w_slam.mdl"

SWEP.Primary.ClipSize      = 1
SWEP.Primary.DefaultClip   = 1
SWEP.Primary.Automatic     = true
SWEP.Primary.Ammo          = "neeve_tripmines"
SWEP.Primary.Delay         = 1

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = true
SWEP.Secondary.Ammo        = "none"
SWEP.Secondary.Delay       = 1.0

SWEP.Kind                  = WEAPON_EQUIP
SWEP.CanBuy                = {ROLE_TRAITOR}
SWEP.LimitedStock          = true

SWEP.AllowDrop             = true
SWEP.NoSights              = true

local cvarTripminesBuyCount = CreateConVar(
    "ttt_tripmine_buy_count"
    , 1
    , bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED)
    , "How many tripmines should the buyer receive?"
)

function SWEP:PrimaryAttack()
    if (self:Clip1() > 0 and self:TripmineStick()) then
        self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
        self:TakePrimaryAmmo(1)
        if (self:Ammo1() + self:Clip1() <= 0) then
            self:Remove()
        else
            self:Reload()
        end
    else
        self:SetNextPrimaryFire(CurTime() + 0.5)
    end
end

function SWEP:Think()
    if (self:Clip1() == 0 and self:Ammo1() > 0) then
        self:TakePrimaryAmmo(1)
        self:SetClip1(1)
    elseif (SERVER and self:Clip1() + self:Ammo1() == 0) then
        self:Remove()
    end
end

local throwsound = Sound("Weapon_SLAM.SatchelThrow")

function SWEP:TripmineStick()
    if SERVER then
        local ply = self.Owner
        if not IsValid(ply) then return end

        if self.Planted then return end

        local ignore = {ply, self}
        local spos = ply:GetShootPos()
        local epos = spos + ply:GetAimVector() * 80
        local tr = util.TraceLine({start=spos, endpos=epos, filter=ignore, mask=MASK_SOLID})

        if tr.HitWorld then
            local tripmine = ents.Create("ttt_tripmine")
            if IsValid(tripmine) then
                tripmine:PointAtEntity(ply)

                local ent = util.TraceEntity({
                    start    = spos
                    , endpos = epos
                    , filter = ignore
                    , mask   = MASK_SOLID
                }, tripmine)

                if (ent.HitWorld) then
                    local ang = ent.HitNormal:Angle()
                    ang:RotateAroundAxis(ang:Right(), -90)

                    tripmine:SetPos(ent.HitPos + ang:Up() * 2)
                    tripmine:SetAngles(ang)
                    tripmine:SetOwner(ply)
                    tripmine:Spawn()

                    local phys = tripmine:GetPhysicsObject()
                    if IsValid(phys) then
                        phys:EnableMotion(false)
                    end

                    return true
                end
            end
        end
    end
end

function SWEP:Reload()
    return false
end

function SWEP:OnRemove()
    if CLIENT
        && IsValid(self.Owner)
        && self.Owner == LocalPlayer()
        && self.Owner:Alive()
    then
        RunConsoleCommand("lastinv")
    end
end

if CLIENT then
    function SWEP:Initialize()
        self:AddHUDHelp("tripmine_help_plant", nil, false)

        self.GhostModel = ClientsideModel("models/weapons/w_slam.mdl")
        self.GhostModel:SetNoDraw(true)
        return self.BaseClass.Initialize(self)
    end

end

function SWEP:Deploy()
    if (IsValid(self.Owner)) then
        self.Owner:DrawViewModel(false)
    end
    return true
end

local laser = Material("sprites/bluelaser1")
local wireframe = Material("models/wireframe")
function SWEP:PostDrawViewModel(vm, weapon, ply)
    local ply = self.Owner
    if not IsValid(ply) then return end

    if self.Planted then return end

    local ignore = {self.Owner, self}
    local spos = ply:GetShootPos()
    local epos = spos
        + ply:GetAimVector() * 8000

    local tr = util.TraceLine {
        start    = spos
        , endpos = epos
        , filter = ignore
        , mask   = MASK_SOLID
    }

    if !tr.HitWorld
        || tr.HitPos:Distance(tr.StartPos) > 80
    then
        return
    end

    local matrix = Matrix()
    matrix:Scale(Vector(0.75, 0.75, 0.25))
    matrix:Scale(Vector(1, 1, 1) * 0.1)
    matrix:Translate(Vector(0, 0, 2))

    local ang = tr.HitNormal:Angle()
    ang:RotateAroundAxis(ang:Right(), -90)

    render.SetBlend(0.75)
    render.SetMaterial(wireframe)
    self.GhostModel:EnableMatrix("RenderMultiply", matrix)
    self.GhostModel:SetPos(tr.HitPos)
    self.GhostModel:SetNoDraw(true)
    self.GhostModel:SetAngles(ang)
    self.GhostModel:DrawModel()
    render.SetBlend(1)

    local pos = self.GhostModel:GetPos()
        + ang:Forward() * -0.2
        + ang:Up()      * 0.1

    render.SetMaterial(laser)
    render.StartBeam(2)
        render.AddBeam(pos, 0.5, 2, Color(255, 0, 0, 128))
        render.AddBeam(pos + ang:Up() * 1, 0.5, 3, Color(255, 0, 0, 128))
    render.EndBeam()
end

function SWEP:WasBought(buyer)
    if IsValid(buyer) then
        local additional = cvarTripminesBuyCount:GetInt() - 1
        if additional > 0 then
            buyer:SetAmmo(buyer:GetAmmoCount("neeve_tripmines") + additional, "neeve_tripmines")
        end
    end
end
