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

----------Args
local GR_dist_pen = 25 ---- Higher = less accurate
local RPG_dist_pen = 15 ---- Higher = less accurate
local GL_dist_pen = 15 ---- Higher = less accurate

---- status effects/ other penalties
local wound_penalty_per_stack = 5 ---- Higher = less accurate
local innacurate_penalty = 15 ---- Higher = less accurate
local blind_dazed_penalty = 15 ---- Higher = less accurate
local rainHeavyPenalty = 10 ---- Higher = less accurate

------ Get item accuracy modidifers
local underslungGLpenalty = -10 --- higher = more accurate

------- Deviation Params ---- MOTOR ABSOLUTO
--
-- O raio do erro e desenhado direto em tiles, sem clamp:
--
--     miss = (roll - gate) / (100 - gate)                 gate = stat * sfp / 100
--     r    = r_min(stat) + (r_max(stat) - r_min(stat)) * miss^dev_shape
--     dir  = 90deg * sinal(u) * |u|^dir_bias  (u uniforme em [-1,1]) + flip de 180deg
--
-- |erro| = r sempre. O r_min e um piso de imprecisao de verdade, e o vies mora na
-- DIRECAO, nao na magnitude. Nao existe max()/min() no caminho, entao a distribuicao
-- nao tem atomo (a versao com piso por clamp empilhava metade da massa num raio so).
--
-- A distancia NAO multiplica mais o erro. Ela entra por um canal so: GR_dist_pen,
-- que desconta do stat. Por isso o clamp de unidades tiles-vs-mundo deixou de existir
-- junto com o bloco geometrico antigo.
--
-- Tudo em milesimos de tile e percentuais inteiros: Lua 5.3 com '/' inteiro, e float
-- em caminho sincronizado vaza para o NetUpdateHash (ver CLAUDE.md).

---- Ajustados por fit ancorado em 15 TILES, contra o alvo do autor:
----   Great tipico 1 t | Good 2 t | Inaccurate 3.5 t | Terrible 5 t
---- A 15t o p50/p90 batem: stat 90 -> 1.15/2.12 | 75 -> 1.65/2.90 | 60 -> 2.36/3.77 | 45 -> 3.09/4.65
---- r_max(100) fica em 0.61 t de proposito: se ele chegasse a zero, um merc de ui alto
---- em curta distancia teria r_max = r_min = 0 e TODO arremesso viraria Perfect.
local r_min_base = 976 ---- erro minimo no stat 0, em milesimos de tile
local r_min_scale = 1910 ---- r_min chega a zero por volta de ui 51
local r_max_base = 7285 ---- erro maximo no stat 0
local r_max_scale = 6676 ---- quanto a skill baixa o teto -> r_max(100) = 0.61 t
---- (r_max_scale - r_min_scale) e a taxa com que a faixa ESTREITA conforme a skill sobe:
---- positivo = skill compra consistencia; zero = skill desloca a faixa inteira (precisao pura)

local dev_shape = 1 ---- expoente INTEIRO. 1 = linear. >1 concentra perto do piso (precisao comum),
---- a curva espelhada 1-(1-miss)^k faz o oposto (precisao rara) -- ver dev_shape_mirror abaixo
local dev_shape_mirror = false ---- true troca miss^k por 1-(1-miss)^k

local dir_bias = 2 ---- expoente INTEIRO. 1 = isotropico. >1 concentra no eixo do arremesso
local short_mul = 100 ---- % do lado que volta pro arremessador. 100 = simetrico, <100 encurta
local launcher_r_pct = 100 ---- % do raio para GL/RPG (no motor antigo eles desviavam ~12% menos)

local stat_factor_perfect_throw = 26 ---- gate = stat * isto / 100; roll abaixo dele = acerto exato

---- rotulos por distancia absoluta, em milesimos de tile.
---- O texto significa a MESMA coisa para qualquer merc e qualquer granada: a skill muda
---- com que frequencia cada um sai, nao o que ele quer dizer.
---- ATENCAO: sao derivados da distribuicao. Mexeu em r_min/r_max/dev_shape, recalibre
---- (a bancada tem o botao "Calibrar rotulos").
local label_great_tiles = 1000
local label_good_tiles = 2000
local label_inacc_tiles = 3500

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

---- raio do erro em milesimos de tile, a partir do roll e do stat da UI
local function deviation_radius(stat, roll, is_grenade)
    local gate = MulDivRound(stat, stat_factor_perfect_throw, 100)
    if roll <= gate then
        return 0, gate
    end
    ---- miss em milesimos: onde este roll cai entre o gate e o pior roll possivel
    local miss = MulDivRound(roll - gate, 1000, 100 - gate)
    local curve = pow_milli(miss, dev_shape)
    if dev_shape_mirror then
        curve = 1000 - pow_milli(1000 - miss, dev_shape)
    end

    local r_min = Max(0, r_min_base - MulDivRound(r_min_scale, stat, 100))
    local r_max = Max(r_min, r_max_base - MulDivRound(r_max_scale, stat, 100))
    local r = r_min + MulDivRound(r_max - r_min, curve, 1000)

    if not is_grenade and launcher_r_pct ~= 100 then
        r = MulDivRound(r, launcher_r_pct, 100)
    end
    return r, gate
end

function MishapProperties:rat_custom_deviation(unit, target_pos, attack_pos, test)

    local is_grenade = IsKindOf(self, "Grenade")
    local ai_modifier = AI_deviate_skill_diff(unit) or 0

    ---- BUGFIX (B9): o wound_penalty ja foi descontado dentro de GetDeviationModifier.
    ---- A versao antiga somava ele de volta aqui, o que anulava o Wounded por completo
    ---- e fazia a tooltip mentir. Aqui o stat da UI entra inteiro, sem correcao.
    local stat = self:GetMishapChance(unit, target_pos)[1]
    stat = Max(0, Min(100, stat - ai_modifier))

    local roll = throw_dice(100, num_dice, unit) + 1
    roll = CheatEnabled("AlwaysHit") and 1 or roll
    roll = CheatEnabled("AlwaysMiss") and 99 or roll

    local radius, gate = deviation_radius(stat, roll, is_grenade)

    if Platform.developer and not test then
        print("----RATONADE - DEBUG deviation")
        print("roll", roll, "stat", stat, "gate", gate, "raio(milesimos de tile)", radius)
    end

    if test then
        return radius, roll
    end

    ---- acerto exato: quem chama trata o false como "nao desviou"
    if radius <= 0 then
        CreateFloatingText(target_pos, T("Perfect Throw"))
        return false
    end

    local dir = target_pos - attack_pos
    dir = point(dir:x(), dir:y(), 0)
    if dir:Len() == 0 then
        return false
    end

    ---- direcao: theta = 90deg * sinal(u) * |u|^dir_bias, u uniforme em [-1000, 1000].
    ---- dir_bias > 1 concentra o erro no eixo do arremesso (cai curto ou passa longe)
    ---- em vez de espalhar para os lados.
    local u = InteractionRand(2001, "RATONADE_DeviationDir", unit) - 1000
    local sign = u < 0 and -1 or 1
    local shaped = pow_milli(abs(u), dir_bias)
    local angle = sign * MulDivRound(90 * 60, shaped, 1000)
    if InteractionRand(2, "RATONADE_DeviationFlip", unit) == 1 then
        angle = angle + 180 * 60
    end

    local radius_world = MulDivRound(radius, const.SlabSizeX, 1000)
    local offset = Rotate(SetLen(dir, radius_world), angle)

    ---- short_mul < 100 encurta so a metade que volta na direcao do arremessador
    if short_mul ~= 100 then
        local fwd = SetLen(dir, 4096)
        local along = MulDivRound(offset:x(), fwd:x(), 4096) + MulDivRound(offset:y(), fwd:y(), 4096)
        if along < 0 then
            local cut = MulDivRound(along, 100 - short_mul, 100)
            offset = offset - point(MulDivRound(fwd:x(), cut, 4096), MulDivRound(fwd:y(), cut, 4096), 0)
        end
    end

    ---- o erro e uma distancia ATE O ALVO, nao uma fracao do vetor de arremesso
    local final_pos = target_pos + offset

    ---- o rotulo sai do erro REAL em tiles, entao tem que ser calculado depois da
    ---- geometria. Na versao antiga o texto era emitido antes, olhando o deviation.
    local err = MulDivRound(offset:Len(), 1000, const.SlabSizeX)
    local float_text
    if err <= label_great_tiles then
        float_text = is_grenade and T("Great Throw") or T("Great Launch")
    elseif err <= label_good_tiles then
        float_text = is_grenade and T("Good Throw") or T("Good Launch")
    elseif err <= label_inacc_tiles then
        float_text = is_grenade and T("<color AmmoAPColor>Innacurate Throw</color>") or
                         T("<color AmmoAPColor>Innacurate Launch</color>")
    else
        float_text = is_grenade and T("<color AmmoAPColor>Terrible Throw</color>") or
                         T("<color AmmoAPColor>Terrible Launch</color>")
    end
    CreateFloatingText(target_pos, float_text)

    DbgAddCircle_devi(target_pos, const.SlabSizeX / 6, const.clrGreen)
    DbgAddVector_devi(attack_pos, dir, const.clrGreen)
    DbgAddVector_devi(target_pos, offset, const.clrRed)

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
    return stacks * wound_penalty_per_stack
end

function GetDeviationModifier(item, unit, target, stat, diff_dist, opt_diff)
    local item_acc = item:get_throw_accuracy(unit)
    local wound_penalty = EO_GetWoundPenalty_Deviation(unit)
    local modifiers = -item_acc + opt_diff + diff_dist + wound_penalty
    modifiers = unit:HasStatusEffect("Inaccurate") and modifiers + innacurate_penalty or modifiers
    modifiers = (unit:HasStatusEffect("Blinded") or unit:HasStatusEffect("dazed_flashbang")) and
                    modifiers + blind_dazed_penalty or modifiers

    if GameState.RainHeavy and IsKindOf(item, "GrenadeProperties") then
        modifiers = modifiers and modifiers + rainHeavyPenalty or 10
    end
    return {Max(0, stat - modifiers)}
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
    local diff_dist = cRound(ratio_dist * GR_dist_pen)

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
        acc = unit and unit.unitdatadef_id == "Barry" and acc or acc - 25
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
    local diff_dist = cRound(ratio_dist * GL_dist_pen)

    local opt_diff = extractNumberWithSignFromString(CurrentModOptions.GL_throw_diff) or 0

    return GetDeviationModifier(self, unit, target, stat, diff_dist, opt_diff)
end

function GrenadeLauncher:get_throw_accuracy(unit)
    if unit then
        local active_wep = unit:GetActiveWeapons()
        return self == active_wep and 0 or underslungGLpenalty
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
    local diff_dist = cRound(ratio_dist * RPG_dist_pen)

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
