function Grenade:GetTrajectory(attack_args, attack_pos, target_pos, mishap, bounce, bounce_angle)
    if not attack_pos and attack_args.lof then
        local lof_idx = table.find(attack_args.lof, "target_spot_group",
                                   attack_args.target_spot_group)
        local lof_data = attack_args.lof[lof_idx or 1]
        attack_pos = lof_data.attack_pos
    end

    if not attack_pos then
        return {}
    end

    local valid_target = true

    -------Removed the sanity check. Why not? :)
    -- sanity-check the target pos
    --local pass = SnapToPassSlab(target_pos)
    --if pass then
    --    pass = pass:IsValidZ() and pass or pass:SetTerrainZ()
    --    if abs(pass:z() - target_pos:z()) >= 2 * const.SlabSizeZ then
    --        valid_target = false
    --    end
    --else
    --    valid_target = false
    --end
    -------

    local num_bounces = attack_args.num_bounces

    if bounce then
        target_pos = target_pos:SetTerrainZ() -- target_pos:SetZ(target_pos:SetTerrainZ():z() +100 * guic)
        DbgAddCircle_rat(attack_args, target_pos, const.SlabSizeX / 1, const.clrMagenta)
    end

    -- try the different trajectories to pick a suitable one
    local angles = {}

    if attack_args.rat_angle and not bounce_angle and not mishap then
        angles = {attack_args.rat_angle}
        -- elseif valid_target or mishap and not bounce then 
    elseif valid_target or mishap or attack_args.rat_deviate and not bounce_angle then
        if target_pos:z() - attack_pos:z() >= 2 * const.SlabSizeZ then
            angles[1] = const.Combat.GrenadeLaunchAngle_Incline
            angles[2] = const.Combat.GrenadeLaunchAngle
        else
            -- throwing down/level, prefer low arc
            if target_pos:z() - attack_pos:z() <= const.SlabSizeZ / 2 then
                angles[1] = const.Combat.GrenadeLaunchAngle_Low
            end
            angles[#angles + 1] = const.Combat.GrenadeLaunchAngle
            if not GameState.Underground then
                angles[#angles + 1] = const.Combat.GrenadeLaunchAngle_Incline
            end
        end
    end

    -------------------
    if bounce_angle then
        angles = {bounce_angle}
    end

    local attacker = attack_args.obj

    local best_dist, best_trajectory = attacker:GetDist(target_pos), {}
    -------------------
    if bounce then
        best_dist, best_trajectory = attack_pos:Dist(target_pos), {}
    end

    ----- Fallback
    if #angles < 1 and not attack_args.prediction then
        angles = {const.Combat.GrenadeLaunchAngle}
    end

    local final_angle
    -----------------
    for _, angle in ipairs(angles) do
        local trajectory
        --------------------------------------
        if bounce then
            trajectory = self:Ratonade_Bounce_CalcTrajectory(attack_args, target_pos, angle,
                                                             (angle ==
                                                                 const.Combat.GrenadeLaunchAngle_Low) and
                                                                 1 or 0, attack_pos)
        else
            ---------------------------------------
            trajectory = self:CalcTrajectory(attack_args, target_pos, angle, (angle ==
                                                 const.Combat.GrenadeLaunchAngle_Low) and 1 or 0)
        end
        local hit_pos = (#trajectory > 0) and trajectory[#trajectory].pos
        if hit_pos and (hit_pos:Dist(trajectory[1].pos) > 0) then

            if IsCloser(hit_pos, target_pos, const.SlabSizeX) then
                best_trajectory, final_angle = trajectory, angle
                break
            end
            local dist = hit_pos:Dist(target_pos)
            if dist < best_dist then
                best_dist, best_trajectory = dist, trajectory
                final_angle = angle
            end
        end
    end

    ---------------

    if not bounce and best_trajectory and #best_trajectory > 0 then

        local launch_time_adjustment_factor = 1 - grenade_mass_factor_adjusted(self, 8) or 0

        launch_time_adjustment_factor = Min(1.20, launch_time_adjustment_factor)

        local launch_time = best_trajectory[2].t ------- T STEP IS ALWAYS 20

        local adjusted_launch_time = cRound(launch_time * launch_time_adjustment_factor)

        for i, step in ipairs(best_trajectory) do
            step.t = adjusted_launch_time +
                         cRound((step.t - launch_time) * launch_time_adjustment_factor)
        end
    end

    -------------

    return best_trajectory, final_angle
end

