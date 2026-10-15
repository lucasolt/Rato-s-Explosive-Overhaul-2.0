function ApplyExplosionDamage(attacker, fx_actor, results, noise, disableBurnFx, ignore_targets)
    local weapon = results.weapon
    local explosion_pos = results.explosion_pos or results.target_pos
    local shr_results = results.shrapnel_results

    if explosion_pos and weapon then
        local time = GameTime()
        if shr_results then
            shrapnel_Execute(shr_results, time)
            ---- BUGFIX (B13): as threads ja tem o que precisam; nao deixa o resultado
            ---- (hits, lof_args, um por estilhaco) pendurado no results do ataque.
            results.shrapnel_results = nil
        elseif IsKindOf(weapon, "Ordnance") and results.attack_from_stealth == nil then
            shr_results = GetShrapnelResults(weapon, explosion_pos, attacker)
            shrapnel_Execute(shr_results, time)
        elseif IsKindOf(weapon, "Landmine") then
            local original_item = weapon.item_thrown and g_Classes[weapon.item_thrown]
            if original_item then
                shr_results = GetShrapnelResults(original_item, explosion_pos, attacker)
                shrapnel_Execute(shr_results, time)
            end
        end
    end

    results = processExplosiveHitEffects(results, weapon)

    original_ApplyExplosionDamage(attacker, fx_actor, results, noise, disableBurnFx, ignore_targets)
end

function shrapnel_Execute(shr_results, time)
    if not shr_results then
        return
    end
    for i, shrapnel in ipairs(shr_results) do
        CreateGameTimeThread(Firearm.Shrapnel_Fly, shrapnel.weapon, shrapnel.attacker,
                             shrapnel.start_pt, shrapnel.end_pt, shrapnel.shrapnel_dir,
                             shrapnel.speed, shrapnel.hits, shrapnel.target, shrapnel.lof_args, time)
    end
end

