------------------------ Debug
local table_of_tests = {}

function s_avg()
    local num = 0
    for unit, hits in pairs(table_of_tests) do
        num = #hits > num and #hits or num
    end

    for unit, hits in pairs(table_of_tests) do

        print("---------------------------------------------", "-----------Unit:", unit)
        print("---------------------------------------------", "-----------N of throws", num)
        local tabuao = {}

        for i, hit in ipairs(hits) do
            for k, log in pairs(hit) do
                if not tabuao[k] then
                    tabuao[k] = log
                else
                    tabuao[k] = tabuao[k] + log
                end
            end
        end

        -- 
        for k, v in pairs(tabuao) do
            print("---------------------------------------------", k, "  =  ", v * 1.00 / num * 1.00)
        end

    end
end

function reset_tt()
    table_of_tests = {}
end

--------- Args

local speed_control = 0.6
local debug_shrap_vec = false
local debug_log = false

local effect_chance_mul = 1.0 --- modifies the chance a shrap causes status effect

local radius_mul = 2.0 -- 1.5 ---- radius of secondary zone (base aoe * this)
local outer_radius_t = 30 --- factor for tertiary radius
local secondary_radius_f = 88 --- % dmg and effects of secondary zone

function get_shrap_args(frag_level, category)

    local frag_args = {
        ['High'] = {diminish = 2, shrap_ceiling = 5, step_mul = 0.5, max_penalty = 0.95},
        ['Medium'] = {diminish = 1, shrap_ceiling = 3, step_mul = 0.75, max_penalty = 0.95},
        ['Low'] = {diminish = 1, shrap_ceiling = 2, step_mul = 0.8, max_penalty = 0.95}

    }
    local entry = frag_args[frag_level]
    if not entry then
        entry = {diminish = 1, shrap_ceiling = 1, step_mul = 1, max_penalty = 1}
    end

    return entry[category]
end
--------------------------------------

function get_FragLevel(grenade)
    local num = grenade.r_shrap_num
    if not num then
        return 0
    end
    if num > 630 then
        return "High"
    elseif num > 280 then
        return "Medium"
    elseif num > 200 then
        return "Low"
    elseif num > 0 then
        return "Very Low"
    end

    return "None"
end

function GetShrapnelResults(self, explosion_pos, attacker)

    local attacker = attacker or g_Units[1]
    -----------------
    local num_shrap

    num_shrap = self.r_shrap_num or 0

    local frag_level = get_FragLevel(self)

    local shrap_num_for_diminish = get_shrap_args(frag_level, "diminish")
    local shrap_num_for_max = get_shrap_args(frag_level, "shrap_ceiling")
    local shrap_damage_penalty_step = get_shrap_args(frag_level, "step_mul")
    local shrap_damage_penaltyMax = get_shrap_args(frag_level, "max_penalty")
    -- local shrap_pen_arg = num_shrap > 250 and shrap_pen_arg_base or 0.95
    --[[ local max_shrap_ceiling = frag_level == "High" and max_shrap_ceiling_high or frag_level == "Medium" and
						                          max_shrap_ceiling_medium or max_shrap_ceiling_low
	local shrap_pen_arg = frag_level == "High" and shrap_pen_arg_high or shrap_pen_arg_medium ]]

    num_shrap = MulDivRound(num_shrap, tonumber(CurrentModOptions.shrap_num) or 100, 100)

    if num_shrap < 1 then
        return
    end

    explosion_pos = IsValidZ(explosion_pos) and explosion_pos or explosion_pos:SetTerrainZ()
    -- explosion_pos = explosion_pos:SetZ(explosion_pos:SetTerrainZ():z()+ guim)
    explosion_pos = explosion_pos:SetZ(explosion_pos:z() + guic)
    local radius = 13000

    ---- if i ever want to not bias distribution when a grenade explodes far above ground
    --[[ local _, slab_z = WalkableSlabByPoint(explosion_pos, "downward only")
	local ground_explosion = explosion_pos:z() - slab_z <= const.SlabSizeZ ]]

    local shrapnels, phis, thetas

    if self.coneShaped then
        local att_pos = attacker:GetPos() or attacker
        att_pos = IsValidZ(att_pos) and att_pos or att_pos:SetTerrainZ()
        local direction = RotateRadius(self.AreaOfEffect * const.SlabSizeX,
                                       CalcOrientation(att_pos or attacker, explosion_pos),
                                       explosion_pos)
        -- DbgAddCircle(direction,1000, const.clrRed)
        direction = IsValidZ(direction) and direction or direction:SetTerrainZ()
        local direction_angle = CalcOrientation(explosion_pos, direction)
        ---- PERF (C5): era "coneAngle * num_shrap / 230", que depende do '/' da engine para
        ---- nao virar float e alimentar um "for i = 1, numPositions" com limite float.
        ---- MulDivRound e a forma que o CLAUDE.md manda usar e devolve inteiro sempre.
        num_shrap = MulDivRound(num_shrap, self.coneAngle, 230) -- 360
        -- print("cone num sjh", num_shrap)
        local cone_args = {
            angle_deg = self.coneAngle,
            direction = direction,
            dir_angle = direction_angle,
            radius = self.AreaOfEffect * const.SlabSizeX
        }

        shrapnels = generateShrapnelPositionsInCone(num_shrap, radius, explosion_pos, cone_args)
    else
        ---- O gerador v2 nao descarta nada: num_shrap aqui e o numero de raios que serao
        ---- TRACADOS. A v1 gerava N e sobrevivia 55,4% deles, entao aplicar o mesmo fator
        ---- aqui mantem a contagem de CheckLOF (e o custo) igual a de antes.
        num_shrap = MulDivRound(num_shrap, const.EO.ShrapTracedPct or 55, 100)
        ---- PERF (C1): os arrays de phi/theta so existem quando o debug visual esta ligado.
        shrapnels, phis, thetas = generateShrapnelPositions(num_shrap, radius, explosion_pos,
                                                            debug_shrap_vec)
    end

    if debug_shrap_vec then
        for i, v in ipairs(shrapnels) do
            DbgAddCircle(v, const.SlabSizeX / 2)
            if phis and thetas then
                -- DbgAddText("phi " .. phis[i] .. " theta " .. thetas[i], v)
                DbgAddText("phi " .. phis[i], v)
            end
        end
    end

    for i, unit in ipairs(g_Units) do
        unit.shrap_received = 0
    end

    local final_pos

    local sharpnel_weapon = g_Classes["weapon_shrapnel"]
    local lof_args = {}
    lof_args.fire_relative_point_attack = false
    lof_args.ignore_colliders = false -- compile_ignore_colliders(killed_colliders, target_unit)
    lof_args.seed = attacker:Random()
    lof_args.ignore_los = true
    lof_args.inside_attack_area_check = false
    lof_args.forced_hit_on_eye_contact = false

    ---
    lof_args.prediction = false
    lof_args.aimIK = false
    lof_args.output_collisions = true
    lof_args.force_hit_seen_target = not config.DisableForcedHitSeenTarget
    ---
    lof_args.weapon = sharpnel_weapon
    lof_args.weapon_visual = false -- self:GetVisualObj(attacker) or false
    lof_args.action_id = "SingleShot"
    lof_args.obj = attacker
    lof_args.step_pos = explosion_pos
    lof_args.can_stuck_on_unit = true

    ---
    lof_args.attack_pos = explosion_pos -- ricochet_start_pos + SetLen(ricochet_dir, guic) -- get away from the collision
    lof_args.target_pos = final_pos
    lof_args.fire_relative_point_attack = false
    lof_args.clamp_to_target = true
    lof_args.extend_shot_start_to_attacker = false
    lof_args.can_hit_attacker = true
    lof_args.ignore_los = true
    lof_args.inside_attack_area_check = false
    lof_args.forced_hit_on_eye_contact = false
    lof_args.penetration_class = -1 -- stuck on the first hit
    lof_args.max_penetration_range = -1
    lof_args.can_use_covers = false
    lof_args.emplacement_weapon = false
    -- lof_args.ricochet = true
    -------

    local end_time_g = GameTime()
    local dmg_log = {}

    local gren_random = 30
    ---- PERF (C3): cRound(gren_random / 2) e constante; rodava uma vez por estilhaco.
    local random_f_base = 100 - cRound(gren_random / 2)

    ---- PERF (C3): base_radius e a faixa secundaria sao constantes da explosao inteira;
    ---- estavam sendo recalculadas dentro do laco, uma vez por estilhaco que acerta.
    local base_radius = self.AreaOfEffect * const.SlabSizeX
    local secondary_radius = cRound(base_radius * radius_mul)

    ---- PERF (C2): a ordem invertida importa (quem chega primeiro conta cheio no teto de
    ---- shrap_received), mas a copia nao: reverseTable alocava um array inteiro so para
    ---- poder percorrer de tras para frente. O laco decrescente faz o mesmo de graca.
    local results = {}
    for i = #shrapnels, 1, -1 do
        local vector = shrapnels[i]
        final_pos = vector
        lof_args.target_pos = final_pos
        lof_args.attack_pos = explosion_pos + SetLen(final_pos - explosion_pos, guic * 12)

        local random_f = random_f_base + attacker:Random(gren_random)

        local attack_data = CheckLOF(final_pos, lof_args)

        local lof, hit, hit_pos
        local max_shrap_dmg_red
        local max_shrap_received
        if attack_data then
            lof = attack_data.lof and attack_data.lof[1]
            hit = lof and lof.hits and lof.hits[1]
            hit_pos = hit and hit.pos

            -- max_shrap = Max(1, MulDivRound(max_shrap, tonumber(CurrentModOptions.shrap_dmg) or 100, 100))
            if hit and hit.obj and IsKindOf(hit.obj, "Unit") then

                ----- log
                if debug_log then
                    local dist_log = hit.obj:GetDist(explosion_pos)
                    if not table_of_tests[hit.obj.session_id] then
                        table_of_tests[hit.obj.session_id] = {}
                    end
                    table_of_tests[hit.obj.session_id].dist = dist_log
                end
                -------

                ------ Damage Control
                if hit.obj.shrap_received >= shrap_num_for_max then
                    -- max_shrap_dmg_red = 1
                    max_shrap_received = true

                    --[[ 					lof_args.attack_pos = hit_pos + SetLen(hit_pos - lof_args.attack_pos, cRound(const.SlabSizeX / 3))
					attack_data = CheckLOF(final_pos, lof_args)
					lof = attack_data.lof and attack_data.lof[1]
					hit = lof and lof.hits and lof.hits[1]
					hit_pos = hit and hit.pos ]]
                elseif hit.obj.shrap_received >= shrap_num_for_diminish then
                    max_shrap_dmg_red = Min(shrap_damage_penaltyMax, (hit.obj.shrap_received -
                                                shrap_num_for_diminish) * shrap_damage_penalty_step)
                    hit.obj.shrap_received = hit.obj.shrap_received + 1
                else
                    hit.obj.shrap_received = hit.obj.shrap_received + 1
                end
                ------
            end
        end

        if attack_data and not max_shrap_received then
            ---- PERF (C3): lof/hit/hit_pos ja foram lidos no bloco acima, que so roda
            ---- quando attack_data existe -- e nada os invalida no meio. A releitura era
            ---- pura repeticao.
            local exclude_civ
            if hit and not hit.terrain and not max_shrap_received then

                local hit_data = {
                    obj = attacker,
                    hits = {hit},
                    target_pos = hit_pos,
                    attack_pos = lof_args.attack_pos
                }

                local dist_ = hit_data.target_pos:Dist(hit_data.attack_pos)

                local dist_t = dist_ <= base_radius and 100 or dist_ <= secondary_radius and
                                   secondary_radius_f or outer_radius_t

                if IsKindOf(hit.obj, "Unit") and hit.obj:IsCivilian() and dist_t < outer_radius_t then
                    exclude_civ = true
                    ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                else

                    sharpnel_weapon:calc_shrap_damage(hit_data, false, random_f, dist_t,
                                                      max_shrap_dmg_red)

                    if IsKindOf(hit.obj, "Unit") and debug_log then

                        if not dmg_log[hit.obj.session_id] then
                            dmg_log[hit.obj.session_id] = {dmg = 0}
                        end

                        dmg_log[hit.obj.session_id].dmg =
                            dmg_log[hit.obj.session_id].dmg + hit.damage
                        dmg_log[hit.obj.session_id][hit.spot_group] =
                            (dmg_log[hit.obj.session_id][hit.spot_group] or 0) + 1

                        -- table.insert_unique(dmg_log[hit.obj.session_id], hit.spot_group)
                        -- print("------------------------------------")
                        -- print("dist_T", dist_t)
                        -- print("hit obj", hit.obj.session_id)
                        -- print("dmg", hit.spot_group, hit.damage)
                        -- print("hit effects", hit.effects)
                        -- print("------------------------------------")
                    end
                end

            end

            local hits = not exclude_civ and {hit} or {}
            -- hits = not max_shrap_received and hits or {}
            hit_pos = exclude_civ and hit_pos or final_pos

            local sharpnel_dir = SetLen((hit_pos or final_pos) - explosion_pos, 4096) -- dir--false--hit_pos - explosion_pos--) or dir
            if debug_shrap_vec then
                if max_shrap_received then
                    DbgAddVector(lof_args.attack_pos, hit_pos - lof_args.attack_pos, const.clrBlue)
                elseif hit then
                    DbgAddVector(lof_args.attack_pos, hit_pos - lof_args.attack_pos, const.clrRed)
                else
                    DbgAddVector(lof_args.attack_pos, final_pos - lof_args.attack_pos)
                end
            end

            local speed = MulDivRound(const.Combat.BulletVelocity * speed_control, random_f, 100) -- /10

            local result = {
                weapon = sharpnel_weapon,
                attacker = attacker,
                start_pt = explosion_pos,
                end_pt = hit_pos or final_pos,
                shrapnel_dir = sharpnel_dir,
                speed = speed,
                hits = hits or false,
                target = hit_pos or final_pos,
                lof = lof_args,
                end_time = end_time_g
            }
            table.insert(results, result)
        end
    end

    ------------ Log
    if debug_log then
        for k, v in pairs(dmg_log) do
            if not table_of_tests[k] then
                table_of_tests[k] = {v}
            else
                table.insert(table_of_tests[k], v)
            end
            print(k, v)
        end
    end
    ---------------
    -- print("number of vectors", #results)
    return results

end

function Firearm:calc_shrap_damage(hit_data, ricochet_idx, random_f, dist_t, max_shrap_dmg_red)

    local attacker = hit_data.obj
    local target = hit_data.target
    local action = CombatActions[hit_data.action_id]
    local hits = hit_data.hits
    local record_breakdown = hit_data.record_breakdown
    local prediction = hit_data.prediction

    --------------------------
    local max_shrap_mul = 1
    if max_shrap_dmg_red then
        max_shrap_mul = (1 - max_shrap_dmg_red)
    end

    -----
    local effect_chance = (dist_t * random_f / 700.00) * effect_chance_mul
    effect_chance = MulDivRound(effect_chance, tonumber(CurrentModOptions.shrap_eff_chance) or 100,
                                100)
    effect_chance = effect_chance * max_shrap_mul
    effect_chance = cRound(effect_chance)

    -- print("distt", dist_t, "effc", effect_chance)
    --------------------------

    if not ricochet_idx then
        local dmg_mod = hit_data.damage_bonus or 0
        if type(dmg_mod) == "table" then
            dmg_mod = dmg_mod[obj]
        end
        if record_breakdown and dmg_mod then
            local name = action and action:GetActionDisplayName({attacker}) or
                             T(328963668848, "Base")
            table.insert(record_breakdown, {name = name, value = dmg_mod})
        end
        ---
        local basedmg = self.Damage -- attacker:GetBaseDamage(self, target, record_breakdown)
        basedmg = MulDivRound(basedmg, tonumber(CurrentModOptions.shrap_dmg) or 100, 100)

        basedmg = basedmg * max_shrap_mul

        ---
        local dmg = MulDivRound(basedmg, Max(0, 100 + (dmg_mod or 0)), 100)
        -- if not prediction then
        -- dmg = RandomizeWeaponDamage(dmg)
        -- end

        dmg = MulDivRound(dmg, random_f, 100)
        dmg = MulDivRound(dmg, dist_t, 100)
        dmg = Max(dmg, 1)
        hit_data.damage = dmg
    end
    local target_reached
    local forced_target_hit = hit_data.forced_target_hit
    local impact_force = self:GetImpactForce()

    for idx = ricochet_idx or 1, hits and #hits or 0 do
        local hit = hits[idx]
        local stray = hit.stray
        local dmg = hit_data.damage
        local obj = hit.obj
        local is_unit
        -- print("hit obj is unit?", idx, IsKindOf(obj, "Unit"), "damage", dmg)
        if obj and IsKindOf(obj, "Unit") and not stray then
            is_unit = true
            stray = obj ~= target
            target_reached = target_reached or target and obj == target

            --[[ 			if not prediction then
				if hit_data.critical == nil and not stray then
					hit_data.target_spot_group = hit_data.target_spot_group or hit.spot_group
					-- pass hit_data instead of attack_args, it has all the relevant data
					local critChance = attacker:CalcCritChance(self, target, action, hit_data, hit_data.step_pos) -- hit_data.aim, hit_data.step_pos, hit_data.target_spot_group or hit.spot_group, action)
					local critRoll = attacker:Random(100)
					hit_data.critical = critRoll < critChance
				end
			end ]]
            if not stray then
                hit.spot_group = hit_data.target_spot_group or hit.spot_group
            end
        end -- hits on non-units are never stray or critical

        hit.stray = false -- stray
        hit.critical = false -- not stray and hit_data.critical
        hit.damage = dmg

        local breakdown = obj == target and record_breakdown -- We only care about the damage breakdown on the target, not objects in the way.

        ---
        self:shrap_precalc_damage_and_effects(attacker, obj, hit_data.step_pos, hit.damage, hit,
                                              hit_data.applied_status, hit_data, breakdown, action,
                                              prediction, effect_chance)
        ---
        hit.impact_force = hit.damage > 0 and impact_force +
                               self:GetDistanceImpactForce(hit.distance) or 0

        if idx < #hits and (hit.armor_prevented or 0) > 0 and not hit.ignored then
            if not forced_target_hit or target_reached then
                local penetrated = false
                if is_unit and (not target or target_reached) then
                    for item, degrade in pairs(hit.armor_decay) do
                        if hit.armor_pen[item] then
                            penetrated = true
                            break
                        end
                    end
                end
                if not penetrated and not hit.ricochet then
                    -- remove the rest of the hits
                    for i = idx + 1, #hits do
                        hits[i] = nil
                    end
                    hit_data.stuck_pos = hit.pos -- adjust the final impact pos of the bullet
                    if hit_data.target_hit_idx and hit_data.target_hit_idx > idx then
                        hit_data.target_hit_idx = nil
                        hit_data.stuck = true
                    end
                    break
                end
            end
        end
    end
end

function BaseWeapon:shrap_precalc_damage_and_effects(attacker, target, attack_pos, damage, hit,
                                                     effect, attack_args, record_breakdown, action,
                                                     prediction, effect_chance)
    if IsKindOf(target, "Unit") then
        local effects = EffectsTable(effect) -- EffectsTable("Bleeding")
        -- print("effects", effects)

        -----------------------------
        local effect_roll = 1 + attacker:Random(100)

        if effect_roll <= cRound(effect_chance * 1.2) then
            EffectTableAdd(effects, "Bleeding")
        end

        local other_effects_add = effect_roll <= effect_chance
        ------------------------------
        local ignoreGrazing = true
        hit.grazing = false
        -- local ignoreGrazing = IsFullyAimedAttack(attack_args) and self:HasComponent("IgnoreGrazingHitsWhenFullyAimed")
        -- local ignore_cover = (hit.aoe or hit.melee_attack or ignoreGrazing) and 100 or self.IgnoreCoverReduction

        -- grazing hits
        -- local chance = 0
        -- local base_chance = 0
        -- cover effect based on attack_pos
        -- if target:IsAware() and not target:HasStatusEffect("Exposed") and target:HasStatusEffect("Protected") and (not ignore_cover or ignore_cover <= 0) then
        -- local cover, any, coverage = target:GetCoverPercentage(attack_pos)
        -- base_chance = const.Combat.GrazingChanceInCover
        -- if target:HasStatusEffect("Protected") then
        -- base_chance = Protected:ResolveValue("base_chance")
        -- end
        -- chance = InterpolateCoverEffect(coverage, base_chance, 0)
        -- hit.grazing_reason = "cover"
        -- end

        -- if not ignoreGrazing and not hit.aoe then
        -- if target:IsConcealedFrom(attack_pos or attacker) then
        -- chance = chance + const.EnvEffects.FogGrazeChance
        -- hit.grazing_reason = "fog"
        -- end
        -- if target:IsObscuredFrom(attack_pos or attacker) then
        -- chance = chance + const.EnvEffects.DustStormGrazeChance
        -- hit.grazing_reason = "duststorm"
        -- end
        -- end		

        -- if not prediction then
        -- local grazing_roll = target:Random(100)
        -- if grazing_roll < chance then
        -- hit.grazing = true
        -- else
        -- hit.grazing_reason = false
        -- end
        -- elseif chance ~= 0 then
        -- hit.grazing = true
        -- end
        -- grazing hits (from cover and gas) cant crit
        -- if hit.grazing then
        -- hit.critical = nil
        -- end
        -- local ignore_armor = hit.aoe or IsKindOf(self, "MeleeWeapon")
        -- Order/method of damage buff calculations might need a revision. The are quite a few now and they seem to be added arbitrary.
        -- if not hit.stray or hit.aoe then
        local ignore_armor = false
        local data = {
            breakdown = record_breakdown or {},
            effects = {},
            base_damage = damage,
            damage_add = 0,
            damage_percent = 100,
            ignore_armor = false,
            ignore_body_part_damage = {},
            action_id = "shrapnel_action",
            weapon = self,
            prediction = false,
            critical = false,
            critical_damage = const.Weapons.CriticalDamage
        }
        local mod_attack_args = attack_args or {}
        local mod_hit_data = hit or {}
        local action_id = "shrapnel_action"
        Msg("GatherDamageModifications", attacker, target, action_id, self, mod_attack_args,
            mod_hit_data, data) -- only called for non-stray hits (no misses)
        if IsKindOf(attacker, "Unit") then
            attacker:CallReactions("OnCalcDamageAndEffects", attacker, target, action, self,
                                   mod_attack_args, mod_hit_data, data)
        end
        if IsKindOf(target, "Unit") then
            target:CallReactions("OnCalcDamageAndEffects", attacker, target, action, self,
                                 mod_attack_args, mod_hit_data, data)
        end
        damage = Max(0, MulDivRound(data.base_damage + data.damage_add, data.damage_percent, 100))
        if data.critical then
            damage = Max(0, MulDivRound(damage, 100 + data.critical_damage, 100))
        end
        hit.critical = data.critical
        for _, effect in ipairs(data.effects) do
            ------------------------
            if other_effects_add then
                EffectTableAdd(effects, effect)
            end
            ------------------------
        end
        ignore_armor = ignore_armor or data.ignore_armor

        local part_def = hit.spot_group and Presets.TargetBodyPart.Default[hit.spot_group]

        if part_def then
            if not data.ignore_body_part_damage[part_def.id] then
                damage = MulDivRound(damage, 100 + part_def.damage_mod, 100)
                if record_breakdown then
                    record_breakdown[#record_breakdown + 1] = {
                        name = part_def.display_name,
                        value = part_def.damage_mod
                    }
                end
            end
            ---------------
            if other_effects_add then
                EffectTableAdd(effects, part_def.applied_effect)
            end
            ---------------
        end
        -- print("dmg", damage)
        -- else
        -- damage = MulDivRound(damage, 50, 100)
        -- end

        hit.damage = damage
        target:ApplyHitDamageReduction(hit, self, hit.spot_group or g_DefaultShotBodyPart, nil,
                                       ignore_armor, record_breakdown)

        ---------------
        local armor_pierced = target:IsArmorPiercedBy(self, 0, hit.spot_group, false)
        if armor_pierced then
            hit.effects = effects
        end
        -------

        -- if hit.grazing then
        -- hit.effects = {}
        -- hit.damage = Max(1, MulDivRound(hit.damage, const.Combat.GrazingHitDamage, 100))
        -- else
        -- hit.effects = effects
        -- end

    else
        -- apply dmg mod for non units
        local obj_dmg_mod = (not hit.ignore_obj_damage_mod and self:HasMember("ObjDamageMod")) and
                                self.ObjDamageMod or 100
        if obj_dmg_mod ~= 100 then
            damage = MulDivRound(damage, obj_dmg_mod, 100)
            if record_breakdown then
                record_breakdown[#record_breakdown + 1] = {
                    name = T {
                        360767699237, "<em><DisplayName></em> damage modifier to objects", self
                    },
                    value = obj_dmg_mod
                }
            end
        end
        -- if HasPerk(attacker, "CollateralDamage") and IsKindOfClasses(self, "HeavyWeapon", "MachineGun") then
        -- local collateralDamage = CharacterEffectDefs.CollateralDamage
        -- local damageBonus = collateralDamage:ResolveValue("objectDamageMod")
        -- damage = MulDivRound(damage, 100 + damageBonus, 100)
        -- if record_breakdown then record_breakdown[#record_breakdown + 1] = { name = collateralDamage.DisplayName, value = damageBonus } end
        -- end
        -- apply armor for non units
        local pen_class = self:HasMember("PenetrationClass") and self.PenetrationClass or
                              #PenetrationClassIds
        local armor_class = target and target.armor_class or 1

        if pen_class >= armor_class then
            hit.damage = damage or 0
            hit.armor_prevented = 0
        else
            hit.damage = 0
            hit.armor_prevented = damage or 0
        end

        -- print("non unit hit", target.class, "damage", hit.damage, "armor class", armor_class, "armor prevented",
        --      hit.armor_prevented)
        if record_breakdown then
            if hit.damage > 0 then
                record_breakdown[#record_breakdown + 1] = {
                    name = T(478438763504, "Armor (Pierced)")
                }
            else
                record_breakdown[#record_breakdown + 1] = {
                    name = T(360312988514, "Armor"),
                    value = -hit.armor_prevented
                }
            end
        end
    end
end

local BulletVegetationCollisionMask = const.cmDefaultObject | const.cmActionCamera
local BulletVegetationCollisionQueryFlags = const.cqfSorted | const.cqfResultIfStartInside
local BulletVegetationClasses = {"Shrub", "SmallTree", "TreeTop"}

function Firearm:Shrapnel_Fly(attacker, start_pt, end_pt, dir, speed, hits, target, attack_args,
                              end_time_g)
    NetUpdateHash("ProjectileFly", attacker, start_pt, end_pt, dir, speed, hits)
    dir = SetLen(dir or end_pt - start_pt, 4096)
    -- print("fly gtime", end_time_g)
    local fx_actor = false
    --[[ 	if IsKindOf(attacker, "Unit") then
		fx_actor = attacker:CallReactions_Modify("OnUnitChooseProjectileFxActor", fx_actor)
	end ]]

    local projectile = PlaceObject("FXBullet")
    projectile.fx_actor_class = fx_actor
    projectile:SetGameFlags(const.gofAlwaysRenderable)
    projectile:SetPos(start_pt)
    local axis, angle = OrientAxisToVector(1, dir) -- 1 = +X
    projectile:SetAxis(axis)
    projectile:SetAngle(angle)

    -- print("projectile", projectile)

    PlayFX("Spawn", "start", projectile)
    local fly_time = MulDivRound(projectile:GetDist(end_pt), 1000, speed)
    ---
    local end_time = end_time_g + fly_time
    ----
    projectile:SetPos(end_pt, fly_time)
    Sleep(const.Combat.BulletDelay)

    -- local wind_last_dist
    -- collision.Collide(start_pt, end_pt - start_pt, BulletVegetationCollisionQueryFlags, 0, BulletVegetationCollisionMask, 
    -- function(o, _, hitX, hitY, hitZ)
    -- if o:IsKindOfClasses(BulletVegetationClasses) and not table.find(hits, "obj", o) then
    -- local hit = {
    -- obj = o,
    -- pos = point(hitX, hitY, hitZ),
    -- distance = start_pt:Dist(hitX, hitY, hitZ),
    -- vegetation = true,
    -- }
    -- table.insert(hits, hit)
    -- if not wind_last_dist or hit.distance - wind_last_dist >= WindModifiersVegetationMinDistance then
    -- PlaceWindModifierBullet(hit.pos)
    -- wind_last_dist = hit.distance
    -- end
    -- end
    -- end)
    -- if wind_last_dist then
    -- table.sortby_field(hits, "distance")
    -- end

    local context = {
        attacker = attacker,
        target = target,
        dir = dir,
        target_hit = false,
        last_unit_hit = false,
        water_hit = false,
        fx_target = false
    }
    --[[ 	local last_start_pos = start_pt
	local last_time = 0

	for i, hit in ipairs(hits) do
		local hit_time = MulDivRound(hit.pos:Dist(last_start_pos), 1000, speed)
		if hit_time > last_time then
			Sleep(hit_time - last_time)
			last_time = hit_time
		end

		----
		self:BulletHit(projectile, hit, context)
		PlayFX("Spawn", "end", projectile, false)
		DoneObject(projectile)
		----
		if hit.ricochet and i < #hits then
			last_start_pos = hit.pos
			last_time = 0
			local ricochet_dir = SetLen(hits[i + 1].pos - last_start_pos, 4096)
			local axis, angle = OrientAxisToVector(1, ricochet_dir) -- 1 = +X
			projectile:SetAxis(axis)
			projectile:SetAngle(angle)
			PlayFX("Ricochet", "start", projectile, context.fx_target, last_start_pos, ricochet_dir)
			local last_pos = hits[#hits].pos
			projectile:SetPos(last_pos, MulDivRound(last_pos:Dist(last_start_pos), 1000, speed))
		end
	end
	-- if IsValid(target) and not context.target_hit then
	-- PlayFX("TargetMissed", "start", target)
	-- end
	-- wait the projectile in case of no hits or long flight after the last hit

	if projectile then
		Sleep(Max(0, end_time - GameTime()))
		PlayFX("Spawn", "end", projectile, false)
		DoneObject(projectile)
	end ]]
    local last_start_pos = start_pt
    local last_time = 0
    if hits[1] then
        self:BulletHit(projectile, hits[1], context)
    end
    --[[ 	for i, hit in ipairs(hits) do
		local hit_time = MulDivRound(hit.pos:Dist(last_start_pos), 1000, speed)
		if hit_time > last_time then
			Sleep(hit_time - last_time)
			last_time = hit_time
		end
		self:BulletHit(projectile, hit, context)
		if hit.ricochet and i < #hits then
			last_start_pos = hit.pos
			last_time = 0
			local ricochet_dir = SetLen(hits[i + 1].pos - last_start_pos, 4096)
			local axis, angle = OrientAxisToVector(1, ricochet_dir) -- 1 = +X
			projectile:SetAxis(axis)
			projectile:SetAngle(angle)
			PlayFX("Ricochet", "start", projectile, context.fx_target, last_start_pos, ricochet_dir)
			local last_pos = hits[#hits].pos
			projectile:SetPos(last_pos, MulDivRound(last_pos:Dist(last_start_pos), 1000, speed))
		end
	end ]]
    --[[ 	if IsValid(target) and not context.target_hit then
		PlayFX("TargetMissed", "start", target)
	end ]]
    -- wait the projectile in case of no hits or long flight after the last hit
    Sleep(Max(0, end_time - GameTime()))
    PlayFX("Spawn", "end", projectile, false)
    DoneObject(projectile)
end

