function AI_deviate_handicap(unit) --- not enabled
    if not EO_IsAI(unit) then
        return 0
    end

    local level = unit:GetLevel() or 1

    if unit.Affiliation == "Adonis" then
        level = level + 2
    elseif unit.Affiliation == "Army" then
        level = level + 1
    end

    local reduction = cRound(level * 1.33)
    reduction = MulDivRound(reduction, tonumber(CurrentModOptions.ai_deviate_hc) or 100, 100)

    return reduction
end

function AI_deviate_skill_diff(unit)
    if not EO_IsAI(unit) then
        return 0
    end
    local modifier = extractNumberWithSignFromString(CurrentModOptions.AI_skill_throw_diff) or 0
    return modifier
end

function AI_ExplosiveStatforIED(unit)
    local unit_level = unit and unit:GetLevel() or 1
    local level_stat = cRound(1.6 * unit_level)
    local random_factor = 12
    local random = InteractionRand(random_factor * 2, "RATONADE_AIstatIED") - random_factor -- unit:Random(random_factor * 2) - random_factor
    return Min(100, 70 + random + level_stat)
end

function AI_adj_targetpos_for_bounce(orig_attack_args, target_pos, attack_pos, grenade)

    local attack_args = table.copy(orig_attack_args)
    local max_tries = 40
    local tries = 0
    local z_adj = 10 * guic

    local trg_pos_traj = grenade:GetTrajectory(attack_args, attack_pos, target_pos, false)

    if #trg_pos_traj > 0 then
        target_pos = trg_pos_traj[#trg_pos_traj].pos or target_pos
    end

    local target_posz = target_pos:z()
    local high_target_pos = target_pos:SetZ(target_posz + const.SlabSizeZ * 10)
    local col, pts = CollideSegmentsNearest(target_pos:SetZ(target_posz + z_adj), high_target_pos)

    if col and pts[1] then
        high_target_pos = pts[1]
    end

    DbgAddCircle_ai_adj(high_target_pos, const.SlabSizeX / 2, const.clrBlue)

    local dir = target_pos - attack_pos

    local best_target_pos, best_dist, best_traj, best_angle, best_bounce_pos

    local thrs_dist = 0.2 * const.SlabSizeX
    local dist_adjst = const.SlabSizeX * 0.15
    local sideways_adjst = const.SlabSizeX / 1.5

    local z_tolerance = const.SlabSizeZ * 2 -- grenade.AreaOfEffect and Max(grenade.AreaOfEffect * const.SlabSizeX, const.SlabSizeZ*2) or const.SlabSizeZ*2

    local positive_thresh = cRound(max_tries / 3)
    DbgAddCircle_ai_adj(target_pos, const.SlabSizeX / 2, const.clrBlack)

    while tries <= max_tries do

        local sign = tries < positive_thresh and 1 or -1

        local adj_mul = tries < positive_thresh and tries or tries - positive_thresh

        local bounce_pos, bounced_trajectory
        local loop_dir = SetLen(dir, dir:Len() + (sign * dist_adjst * adj_mul))

        local final_target_pos = attack_pos + loop_dir
        final_target_pos = final_target_pos:SetTerrainZ()

        DbgAddCircle_ai_adj(final_target_pos, const.SlabSizeX / 2, const.clrPink)

        local fin_col, fin_pts = CollideSegmentsNearest(
                                     high_target_pos:SetZ(high_target_pos:z() - z_adj),
                                     final_target_pos)

        if fin_col and fin_pts[1] then
            final_target_pos = fin_pts[1]
        end
        DbgAddCircle_ai_adj(final_target_pos, const.SlabSizeX / 6, const.clrRed)
        DbgAddVector_ai_adj(high_target_pos, final_target_pos - high_target_pos)

        local trajectory, angle = grenade:GetTrajectory(attack_args, attack_pos, final_target_pos,
                                                        false)

        if #trajectory > 0 then
            local normal, colide_obj, colide_obj_pos, terrain_material = collision_obj_norm_pos(
                                                                             trajectory, attack_args)

            if colide_obj_pos then
                local att_args_copy = table.copy(attack_args)
                final_target_pos = colide_obj_pos
                trajectory, angle = grenade:GetTrajectory(att_args_copy, attack_pos,
                                                          final_target_pos, false)
            end
        end
        DbgAddCircle_ai_adj(final_target_pos, const.SlabSizeX / 6, const.clrMagenta)

        local explosion_pos
        if #trajectory > 0 then
            explosion_pos = trajectory[#trajectory].pos
        end

        if explosion_pos then

            bounced_trajectory, bounce_pos = get_bounces(grenade, trajectory, attack_args,
                                                         explosion_pos)

            if bounced_trajectory and #bounced_trajectory > 0 then
                bounce_pos = bounced_trajectory[#bounced_trajectory].pos
            else
                bounce_pos = nil
            end

            if bounce_pos then
                local bounce_dist_target = bounce_pos:Dist(target_pos)

                if abs(bounce_pos:z() - target_pos:z()) <= z_tolerance then
                    if bounce_dist_target <= thrs_dist then
                        DbgAddCircle_ai_adj(final_target_pos, const.SlabSizeX / 6, const.clrYellow)
                        best_target_pos, best_dist, best_traj, best_angle, best_bounce_pos =
                            final_target_pos, bounce_dist_target, bounced_trajectory, angle,
                            bounce_pos
                        break

                    elseif not best_target_pos or bounce_dist_target < best_dist then
                        best_target_pos, best_dist, best_traj, best_angle, best_bounce_pos =
                            final_target_pos, bounce_dist_target, bounced_trajectory, angle,
                            bounce_pos
                    end
                end
            end
        end

        tries = tries + 1
    end

    for i, step in ipairs(best_traj or empty_table) do
        DbgAddCircle_ai_adj(step.pos, const.SlabSizeX / 10, const.clrCyan)
    end

    return best_target_pos or target_pos, best_traj, best_angle, false, false
end
