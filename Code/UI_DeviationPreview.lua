---------------------------------------------------------------------------------------------------
---- Aim preview for grenades and launchers: a dotted ellipse where 90% of the throws land, and a
---- badge on every visible unit with its chance to end up inside the blast.
---- Both read EO_LandingDistribution, the same dice and offset math as rat_custom_deviation.
---------------------------------------------------------------------------------------------------

DefineClass.EO_DeviationEllipse = {__parents = {"Mesh"}}

local last_key = false

---- badges are UI windows, not map objects: found by flag so a mod reload leaves no orphans
local function close_badges()
    local igi = GetInGameInterface()
    for i = #(igi or empty_table), 1, -1 do
        local win = igi[i]
        if win.eo_devi_badge and win.window_state ~= "destroying" then
            win:Close()
        end
    end
end

function EO_ClearDeviationPreview()
    close_badges()
    MapForEach("map", "EO_DeviationEllipse", DoneObject)
    last_key = false
end

local function draw_ellipse(center, fwd, a, b)
    local n = const.EO.DeviationPreviewDashes
    local side = point(-fwd:y(), fwd:x(), 0)
    local z = (center:IsValidZ() and center:z() or terrain.GetHeight(center)) +
                  const.EO.DeviationPreviewLift
    local function at(i)
        local ang = MulDivRound(i, 360 * 60, n)
        local ca, sa = MulDivRound(a, cos(ang), 4096), MulDivRound(b, sin(ang), 4096)
        return point(center:x() + MulDivRound(fwd:x(), ca, 4096) + MulDivRound(side:x(), sa, 4096),
                     center:y() + MulDivRound(fwd:y(), ca, 4096) + MulDivRound(side:y(), sa, 4096), z)
    end
    local mesh = pstr("", 4096)
    local dist = 0
    for i = 0, n - 1, 2 do
        dist = CRTrail_AppendLineSegment(mesh, at(i), at(i + 1), dist, false, false)
    end
    local obj = PlaceObject("EO_DeviationEllipse")
    obj:SetMeshFlags(const.mfWorldSpace)
    local mat = CRM_VisionLinePreset:GetById("PreparedAttack"):Clone()
    mat.fill_color = const.EO.DeviationPreviewColor
    mat.glow_color = SetA(const.EO.DeviationPreviewColor, 60)
    mat.length = dist
    obj:SetCRMaterial(mat)
    obj:SetMesh(mesh)
    obj:SetPos(center)
end

local function show_badge(unit, permille, friendly)
    local igi = GetInGameInterface()
    if not igi then
        return
    end
    local win = XWindow:new({
        HAlign = "left", VAlign = "top", HandleMouse = false, UseClipBox = false,
        eo_devi_badge = true
    }, igi)
    ---- setters, not constructor props: XText only measures what SetText/SetTextStyle hand it
    local label = XText:new({Translate = false, UseClipBox = false, Clip = false}, win)
    label:SetTextStyle("CrosshairBadgeName")
    label:SetTextColor(friendly and const.EO.DeviationBadgeFriendlyColor or
                           const.EO.DeviationBadgeEnemyColor)
    label:SetText(string.format("%d%%", (permille + 5) / 10))
    win:AddDynamicPosModifier({
        id = "attached_ui",
        target = unit:GetVisualPos() + point(0, 0, const.EO.DeviationBadgeHeight)
    })
    win:Open()
end

---- chance (permille) that the blast centered on each landing sample reaches the unit
local function blast_permille(dist, target_pos, unit_pos, blast)
    local hits = 0
    for _, smp in ipairs(dist.samples) do
        if (target_pos + smp.offset):Dist2D(unit_pos) <= blast then
            hits = hits + smp.w
        end
    end
    return MulDivRound(hits, 1000, dist.total)
end

local function show_badges(attacker, dist, target_pos, blast)
    local reach = blast + Max(dist.along, dist.across) * 2
    for _, unit in ipairs(g_Units) do
        if not unit:IsDead() and unit:IsValidPos() and unit:GetDist2D(target_pos) <= reach and
            (unit.team == attacker.team or HasVisibilityTo(attacker.team, unit)) then
            local p = blast_permille(dist, target_pos, unit:GetPos(), blast)
            if p >= const.EO.DeviationBadgeMinPermille then
                show_badge(unit, p, not unit:IsOnEnemySide(attacker))
            end
        end
    end
end

local function preview_weapon(dialog)
    local action = dialog.action
    local attacker = dialog.attacker
    local weapon = action and IsValid(attacker) and action:GetAttackWeapons(attacker)
    if IsKindOfClasses(weapon, "Grenade", "GrenadeLauncher", "RocketLauncher") then
        return weapon, action, attacker
    end
end

function EO_UpdateDeviationPreview(dialog, blackboard, command)
    if not const.EO.DeviationPreview or command == "delete" or command == "delete-except-grenade" or
        dialog.attack_confirmed then
        EO_ClearDeviationPreview()
        return
    end
    local weapon, action, attacker = preview_weapon(dialog)
    local aim_pt = dialog.target_as_pos
    if not weapon or not IsPoint(aim_pt) then
        EO_ClearDeviationPreview()
        return
    end
    local key = tostring(aim_pt) .. tostring(attacker:GetPos()) .. tostring(weapon)
    if key == last_key then
        return
    end
    EO_ClearDeviationPreview()
    last_key = key
    local dist = EO_LandingDistribution(weapon, attacker, aim_pt, const.EO.DeviationPreviewDirSamples)
    if not dist then
        return
    end
    local params = weapon:GetAreaAttackParams(action.id, attacker, aim_pt)
    local blast = (params and params.max_range or 0) * const.SlabSizeX
    if dist.along > 0 or dist.across > 0 then
        draw_ellipse(aim_pt, dist.fwd, Max(dist.along, guim / 4), Max(dist.across, guim / 4))
    end
    if blast > 0 then
        show_badges(attacker, dist, aim_pt, blast)
    end
end

local Targeting_AOE_ParabolaAoE_orig = Targeting_AOE_ParabolaAoE
function Targeting_AOE_ParabolaAoE(dialog, blackboard, command, pt)
    Targeting_AOE_ParabolaAoE_orig(dialog, blackboard, command, pt)
    EO_UpdateDeviationPreview(dialog, blackboard, command)
end

---- the lookup captures the function value when it is built
local function patch_lookup()
    if TargetingModeLookup then
        TargetingModeLookup["parabola aoe"] = Targeting_AOE_ParabolaAoE
    end
end
patch_lookup()
OnMsg.ClassesBuilt = patch_lookup
