if not ratG_simple_ied_misfire then
	print("RATONADE - Changing Inventory Split and Merge functions")
	function AddItemsToInventory(inventoryObj, items, bLog)
		print("AddItemsToInventory")
		for i = #items, 1, -1 do
			local item = items[i]

			if IsKindOf(item, "InventoryStack") and item.is_ied then
				print("RATONADE - APPLYING IED MERGE ____ from AddItemsToInventory")

				local item_amount = item.Amount
				local item_table = item.ied_quality_stack or {}

				inventoryObj:ForEachItemDef(item.class, function(curitm, slot_name, item_left, item_top)
					if slot_name ~= "Inventory" then
						return
					end

					if curitm.Amount < curitm.MaxStacks then

						local to_add = Min(curitm.MaxStacks - curitm.Amount, item_amount)

						item_amount = item_amount - to_add

						local curitem_table = curitm.ied_quality_stack or {}

						for i = 1, to_add do
							if item_table[i] then
								table.insert(curitem_table, item_table[i])
							end
						end
						local new_item_table = {}
						for i = to_add + 1, #item_table do
							if item_table[i] then
								table.insert(new_item_table, item_table[i])
							end
						end

						item_table = new_item_table
						curitm.ied_quality_stack = curitem_table
						ObjModified(curitm)
						if item_amount <= 0 then
							return "break"
						end
					end
				end)
				item.ied_quality_stack = item_table
				ObjModified(item)
			end
		end
		return rat_original_AddItemsToInventory(inventoryObj, items, bLog)
	end

	function MoveItem(args)
		print("MoveItem")
		local item = args.item
		--[[ 	local sync_call = args.sync_call
	print("sync call", args.sync_call) ]]
		if item.is_ied then

			local dest_x = args.dest_x or args.x
			local dest_y = args.dest_y or args.y
			local s_item_at_dest = args.s_item_at_dest
			--
			local sync_call = args.sync_call
			local s_sync_unit = args.s_sync_unit
			--
			local amount = args.amount
			local dest_container = args.dest_container
			local dest_container_slot_name = args.dest_container_slot_name or args.dest_slot
			local item_at_dest = dest_x and dest_container:GetItemInSlot(dest_container_slot_name, nil, dest_x, dest_y)
			if item_at_dest == item then
				item_at_dest = false
			end
			local item_is_stack = IsKindOf(item, "InventoryStack")
			local item_table, dest_item_table, item_num, dest_item_num

			---
			if dest_container == "drop" then
				dest_container_slot_name = "Inventory"
				if sync_call then
					dest_container = GetDropContainer(s_sync_unit, false, item)
				else
					dest_container = PlaceObject("LocalDropContainer")
				end
			elseif type(dest_container) == "number" then -- unopenned squad bag, this being the squad id
				dest_container = PlaceObject("UnopennedSquadBag", {
					squad_id = dest_container,
				})
			end
			---

			if item_at_dest then
				local merging = item_is_stack and item.class == item_at_dest.class and item_at_dest.Amount < item_at_dest.MaxStacks
				if merging then
					print("RATONADE - APPLYING IED MERGE ____ from MoveItem")
					local to_add = Min(item_at_dest.MaxStacks - item_at_dest.Amount, item.Amount, amount or max_int)

					item_table = item.ied_quality_stack or {}
					dest_item_table = item_at_dest.ied_quality_stack or {}

					item_num = item.Amount
					dest_item_num = item_at_dest.Amount

					local new_tabuao = table.copy(item.ied_quality_stack)
					for i, v in ipairs(item_at_dest.ied_quality_stack) do
						table.insert(new_tabuao, v)
					end
					local item_at_dest_new_amount = item_at_dest.Amount + to_add
					local item_new_amount = item.Amount - to_add
					local new_item_at_dest_table = {}
					local new_item_table = {}
					for i = 1, item_at_dest_new_amount do
						if new_tabuao[i] then
							table.insert(new_item_at_dest_table, new_tabuao[i])
						end
					end

					for i = item_at_dest_new_amount + 1, #new_tabuao do
						if new_tabuao[i] then
							table.insert(new_item_table, new_tabuao[i])
						end
					end

					item_at_dest.ied_quality_stack = new_item_at_dest_table
					item.ied_quality_stack = new_item_table
					ObjModified(item)
					ObjModified(item_at_dest)
				end
			end
		end

		rat_original_MoveItem(args)

		if item.is_ied and Platform.developer then
			print("-------after move")
			print(item.ied_quality_stack, "n", #(item.ied_quality_stack), "item amnt", item.Amount)
		end
	end

	function MergeStackIntoContainer(dest_container, dest_slot, item, check, up_to_amount, local_changes)
		print("MergeStackIntoContainer")

		local original_loc_changes = local_changes
		if not check and item.is_ied then
			local function get_local_changes(i)
				return local_changes and local_changes[i] or 0
			end

			local a = Min(item.Amount, up_to_amount)
			----
			local item_table = item.ied_quality_stack or {}
			----
			local cls = item.class
			local other_stack_items = {}
			dest_container:ForEachItemInSlot(dest_slot, false,
			                                 function(item_at_dest) -- this loops in reverse, so in order to fill stacks in a nice way its 2ON
				if item_at_dest.class == cls then
					table.insert(other_stack_items, item_at_dest)
				end
			end)

			table.sort(other_stack_items, function(a, b)
				local a_a = a.Amount + get_local_changes(a)
				local b_a = b.Amount + get_local_changes(b)
				return a_a > b_a
			end)

			for _, item_at_dest in ipairs(other_stack_items) do
				print("RATONADE - APPLYING IED MERGE ____ from MergeStackIntoContainer")

				local item_at_dest_table = item_at_dest.ied_quality_stack or {}

				local to_add = item_at_dest.MaxStacks - (item_at_dest.Amount + get_local_changes(item_at_dest))
				to_add = Min(to_add, a)
				if to_add > 0 then
					a = a - to_add
					if not check then
						for i = 1, to_add do
							if item_table[i] then
								table.insert(item_at_dest_table, item_table[i])
							end
						end
						local new_item_table = {}
						for i = to_add + 1, #item_table do
							if item_table[i] then
								table.insert(new_item_table, item_table[i])
							end
						end
						item_table = new_item_table
						item_at_dest.ied_quality_stack = item_at_dest_table
						ObjModified(item_at_dest)
					end
					if a <= 0 then
						break
					end
				end
			end
			item.ied_quality_stack = item_table
			ObjModified(item)
		end
		rat_original_MergeStackIntoContainer(dest_container, dest_slot, item, check, up_to_amount, original_loc_changes)
	end

	function InventoryStack:SplitStack(newStackAmount, splitIfEqual)
		if self.is_ied then
			print("RATONADE - APPLYING IED SPLIT ____ from InventoryStack:SplitStack")
			local old_stack_table = table.copy(self.ied_quality_stack)
			local newItem = rat_original_InventoryStack_SplitStack(self, newStackAmount, splitIfEqual) -- self:original_SplitStack(newStackAmount, splitIfEqual)

			local new_stack_amount = newItem.Amount
			local splited_stack_amount = self.Amount

			local old_stack_contents = {}
			local new_stack_contents = {}

			for i = 1, new_stack_amount do
				if old_stack_table[i] then
					table.insert(new_stack_contents, old_stack_table[i])
				end
			end

			for i = 1 + new_stack_amount, #old_stack_table do
				if old_stack_table[i] then
					table.insert(old_stack_contents, old_stack_table[i])
				end
			end

			self.ied_quality_stack = old_stack_contents
			newItem.ied_quality_stack = new_stack_contents
			ObjModified(self)
			-- ObjModified(newItem)
			return newItem
		end

		return rat_original_InventoryStack_SplitStack(self, newStackAmount, splitIfEqual)
	end

end
