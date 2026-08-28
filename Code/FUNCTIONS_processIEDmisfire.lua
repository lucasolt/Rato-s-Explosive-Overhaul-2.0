function processIEDmisfire(weapon, unit)
    -- print("process ied")
    local opt = tonumber(CurrentModOptions.mifire_chance_mul or 100)
    -- print("opt", opt)

    if weapon and weapon.is_ied and opt ~= 0 then
        if CheatEnabled("AlwaysMiss") then
            return true
        end
        local chance
        if ratG_simple_ied_misfire then
            chance = simple_IED_misfire_Chance(unit)
        else
            local count = weapon.Amount or 1
            -- if IsKindOf(weapon, "InventoryStack") then
            local stack_qual = weapon.ied_quality_stack
            local stack_correct
            stack_qual, stack_correct = assertStackQual(stack_qual, weapon, unit)

            local index = InteractionRand(count, "RATONADE_IEDqual_index") + 1 -- unit:Random(count) + 1

            chance = stack_qual[index] or 5

            -- print("misfire chance", chance)
            if stack_qual[index] then
                table.remove(stack_qual, index)
            end
            weapon.ied_quality_stack = stack_qual
            ObjModified(weapon)
        end

		if GameState.RainHeavy and IsKindOf(weapon, "GrenadeProperties") then
    	    chance = MulDivRound(chance, const.EO.HeavyRainIEDMisfireMul, 100)
    	end


        chance = Max(1, MulDivRound(chance, opt, 100))
        --[[ 		print("pos process stack qual", weapon.ied_quality_stack)
		print("chance", chance) ]]

        local roll = InteractionRand(100, "RATONADE_IEDMisfire_Roll") + 1 -- unit:Random(100) + 1
        -- print("chance", chance, "roll", roll)
        if roll <= chance then
            -- print("misfire")
            return true
        end
    end
    return false
end

function simple_IED_misfire_Chance(unit)
    local override_stat = EO_IsAI(unit) and AI_ExplosiveStatforIED(unit) or false
    local chance = determine_IED_misfire_chance(false, unit, override_stat)
    return chance
end

function assertStackQual(stack_qual, item, unit)
    --[[ 	if not stack_qual then
		return {}, false
	end ]]
    local item_amount = item.Amount or 1
    if item_amount == #stack_qual then
        return stack_qual, true
    end
    if item_amount < #stack_qual then
        local new_stack_qual = {}
        for i = 1, item_amount do
            if stack_qual[i] then
                table.insert(new_stack_qual, stack_qual[i])
            end
        end
        return new_stack_qual, false
    elseif unit then
        local override_stat = EO_IsAI(unit) and AI_ExplosiveStatforIED(unit) or false
        return determine_IED_misfire_chance(item, unit, override_stat), false
    else
        local new_stack_qual = {}
        for i = 1, item_amount do
            table.insert(new_stack_qual, 5)
        end
        return new_stack_qual, false
    end
    return {}, false
end

function MishapProperties:IED_trap_OnLand(thrower, attackResults, visual_obj, original_fx_actor)

    --[[ 	if self.TriggerType == "Contact" then
		Grenade.OnLand(self, thrower, attackResults, visual_obj)
		return
	end ]]

    PushUnitAlert("thrown", visual_obj, thrower)

    -- <Unit> Heard a thud
    PushUnitAlert("noise", visual_obj, self.ThrowNoise,
                  Presets.NoiseTypes.Default.ThrowableLandmine.display_name)

    local finalPointOfTrajectory = attackResults.explosion_pos
    assert(finalPointOfTrajectory, "Where'd that grenade fall?")
    if not finalPointOfTrajectory then
        return
    end

    local teamSide = thrower and thrower.team and thrower.team.side
    assert(teamSide)
    teamSide = teamSide or "player1"

    ----------------
    local random_type = thrower:Random(3)
    local landmine_args
    if random_type == 1 then
        -- print("prox")
        landmine_args = {TriggerType = "Proximity", triggerRadius = 1, TimedExplosiveTurns = 1}
    elseif random_type == 2 then
        -- print("timed")
        landmine_args = {
            TriggerType = "Timed",
            triggerRadius = 0,
            TimedExplosiveTurns = thrower:Random(3) + 1

        }
    else
        -- print("inert")
        landmine_args = {TriggerType = "Proximity", triggerRadius = 0, TimedExplosiveTurns = 1}
    end

    local newLandmine = PlaceObject("DynamicSpawnLandmine_MisfiredIED", {
        -- The landmine properties need to be set at init time
        TriggerType = landmine_args.TriggerType,
        triggerRadius = landmine_args.triggerRadius,
        TimedExplosiveTurns = landmine_args.TimedExplosiveTurns,
        DisplayName = self.DisplayName,
        triggerChance = "Always",
        fx_actor_class = self.class .. "_Misfired",
        item_thrown = self.class,
        team_side = teamSide,
        attacker = thrower,
        GrenadeExplosion = IsKindOf(self, "Grenade") or false -- true,
    })
    ------------
    if IsValid(visual_obj) then
        DoneObject(visual_obj)
    end

    -- Copy explosive type config to the mine
    local explosiveTypePreset = IsKindOf(self, "ThrowableTrapItem") and
                                    self:GetExplosiveTypePreset() or self -- g_Classes["C4"] -- self:GetExplosiveTypePreset()
    newLandmine:CopyProperties(explosiveTypePreset, TrapExplosionProperties:GetProperties())

    -- Add explosive skill to landmine damage.
    newLandmine.BaseDamage = thrower:GetBaseDamage(self)

    -- Throwable mines are seen by all
    -- newLandmine.discovered_by[teamSide] = true
    newLandmine:SetPos(finalPointOfTrajectory)
    newLandmine:EnterSectorInit()
    VisibilityUpdate(true)

    table.iclear(attackResults)

    --
    CreateFloatingText(newLandmine:GetPos(), T("<color AmmoAPColor>IED Misfire</color>"))
    --

    attackResults.trap_placed = true

end

