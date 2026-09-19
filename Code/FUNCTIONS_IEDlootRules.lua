function disable_normal_explosive_crafting()

    if CurrentModOptions["disable_IED_craftRules"] then
        return
    end
    local recipes = g_RecipesCraftExplosives
    if type(recipes) ~= "table" then
        return
    end
    local to_remove_item = {
        "IncendiaryGrenade", "FragGrenade", "ConcussiveGrenade", "HE_Grenade", "HE_Grenade_1",
        "SmokeGrenade", "TearGasGrenade"
    }
    for i = #recipes, 1, -1 do
        if table.find(to_remove_item, recipes[i].item_id) then
            table.remove(recipes, i)
        end
    end
end

-- Fill builds the list on first open, unfiltered; pruning only before Validate missed it
local original_SectorOperationFillItemsToCraft = SectorOperationFillItemsToCraft
function SectorOperationFillItemsToCraft(sector_id, operation_id, merc)
    local result = original_SectorOperationFillItemsToCraft(sector_id, operation_id, merc)
    disable_normal_explosive_crafting()
    return result
end

local original_SectorOperationValidateItemsToCraft = SectorOperationValidateItemsToCraft
function SectorOperationValidateItemsToCraft(sector_id, operation_id, merc)
    original_SectorOperationValidateItemsToCraft(sector_id, operation_id, merc)
    disable_normal_explosive_crafting()
end
--[[ function OnMsg.DataLoaded()
	print("trying to disable explosive craft")
	for i, v in ipairs(g_RecipesCraftExplosives) do
		print(v)
	end
	disable_normal_explosive_crafting()
end ]]

------ AI explosive replacements

function OnMsg.UnitEnterCombat(unit)
    replace_explosive_or_iedAI(unit)
end

function OnMsg.UnitDied(unit)
    replace_explosive_or_iedAI(unit)
end

function replace_explosive_or_iedAI(unit)

    if CurrentModOptions.SkipIEDLootChanges then
        return
    end

    if not EO_IsAI(unit) then
        return
    end

    local affiliation = unit.Affiliation or ""

    local islegion_thug = affiliation == "Legion" or affiliation == "Thugs"

    if not islegion_thug then
        replaceIED_for_explosive(unit)
        return
    end

    if unit.EO_AI_replacedIED then
        return
    end

    local override_stat = AI_ExplosiveStatforIED(unit)
    unit:ForEachItem(function(item, slot)
        if IsKindOfClasses(item, "MishapProperties") then

            local new_item_id = get_replacement_ied(unit, item)
            if new_item_id and g_Classes[new_item_id] then
                local amount = item.Amount or 1
                local new_item = PlaceInventoryItem(new_item_id)
                new_item.Amount = amount
                if new_item.is_ied and not ratG_simple_ied_misfire then
                    new_item.ied_quality_stack = determine_IED_misfire_chance(new_item, unit,
                                                                              override_stat)
                end
                unit:RemoveItem(slot, item)
                unit:AddItem(slot, new_item)

                ObjModified(unit)
            end
        end
    end)
    unit.EO_AI_replacedIED = true

end

function replaceIED_for_explosive(unit)
    unit:ForEachItem(function(item, slot)
        if IsKindOfClasses(item, "MishapProperties") then
            local new_item_id = get_replacement_explosive(item, unit)
            if new_item_id and g_Classes[new_item_id] then
                local amount = item.Amount or 1
                local new_item = PlaceInventoryItem(new_item_id)
                new_item.Amount = amount
                unit:RemoveItem(slot, item)
                unit:AddItem(slot, new_item)

                ObjModified(unit)
            end
        end
    end)
end

local rep_table = {
    FragGrenade = {{item = "PipeBomb", weight = 35}, {item = "NailBomb_IED", weight = 65}},
    HE_Grenade = {
        {item = "PipeBomb", weight = 20}, {item = "NailBomb_IED", weight = 60},
        {item = "TNTBolt_IED", weight = 20}
    },
    HE_Grenade_1 = {
        {item = "PipeBomb", weight = 20}, {item = "NailBomb_IED", weight = 10},
        {item = "TNTBolt_IED", weight = 60}
    },
    IncendiaryGrenade = {{item = "Molotov", weight = 100}},
    SmokeGrenade = {{item = "SmokeGrenade_IED", weight = 100}},
    TearGasGrenade = {{item = "TearGasGrenade_IED", weight = 100}},
    ConcussiveGrenade = {{item = "ConcussiveGrenade_IED", weight = 100}}
}
function get_replacement_explosive(item, unit)
    local ieds = {}
    for k, v in sorted_pairs(rep_table) do
        for i, entry in ipairs(v) do
            if not ieds[entry.item] then
                ieds[entry.item] = {k}
            else
                table.insert(ieds[entry.item], k)
            end
        end
    end
    local explos = ieds[item.class]
    if explos then
        if #explos == 1 then
            return explos[1]
        else
            local rand = InteractionRand(#explos, "RATONADE_get_replacement_explosive") + 1 -- unit:Random(#explos) + 1
            return rand <= #explos and explos[rand] or explos[1]
        end
    end
    return false
end

function get_replacement_ied(unit, item)
    if rep_table[item.class] then
        local chance = 85
        local roll = InteractionRand(100, "RATONADE_replacement_chance_roll") + 1 -- unit:Random(100) + 1
        if roll <= chance then
            local replacements = rep_table[item.class]
            if #replacements == 1 then
                -- If there's only one replacement option, return it directly
                return replacements[1].item
            else
                -- Calculate total weight
                local totalWeight = 0
                for _, replacement in ipairs(replacements) do
                    totalWeight = totalWeight + replacement.weight
                end

                -- Generate a random number within the range of total weight
                local randomNum = InteractionRand(totalWeight, "RATONADE_replacement_weighted_roll") -- unit:Random(totalWeight)

                -- Iterate over replacement options
                local cumulativeWeight = 0
                for _, replacement in ipairs(replacements) do
                    cumulativeWeight = cumulativeWeight + replacement.weight
                    -- Check if random number falls within the range of this replacement option
                    if randomNum <= cumulativeWeight then
                        -- Return the selected replacement item
                        return replacement.item
                    end
                end
            end
        end
    end
    -- If no replacement was chosen or the chance condition was not met, return nil
    return nil
end
