AddCSLuaFile()

local tripMines_guiWasRendering
if CLIENT then
    ENT.Icon = "vgui/ttt/icon_tripmine"
    ENT.PrintName = "tripmine_name"

    ENT.TargetIDHint = {
        name = "tripmine_name"
    };

    tripMines_guiWasRendering = {}
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

local cvarSleepTime = CreateConVar(
    "ttt_tripmine_sleeptime"
    , 2
    , bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED)
    , "Defines the time after which a tripmine starts emitting laser"
)

local drawMatrix = Matrix()
drawMatrix:Scale(Vector(0.75, 0.75, 0.25))
drawMatrix:Translate(Vector(0, 0, -6))

function ENT:Draw()
    local ang = self:GetAngles()

    self:EnableMatrix("RenderMultiply", drawMatrix)
    self:DrawModel()
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
    else
        if LocalPlayer():GetTraitor() then
            tripMines_guiWasRendering[self:EntIndex()] = nil

            chat.AddText(Color( 255, 30, 40 ),
                Format("(%s) ", string.upper(LANG.GetTranslation("traitor"))),
                Color( 255, 200, 20),
                self:GetOwner():Name(),
                Color( 255, 255, 200),
                ": " .. LANG.GetTranslation("tripmine_i_have_planted")
            )
        end
    end

    self:SetHealth(10)
    self.fingerprints = { self.Owner }

    timer.Simple(cvarSleepTime:GetFloat() || 2, function()
        if (IsValid(self)) then
            self.Enabled = true
        end
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
                start         = pos
                , endpos      = pos + ang:Up() * (cvarLaserLength:GetFloat() || 512)
                , mask        = MASK_SOLID
                , filter      = self
                , ignoreworld = false
            }
            
            local ent = trLine.Entity

            if !IsValid(ent) then
                local dist = trLine.StartPos:Distance(trLine.HitPos)
                local tr = util.TraceHull {
                    start    = pos
                    , endpos = pos + ang:Up() * dist
                    , maxs   = ang:Forward() *  4 + ang:Right() *  4
                    , mins   = ang:Forward() * -4 + ang:Right() * -4
                    , mask   = MASK_SOLID
                    , filter = self
                }

                ent = tr.Entity
            end

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
    local cvarTripTooltipDisable_cl = CreateConVar(
        "ttt_tripmine_tooltip_disable"
        , 0
        , bit.bor(FCVAR_ARCHIVE)
        , "Disables the trip mine world tooltip. Why?"
    )

    local cvarTripTooltipPreferTripMines_cl = CreateConVar(
        "ttt_tripmine_tooltip_prefer_tripmines"
        , 0
        , bit.bor(FCVAR_ARCHIVE)
        , "Defines whether the tooltip should prefer tripmines and not closest points to lasers"
    )

    local cvarTripTooltipDistance_cl = CreateConVar(
        "ttt_tripmine_tooltip_mindistance"
        , 384
        , bit.bor(FCVAR_ARCHIVE)
        , "Defines the minimum distance at which the tooltip should appear"
    )

    local cvarTripTooltipNoText_cl = CreateConVar(
        "ttt_tripmine_tooltip_notext"
        , 0
        , bit.bor(FCVAR_ARCHIVE)
        , "Disables the tooltip text"
    )

    local cvarTripTooltipNoIcon_cl = CreateConVar(
        "ttt_tripmine_tooltip_noicon"
        , 0
        , bit.bor(FCVAR_ARCHIVE)
        , "Disables the tooltip trip mine icon"
    )

    surface.CreateFont( "Neeve Claymores Font", {
        font = "Roboto",
        extended = false,
        size = ScreenScale(8),
        weight = 500,
        blursize = 0,
        scanlines = 0,
        antialias = true,
    } )

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
                    start         = pos
                    , endpos      = pos + ang:Up() * (cvarLaserLength:GetFloat() || 512)
                    , filter      = v
                    , mask        = MASK_SOLID
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

    local tripMines_guiX = {}
    local tripMines_guiY = {}
    local tripMineHUDMatrix = Matrix()

    local triangleA = {
        { x = -0.55 , y = 0.5  },
        { x = 0    , y = -0.6 },
        { x = 0    , y = 0.1 },
        { x = -0.2 , y = 0.5  },
    }

    local triangleB = {
        { x = 0.2 , y = 0.5  },
        { x = 0    , y = 0.1 },
        { x = 0    , y = -0.6 },
        { x = 0.55 , y = 0.5  },
    }    

    local color_white = Color(255, 255, 255, 255)
    local color_black = Color(0, 0, 0, 255)

    local tripMineHUDScale = math.min(ScrW(), ScrH()) * 0.03
    tripMineHUDMatrix:SetScale(Vector(tripMineHUDScale, tripMineHUDScale, tripMineHUDScale))

    hook.Add("HUDPaint", "Neeve Claymores Indicators", function()
        local client = LocalPlayer()

        if !client:GetTraitor() or cvarTripTooltipDisable_cl:GetBool() then
            return
        end

        local frameTime = RealFrameTime()
        surface.DisableClipping(true)

        for k, v in pairs(ents.GetAll()) do
            if v:GetClass() == "ttt_tripmine" then
                local entId = v:EntIndex()

                local ang = v:GetAngles()
                local pos = v:GetPos()
                    + ang:Forward() * -2.0
                    + ang:Up() * -1.3

                local tr = util.TraceLine {
                    start         = pos
                    , endpos      = pos + ang:Up() * (cvarLaserLength:GetFloat() || 512)
                    , filter      = v
                    , mask        = MASK_SOLID
                    , ignoreworld = false
                }

                -- Get the dot of the player position to the laser
                local distance = (tr.StartPos):Distance(tr.HitPos)
                local dVec = client:GetPos() - tr.StartPos
                local vec = math.Clamp(dVec:Dot(tr.Normal), 0, distance) * tr.Normal

                distance = (tr.StartPos + vec):Distance(client:GetPos())

                local minDst = cvarTripTooltipDistance_cl:GetFloat() || 384
                if minDst >= distance then
                    -- Helpful stuff
                    local HALF_SCREEN_WIDTH = ScrW() / 2
                    local HALF_SCREEN_HEIGHT = ScrH() / 2
                    local screenXRadius = HALF_SCREEN_WIDTH * 0.8
                    local screenYRadius = HALF_SCREEN_HEIGHT * 0.8

                    -- Check the convar if player prefers tripmines, and choose a point
                    local laserVec
                    if (!v.Enabled || cvarTripTooltipPreferTripMines_cl:GetBool()) then
                        laserVec = tr.StartPos
                    else
                        laserVec = tr.StartPos + vec
                    end

                    -- Define the alpha modifier based on the current distance
                    local alphaMod = 2 * math.Clamp(1 - (distance / minDst), 0, 1)

                    -- Calculate the on-screen point, and the distance to the screen center
                    laserVec = laserVec:ToScreen()
                    local localScreenX = laserVec.x
                    local localScreenY = laserVec.y
                    local magLocal = math.sqrt((localScreenX - HALF_SCREEN_WIDTH)^2 + (localScreenY - HALF_SCREEN_HEIGHT)^2)
                    
                    -- Calculate the angle of the on-screen point
                    local angle = math.atan2(localScreenY - HALF_SCREEN_HEIGHT, localScreenX - HALF_SCREEN_WIDTH)

                    -- Calculate the ellipse/radial point
                    local x = math.cos(angle) * screenXRadius
                    local y = math.sin(angle) * screenYRadius    
                    local magRadial = math.sqrt(x^2 + y^2)

                    -- Pick whether we should prefer the radial or the on-screen point based on the distance
                    local newX, newY
                    if magRadial <= magLocal then
                        newX = HALF_SCREEN_WIDTH  + x
                        newY = HALF_SCREEN_HEIGHT + y
                    else
                        newX = localScreenX
                        newY = localScreenY
                    end
                    
                    -- Make the point "pop" from the screen middle if this is the first rendering operation
                    local oldX, oldY
                    if tripMines_guiWasRendering[entId] then
                        oldX = tripMines_guiX[entId] || newX
                        oldY = tripMines_guiY[entId] || newY
                    else
                        oldX = HALF_SCREEN_WIDTH
                        oldY = HALF_SCREEN_HEIGHT
                    end

                    -- Lerp old X/Y values towards the new point
                    tripMines_guiX[entId] = math.Approach(oldX, newX, frameTime * (newX - oldX) * 12)
                    tripMines_guiY[entId] = math.Approach(oldY, newY, frameTime * (newY - oldY) * 12)  
        
                    -- Shorten the resulted vector ever so slightly
                    local trVec = Vector(tripMines_guiX[entId], tripMines_guiY[entId], 0)
                    do
                        local mag   = math.sqrt(
                            (trVec.x - HALF_SCREEN_WIDTH)^2 
                            + (trVec.y - HALF_SCREEN_HEIGHT)^2
                        ) - tripMineHUDScale * 1.25

                        angle = math.atan2(trVec.y - HALF_SCREEN_HEIGHT, trVec.x - HALF_SCREEN_WIDTH)

                        local rx   = HALF_SCREEN_WIDTH  + math.cos(angle) * (mag)
                        local ry   = HALF_SCREEN_HEIGHT + math.sin(angle) * (mag)
                        trVec = Vector(rx, ry, 0)
                    end

                    -- Draw the tooltip
                    if !cvarTripTooltipNoText_cl:GetBool() then
                        local owner = IsValid(v:GetOwner()) && v:GetOwner()
                        local text
                        if IsPlayer(owner) then
                            text = string.format(LANG.GetTranslation("tripmine_tooltip_careful"), owner:Name())
                        else
                            text = LANG.GetTranslation("tripmine_tooltip_careful_no_player")
                        end

                        draw.SimpleText(text, "TargetID", trVec.x - 1, trVec.y + ScreenScale(8) - 1, ColorAlpha(color_black, 255 * alphaMod), TEXT_ALIGN_CENTER)
                        draw.SimpleText(text, "TargetID", trVec.x,     trVec.y + ScreenScale(8)    , ColorAlpha(color_white, 255 * alphaMod), TEXT_ALIGN_CENTER)
                        
                        -- Draw the tooltip icon
                        if !cvarTripTooltipNoIcon_cl:GetBool() then
                            surface.SetFont( "TargetID" )
                            local textWidth, textHeight = surface.GetTextSize(text)

                            surface.SetMaterial(clay_mat)
                            surface.SetDrawColor(255, 255, 255, 255 * alphaMod)

                            surface.DrawTexturedRect(
                                trVec.x          - tripMineHUDScale * 2.25 - textWidth  / 2
                                , (trVec.y + ScreenScale(8)) - tripMineHUDScale / 2    - textHeight / 2
                                , tripMineHUDScale * 2
                                , tripMineHUDScale * 2
                            )
                        end
                    -- Or draw just the icon, if the tooltip is disabled
                    elseif !cvarTripTooltipNoIcon_cl:GetBool() then
                        surface.SetMaterial(clay_mat)
                        surface.SetDrawColor(255, 255, 255, 255 * alphaMod)
                        
                        surface.DrawTexturedRect(
                            trVec.x          - tripMineHUDScale
                            , (trVec.y + ScreenScale(8)) - tripMineHUDScale
                            , tripMineHUDScale * 2
                            , tripMineHUDScale * 2
                        )
                    end

                    -- Draw the orange arrow
                    draw.NoTexture()
                    surface.SetDrawColor(220, 64, 64, 255 * alphaMod)

                    tripMineHUDMatrix:SetTranslation(-trVec)
                    tripMineHUDMatrix:SetAngles(Angle(0, math.deg(angle) + 90, 0))
                    tripMineHUDMatrix:SetTranslation(trVec)
                    cam.PushModelMatrix(tripMineHUDMatrix)
                        surface.DrawPoly(triangleA)
                        surface.DrawPoly(triangleB)
                    cam.PopModelMatrix(tripMineHUDMatrix)

                    -- Mark the arrow as drawn
                    if !tripMines_guiWasRendering[entId] then
                        tripMines_guiWasRendering[entId] = true
                    end
                else
                    -- Unmark the arrow as drawn
                    if tripMines_guiWasRendering[entId] then
                        tripMines_guiWasRendering[entId] = nil
                    end
                end
            end
        end

        surface.DisableClipping(false)
    end)
end
