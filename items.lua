return {
	PlaceObj('ModItemCharacterEffectCompositeDef', {
		'Id', "cancel_shot_flashbang",
		'SortKey', 2,
		'object_class', "CharacterEffect",
		'msg_reactions', {
			PlaceObj('MsgReaction', {
				Event = "StatusEffectAdded",
				Handler = function (self, obj, id, stacks)
					local reaction_idx = table.find(self.msg_reactions or empty_table, "Event", "StatusEffectAdded")
					if not reaction_idx then return end
					
					local function exec(self, obj, id, stacks)
					if IsKindOf(obj, "Unit") then
						obj:InterruptPreparedAttack()
						obj:ActivatePerk("MeleeTraining")
						obj:RemoveStatusEffect("BandageInCombat")
						obj:RemoveStatusEffect("CancelShot")
						obj:UpdateMeleeTrainingVisual()
					end
					end
					local _id = GetCharacterEffectId(self)
					if _id == id then exec(self, obj, id, stacks) end
					
				end,
				HandlerCode = function (self, obj, id, stacks)
					if IsKindOf(obj, "Unit") then
						obj:InterruptPreparedAttack()
						obj:ActivatePerk("MeleeTraining")
						obj:RemoveStatusEffect("BandageInCombat")
						obj:RemoveStatusEffect("CancelShot")
						obj:UpdateMeleeTrainingVisual()
					end
				end,
				param_bindings = false,
			}),
		},
		'DisplayName', T(192684063690, --[[ModItemCharacterEffectCompositeDef cancel_shot_flashbang DisplayName]] "Cancel readied attack"),
		'Description', T(335808529700, --[[ModItemCharacterEffectCompositeDef cancel_shot_flashbang Description]] "Removes <color EmStyle>Overwatch</color> and <color EmStyle>Pin Down</color>."),
		'Icon', "UI/Icons/Perks/CancelShotPerk",
	}),
	PlaceObj('ModItemCharacterEffectCompositeDef', {
		'Id', "dazed_flashbang",
		'Parameters', {
			PlaceObj('PresetParamPercent', {
				'Name', "cth_effect",
				'Value', -40,
				'Tag', "<cth_effect>%",
			}),
		},
		'object_class', "CharacterEffect",
		'msg_reactions', {
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
				HandlerCode = function (self, obj, id, stacks)
					if IsKindOf(obj, "Unit") then
						obj:SetEffectValue("blinded_start_time", GameTime())
					
					end
				end,
				param_bindings = false,
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
				HandlerCode = function (self, obj, id, stacks, reason)
					if IsKindOf(obj, "Unit") then
						obj:SetEffectValue("blinded_start_time")
						ObjModified(obj)
					end
				end,
				param_bindings = false,
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
				HandlerCode = function (self, unit)
					if not unit:IsDead() then
						EnvEffectTearGasTick(unit, nil, "start turn")
					end
				end,
				param_bindings = false,
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
				HandlerCode = function (self, unit)
					if not unit:IsDead() then
						EnvEffectTearGasTick(unit, nil, "end turn")
					end
				end,
				param_bindings = false,
			}),
		},
		'unit_reactions', {
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
				param_bindings = false,
			}),
		},
		'Modifiers', {},
		'DisplayName', T(236964331685, --[[ModItemCharacterEffectCompositeDef dazed_flashbang DisplayName]] "Dazed"),
		'Description', T(572612774636, --[[ModItemCharacterEffectCompositeDef dazed_flashbang Description]] "This character has been dazed by a flashbang. Accuracy is dramatically decreased."),
		'GetDescription', function (self)
			return self.Description
		end,
		'AddEffectText', T(359994604091, --[[ModItemCharacterEffectCompositeDef dazed_flashbang AddEffectText]] "<color EmStyle><DisplayName></color> is dazed"),
		'type', "Debuff",
		'lifetime', "Until End of Turn",
		'Icon', "UI/Hud/Status effects/blinded",
		'RemoveOnEndCombat', true,
		'RemoveOnSatViewTravel', true,
		'RemoveOnCampaignTimeAdvance', true,
		'Shown', true,
		'HasFloatingText', true,
	}),
	PlaceObj('ModItemCode', {
		'name', "____init_globals",
		'CodeFileName', "Code/____init_globals.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "__EOParams",
		'CodeFileName', "Code/__EOParams.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "CUAE_Params",
		'CodeFileName', "Code/CUAE_Params.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "SOURCE_CalcBounceParabola_LUA",
		'CodeFileName', "Code/SOURCE_CalcBounceParabola_LUA.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "SOURCE_SectorOperations_CraftCommonBase_Tick",
		'CodeFileName', "Code/SOURCE_SectorOperations_CraftCommonBase_Tick.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "SOURCE_AnimGrenadeTraj",
		'CodeFileName', "Code/SOURCE_AnimGrenadeTraj.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "SOURCE_GrenadeGetAttackResults",
		'CodeFileName', "Code/SOURCE_GrenadeGetAttackResults.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "SOURCE_ApplyExplosionDamage",
		'CodeFileName', "Code/SOURCE_ApplyExplosionDamage.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "SOURCE_HeavyWeaponsGetAttackResults",
		'CodeFileName', "Code/SOURCE_HeavyWeaponsGetAttackResults.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "SOURCE_GrenadeOnLand",
		'CodeFileName', "Code/SOURCE_GrenadeOnLand.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "SOURCE_GrenadeGetTrajectory",
		'CodeFileName', "Code/SOURCE_GrenadeGetTrajectory.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "SOURCE_GetGrenadeBonusDamage",
		'comment', "------ Dmg Option is implemented here",
		'CodeFileName', "Code/SOURCE_GetGrenadeBonusDamage.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "SOURCE_GrenadeCalcTrajectory",
		'CodeFileName', "Code/SOURCE_GrenadeCalcTrajectory.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "SOURCE_CombatActionGrenadeDescription",
		'CodeFileName', "Code/SOURCE_CombatActionGrenadeDescription.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "SOURCE_FormatMishapChance",
		'CodeFileName', "Code/SOURCE_FormatMishapChance.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "SOURCE_SetAPIndicator",
		'CodeFileName', "Code/SOURCE_SetAPIndicator.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "SOURCE_LandmineFunctions",
		'CodeFileName', "Code/SOURCE_LandmineFunctions.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "SOURCE_DynamicSpawnLandmine_GameInit",
		'CodeFileName', "Code/SOURCE_DynamicSpawnLandmine_GameInit.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "SOURCE_MergeAndSplitIED",
		'CodeFileName', "Code/SOURCE_MergeAndSplitIED.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "COMBATACTION_ThrowGrenade",
		'CodeFileName', "Code/COMBATACTION_ThrowGrenade.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "FUNCTIONS_BounceGrenade",
		'CodeFileName', "Code/FUNCTIONS_BounceGrenade.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "FUNCTIONS_Compatibility",
		'CodeFileName', "Code/FUNCTIONS_Compatibility.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "FUNCTIONS_IEDlootRules",
		'CodeFileName', "Code/FUNCTIONS_IEDlootRules.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "FUNCTIONS_DynamicSpawnLandmine_MisfiredIED",
		'CodeFileName', "Code/FUNCTIONS_DynamicSpawnLandmine_MisfiredIED.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "FUNCTIONS_DeviateGrenade",
		'CodeFileName', "Code/FUNCTIONS_DeviateGrenade.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "FUNCTIONS_RatonadeBounceCalcTrajectory",
		'CodeFileName', "Code/FUNCTIONS_RatonadeBounceCalcTrajectory.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "FUNCTIONS_BounceObjMaterialSpeed",
		'CodeFileName', "Code/FUNCTIONS_BounceObjMaterialSpeed.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "FUNCTIONS_processIEDmisfire",
		'CodeFileName', "Code/FUNCTIONS_processIEDmisfire.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "FUNCTIONS_Debug",
		'CodeFileName', "Code/FUNCTIONS_Debug.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "FUNCTIONS_Shrapnel",
		'CodeFileName', "Code/FUNCTIONS_Shrapnel.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "FUNCTIONS_Shrapnel_VectorGenerators",
		'CodeFileName', "Code/FUNCTIONS_Shrapnel_VectorGenerators.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "FUNCTIONS_Util",
		'CodeFileName', "Code/FUNCTIONS_Util.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "FUNCTIONS_processExplosiveHitEffects",
		'CodeFileName', "Code/FUNCTIONS_processExplosiveHitEffects.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "FUNCTIONS_ItemChanges",
		'CodeFileName', "Code/FUNCTIONS_ItemChanges.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "FUNCTIONS_AIAdjustment",
		'CodeFileName', "Code/FUNCTIONS_AIAdjustment.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "FUNCTIONS_AlterExternalItems",
		'CodeFileName', "Code/FUNCTIONS_AlterExternalItems.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "FUNCTIONS_DetermineIEDMisfireChance_Craft",
		'CodeFileName', "Code/FUNCTIONS_DetermineIEDMisfireChance_Craft.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "DESCRIPTION_HINTS",
		'CodeFileName', "Code/DESCRIPTION_HINTS.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "PROPERTIES_Explosives",
		'CodeFileName', "Code/PROPERTIES_Explosives.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "PROPERTIES_Landmine",
		'CodeFileName', "Code/PROPERTIES_Landmine.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "PROPERTIES_Unit",
		'CodeFileName', "Code/PROPERTIES_Unit.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "PROPERTIES_InventoryStack",
		'CodeFileName', "Code/PROPERTIES_InventoryStack.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "PATCH_EO_explosives",
		'CodeFileName', "Code/PATCH_EO_explosives.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "PATCH_call",
		'CodeFileName', "Code/PATCH_call.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "FX_PlaceObj",
		'CodeFileName', "Code/FX_PlaceObj.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "FX_Inherit",
		'CodeFileName', "Code/FX_Inherit.lua",
	}),
	PlaceObj('ModItemCode', {
		'name', "FX_DefineVisualClass",
		'CodeFileName', "Code/FX_DefineVisualClass.lua",
	}),
	PlaceObj('ModItemOptionChoice', {
		'name', "grenade_throw_diff",
		'DisplayName', "Grenade Throw Skill Check Difficulty",
		'Help', "Affects accuracy of thrown grenades. Positive numbers make it harder.",
		'DefaultValue', "Normal (0)",
		'ChoiceList', {
			"-30",
			"Trivial (-25)",
			"-20",
			"-15",
			"Easy (-10)",
			"-5",
			"Normal (0)",
			"5",
			"Hard (10)",
			"15",
			"Very Hard (20)",
			"25",
			"30",
		},
	}),
	PlaceObj('ModItemOptionChoice', {
		'name', "GL_throw_diff",
		'DisplayName', "Grenade Launch Skill Check Difficulty",
		'Help', "Affects accuracy of Grenade Launcher. Positive numbers make it harder.",
		'DefaultValue', "Normal (0)",
		'ChoiceList', {
			"-30",
			"Trivial (-25)",
			"-20",
			"-15",
			"Easy (-10)",
			"-5",
			"Normal (0)",
			"5",
			"Hard (10)",
			"15",
			"Very Hard (20)",
			"25",
			"30",
		},
	}),
	PlaceObj('ModItemOptionChoice', {
		'name', "RPG_throw_diff",
		'DisplayName', "Rocket Launch Skill Check Difficulty",
		'Help', "Affects accuracy of RPG. Positive numbers make it harder.",
		'DefaultValue', "Normal (0)",
		'ChoiceList', {
			"-30",
			"Trivial (-25)",
			"-20",
			"-15",
			"Easy (-10)",
			"-5",
			"Normal (0)",
			"5",
			"Hard (10)",
			"15",
			"Very Hard (20)",
			"25",
			"30",
		},
	}),
	PlaceObj('ModItemOptionChoice', {
		'name', "AI_skill_throw_diff",
		'DisplayName', "AI throw Skill Check Difficulty Modifier",
		'Help', "Affects accuracy of all explosives throw/launch for the AI. This will be applied on top of the other settings. Positive numbers make it harder.",
		'DefaultValue', "Normal (0)",
		'ChoiceList', {
			"-30",
			"Trivial (-25)",
			"-20",
			"-15",
			"Easy (-10)",
			"-5",
			"Normal (0)",
			"5",
			"Hard (10)",
			"15",
			"Very Hard (20)",
			"25",
			"30",
		},
	}),
	PlaceObj('ModItemOptionToggle', {
		'name', "enabled_bounce",
		'DisplayName', "Enabled Grenade Bouncing",
		'Help', "If enabled, grenades will bounce when colliding with walls, the ground or other objects.",
		'DefaultValue', true,
	}),
	PlaceObj('ModItemOptionToggle', {
		'name', "enabled_bounce_pred",
		'DisplayName', "Enabled Bouncing Prediction",
		'Help', "Will show the bouncing trajectory when targeting. Disable this if facing performance issues, or if you want the extra challenge.",
		'DefaultValue', true,
	}),
	PlaceObj('ModItemOptionToggle', {
		'name', "disable_IED_craftRules",
		'DisplayName', "Disable IED only crafting*",
		'Help', "Enable this if you want to be able to craft every explosive. Otherwise, you will be limited to IED explosives only. *Requires restart",
	}),
	PlaceObj('ModItemOptionChoice', {
		'name', "explosive_dmg",
		'DisplayName', "Explosive Damage Mul %",
		'Help', "Multiplies the explosive damage for all explosives",
		'DefaultValue', "100",
		'ChoiceList', {
			"0",
			"10",
			"20",
			"30",
			"40",
			"50",
			"60",
			"70",
			"80",
			"90",
			"100",
			"110",
			"120",
			"130",
			"140",
			"150",
			"160",
			"170",
			"180",
			"190",
			"200",
		},
	}),
	PlaceObj('ModItemOptionChoice', {
		'name', "mifire_chance_mul",
		'DisplayName', "IED Misfire Chance Mul %",
		'Help', "Multiplies the chance of IED mishap. Set to 0 to disable.",
		'DefaultValue', "100",
		'ChoiceList', {
			"0",
			"10",
			"20",
			"30",
			"40",
			"50",
			"60",
			"70",
			"80",
			"90",
			"100",
			"110",
			"120",
			"130",
			"140",
			"150",
			"160",
			"170",
			"180",
			"190",
			"200",
		},
	}),
	PlaceObj('ModItemOptionChoice', {
		'name', "shrap_dmg",
		'DisplayName', "Shrapnel Damage Mul %",
		'Help', "Multiplies the shrapnel damage",
		'DefaultValue', "100",
		'ChoiceList', {
			"0",
			"10",
			"20",
			"30",
			"40",
			"50",
			"60",
			"70",
			"80",
			"90",
			"100",
			"110",
			"120",
			"130",
			"140",
			"150",
			"160",
			"170",
			"180",
			"190",
			"200",
		},
	}),
	PlaceObj('ModItemOptionChoice', {
		'name', "shrap_num",
		'DisplayName', "Shrapnel Number Mul %",
		'Help', "Multiplies the number of shrapnel spawned. Recommended to leave as default, but you can decrease if facing performance issues. Increase the shrap damage by a similar amount if you do this.",
		'DefaultValue', "100",
		'ChoiceList', {
			"0",
			"10",
			"20",
			"30",
			"40",
			"50",
			"60",
			"70",
			"80",
			"90",
			"100",
			"110",
			"120",
			"130",
			"140",
			"150",
			"160",
			"170",
			"180",
			"190",
			"200",
		},
	}),
	PlaceObj('ModItemOptionChoice', {
		'name', "shrap_eff_chance",
		'DisplayName', "Shrapnel Effect Mul %",
		'Help', "Multiplies the chance of shrapnel causing Bleeding or other status effects related to hitting bodypart.",
		'DefaultValue', "100",
		'ChoiceList', {
			"0",
			"10",
			"20",
			"30",
			"40",
			"50",
			"60",
			"70",
			"80",
			"90",
			"100",
			"110",
			"120",
			"130",
			"140",
			"150",
			"160",
			"170",
			"180",
			"190",
			"200",
		},
	}),
	PlaceObj('ModItemOptionChoice', {
		'name', "deviate_stat",
		'DisplayName', "Throw Accuracy Stat",
		'Help', 'The stat that will determine grenade throwing accuracy. If set to "Dexterity/Explosives", will use the average of these attributes.',
		'DefaultValue', "Dexterity/Explosives",
		'ChoiceList', {
			"Dexterity",
			"Explosives",
			"Dexterity/Explosives",
		},
	}),
	PlaceObj('ModItemOptionChoice', {
		'name', "deviate_stat_GL",
		'DisplayName', "Grenade Launch Accuracy Stat",
		'Help', 'The stat that will determine Grenade Launcher throwing accuracy. If set to "Marksmanship/Explosives", will use the average of these attributes.',
		'DefaultValue', "Marksmanship/Explosives",
		'ChoiceList', {
			"Marksmanship",
			"Explosives",
			"Marksmanship/Explosives",
		},
	}),
	PlaceObj('ModItemOptionChoice', {
		'name', "deviate_stat_RPG",
		'DisplayName', "Rocket Launch Accuracy Stat",
		'Help', 'The stat that will determine RPG accuracy. If set to "Strength/Explosives", will use the average of these attributes.',
		'DefaultValue', "Strength/Explosives",
		'ChoiceList', {
			"Strength",
			"Explosives",
			"Strength/Explosives",
		},
	}),
	PlaceObj('ModItemOptionChoice', {
		'name', "extra_proximityExplosive_radius",
		'DisplayName', "Extra activation radius - Proximity Explosive",
		'Help', "This will increase the radius of the proximty explosives activation range. Vanilla is 0.",
		'DefaultValue', "0",
		'ChoiceList', {
			"0",
			"1",
			"2",
			"3",
			"4",
			"5",
		},
	}),
	PlaceObj('ModItemOptionNumber', {
		'name', "ExplosiveNoiseIncrease",
		'DisplayName', "Explosive Noise Increase (%)",
		'Help', "This option will multiply the explosives noise by the selected value. If set to 100, the values will be close to vanilla. EO's Default is 400, which gives a normal frag grenade a range of 70 tiles (vanilla is 20).",
		'DefaultValue', 400,
		'MaxValue', 501,
		'StepSize', 10,
	}),
	PlaceObj('ModItemOptionToggle', {
		'name', "SkipIEDLootChanges",
		'DisplayName', "Disable changing explosives for IEDs (AI)",
		'Help', "Disable the function that changes Legion explosives to IEDs variants, which can cause desyncs in coop games.",
	}),
	PlaceObj('ModItemInventoryItemCompositeDef', {
		'Id', "weapon_shrapnel",
		'object_class', "HeavyWeapon",
		'ScrapParts', 6,
		'RepairCost', 70,
		'Reliability', 50,
		'Caliber', "9mm",
		'DisplayName', T(214207252979, --[[ModItemInventoryItemCompositeDef weapon_shrapnel DisplayName]] "shrap"),
		'DisplayNamePlural', T(163052994957, --[[ModItemInventoryItemCompositeDef weapon_shrapnel DisplayNamePlural]] "shrap"),
		'UnitStat', "Marksmanship",
		'Cost', 500,
		'CategoryPair', "Handguns",
		'CanAppearStandard', false,
		'Damage', 9,
		'ObjDamageMod', 50,
		'AimAccuracy', 1,
		'CritChanceScaled', 0,
		'MagazineSize', 15,
		'WeaponRange', 200,
		'PointBlankBonus', 1,
		'OverwatchAngle', 2160,
		'Noise', 10,
		'HolsterSlot', "Leg",
		'AvailableAttacks', {
			"SingleShot",
			"DualShot",
			"CancelShot",
			"MobileShot",
		},
	}),
	PlaceObj('ModItemFolder', {
		'name', "Entity",
	}, {
		PlaceObj('ModItemEntity', {
			'name', "frag_tnt_misfired",
			'ClassParents', {},
			'entity_name', "frag_tnt_misfired",
		}),
		PlaceObj('ModItemEntity', {
			'name', "fragmentary_tnt",
			'ClassParents', {},
			'entity_name', "fragmentary_tnt",
		}),
		PlaceObj('ModItemEntity', {
			'name', "smoke_can",
			'ClassParents', {},
			'entity_name', "smoke_can",
			'material_type', "Tin_Props",
		}),
		PlaceObj('ModItemEntity', {
			'name', "flash_can",
			'ClassParents', {},
			'entity_name', "flash_can",
		}),
		PlaceObj('ModItemEntity', {
			'name', "tear_can",
			'ClassParents', {},
			'entity_name', "tear_can",
		}),
		PlaceObj('ModItemEntity', {
			'name', "nail_can",
			'ClassParents', {},
			'entity_name', "nail_can",
		}),
		}),
	PlaceObj('ModItemFolder', {
		'name', "Crafting",
	}, {
		PlaceObj('ModItemCraftOperationsRecipeDef', {
			CraftTime = 10,
			Ingredients = {
				PlaceObj('RecipeIngredient', {
					'item', "Parts",
					'amount', 10,
				}),
				PlaceObj('RecipeIngredient', {
					'item', "BlackPowder",
					'amount', 2,
				}),
			},
			ResultItem = PlaceObj('RecipeIngredient', {
				'item', "NailBomb_IED",
				'amount', 5,
			}),
			group = "Explosives",
			id = "CraftNailBombIED",
		}),
		PlaceObj('ModItemCraftOperationsRecipeDef', {
			CraftTime = 15,
			Ingredients = {
				PlaceObj('RecipeIngredient', {
					'item', "Parts",
					'amount', 15,
				}),
				PlaceObj('RecipeIngredient', {
					'item', "TNT",
					'amount', 2,
				}),
			},
			ResultItem = PlaceObj('RecipeIngredient', {
				'item', "HE_Grenade_1",
				'amount', 5,
			}),
			group = "Explosives",
			id = "He_grenade_craft_1",
		}),
		PlaceObj('ModItemCraftOperationsRecipeDef', {
			CraftTime = 8,
			Ingredients = {
				PlaceObj('RecipeIngredient', {
					'item', "Parts",
					'amount', 10,
				}),
				PlaceObj('RecipeIngredient', {
					'item', "TNT",
				}),
			},
			ResultItem = PlaceObj('RecipeIngredient', {
				'item', "TNTBolt_IED",
				'amount', 3,
			}),
			group = "Explosives",
			id = "CraftTNTFragIED",
		}),
		PlaceObj('ModItemCraftOperationsRecipeDef', {
			CraftTime = 10,
			Ingredients = {
				PlaceObj('RecipeIngredient', {
					'item', "Parts",
					'amount', 15,
				}),
				PlaceObj('RecipeIngredient', {
					'item', "BlackPowder",
				}),
			},
			ResultItem = PlaceObj('RecipeIngredient', {
				'item', "IncendiaryGrenade",
				'amount', 5,
			}),
			group = "Explosives",
			id = "CraftIncendiaryGrenade",
		}),
		PlaceObj('ModItemCraftOperationsRecipeDef', {
			CraftTime = 10,
			Ingredients = {
				PlaceObj('RecipeIngredient', {
					'item', "Parts",
					'amount', 10,
				}),
				PlaceObj('RecipeIngredient', {
					'item', "Meds",
					'amount', 5,
				}),
				PlaceObj('RecipeIngredient', {
					'item', "BlackPowder",
				}),
			},
			ResultItem = PlaceObj('RecipeIngredient', {
				'item', "SmokeGrenade_IED",
				'amount', 5,
			}),
			group = "Explosives",
			id = "CraftSmokeIED",
		}),
		PlaceObj('ModItemCraftOperationsRecipeDef', {
			CraftTime = 15,
			Ingredients = {
				PlaceObj('RecipeIngredient', {
					'item', "Parts",
					'amount', 10,
				}),
				PlaceObj('RecipeIngredient', {
					'item', "Meds",
					'amount', 15,
				}),
				PlaceObj('RecipeIngredient', {
					'item', "BlackPowder",
				}),
			},
			ResultItem = PlaceObj('RecipeIngredient', {
				'item', "TearGasGrenade_IED",
				'amount', 5,
			}),
			group = "Explosives",
			id = "CraftTearGasIED",
		}),
		PlaceObj('ModItemCraftOperationsRecipeDef', {
			CraftTime = 10,
			Ingredients = {
				PlaceObj('RecipeIngredient', {
					'item', "Parts",
					'amount', 10,
				}),
				PlaceObj('RecipeIngredient', {
					'item', "BlackPowder",
					'amount', 2,
				}),
			},
			ResultItem = PlaceObj('RecipeIngredient', {
				'item', "ConcussiveGrenade_IED",
				'amount', 5,
			}),
			group = "Explosives",
			id = "CraftFlashbangIED",
		}),
		}),
	PlaceObj('ModItemFolder', {
		'name', "FXs",
	}, {
		PlaceObj('ModItemFolder', {
			'name', "Pipe",
		}, {
			PlaceObj('ModItemActionFXObject', {
				Action = "Spawn",
				Actor = "Pipe_IED",
				Attach = true,
				ColorModifier = 4284769380,
				Delay = 100,
				DetailLevel = 100,
				GameTime = true,
				Moment = "start",
				Object = "Weapon_PipeBomb",
				OffsetDir = "ActionDir",
				group = "Explosion - Grenade - Pipe Bomb VFX",
				handle = "K8Qy_JDY",
				id = "mwoiOav_",
			}),
			}),
		PlaceObj('ModItemFolder', {
			'name', "Cylinder",
		}, {
			PlaceObj('ModItemActionFXObject', {
				Action = "Spawn",
				Actor = "IncendiaryGrenade",
				Attach = true,
				ColorModifier = 4289795598,
				Delay = 100,
				DetailLevel = 100,
				GameTime = true,
				Moment = "start",
				Object = "Weapon_IncendiaryGrenade",
				OffsetDir = "ActionDir",
				group = "Explosion - Grenade - Pipe Bomb VFX",
				handle = "K8Qy_JDY",
				id = "3YQdpAfz",
			}),
			PlaceObj('ModItemActionFXObject', {
				Action = "Spawn",
				Actor = "HE_Grenade_1",
				Attach = true,
				Delay = 100,
				DetailLevel = 100,
				Moment = "start",
				Object = "Weapon_SmokeGrenade",
				Scale = 90,
				group = "Default",
				handle = "K8Qy_JDY",
				id = "K8Qy_JDY",
			}),
			}),
		PlaceObj('ModItemFolder', {
			'name', "Stick",
		}, {
			PlaceObj('ModItemActionFXParticles', {
				Action = "Spawn",
				Actor = "Weapon_TNT_frag_IED",
				Attach = true,
				BehaviorMoment = "end",
				Moment = "start",
				Offset = point(-10, 15, 235),
				OffsetDir = "SpotY",
				Particles = "Weapon_PipeBomb_Fuse",
				Spot = "Particle",
				group = "Default",
				handle = "NzCxQfx-",
				id = "EkRCa1g6",
			}),
			PlaceObj('ModItemActionFXObject', {
				Action = "Spawn",
				Actor = "TNTBolt_IED",
				Attach = true,
				ColorModifier = 3377549392,
				Delay = 100,
				DetailLevel = 100,
				GameTime = true,
				Moment = "start",
				Object = "Weapon_TNT_frag_IED",
				Offset = point(0, 0, -50),
				OffsetDir = "ActionDir",
				Scale = 180,
				group = "Explosion - Grenade - Pipe Bomb VFX",
				handle = "K8Qy_JDY",
				id = "bBo7O2vQ",
			}),
			}),
		PlaceObj('ModItemFolder', {
			'name', "Jar",
		}),
		PlaceObj('ModItemFolder', {
			'name', "Can",
		}, {
			PlaceObj('ModItemActionFXObject', {
				Action = "Spawn",
				Actor = "ConcussiveGrenade_IED",
				Attach = true,
				Delay = 100,
				DetailLevel = 100,
				GameTime = true,
				Moment = "start",
				Object = "Weapon_FlashCanIED",
				OffsetDir = "ActionDir",
				group = "Explosion - Grenade - Pipe Bomb VFX",
				handle = "K8Qy_JDY",
				id = "YmH6IxkH",
			}),
			PlaceObj('ModItemActionFXParticles', {
				Action = "Spawn",
				Actor = "Weapon_CanIED",
				Attach = true,
				BehaviorMoment = "end",
				Moment = "start",
				Offset = point(0, 0, 150),
				OffsetDir = "SpotY",
				Particles = "Weapon_PipeBomb_Fuse",
				Scale = 80,
				Spot = "Particle",
				group = "Default",
				handle = "NzCxQfx-",
				id = "NzCxQfx-",
			}),
			PlaceObj('ModItemActionFXParticles', {
				Action = "Spawn",
				Actor = "Weapon_FlashCanIED",
				Attach = true,
				BehaviorMoment = "end",
				Moment = "start",
				Offset = point(0, 0, 250),
				OffsetDir = "SpotY",
				Particles = "Weapon_PipeBomb_Fuse",
				Scale = 80,
				Spot = "Particle",
				group = "Explosion - Grenade - Pipe Bomb VFX",
				handle = "NzCxQfx-",
				id = "tFubTyTu",
			}),
			PlaceObj('ModItemActionFXParticles', {
				Action = "Spawn",
				Actor = "Weapon_NailCanIED",
				Attach = true,
				BehaviorMoment = "end",
				Moment = "start",
				Offset = point(0, 0, 150),
				OffsetDir = "SpotY",
				Particles = "Weapon_PipeBomb_Fuse",
				Scale = 80,
				Spot = "Particle",
				group = "Explosion - Grenade - Pipe Bomb VFX",
				handle = "NzCxQfx-",
				id = "R-7C51GE",
			}),
			PlaceObj('ModItemActionFXObject', {
				Action = "Spawn",
				Actor = "NailBomb_IED",
				Attach = true,
				ColorModifier = 87308093,
				Delay = 100,
				DetailLevel = 100,
				EditableColor1 = 4281612093,
				EditableColor2 = 4281612093,
				EditableColor3 = 4286742648,
				EditableMetallic3 = 53,
				EditableRoughness1 = 127,
				EditableRoughness2 = 127,
				EditableRoughness3 = 127,
				GameTime = true,
				Moment = "start",
				Object = "Weapon_NailCanIED",
				Offset = point(1, -1, 0),
				OffsetDir = "ActionDir",
				Scale = 120,
				group = "Explosion - Grenade - Pipe Bomb VFX",
				handle = "K8Qy_JDY",
				id = "uvI7IVhL",
			}),
			PlaceObj('ModItemActionFXObject', {
				Action = "Spawn",
				Actor = "SmokeGrenade_IED",
				Attach = true,
				ColorModifier = 87308093,
				Delay = 100,
				DetailLevel = 100,
				EditableColor1 = 4281612093,
				EditableColor2 = 4281612093,
				EditableColor3 = 4286742648,
				EditableMetallic3 = 53,
				EditableRoughness1 = 127,
				EditableRoughness2 = 127,
				EditableRoughness3 = 127,
				GameTime = true,
				Moment = "start",
				Object = "Weapon_SmokeCanIED",
				Offset = point(1, -1, 0),
				OffsetDir = "ActionDir",
				Scale = 125,
				group = "Explosion - Grenade - Pipe Bomb VFX",
				handle = "K8Qy_JDY",
				id = "l0V-TW9J",
			}),
			PlaceObj('ModItemActionFXObject', {
				Action = "Spawn",
				Actor = "TearGasGrenade_IED",
				Attach = true,
				ColorModifier = 87308093,
				Delay = 100,
				DetailLevel = 100,
				EditableColor1 = 4281612093,
				EditableColor2 = 4281612093,
				EditableColor3 = 4286742648,
				EditableMetallic3 = 53,
				EditableRoughness1 = 127,
				EditableRoughness2 = 127,
				EditableRoughness3 = 127,
				GameTime = true,
				Moment = "start",
				Object = "Weapon_TearCanIED",
				Offset = point(1, -1, 0),
				OffsetDir = "ActionDir",
				Scale = 125,
				group = "Explosion - Grenade - Pipe Bomb VFX",
				handle = "K8Qy_JDY",
				id = "Gopwg9SS",
			}),
			}),
		PlaceObj('ModItemFolder', {
			'name', "Misfired_IED",
		}, {
			PlaceObj('ModItemActionFXObject', {
				Action = "Spawn",
				Actor = "NailBomb_IED_Misfired",
				Attach = true,
				ColorModifier = 87308093,
				Delay = 100,
				DetailLevel = 100,
				EditableColor1 = 4281612093,
				EditableColor2 = 4281612093,
				EditableColor3 = 4286742648,
				EditableMetallic3 = 53,
				EditableRoughness1 = 127,
				EditableRoughness2 = 127,
				EditableRoughness3 = 127,
				EndRules = {
					PlaceObj('ActionFXEndRule', {
						'EndAction', "TrapDisarmed",
						'EndMoment', "start",
					}),
				},
				GameTime = true,
				Moment = "start",
				Object = "Weapon_NailCanIED_Misfired",
				Offset = point(0, 0, 50),
				OffsetDir = "OrientByTerrainWithRandomAngle",
				Orientation = "RotateByPresetAngle",
				PresetOrientationAngle = 90,
				Scale = 120,
				behaviors = {
					PlaceObj('ActionFXBehavior', nil),
				},
				group = "Explosion - Grenade - Pipe Bomb VFX",
				handle = "K8Qy_JDY",
				id = "tq7Inev-",
			}),
			PlaceObj('ModItemActionFXObject', {
				Action = "Spawn",
				Actor = "TNTBolt_IED_Misfired",
				Attach = true,
				ColorModifier = 3377549392,
				Delay = 100,
				DetailLevel = 100,
				EditableColor1 = 4281612093,
				EditableColor2 = 4281612093,
				EditableColor3 = 4286742648,
				EditableMetallic3 = 53,
				EditableRoughness1 = 127,
				EditableRoughness2 = 127,
				EditableRoughness3 = 127,
				EndRules = {
					PlaceObj('ActionFXEndRule', {
						'EndAction', "TrapDisarmed",
						'EndMoment', "start",
					}),
				},
				GameTime = true,
				Moment = "start",
				Object = "Weapon_TNT_frag_IED_Misfired",
				Offset = point(0, 0, 50),
				OffsetDir = "OrientByTerrainWithRandomAngle",
				Orientation = "RotateByPresetAngle",
				PresetOrientationAngle = 90,
				Scale = 180,
				behaviors = {
					PlaceObj('ActionFXBehavior', nil),
				},
				group = "Explosion - Grenade - Pipe Bomb VFX",
				handle = "K8Qy_JDY",
				id = "0-jiTofE",
			}),
			PlaceObj('ModItemActionFXObject', {
				Action = "Spawn",
				Actor = "SmokeGrenade_IED_Misfired",
				Attach = true,
				ColorModifier = 87308093,
				Delay = 100,
				DetailLevel = 100,
				EditableColor1 = 4281612093,
				EditableColor2 = 4281612093,
				EditableColor3 = 4286742648,
				EditableMetallic3 = 53,
				EditableRoughness1 = 127,
				EditableRoughness2 = 127,
				EditableRoughness3 = 127,
				EndRules = {
					PlaceObj('ActionFXEndRule', {
						'EndAction', "TrapDisarmed",
						'EndMoment', "start",
					}),
				},
				GameTime = true,
				Moment = "start",
				Object = "Weapon_SmokeCanIED_Misfired",
				Offset = point(0, 0, 50),
				OffsetDir = "OrientByTerrainWithRandomAngle",
				Orientation = "RotateByPresetAngle",
				PresetOrientationAngle = 90,
				Scale = 125,
				behaviors = {
					PlaceObj('ActionFXBehavior', nil),
				},
				group = "Explosion - Grenade - Pipe Bomb VFX",
				handle = "K8Qy_JDY",
				id = "IwSIcixg",
			}),
			PlaceObj('ModItemActionFXObject', {
				Action = "Spawn",
				Actor = "ConcussiveGrenade_IED_Misfired",
				Attach = true,
				ColorModifier = 87308093,
				Delay = 100,
				DetailLevel = 100,
				EditableColor1 = 4281612093,
				EditableColor2 = 4281612093,
				EditableColor3 = 4286742648,
				EditableMetallic3 = 53,
				EditableRoughness1 = 127,
				EditableRoughness2 = 127,
				EditableRoughness3 = 127,
				EndRules = {
					PlaceObj('ActionFXEndRule', {
						'EndAction', "TrapDisarmed",
						'EndMoment', "start",
					}),
				},
				GameTime = true,
				Moment = "start",
				Object = "Weapon_FlashCanIED_Misfired",
				Offset = point(0, 0, 50),
				OffsetDir = "OrientByTerrainWithRandomAngle",
				Orientation = "RotateByPresetAngle",
				PresetOrientationAngle = 90,
				Scale = 125,
				behaviors = {
					PlaceObj('ActionFXBehavior', nil),
				},
				group = "Explosion - Grenade - Pipe Bomb VFX",
				handle = "K8Qy_JDY",
				id = "AcHQN0Ff",
			}),
			PlaceObj('ModItemActionFXObject', {
				Action = "Spawn",
				Actor = "PipeBomb_Misfired",
				Animation = "onground",
				Attach = true,
				Delay = 100,
				DetailLevel = 100,
				EndRules = {
					PlaceObj('ActionFXEndRule', {
						'EndAction', "TrapDisarmed",
						'EndMoment', "start",
					}),
				},
				GameTime = true,
				Moment = "start",
				Object = "Weapon_PipeBomb_Misfired",
				OffsetDir = "",
				behaviors = {
					PlaceObj('ActionFXBehavior', nil),
				},
				group = "Explosion - Grenade - Pipe Bomb VFX",
				handle = "K8Qy_JDY",
				id = "qLAsLR2x",
			}),
			PlaceObj('ModItemActionFXObject', {
				Action = "Spawn",
				Actor = "TearGasGrenade_IED_Misfired",
				Attach = true,
				ColorModifier = 87308093,
				Delay = 100,
				DetailLevel = 100,
				EditableColor1 = 4281612093,
				EditableColor2 = 4281612093,
				EditableColor3 = 4286742648,
				EditableMetallic3 = 53,
				EditableRoughness1 = 127,
				EditableRoughness2 = 127,
				EditableRoughness3 = 127,
				EndRules = {
					PlaceObj('ActionFXEndRule', {
						'EndAction', "TrapDisarmed",
						'EndMoment', "start",
					}),
				},
				GameTime = true,
				Moment = "start",
				Object = "Weapon_TearCanIED_Misfired",
				Offset = point(0, 0, 50),
				OffsetDir = "OrientByTerrainWithRandomAngle",
				Orientation = "RotateByPresetAngle",
				PresetOrientationAngle = 90,
				Scale = 125,
				behaviors = {
					PlaceObj('ActionFXBehavior', nil),
				},
				group = "Explosion - Grenade - Pipe Bomb VFX",
				handle = "K8Qy_JDY",
				id = "bk0RbORD",
			}),
			}),
		PlaceObj('ModItemFolder', {
			'name', "Can_on_ground",
		}, {
			PlaceObj('ModItemActionFXObject', {
				Actor = "SmokeGrenadeSpinner",
				Attach = true,
				Moment = "start",
				Object = "smoke_can",
				Offset = point(0, 0, 50),
				Orientation = "RotateByPresetAngle",
				PresetOrientationAngle = 90,
				Scale = 125,
				Source = "ActorParent",
				group = "Explosion - Grenade - Pipe Bomb VFX",
				handle = "QTMDxdo6",
				id = "QTMDxdo6",
			}),
			}),
		PlaceObj('ModItemActionFXParticles', {
			Action = "Spawn",
			Actor = "Weapon_MolotovCocktail",
			Attach = true,
			BehaviorMoment = "end",
			Flags = "LockedOrientation",
			Moment = "start",
			Particles = "Molotov_Fire1x1",
			PresetOrientationAngle = -1,
			Scale = 9,
			SingleAttach = true,
			Spot = "Particle",
			UseActorColorModifier = true,
			group = "Default",
			handle = "NzCxQfx-",
			id = "ORWlPyss",
		}),
		}),
	PlaceObj('ModItemFolder', {
		'name', "Explosives",
	}, {
		PlaceObj('ModItemFolder', {
			'name', "IEDs",
		}, {
			PlaceObj('ModItemInventoryItemCompositeDef', {
				'Group', "Grenade - Explosive",
				'Id', "TNTBolt_IED",
				'object_class', "Grenade",
				'Repairable', false,
				'Reliability', 100,
				'Icon', "Mod/RATONADE/Images/TNTBOLT7.png",
				'ItemType', "Grenade",
				'DisplayName', T(564860260183, --[[ModItemInventoryItemCompositeDef TNTBolt_IED DisplayName]] "Fragmentary TNT Stick"),
				'DisplayNamePlural', T(735927037683, --[[ModItemInventoryItemCompositeDef TNTBolt_IED DisplayNamePlural]] "Fragmentary TNT Sticks"),
				'AdditionalHint', T(639163114527, --[[ModItemInventoryItemCompositeDef TNTBolt_IED AdditionalHint]] "<EO_description_hints>\n<image UI/Conversation/T_Dialogue_IconBackgroundCircle.tga 400 130 128 120> Explodes immediately"),
				'UnitStat', "Explosives",
				'Cost', 400,
				'CanAppearInShop', true,
				'Tier', 2,
				'CategoryPair', "Grenade",
				'MinMishapChance', -2,
				'MaxMishapChance', 18,
				'MaxMishapRange', 6,
				'CenterUnitDamageMod', 130,
				'CenterObjDamageMod', 500,
				'AreaObjDamageMod', 500,
				'PenetrationClass', 4,
				'DeathType', "BlowUp",
				'Entity', "World_Flarestick_01",
				'ActionIcon', "Mod/RATONADE/Images/tnt_action.png",
				'is_ied', true,
				'r_soft_surface', true,
			}),
			PlaceObj('ModItemInventoryItemCompositeDef', {
				'Group', "Grenade - Explosive",
				'Id', "NailBomb_IED",
				'object_class', "Grenade",
				'Repairable', false,
				'Reliability', 100,
				'Icon', "Mod/RATONADE/Images/nailbomb2 4.png",
				'ItemType', "Grenade",
				'DisplayName', T(439953250262, --[[ModItemInventoryItemCompositeDef NailBomb_IED DisplayName]] "Nail Bomb"),
				'DisplayNamePlural', T(880534339154, --[[ModItemInventoryItemCompositeDef NailBomb_IED DisplayNamePlural]] "Nail Bombs"),
				'AdditionalHint', T(808458367295, --[[ModItemInventoryItemCompositeDef NailBomb_IED AdditionalHint]] "<EO_description_hints>\n<image UI/Conversation/T_Dialogue_IconBackgroundCircle.tga 400 130 128 120> Explodes immediately"),
				'UnitStat', "Explosives",
				'Cost', 400,
				'CanAppearInShop', true,
				'Tier', 2,
				'CategoryPair', "Grenade",
				'MinMishapChance', -2,
				'MaxMishapChance', 18,
				'MaxMishapRange', 6,
				'CenterUnitDamageMod', 130,
				'CenterObjDamageMod', 500,
				'AreaObjDamageMod', 500,
				'PenetrationClass', 4,
				'DeathType', "BlowUp",
				'Entity', "World_Flarestick_01",
				'ActionIcon', "Mod/RATONADE/Images/nail_action.png",
				'is_ied', true,
			}),
			PlaceObj('ModItemInventoryItemCompositeDef', {
				'Group', "Grenade - Throwable",
				'Id', "SmokeGrenade_IED",
				'object_class', "Grenade",
				'Repairable', false,
				'Reliability', 100,
				'Icon', "Mod/RATONADE/Images/smoke_ied.png",
				'ItemType', "Throwables",
				'DisplayName', T(603817580280, --[[ModItemInventoryItemCompositeDef SmokeGrenade_IED DisplayName]] "Improvised Smoke Grenade"),
				'DisplayNamePlural', T(521720469032, --[[ModItemInventoryItemCompositeDef SmokeGrenade_IED DisplayNamePlural]] "Improvised Smoke Grenades"),
				'AdditionalHint', T(953201278809, --[[ModItemInventoryItemCompositeDef SmokeGrenade_IED AdditionalHint]] "<EO_description_hints>\n<image UI/Conversation/T_Dialogue_IconBackgroundCircle.tga 400 130 128 120> Ranged attacks passing through gas become <color EmStyle>grazing</color> hits\n<image UI/Conversation/T_Dialogue_IconBackgroundCircle.tga 400 130 128 120> No damage\n<image UI/Conversation/T_Dialogue_IconBackgroundCircle.tga 400 130 128 120> Almost silent"),
				'UnitStat', "Explosives",
				'Cost', 600,
				'CanAppearInShop', true,
				'Tier', 2,
				'RestockWeight', 25,
				'CategoryPair', "Grenade",
				'MinMishapChance', -2,
				'MaxMishapChance', 18,
				'MinMishapRange', 0,
				'CenterUnitDamageMod', 0,
				'CenterObjDamageMod', 0,
				'AreaUnitDamageMod', 0,
				'AreaObjDamageMod', 0,
				'PenetrationClass', 1,
				'BaseDamage', 0,
				'Scatter', 4,
				'AttackAP', 4000,
				'InaccurateMaxOffset', 3000,
				'Noise', 0,
				'aoeType', "smoke",
				'Entity', "Weapon_SmokeGrenade_Test",
				'ActionIcon', "UI/Icons/Hud/smoke_grenade",
				'r_timer', 3500,
				'r_mass', 610,
				'r_shape', "Cylindrical",
				'is_ied', true,
			}),
			PlaceObj('ModItemInventoryItemCompositeDef', {
				'Group', "Grenade - Explosive",
				'Id', "TearGasGrenade_IED",
				'object_class', "Grenade",
				'Repairable', false,
				'Reliability', 100,
				'Icon', "Mod/RATONADE/Images/TEAR2_ied.png",
				'ItemType', "GrenadeGas",
				'DisplayName', T(992290877366, --[[ModItemInventoryItemCompositeDef TearGasGrenade_IED DisplayName]] "Improvised Tear Gas Grenade"),
				'DisplayNamePlural', T(520192725614, --[[ModItemInventoryItemCompositeDef TearGasGrenade_IED DisplayNamePlural]] "Improvised Tear Gas Grenades"),
				'AdditionalHint', T(468937308243, --[[ModItemInventoryItemCompositeDef TearGasGrenade_IED AdditionalHint]] "<EO_description_hints>\n<image UI/Conversation/T_Dialogue_IconBackgroundCircle.tga 400 130 128 120> Inflicts <color EmStyle>Blinded</color>\n<image UI/Conversation/T_Dialogue_IconBackgroundCircle.tga 400 130 128 120> Ranged attacks passing through gas become <color EmStyle>grazing</color> hits\n<image UI/Conversation/T_Dialogue_IconBackgroundCircle.tga 400 130 128 120> No damage\n<image UI/Conversation/T_Dialogue_IconBackgroundCircle.tga 400 130 128 120> Almost silent"),
				'UnitStat', "Explosives",
				'Cost', 800,
				'CanAppearInShop', true,
				'Tier', 2,
				'RestockWeight', 25,
				'CategoryPair', "Grenade",
				'MinMishapChance', 2,
				'MaxMishapChance', 30,
				'MinMishapRange', 0,
				'CenterUnitDamageMod', 0,
				'CenterObjDamageMod', 0,
				'AreaUnitDamageMod', 0,
				'AreaObjDamageMod', 0,
				'PenetrationClass', 1,
				'BaseDamage', 0,
				'Scatter', 4,
				'AttackAP', 4000,
				'InaccurateMaxOffset', 4000,
				'Noise', 0,
				'aoeType', "teargas",
				'Entity', "Weapon_MolotovCocktail",
				'ActionIcon', "UI/Icons/Hud/tear_gas_grenade",
				'r_timer', 4000,
				'r_mass', 610,
				'r_shape', "Cylindrical",
				'is_ied', true,
			}),
			PlaceObj('ModItemInventoryItemCompositeDef', {
				'Group', "Grenade - Throwable",
				'Id', "ConcussiveGrenade_IED",
				'object_class', "Grenade",
				'Repairable', false,
				'Reliability', 100,
				'Icon', "Mod/RATONADE/Images/flash_ied 3.png",
				'ItemType', "Grenade",
				'DisplayName', T(919480215237, --[[ModItemInventoryItemCompositeDef ConcussiveGrenade_IED DisplayName]] "Improvised Flashbang"),
				'DisplayNamePlural', T(462067699032, --[[ModItemInventoryItemCompositeDef ConcussiveGrenade_IED DisplayNamePlural]] "Improvised Flashbangs"),
				'AdditionalHint', T(261788256938, --[[ModItemInventoryItemCompositeDef ConcussiveGrenade_IED AdditionalHint]] "<EO_description_hints>\n<image UI/Conversation/T_Dialogue_IconBackgroundCircle.tga 400 130 128 120> Causes <color EmStyle>Suppressed</color>\n<image UI/Conversation/T_Dialogue_IconBackgroundCircle.tga 400 130 128 120> Causes <color EmStyle>Dazed</color>\n<image UI/Conversation/T_Dialogue_IconBackgroundCircle.tga 400 130 128 120> Cancel readied attacks\n<image UI/Conversation/T_Dialogue_IconBackgroundCircle.tga 400 130 128 120> Very loud. That's the point of this grenade"),
				'UnitStat', "Explosives",
				'Cost', 800,
				'CanAppearInShop', true,
				'Tier', 2,
				'RestockWeight', 25,
				'CategoryPair', "Grenade",
				'MinMishapChance', -2,
				'MaxMishapChance', 18,
				'MinMishapRange', 0,
				'CenterUnitDamageMod', 0,
				'CenterObjDamageMod', 0,
				'CenterAppliedEffects', {
					"Suppressed",
					"dazed_flashbang",
					"cancel_shot_flashbang",
				},
				'AreaUnitDamageMod', 0,
				'AreaObjDamageMod', 0,
				'AreaAppliedEffects', {
					"cancel_shot_flashbang",
					"Suppressed",
					"dazed_flashbang",
				},
				'PenetrationClass', 1,
				'BurnGround', false,
				'BaseDamage', 0,
				'Scatter', 4,
				'AttackAP', 4000,
				'InaccurateMaxOffset', 4000,
				'Noise', 40,
				'Entity', "Weapon_StunGrenadeM84",
				'ActionIcon', "UI/Icons/Hud/concussive_grenade",
				'r_timer', 3000,
				'r_mass', 370,
				'r_shape', "Cylindrical",
				'is_ied', true,
			}),
			}),
		PlaceObj('ModItemFolder', {
			'name', "New Explosives",
		}, {
			PlaceObj('ModItemInventoryItemCompositeDef', {
				'Group', "Grenade - Throwable",
				'Id', "IncendiaryGrenade",
				'object_class', "Grenade",
				'Repairable', false,
				'Reliability', 100,
				'Icon', "Mod/RATONADE/Images/incendiary2.png",
				'ItemType', "GrenadeFire",
				'DisplayName', T(690193619979, --[[ModItemInventoryItemCompositeDef IncendiaryGrenade DisplayName]] "Incendiary Grenade"),
				'DisplayNamePlural', T(169272979158, --[[ModItemInventoryItemCompositeDef IncendiaryGrenade DisplayNamePlural]] "Incendiary Grenades"),
				'AdditionalHint', T(622520137835, --[[ModItemInventoryItemCompositeDef IncendiaryGrenade AdditionalHint]] "<EO_description_hints>\n<image UI/Conversation/T_Dialogue_IconBackgroundCircle.tga 400 130 128 120> Sets an area on fire and inflicts <color EmStyle>Burning</color>\n"),
				'UnitStat', "Explosives",
				'Cost', 300,
				'CanAppearInShop', true,
				'RestockWeight', 50,
				'CategoryPair', "Grenade",
				'MinMishapChance', 2,
				'MaxMishapChance', 30,
				'MinMishapRange', 0,
				'CenterUnitDamageMod', 0,
				'CenterObjDamageMod', 0,
				'CenterAppliedEffects', {
					"Burning",
				},
				'AreaOfEffect', 4,
				'AreaUnitDamageMod', 0,
				'AreaObjDamageMod', 0,
				'AreaAppliedEffects', {
					"Burning",
				},
				'PenetrationClass', 1,
				'BaseDamage', 0,
				'Scatter', 4,
				'AttackAP', 4000,
				'InaccurateMaxOffset', 4000,
				'Noise', 0,
				'aoeType', "fire",
				'Entity', "Weapon_MolotovCocktail",
				'ActionIcon', "Mod/RATONADE/Images/ge_cilinder_grenade_FIRE.png",
				'r_mass', 400,
				'r_shape', "Cylindrical",
			}),
			PlaceObj('ModItemInventoryItemCompositeDef', {
				'Group', "Grenade - Explosive",
				'Id', "HE_Grenade_1",
				'object_class', "Grenade",
				'Repairable', false,
				'Reliability', 100,
				'Icon', "Mod/RATONADE/Images/he2 4.png",
				'ItemType', "Grenade",
				'DisplayName', T(863833209471, --[[ModItemInventoryItemCompositeDef HE_Grenade_1 DisplayName]] "High Explosive Grenade"),
				'DisplayNamePlural', T(493053531072, --[[ModItemInventoryItemCompositeDef HE_Grenade_1 DisplayNamePlural]] "High Explosive Grenades"),
				'Description', T(868146148463, --[[ModItemInventoryItemCompositeDef HE_Grenade_1 Description]] "<image UI/Conversation/T_Dialogue_IconBackgroundCircle.tga 400 130 128 120>Inflicts <color EmStyle>Bleeding</color>"),
				'AdditionalHint', T(928260625708, --[[ModItemInventoryItemCompositeDef HE_Grenade_1 AdditionalHint]] "<EO_description_hints>\n<image UI/Conversation/T_Dialogue_IconBackgroundCircle.tga 400 130 128 120> Knocks down units \n<image UI/Conversation/T_Dialogue_IconBackgroundCircle.tga 400 130 128 120> Good at destroying objects\n<image UI/Conversation/T_Dialogue_IconBackgroundCircle.tga 400 130 128 120> Penetrates any armor"),
				'UnitStat', "Explosives",
				'Cost', 400,
				'CanAppearInShop', true,
				'Tier', 2,
				'CategoryPair', "Grenade",
				'MinMishapChance', -2,
				'MaxMishapChance', 18,
				'MinMishapRange', 0,
				'CenterUnitDamageMod', 130,
				'CenterObjDamageMod', 500,
				'CenterAppliedEffects', {
					"KnockDown",
				},
				'AreaObjDamageMod', 500,
				'AreaAppliedEffects', {
					"KnockDown",
				},
				'BurnGround', false,
				'DeathType', "BlowUp",
				'BaseDamage', 35,
				'Scatter', 4,
				'BaseRange', 7,
				'ThrowMaxRange', 17,
				'InaccurateMaxOffset', 3000,
				'Noise', 30,
				'Entity', "MilitaryCamp_Grenade_02",
				'ActionIcon', "Mod/RATONADE/Images/ge_cilinder_grenade2.png",
				'r_mass', 600,
				'r_shape', "Cylindrical",
				'r_shrap_num', 500,
			}),
			}),
		}),
}