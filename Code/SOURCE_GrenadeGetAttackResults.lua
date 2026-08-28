local dev_bounce = true

function bnc(bool)
    dev_bounce = bool
    print("dev_bounce:", dev_bounce)
end

function Grenade:GetAttackResults(action, attack_args)

    local attacker = attack_args.obj
    local explosion_pos = attack_args.explosion_pos
    local trajectory = {}
    local mishap
    ---
    local bounce_pos
    ---
    -- local mishap_pos
    if not explosion_pos and attack_args.lof then

        local lof_idx = table.find(attack_args.lof, "target_spot_group",
                                   attack_args.target_spot_group)
        local lof_data = attack_args.lof[lof_idx or 1]
        local attack_pos = lof_data.attack_pos
        local target_pos = lof_data.target_pos
        local hits_table = lof_data.hits

        -----------------------
        local can_bounce = self.CanBounce
        -- local is_explosive = self.is_explosive

        target_pos = validate_deviated_gren_pos(target_pos, attack_args)

        -- if Platform.developer and Platform.cheats then
        -- can_bounce = dev_bounce
        -- end

        local igi = GetInGameInterface()
        local is_targeting = igi and igi.mode_dialog and igi.mode_dialog.targeting_blackboard and
                                 igi.mode_dialog.targeting_blackboard.arc_meshes ~= {}

        can_bounce = can_bounce and CurrentModOptions["enabled_bounce"]
        can_bounce = can_bounce and
                         ((CurrentModOptions["enabled_bounce_pred"] and is_targeting) or
                             not attack_args.prediction)

        ----------------------

        -------------------- Spetacular Mishap (fumbling)

        --[[ 		if not attack_args.prediction and IsKindOf(self, "MishapProperties") and is_explosive then
			local chance = self:GetMishapChance(attacker, target_pos)
			--print("mishap chance", chance)
			if CheatEnabled("AlwaysMiss") or (chance>0 and attacker:Random(100) < chance) then
				--mishap = true
				--mishap_pos = attack_pos--target_pos
				--target_pos = attack_pos
				--attacker:ShowMishapNotification(action)
			end
		end ]]
        ---------------------

        ------------------------- Ai bounce adjustment
        local ai_trajectory, ai_angle
        if can_bounce and not attack_args.prediction and EO_IsAI(attacker) then
            target_pos, ai_trajectory, ai_angle = AI_adj_targetpos_for_bounce(attack_args,
                                                                              target_pos,
                                                                              attack_pos, self)
            if ai_angle then
                attack_args.rat_angle = ai_angle
                ---- BUGFIX (B10): marca que este angulo veio da compensacao de bounce.
                ---- O par (angulo, ponto de mira) foi resolvido junto la dentro, entao o
                ---- GetTrajectory NAO pode trocar so o angulo depois do desvio.
                attack_args.rat_bounce_aim = true
            end
        end

        ---------------------------- angle for deviation
        local traj, angle
        if not attack_args.prediction and not mishap and not ai_angle then
            traj, angle = self:GetTrajectory(attack_args, attack_pos, target_pos, mishap)

            if angle then
                attack_args.rat_angle = angle
            end
        end
        ----------------------------
        ----collide test
        DbgAddCircle_collide_test(target_pos, const.SlabSizeX / 5, const.clrCyan)

        local enabled_deviation = true -- CurrentModOptions['grenade_deviation_enabled'] or true -- ~= nil and CurrentModOptions['grenade_deviation_enabled'] or true

        -------------------------------   Deviation
        local deviate, deviated_traj

        if not attack_args.prediction and not mishap and enabled_deviation then
            target_pos, deviate = self:rat_deviation(attacker, target_pos, attack_args, attack_pos)
            attack_args.rat_deviate = deviate
        end

        ---------------------------------- Vanilla mishap chance
        -- mishap & stealth kill checks
        -- if not attack_args.prediction and IsKindOf(self, "MishapProperties") and not enabled_deviation then
        -- local chance = self:GetMishapChance(attacker, target_pos)
        -- if CheatEnabled("AlwaysMiss") or attacker:Random(100) < chance then
        -- mishap = true

        -----Try a couple of times to get a valid deviated position
        -- local validPositionTries = 0
        -- local maxPositionTries = 5
        -- while validPositionTries < maxPositionTries do
        -- local dv = self:GetMishapDeviationVector(attacker, target_pos)
        -- local deviatePosition = target_pos + dv
        -- local trajectory = self:GetTrajectory_Original(attack_args, attack_pos, deviatePosition, "mishap")
        -- local finalPos = #trajectory > 0 and trajectory[#trajectory].pos
        -- if finalPos and self:ValidatePos(finalPos, attack_args) then
        -- target_pos = deviatePosition
        -- break
        -- end
        -- validPositionTries = validPositionTries + 1
        -- end
        -- attacker:ShowMishapNotification(action)
        -- end
        -- end
        -----------------------------------

        ----------------------------------- Determine Trajectory

        ------ if ever introduce fumbling again

        --[[ 		if mishap and not IsKindOf(self, "Molotov") then
			local anim_phase = attacker:GetAnimMoment(attack_args.anim, "hit") or 0
			local grenade_pos = attacker:GetRelativeAttachSpotLoc(attack_args.anim, anim_phase, attacker,
			                                                      attacker:GetSpotBeginIndex("Weaponr"))
			trajectory = {
				{
					pos = grenade_pos,
					t = 0,
				}}
		else
			print("getting default traj", GameTime())
			
			trajectory = not deviate and (ai_trajectory or traj) or
								             self:GetTrajectory(attack_args, attack_pos, target_pos, mishap)
		end ]]
        --------

        ---- BUGFIX (B11): quando houve desvio, a trajetoria e RECALCULADA aqui -- e a
        ---- recalculada e uma parabola direta, sem o ricochete que o ai_trajectory ja
        ---- trazia embutido. Guardar esse fato para o bloco de bounce la embaixo, que
        ---- antes olhava so para "ai_trajectory" (o sinal PRE-desvio) e por isso pulava
        ---- o get_bounces justamente no caso em que ele passou a ser necessario.
        local using_ai_trajectory = ai_trajectory and not deviate

        ---- mesma semantica do "not deviate and (ai_trajectory or traj) or GetTrajectory()"
        ---- original: sem trajetoria pronta (predicao, por exemplo) ainda cai no calculo.
        if not deviate and (ai_trajectory or traj) then
            trajectory = ai_trajectory or traj
        else
            trajectory = self:GetTrajectory(attack_args, attack_pos, target_pos, mishap)
        end
        ----------------------------------

        if #trajectory > 0 then
            explosion_pos = trajectory[#trajectory].pos
        end
        explosion_pos = self:ValidatePos(explosion_pos, attack_args)

        --------------Debug
        -- if not attack_args.prediction then
        -- DbgAddVector_rat(attack_args, attack_pos, explosion_pos-attack_pos , const.clrBlue)
        -- DbgAddVector_rat(attack_args, trajectory[1].pos, trajectory[#trajectory], const.clrRed)
        -- end

        ------------Bounce block

        ---- BUGFIX (B11): a guarda era "not ai_trajectory", que continuava valendo mesmo
        ---- depois de a trajetoria ter sido recalculada por causa do desvio. Resultado:
        ---- granada de IA com bounce, ao desviar, virava parabola direta e explodia na
        ---- primeira colisao -- sem ricochete nenhum, como se can_bounce fosse falso.
        ---- Agora a guarda olha para a trajetoria ATUAL: so pula quando ela e mesmo a
        ---- ai_trajectory, que ja vem com o ricochete embutido.
        if not using_ai_trajectory and #trajectory > 0 and can_bounce and not mishap then
            -- print("entering bounce block", GameTime())
            for i, step in ipairs(trajectory) do
                DbgAddCircle_rat(attack_args, step.pos, const.SlabSizeX / 10, const.clrCyan)
            end

            local bounce_pos
            trajectory, bounce_pos = get_bounces(self, trajectory, attack_args, explosion_pos)
        end

        ------------------------------ Time limit
        local time_limit = self.r_timer
        local new_trajectory = {}
        if time_limit then
            for i, step in ipairs(trajectory) do

                if step.t <= time_limit then

                    table.insert(new_trajectory, step)
                end
            end
            trajectory = new_trajectory
        end
        -------------------------------

        target_pos = bounce_pos or target_pos
        if #trajectory > 0 then
            explosion_pos = trajectory[#trajectory].pos
        end
        -- explosion_pos = self:ValidatePos(explosion_pos, attack_args)

    end

    local results
    if explosion_pos then
        local aoe_params = self:GetAreaAttackParams(action.id, attacker, explosion_pos,
                                                    attack_args.step_pos)
        if attack_args.stealth_attack then
            aoe_params.stealth_attack_roll = not attack_args.prediction and attacker:Random(100) or
                                                 100
        end
        aoe_params.prediction = attack_args.prediction
        if aoe_params.aoe_type ~= "none" or IsKindOf(self, "Flare") then
            aoe_params.damage_mod = "no damage"
        end
        results = GetAreaAttackResults(aoe_params)
        CompileKilledUnits(results)

        -------
        if not attack_args.prediction and attack_args.explosion_pos then
            -- print("entering shrapnel block", GameTime())
            results.shrapnel_results = GetShrapnelResults(self, explosion_pos, attacker)
            if not IsKindOf(self, "ThrowableTrapItem") or (self.TriggerType or "") == "Contact" then
                local misfire = processIEDmisfire(self, attacker)
                results.ied_misfire = misfire
            end
        end
        -------

        local radius = aoe_params.max_range * const.SlabSizeX
        local explosion_voxel_pos = SnapToVoxel(explosion_pos) + point(0, 0, const.SlabSizeZ / 2)
        local impact_force = self:GetImpactForce()
        local unit_damage = {}
        for _, hit in ipairs(results) do
            local obj = hit.obj
            if not obj or hit.damage == 0 then
                goto continue
            end

            local dist = hit.obj:GetDist(explosion_voxel_pos)

            if IsKindOf(obj, "Unit") then
                if not obj:IsDead() then
                    unit_damage[obj] = (unit_damage[obj] or 0) + hit.damage
                    if unit_damage[obj] >= obj:GetTotalHitPoints() then
                        results.killed_units = results.killed_units or {}
                        table.insert_unique(results.killed_units, obj)
                    end
                end
            end
            hit.impact_force = impact_force + self:GetDistanceImpactForce(dist)
            hit.explosion = true
            ::continue::
        end
    else
        results = {}
    end
    results.trajectory = trajectory
    results.explosion_pos = explosion_pos
    results.weapon = self
    results.mishap = mishap
    results.no_damage = IsKindOf(self, "Flare")

    return results
end

