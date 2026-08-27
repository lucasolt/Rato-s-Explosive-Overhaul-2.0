function Grenade:CalcTrajectory(attack_args, target_pos, angle, max_bounces, attack_pos)
	-- local no_col = attack_args and attack_args.no_col or false
	local attacker = attack_args.obj
	local anim_phase = attacker:GetAnimMoment(attack_args.anim, "hit") or 0
	local attack_offset = attacker:GetRelativeAttachSpotLoc(attack_args.anim, anim_phase, attacker,
	                                                        attacker:GetSpotBeginIndex("Weaponr"))
	local step_pos = attack_args.step_pos
	if not step_pos:IsValidZ() then
		step_pos = step_pos:SetTerrainZ()
	end

	local pos0 = step_pos:SetZ(step_pos:z() + attack_offset:z())
	if not angle then
		if target_pos:z() - pos0:z() > const.SlabSizeZ / 2 then
			angle = const.Combat.GrenadeLaunchAngle_Incline
		else
			angle = const.Combat.GrenadeLaunchAngle
		end
	end
	local sina, cosa = sincos(angle)
	local aim_pos = pos0 + Rotate(point(cosa, 0, sina), CalcOrientation(pos0, target_pos))
	local grenade_pos = GetAttackPos(attack_args.obj, step_pos, axis_z, attack_args.angle, aim_pos, attack_args.anim,
	                                 anim_phase, attack_args.weapon_visual)
	if grenade_pos:Equal2D(target_pos) then
		return empty_table
	end

	local dir = target_pos - grenade_pos
	local bounce_diminish = 40
	local vec
	local can_bounce = self.CanBounce
	if attack_args.can_bounce ~= nil then
		can_bounce = attack_args.can_bounce
	end
	max_bounces = can_bounce and max_bounces or 0
	if can_bounce then
		max_bounces = 1
	end
	-- if max_bounces > 0 then
	-- local coeff = 1000
	-- local d = 10 * bounce_diminish
	-- for i = 1, max_bounces do
	-- coeff = coeff + d
	-- d = MulDivRound(d, bounce_diminish, 100)
	-- end
	-- local bounce_target_pos = grenade_pos + MulDivRound(dir, 1000, coeff)
	-- vec = CalcLaunchVector(grenade_pos, bounce_target_pos, angle, const.Combat.Gravity)
	-- else

	
	vec = CalcLaunchVector(grenade_pos, target_pos, angle, const.Combat.Gravity)
	-- end
	local time = MulDivRound(grenade_pos:Dist2D(target_pos), 1000, Max(vec:Len2D(), 1))
	if time == 0 then
		return empty_table
	end

	-- local trajectory = no_col and CalcBounceParabolaTrajectory_for_deviation(grenade_pos, vec, const.Combat.Gravity, time, 20, max_bounces, bounce_diminish, no_col) or CalcBounceParabolaTrajectory(grenade_pos, vec, const.Combat.Gravity, time, 20, max_bounces, bounce_diminish, false)

	local trajectory = CalcBounceParabolaTrajectory(grenade_pos, vec, const.Combat.Gravity, time, 20, max_bounces,
	                                                bounce_diminish, false)
	return trajectory
end

