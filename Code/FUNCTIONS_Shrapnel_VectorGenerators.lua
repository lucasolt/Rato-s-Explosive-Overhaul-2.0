--- The shrapnel scatter used to be driven by math.random, which is not part of
--- the game's synced random state. In co-op each machine rolled its own values,
--- so the shrapnel cloud (and therefore every hit and every point of damage it
--- caused) differed between players. Both generators now take a deterministic
--- seed and hand the advanced state back to the caller, so the whole cloud is
--- reproducible from one synced roll.

function generateShrapnelPositionsInCone(numPositions, radius, center, args, seed)
	local positions = {}
	local phis_list = {}

	seed = rat_rand_seed(seed)

	local angle_radians = args.angle_deg * math.pi / 180
	-- local count = 0
	local spread_p = center:SetZ(center:z() + args.radius)
	spread_p = RotateAxis(spread_p, point(1, 0, 0), 90 * 60, center)
	local spread_orient = CalcOrientation(center, spread_p)
	local angle_offset = (args.dir_angle - spread_orient)

	for i = 1, numPositions do
		local r1, r2
		r1, seed = rat_rand_float(seed)
		r2, seed = rat_rand_float(seed)

		local theta = r1 * 2 * math.pi
		local h = r2 * radius * math.tan(angle_radians / 2)

		local x = center:x() + math.cos(theta) * h
		local y = center:y() + math.sin(theta) * h
		local z = center:z() + math.sqrt(radius ^ 2 - h ^ 2)

		local p = point(x, y, z)
		p = RotateAxis(p, point(1, 0, 0), 90 * 60, center)
		p = RotateAxis(p, point(0, 0, 1), angle_offset, center)
		p = p:SetZ(p:z() * 1.12)

		if p:z() >= center:z() then
			table.insert(positions, p)
			-- count = count + 1
		end
		-- table.insert(phis_list, theta)  -- Store the theta angle for potential use
	end
	-- print("count", count)
	return positions, seed -- , phis_list
end

function generateShrapnelPositions(numPositions, radius, center, cone_args, seed)
	local positions = {}
	local phis_list = {}
	local theta_list = {}
	local vectors, phis, thetas = generateShrapnelVectors(numPositions)

	seed = rat_rand_seed(seed)

	local maxRandomOffset = const.SlabSizeX * 0.15

	for i, v in ipairs(vectors) do
		-- print(v)
		local x = v[1] * radius + center:x()
		local y = v[2] * radius + center:y()
		local z = v[3] * radius + center:z()

		local xOffset, yOffset, zOffset
		xOffset, seed = rat_rand_range(seed, -maxRandomOffset, maxRandomOffset)
		yOffset, seed = rat_rand_range(seed, -maxRandomOffset, maxRandomOffset)
		zOffset, seed = rat_rand_range(seed, -maxRandomOffset, maxRandomOffset)

		x = x + xOffset
		y = y + yOffset
		z = (z + zOffset) -- * 0.9
		if z > center:z() then
			local point = point(x, y, z)

			table.insert(positions, point)
			table.insert(phis_list, phis[i])
			table.insert(theta_list, thetas[i])
		end
	end

	return positions, phis_list, theta_list, seed
end

function generateShrapnelVectors(numVectors)
	local vectors = {}
	local phis = {}
	local thetas = {}

	local goldenRatio = (1 + math.sqrt(5)) / 2

	for i = 1, numVectors do
		local theta = 2 * math.pi * (i - 1) / goldenRatio

		local phi = math.acos(-1 + 2 * (i - 0.5) / numVectors) -- *0.7 ---- bias to north hemisphere. 
		-- local phi = math.acos(math.random() * 2 - 1) *0.9
		-- phi = phi >= 1.4 and phi * 0.8 or phi * 3 ---- bias to the equator, a little to the north
		-- phi = phi >= 1.4 and phi * 0.8 or phi * 2.8
		phi = phi >= 1.4 and phi * 0.65 or phi * 2.5

		local x = math.sin(phi) * math.cos(theta)
		local y = math.sin(phi) * math.sin(theta)
		local z = math.cos(phi)

		table.insert(vectors, {x, y, z})
		table.insert(phis, phi)
		table.insert(thetas, theta)
	end

	return vectors, phis, thetas
end
