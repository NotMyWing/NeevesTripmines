AddCSLuaFile()

game.AddAmmoType({
    name = "neeve_tripmines"
})

SWEP.HoldType              = "slam"

if CLIENT then
    SWEP.PrintName         = "tripmine_name"
    SWEP.Slot              = 6

    SWEP.ViewModelFlip     = false
    SWEP.ViewModelFOV      = 60
    SWEP.DrawCrosshair     = false

    SWEP.EquipMenuData = {
        type = "item_weapon",
        desc = "tripmine_desc"
    };

    SWEP.Icon              = "vgui/ttt/icon_tripmine"
end

SWEP.Base                  = "weapon_tttbase"
SWEP.ViewModel             = "models/weapons/c_slam.mdl"
SWEP.WorldModel            = "models/weapons/w_slam.mdl"

SWEP.Primary.ClipSize      = 1
SWEP.Primary.DefaultClip   = 1
SWEP.Primary.Automatic     = true
SWEP.Primary.Ammo          = "neeve_tripmines"
SWEP.Primary.Delay         = 2

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

SWEP.UseHands              = true

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
            timer.Simple(0.3, function()
                if (self:IsValid() and self:Ammo1() + self:Clip1() <= 0) then
                    self:Remove()
                end
            end)
        end

        self:SendWeaponAnim(ACT_SLAM_TRIPMINE_ATTACH2)
        timer.Simple(self.Primary.Delay - 0.5, function()
            if (self:IsValid()) then
                self:SendWeaponAnim(ACT_SLAM_TRIPMINE_DRAW)
            end
        end)
    else
        self:SetNextPrimaryFire(CurTime())
    end
end

function SWEP:Think()
    if (self:Clip1() == 0 and self:Ammo1() > 0) then
        self:TakePrimaryAmmo(1)
        self:SetClip1(1)
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
                    tripmine:SetNWEntity("Owner", ply)
                    tripmine:Spawn()
                    tripmine.fingerprints = { ply }

                    net.Start("Neeve Tripmines Notify")
                        net.WriteEntity(ply)
                    net.Send(GetTraitorFilter())

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
    self:SetNextPrimaryFire(CurTime())
    self:SendWeaponAnim(ACT_SLAM_TRIPMINE_DRAW)
    return true
end

local laser = Material("sprites/bluelaser1")
local wireframe = Material("models/wireframe")

function SWEP:DrawHUD()
    self.BaseClass.DrawHUD(self)

    cam.Start3D()
        local ply = self.Owner
        if not IsValid(ply) then return cam.End3D() end

        if self.Planted then return cam.End3D() end

        local ignore = {self.Owner, self}
        local spos = ply:EyePos()
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
            return cam.End3D()
        end

        local matrix = Matrix()
        matrix:Scale(Vector(0.75, 0.75, 0.25))
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
            + ang:Forward() * -2.0 

        render.SetMaterial(laser)
        render.StartBeam(2)
            render.AddBeam(pos, 0.5, 2, Color(255, 0, 0, 128))
            render.AddBeam(pos + ang:Up() * 4, 0.5, 3, Color(255, 0, 0, 128))
        render.EndBeam()
    cam.End3D()
end

function SWEP:WasBought(buyer)
    if IsValid(buyer) then
        local additional = cvarTripminesBuyCount:GetInt() - 1
        if additional > 0 then
            buyer:SetAmmo(buyer:GetAmmoCount("neeve_tripmines") + additional, "neeve_tripmines")
        end
    end
end

if (SERVER) then
    util.AddNetworkString("Neeve Tripmines Notify")
else
    net.Receive("Neeve Tripmines Notify", function()
        local ply = net.ReadEntity()
        if (ply:IsValid() and ply:IsPlayer()) then
            chat.AddText(Color( 255, 30, 40 ),
                Format("(%s) ", string.upper(LANG.GetTranslation("traitor"))),
                Color( 255, 200, 20),
                ply:Name(),
                Color( 255, 255, 200),
                ": " .. LANG.GetTranslation("tripmine_i_have_planted")
            )
        end
    end)
end
