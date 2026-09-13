function MishapProperties:rat_deviation(attacker, target_pos, attack_args, attack_pos)

    -- target_pos = target_pos or attack_args.target_pos
    -- or attack_args.target and IsValid(attack_args.target) and attack_args.target:GetPos()

    local deviatePosition = self:rat_custom_deviation(attacker, target_pos, attack_pos, false)
    if not deviatePosition then
        return target_pos, false
    end
    -- DbgAddCircle(target_pos, const.SlabSizeX, const.clrGreen)
    -- DbgAddCircle(deviatePosition, const.SlabSizeX, const.clrRed)
    local target_posz = target_pos:z()

    target_pos = validate_deviated_gren_pos(IsValidZ(deviatePosition) and deviatePosition or
                                                deviatePosition:SetZ(target_posz), attack_args)
    -- DbgAddCircle(target_pos, const.SlabSizeX, const.clrCyan)
    return target_pos, true
end

function validate_deviated_gren_pos(explosion_pos, attack_args)
    -- if not explosion_pos then
    --     return explosion_pos
    -- end
    -- if not IsValidZ(explosion_pos) then
    --     explosion_pos = explosion_pos:SetTerrainZ()
    -- end
    local newGroundPos -- = explosion_pos
    if explosion_pos then
        local slab, slab_z = WalkableSlabByPoint(explosion_pos, "downward only")
        local z = explosion_pos:z()
        if slab_z and slab_z <= z and slab_z >= z - guim then
            newGroundPos = explosion_pos:SetZ(slab_z)
        else
            newGroundPos = explosion_pos:SetTerrainZ()
            local col, pts = CollideSegmentsNearest(explosion_pos, newGroundPos)
            if col then
                newGroundPos = pts[1]
            end
        end
    end

    return newGroundPos
end

---- em qual banda cai um erro (em milesimos de tile)
local function band_of(err)
    for _, b in ipairs(const.EO.DeviationLabelBands) do
        if not b.max or err <= b.max then
            return b
        end
    end
    return const.EO.DeviationLabelBands[#const.EO.DeviationLabelBands]
end

---- T() so na primeira chamada: nao depende de T estar pronto na hora do load
local BAND_TEXTS
local function band_text(b, is_grenade)
    ---- banda muda: e o arremesso comum, nao merece texto na tela
    if b.silent then
        return nil
    end
    BAND_TEXTS = BAND_TEXTS or {
        Perfect = {T("Perfect Throw"), T("Perfect Launch")},
        Great = {T("Great Throw"), T("Great Launch")},
        Innacurate = {
            T("<color AmmoAPColor>Innacurate Throw</color>"),
            T("<color AmmoAPColor>Innacurate Launch</color>")
        },
        Terrible = {
            T("<color AmmoAPColor>Terrible Throw</color>"),
            T("<color AmmoAPColor>Terrible Launch</color>")
        }
    }
    local row = BAND_TEXTS[b.name]
    return row and row[is_grenade and 1 or 2]
end

local num_dice = 2
---------

local function throw_dice(max_value, num_dice, unit)

    num_dice = num_dice or 2 -- Default to 2 dice if not provided
    local total = 0

    local dice_value = MulDivRound(max_value, 1, num_dice)

    for i = 1, num_dice do
        total = total + InteractionRand(dice_value, "RATONADE_DeviationRoll", unit)
    end

    return total
end

---- eleva um valor em milesimos a um expoente inteiro, mantendo a escala de milesimos
local function pow_milli(v, k)
    local r = 1000
    for _ = 1, k do
        r = MulDivRound(r, v, 1000)
    end
    return r
end

---- alcance maximo do item em tiles (mesma conta que o GetMishapChance faz)
local function max_range_tiles(item, unit)
    if IsKindOf(item, "Grenade") then
        local mr = item:GetMaxAimRange(unit)
        if HasPerk(unit, "Throwing") then
            mr = mr + (CharacterEffectDefs.Throwing:ResolveValue("RangeIncrease") or 0)
        end
        return mr
    end
    return item.WeaponRange
end

---- raio do erro em milesimos de tile, a partir do roll e do stat da UI.
---- dist_pct = distancia do arremesso como % do alcance maximo (0..100)
local function deviation_radius(stat, roll, is_grenade, dist_pct)
    local gate = MulDivRound(stat, const.EO.DeviationStatFactorForPerfectThrow, 100)
    if roll <= gate then
        return 0, gate
    end
    ---- miss em milesimos: onde este roll cai entre o gate e o pior roll possivel
    local miss = MulDivRound(roll - gate, 1000, 100 - gate)
    local curve = pow_milli(miss, const.EO.DeviationShape)
    if const.EO.DeviationShapeMirror then
        curve = 1000 - pow_milli(1000 - miss, const.EO.DeviationShape)
    end

    local r_min = Max(0, const.EO.DeviationMinBASE -
                          MulDivRound(const.EO.DeviationMinSCALE, stat, 100))
    local r_max = Max(r_min, const.EO.DeviationMaxBASE -
                          MulDivRound(const.EO.DeviationMaxSCALE, stat, 100))
    ---- canal 2: a distancia mexe na largura. O piso nao se mexe.
    local perto = const.EO.DeviationSpreadNEAR or 100
    local longe = const.EO.DeviationSpreadFAR or 100
    if perto ~= 100 or longe ~= 100 then
        local spread = perto + MulDivRound(longe - perto, Min(100, dist_pct or 100), 100)
        r_max = r_min + MulDivRound(r_max - r_min, Max(0, spread), 100)
    end

    local r = r_min + MulDivRound(r_max - r_min, curve, 1000)

    if not is_grenade and const.EO.DeviationLauncherRadiusMul ~= 100 then
        r = MulDivRound(r, const.EO.DeviationLauncherRadiusMul, 100)
    end
    return r, gate
end

---- "1972" -> "1.97"
local function fmt_tiles(milesimos)
    local neg = milesimos < 0
    local m = neg and -milesimos or milesimos
    return string.format("%s%d.%02d", neg and "-" or "", m / 1000, (m % 1000) / 10)
end

---- Rolls que caem em cada percentil do dado (2 x InteractionRand(50), roll 1..99).
---- Como o raio e monotonico no roll, o percentil do raio e o raio DO percentil do roll.
local pctl_rolls = {{10, 22}, {25, 35}, {50, 50}, {75, 65}, {90, 78}}

---- Desenha, em volta do alvo, os aneis de percentil deste arremessador e os
---- limiares dos rotulos.
---- ---------------------------------------------------------------------------
---- Chaves do desenho de debug. Todas globais: da para ligar e desligar ao vivo
---- pelo console, sem recarregar o Lua.
----
----   EO_DeviationDebug       CHAVE MESTRA: desliga desenho E print de uma vez
----   EO_DeviationRings       liga/desliga o desenho inteiro
----   EO_DeviationLabels      os aneis dos rotulos  (verde / amarelo / vermelho)
----   EO_DeviationPercentis   os aneis de percentil (azul, p50 em ciano)
----   EO_DeviationClear       limpar a tela antes de cada arremesso
----
---- Desligue o EO_DeviationClear para acumular varios arremessos na tela e comparar.
---- Nesse modo nada apaga sozinho: chame DbgClear() no console quando quiser zerar.
---- (A versao anterior tentava manter N arremessos com um contador e nao funcionou
---- na pratica, entao virou um liga/desliga simples.)
---- ---------------------------------------------------------------------------
if EO_DeviationDebug == nil then
    EO_DeviationDebug = false
end
if EO_DeviationRings == nil then
    EO_DeviationRings = true
end
if EO_DeviationLabels == nil then
    EO_DeviationLabels = true
end
if EO_DeviationPercentis == nil then
    EO_DeviationPercentis = true
end
if EO_DeviationClear == nil then
    EO_DeviationClear = true
end

function EO_DrawDeviationRings(target_pos, stat, is_grenade, dist_pct)
    if not EO_DeviationDebug or not EO_DeviationRings or not target_pos then
        return
    end
    if EO_DeviationClear and DbgClear then
        DbgClear()
    end

    ---- limiares dos rotulos: fixos em tiles, iguais para todo merc e toda granada
    for _, b in ipairs(EO_DeviationLabels and const.EO.DeviationLabelBands or empty_table) do
        if b.ring and b.max and b.max > 0 then
            DbgAddCircle_devi(target_pos, MulDivRound(b.max, const.SlabSizeX, 1000), const[b.ring])
        end
    end

    ---- percentis do arremessador: onde a granada dele cai em 10/25/50/75/90% dos casos
    for _, row in ipairs(EO_DeviationPercentis and pctl_rolls or empty_table) do
        local r = deviation_radius(stat, row[2], is_grenade, dist_pct)
        if r > 0 then
            local c = (row[1] == 50) and const.clrCyan or const.clrBlue
            DbgAddCircle_devi(target_pos, MulDivRound(r, const.SlabSizeX, 1000), c)
        end
    end

end

---- Uma linha por arremesso, com tudo que esta desenhado no mapa.
function EO_PrintDeviation(info)
    if not EO_DeviationDebug or not Platform.developer then
        return
    end
    local pct = {}
    for _, row in ipairs(pctl_rolls) do
        pct[#pct + 1] = string.format("p%d %s", row[1], fmt_tiles(
                                          deviation_radius(info.stat, row[2], info.is_grenade,
                                                           info.dist_pct)))
    end
    print("---- RATONADE deviation --------------------------------------")
    print(string.format(
              "   stat  base %d | mods -%d (range -%d @ %s t) | UI %d | IA %+d | usado %d",
              info.stat_base, info.mods, info.range_pen, fmt_tiles(info.dist_m), info.stat_ui,
              -info.ai_modifier, info.stat))
    print(string.format("   roll %d | gate %d | erro %s t  ->  %s", info.roll, info.gate,
                        fmt_tiles(info.err), band_of(info.err).name))
    print("   percentis (aneis azuis, p50 ciano):  " .. table.concat(pct, "   "))
    local faixas = {}
    for _, b in ipairs(const.EO.DeviationLabelBands) do
        if b.max and b.max > 0 then
            faixas[#faixas + 1] = string.format("%s <=%s", b.name, fmt_tiles(b.max))
        elseif not b.max then
            faixas[#faixas + 1] = b.name .. " acima"
        end
    end
    print("   rotulos (verde/amarelo/vermelho):  " .. table.concat(faixas, "   "))
    print("--------------------------------------------------------------")
end

function MishapProperties:rat_custom_deviation(unit, target_pos, attack_pos, test)

    local is_grenade = IsKindOf(self, "Grenade")
    local ai_modifier = AI_deviate_skill_diff(unit) or 0

    ---- BUGFIX (B9): o wound_penalty ja foi descontado dentro de GetDeviationModifier.
    ---- A versao antiga somava ele de volta aqui, o que anulava o Wounded por completo
    ---- e fazia a tooltip mentir. Aqui o stat da UI entra inteiro, sem correcao.
    local mishap = self:GetMishapChance(unit, target_pos)
    local stat_ui = mishap[1]
    local stat_base, mods, range_pen = mishap[2] or stat_ui, mishap[3] or 0, mishap[4] or 0
    local stat = Max(0, Min(100, stat_ui - ai_modifier))
    local dist_m = (target_pos and attack_pos) and
                       MulDivRound(attack_pos:Dist(target_pos), 1000, const.SlabSizeX) or 0
    local mr_tiles = max_range_tiles(self, unit) or 0
    local dist_pct = mr_tiles > 0 and Min(100, MulDivRound(dist_m, 100, mr_tiles * 1000)) or 100

    local roll = throw_dice(100, num_dice, unit) + 1

    ---- BUGFIX (B12) desync: os dois rolls de direcao saem SEMPRE, antes de qualquer
    ---- early return. O "radius <= 0" depende de mod options locais (deviate_stat,
    ---- grenade_throw_diff, dificuldade da IA) e de cheat; pular os rolls num acerto
    ---- perfeito fazia cada maquina consumir uma quantidade diferente do InteractionRand.
    local dir_roll = InteractionRand(2001, "RATONADE_DeviationDir", unit) - 1000
    local flip_roll = InteractionRand(2, "RATONADE_DeviationFlip", unit)

    roll = CheatEnabled("AlwaysHit") and 1 or roll
    roll = CheatEnabled("AlwaysMiss") and 99 or roll

    local radius, gate = deviation_radius(stat, roll, is_grenade, dist_pct)

    if test then
        return radius, roll
    end

    EO_DrawDeviationRings(target_pos, stat, is_grenade, dist_pct)

    ---- acerto exato: quem chama trata o false como "nao desviou"
    if radius <= 0 then
        EO_PrintDeviation({
            stat_base = stat_base,
            mods = mods,
            range_pen = range_pen,
            dist_m = dist_m,
            dist_pct = dist_pct,
            stat_ui = stat_ui,
            ai_modifier = ai_modifier,
            stat = stat,
            roll = roll,
            gate = gate,
            err = 0,
            is_grenade = is_grenade
        })
        CreateFloatingText(target_pos, T("Perfect Throw"))
        return false
    end

    local dir = target_pos - attack_pos
    dir = point(dir:x(), dir:y(), 0)
    if dir:Len() == 0 then
        return false
    end

    ---- direcao: theta = 90deg * sinal(u) * |u|^const.EO.DeviationDirBias, u uniforme em [-1000, 1000].
    ---- const.EO.DeviationDirBias > 1 concentra o erro no eixo do arremesso (cai curto ou passa longe)
    ---- em vez de espalhar para os lados.
    local u = dir_roll
    local sign = u < 0 and -1 or 1
    local shaped = pow_milli(abs(u), const.EO.DeviationDirBias)
    local angle = sign * MulDivRound(90 * 60, shaped, 1000)
    if flip_roll == 1 then
        angle = angle + 180 * 60
    end

    local radius_world = MulDivRound(radius, const.SlabSizeX, 1000)
    local offset = Rotate(SetLen(dir, radius_world), angle)

    ---- const.EO.DeviationShortMul < 100 encurta so a metade que volta na direcao do arremessador
    if const.EO.DeviationShortMul ~= 100 then
        local fwd = SetLen(dir, 4096)
        local along = MulDivRound(offset:x(), fwd:x(), 4096) +
                          MulDivRound(offset:y(), fwd:y(), 4096)
        if along < 0 then
            local cut = MulDivRound(along, 100 - const.EO.DeviationShortMul, 100)
            offset = offset -
                         point(MulDivRound(fwd:x(), cut, 4096), MulDivRound(fwd:y(), cut, 4096), 0)
        end
    end

    ---- o erro e uma distancia ATE O ALVO, nao uma fracao do vetor de arremesso
    local final_pos = target_pos + offset

    ---- o rotulo sai do erro REAL em tiles, entao tem que ser calculado depois da
    ---- geometria. Na versao antiga o texto era emitido antes, olhando o deviation.
    local err = MulDivRound(offset:Len(), 1000, const.SlabSizeX)
    local float_text = band_text(band_of(err), is_grenade)
    if float_text then
        CreateFloatingText(target_pos, float_text)
    end
    EO_PrintDeviation({
        stat_base = stat_base,
        mods = mods,
        range_pen = range_pen,
        dist_m = dist_m,
        dist_pct = dist_pct,
        stat_ui = stat_ui,
        ai_modifier = ai_modifier,
        stat = stat,
        roll = roll,
        gate = gate,
        err = err,
        is_grenade = is_grenade
    })

    ---- onde caiu de verdade: ponto branco na ponta do vetor vermelho
    DbgAddVector_devi(target_pos, offset, const.clrRed)
    DbgAddCircle_devi(final_pos, const.SlabSizeX / 5, const.clrWhite)

    return final_pos
end

function EO_GetWoundPenalty_Deviation(unit)
    if not IsGameRuleActive("HeavyWounds") then
        return 0
    end
    local wounds = unit:GetStatusEffect("Wounded")
    if not wounds then
        return 0
    end
    local max_wounds = GameRuleDefs.HeavyWounds:ResolveValue("MaxWoundsEffect")

    local stacks = Min(max_wounds, wounds.stacks)
    return stacks * const.EO.DeviationWoundStackPenalty
end

if EO_DeviationDebugRoll == nil then
    EO_DeviationDebugRoll = false
end

function GetDeviationModifier(item, unit, target, stat, diff_dist, opt_diff)
    local item_acc = item:get_throw_accuracy(unit)
    local wound_penalty = EO_GetWoundPenalty_Deviation(unit)
    local modifiers = -item_acc + opt_diff + diff_dist + wound_penalty
    modifiers = unit:HasStatusEffect("Inaccurate") and modifiers + const.EO.DeviationInnacuratePenalty or modifiers
    modifiers = (unit:HasStatusEffect("Blinded") or unit:HasStatusEffect("dazed_flashbang")) and
                    modifiers + const.EO.DeviationBlindDazedPenalty or modifiers

    --if GameState.RainHeavy and IsKindOf(item, "GrenadeProperties") then
    --    modifiers = modifiers and modifiers + const.EO.DeviationHeavyRainPenalty or 10
    --end
    ---- [1] e o que a UI mostra e o que o motor usa. Os demais existem so para o
    ---- print de debug conseguir mostrar de onde o numero veio.
    if EO_DeviationDebugRoll then
        return {EO_DeviationDebugRoll, stat, modifiers, diff_dist}
    end

    return {Max(0, stat - modifiers), stat, modifiers, diff_dist}
end

------------Grenade

function Grenade:GetMishapChance(unit, target, async)
    local attack_pos = unit:GetPos()
    local target_pos = target
    if not target then
        return {0, 0}
    end
    local dex = unit.Dexterity
    local explo = unit.Explosives
    local thrower_perk = HasPerk(unit, "Throwing")
    local opt = CurrentModOptions.deviate_stat or "Dexterity/Explosives"

    dex = opt == "Dexterity" and dex or opt == "Explosives" and explo or cRound((dex + explo) / 2)
    dex = dex + 0
    dex = thrower_perk and dex + 10 or dex
    dex = Max(45, dex)

    local max_range = self:GetMaxAimRange(unit)
    if thrower_perk then
        max_range = max_range + CharacterEffectDefs.Throwing:ResolveValue("RangeIncrease") or 0
    end
    max_range = max_range * const.SlabSizeX
    local dist = attack_pos:Dist(target_pos)
    local ratio_dist = dist * 1.00 / max_range * 1.00
    local diff_dist = cRound(ratio_dist * const.EO.DeviationGrenadeDistPen)

    local opt_diff = extractNumberWithSignFromString(CurrentModOptions.grenade_throw_diff) or 0

    return GetDeviationModifier(self, unit, target, dex, diff_dist, opt_diff)
end

function Grenade:get_throw_accuracy(unit)
    local shape_list = {
        Spherical = 0,
        Stick_like = 0,
        Cylindrical = -2,
        Can = -3,
        Long = -5,
        Brick = -4,
        Bottle = -6
    }
    local acc = shape_list[self.r_shape] or 0

    if IsKindOf(self, "FlareStick") or IsKindOf(self, "GlowStick") then
        acc = acc + 12
    end

    if IsKindOf(self, "ShapedCharge") then
        acc = unit and unit.unitdatadef_id == "Barry" and acc + const.EO.ShapedChargeBarryAccModifier or acc + const.EO.ShapedChargeOthersAccModifier
    end
    return acc
end

-----------GL
function GrenadeLauncher:GetMishapChance(unit, target, async)
    local attack_pos = unit:GetPos()
    local target_pos = target

    if not target then
        return {0, 0}
    end

    local deviation = 0
    local marks = unit.Marksmanship
    local explo = unit.Explosives

    local opt = CurrentModOptions.deviate_stat_GL or "Marksmanship/Explosives"
    local stat = (marks + explo) / 2

    stat = opt == "Marksmanship" and marks or opt == "Explosives" and explo or
               cRound((marks + explo) / 2)
    stat = Max(45, stat)

    local max_range = self.WeaponRange

    max_range = max_range * const.SlabSizeX
    local dist = attack_pos:Dist(target_pos)
    local ratio_dist = dist * 1.00 / max_range * 1.00
    local diff_dist = cRound(ratio_dist * const.EO.DeviationGLDistPen)

    local opt_diff = extractNumberWithSignFromString(CurrentModOptions.GL_throw_diff) or 0

    return GetDeviationModifier(self, unit, target, stat, diff_dist, opt_diff)
end

function GrenadeLauncher:get_throw_accuracy(unit)
    if unit then
        local active_wep = unit:GetActiveWeapons()
        return self == active_wep and 0 or const.EO.DeviationUnderSlungGLModifier
    end
    return 0
end

-----------RPG

function RocketLauncher:GetMishapChance(unit, target, async)
    local attack_pos = unit:GetPos()
    local target_pos = target

    if not target then
        return {0, 0}
    end

    local str = unit.Strength
    local explo = unit.Explosives

    local opt = CurrentModOptions.deviate_stat_RPG or "Strength/Explosives"
    local stat = (str + explo) / 2

    stat = opt == "Strength" and str or opt == "Explosives" and explo or cRound((str + explo) / 2)
    stat = Max(45, stat)

    local max_range = self.WeaponRange

    max_range = max_range * const.SlabSizeX
    local dist = attack_pos:Dist(target_pos)
    local ratio_dist = dist * 1.00 / max_range * 1.00
    local diff_dist = cRound(ratio_dist * const.EO.DeviationRPGDistPen)

    local opt_diff = extractNumberWithSignFromString(CurrentModOptions.RPG_throw_diff) or 0

    return GetDeviationModifier(self, unit, target, stat, diff_dist, opt_diff)
end

function RocketLauncher:get_throw_accuracy(unit)
    return 0
end
-------------
function get_label_throwacc(num)
    if num == 100 then
        return T("Perfect")
    elseif num >= 90 then
        return T("Very High")
    elseif num >= 80 then
        return T("High")
    elseif num >= 70 then
        return T("Moderately High")
    elseif num >= 60 then
        return T("Medium")
    elseif num >= 50 then
        return T("Moderately Low")
    elseif num >= 40 then
        return T("Low")
    elseif num >= 30 then
        return T("Very Low")
    elseif num >= 20 then
        return T("Extremely Low")
    else
        return T("Abysmal")
    end
end
------------------Tests

---- this is not working anymore
function deviation_prob(dex, expl, steps, not_round)
    local dex = dex or 80
    local expl = expl or 80
    local steps = steps or 0.5
    local deviations = {}
    local unit = g_Units.Barry
    unit.Dexterity = dex
    unit.Explosives = expl
    local grenade = g_Classes["Grenade"] -- unit:GetItemInSlot("Handheld A", "Grenade", 1, 1)
    local mishap_chance = grenade:GetMishapChance(unit, unit:GetPos())
    local num_rolls = 10000
    local deviation
    for i = 1, num_rolls do
        local mishap = false -- unit:Random(100) < mishap_chance and "mishap"
        deviation = mishap or grenade:rat_custom_deviation(unit, false, false, true)
        if not not_round then
            deviation = not mishap and cRoundFlt(deviation, steps) or deviation
        end
        if not deviations[deviation] then
            deviations[deviation] = 1
        else
            deviations[deviation] = deviations[deviation] + 1
        end
    end
    local sorted_keys = {}
    for deviation, _ in pairs(deviations) do
        table.insert(sorted_keys, deviation)
    end
    table.sort(sorted_keys, function(a, b)
        if a == "mishap" then
            return false
        elseif b == "mishap" then
            return true
        else
            return a < b
        end
    end)
    print("Deviation   Probability   for " .. dex .. " dex and " .. expl, " expl")
    for _, deviation in ipairs(sorted_keys) do
        local devi = deviations[deviation]
        local probability = (devi * 1.00000000 / num_rolls * 1.00000000) * 100.000000
        print(deviation .. "         " .. probability)
    end
end

function test_roll()
    local unit = g_Units.Barry
    local num_rolls = 10000
    local deviations = {}
    local deviation
    for i = 1, num_rolls do
        deviation = 1 + unit:Random(100)
        if deviations[deviation] == nil then
            deviations[deviation] = 1
        else
            deviations[deviation] = deviations[deviation] + 1
        end
    end
    for deviation, count in pairs(deviations) do
        local probability = count / num_rolls * 100
        print(deviation .. "         " .. probability)
    end
end
