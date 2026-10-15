function OrdnanceProperties:GetEO_description_hints()

	return EO_grenade_format_hints(self)
end

function GrenadeProperties:GetEO_description_hints()
	return EO_grenade_format_hints(self)
end

---- T() so na primeira chamada: nao depende de T estar pronto na hora do load
local HINT_TEXTS
local function hint_texts()
	HINT_TEXTS = HINT_TEXTS or {
		shapes = {
			Stick_like = T(578037172437, "Stick"),
			Spherical = T(145226011415, "Spherical"),
			Cylindrical = T(527458804193, "Cylindrical"),
			Bottle = T(366849131119, "Bottle"),
			Brick = T(592944541650, "Brick"),
			Long = T(506994741710, "Long"),
			Can = T(789854560400, "Can"),
		},
		---- chaves = retorno de get_FragLevel, que tambem e usado na logica (get_shrap_args)
		frag = {
			High = T(224058173643, "High"),
			Medium = T(526794963176, "Medium"),
			Low = T(480969167765, "Low"),
			["Very Low"] = T(241712020083, "Very Low"),
			None = T(643219029758, "None"),
		},
		yes = T(1138, "Yes"),
		no = T(1139, "No"),
		accuracy = T(244543786320, "Accuracy:"),
		fragmentation = T(258032549932, "Fragmentation:"),
		can_bounce = T(999408551812, "Can Bounce:"),
		shape = T(201648498674, "Shape:"),
		mass = T(336590053484, "Mass:"),
		fuse_timer = T(780264648428, "Fuse Timer:"),
	}
	return HINT_TEXTS
end

function EO_grenade_format_hints(self)
	local texts = hint_texts()

	local owner = self.owner and (not gv_SatelliteView and g_Units[self.owner] or gv_UnitData[self.owner]) or false

	local function getshape(self)
		return texts.shapes[self.r_shape] or false
	end

	local function getcanbounce(self)
		return self.CanBounce and texts.yes or texts.no
	end

	local function getmass(self)
		local mass = self.r_mass
		if not mass then
			return false
		end
		return T{248484752991, "<mass> <color PDABrowserFlavorMedium>Grams</color>", mass = mass}
	end

	local function getacc(self)
		local acc = self:get_throw_accuracy(owner) + 10 or 0
		if acc > 0 then
			return "+" .. abs(acc)
		elseif acc < 0 then
			return "-" .. abs(acc)
		end
		return acc
	end

	local function getfusetimer(self)
		local time = self.r_timer
		if not time or time == 0 then
			return false
		end
		return T{307481463909, "<seconds> <color PDABrowserFlavorMedium>Seconds</color>", seconds = time / 1000.0}
	end

	local termList = {
		{texts.fragmentation, texts.frag[get_FragLevel(self)]},
		{texts.can_bounce, getcanbounce(self)}, {texts.fuse_timer, getfusetimer(self)}}

	if IsKindOf(self, "Grenade") then
		table.insert(termList, 1, {texts.accuracy, getacc(self)})
		table.insert(termList, 3, {texts.shape, getshape(self)})
		table.insert(termList, 5, {texts.mass, getmass(self)})
	end

	local lines = {}
	for _, term in ipairs(termList) do
		if term[2] then
			lines[#lines + 1] = T{223837797518,
				"<color PDABrowserFlavorMedium><label></color> <color PDABrowserTextHighlight><value></color>",
				label = term[1], value = term[2]}
		end
	end

	if self.is_ied then
		lines[#lines + 1] = T(908569475282, "<color PDABrowserTextHighlight>Can Misfire</color>")
	end

	return T{331479029909, "<style CrosshairAPTotal><lines></style>", lines = table.concat(lines, "\n")}
end
