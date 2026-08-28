UndefineClass('dazed_flashbang')
DefineClass.dazed_flashbang = {
	__parents = { "CharacterEffect" },
	__generated_by_class = "ModItemCharacterEffectCompositeDef",


	object_class = "CharacterEffect",
	msg_reactions = {
		PlaceObj('MsgReaction', {
			Event = "StatusEffectAdded",
			Handler = function (self, obj, id, stacks)
				local reaction_idx = table.find(self.msg_reactions or empty_table, "Event", "StatusEffectAdded")
				if not reaction_idx then return end
				
				local function exec(self, obj, id, stacks)
				if IsKindOf(obj, "Unit") then
					obj:SetEffectValue("blinded_start_time", GameTime())
				
				end
				end
				local _id = GetCharacterEffectId(self)
				if _id == id then exec(self, obj, id, stacks) end
				
			end,
		}),
		PlaceObj('MsgReaction', {
			Event = "StatusEffectRemoved",
			Handler = function (self, obj, id, stacks, reason)
				local reaction_idx = table.find(self.msg_reactions or empty_table, "Event", "StatusEffectRemoved")
				if not reaction_idx then return end
				
				local function exec(self, obj, id, stacks, reason)
				if IsKindOf(obj, "Unit") then
					obj:SetEffectValue("blinded_start_time")
					ObjModified(obj)
				end
				end
				local _id = GetCharacterEffectId(self)
				if _id == id then exec(self, obj, id, stacks, reason) end
				
			end,
		}),
		PlaceObj('MsgReaction', {
			Event = "UnitBeginTurn",
			Handler = function (self, unit)
				local reaction_idx = table.find(self.msg_reactions or empty_table, "Event", "UnitBeginTurn")
				if not reaction_idx then return end
				
				local function exec(self, unit)
				if not unit:IsDead() then
					EnvEffectTearGasTick(unit, nil, "start turn")
				end
				end
				local id = GetCharacterEffectId(self)
				
				if id then
					if IsKindOf(unit, "StatusEffectObject") and unit:HasStatusEffect(id) then
						exec(self, unit)
					end
				else
					exec(self, unit)
				end
				
			end,
		}),
		PlaceObj('MsgReaction', {
			Event = "UnitEndTurn",
			Handler = function (self, unit)
				local reaction_idx = table.find(self.msg_reactions or empty_table, "Event", "UnitEndTurn")
				if not reaction_idx then return end
				
				local function exec(self, unit)
				if not unit:IsDead() then
					EnvEffectTearGasTick(unit, nil, "end turn")
				end
				end
				local id = GetCharacterEffectId(self)
				
				if id then
					if IsKindOf(unit, "StatusEffectObject") and unit:HasStatusEffect(id) then
						exec(self, unit)
					end
				else
					exec(self, unit)
				end
				
			end,
		}),
	},
	unit_reactions = {
		PlaceObj('UnitReaction', {
			Event = "OnCalcChanceToHit",
			Handler = function (self, target, attacker, action, attack_target, weapon1, weapon2, data)
				if target == attacker then
					local dazed_Cth = {id = "dazed_cth", name = T{"Dazed"}, value = const.EO.DazedCTHPenalty}
					data.modifiers = data.modifiers or {}
					table.insert(data.modifiers, dazed_Cth)
					data.mod_add = data.mod_add + const.EO.DazedCTHPenalty
				end
			end,
		}),
	},
	Modifiers = {},
	DisplayName = T(236964331685, --[[ModItemCharacterEffectCompositeDef dazed_flashbang DisplayName]] "Dazed"),
	Description = T(572612774636, --[[ModItemCharacterEffectCompositeDef dazed_flashbang Description]] "This character has been dazed by a flashbang. Accuracy is dramatically decreased."),
	GetDescription = function (self)
		return self.Description
	end,
	AddEffectText = T(359994604091, --[[ModItemCharacterEffectCompositeDef dazed_flashbang AddEffectText]] "<color EmStyle><DisplayName></color> is dazed"),
	type = "Debuff",
	lifetime = "Until End of Turn",
	Icon = "UI/Hud/Status effects/blinded",
	RemoveOnEndCombat = true,
	RemoveOnSatViewTravel = true,
	RemoveOnCampaignTimeAdvance = true,
	Shown = true,
	HasFloatingText = true,
}

