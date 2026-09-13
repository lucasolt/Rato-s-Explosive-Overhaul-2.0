if FirstLoad then
    original_ApplyExplosionDamage = ApplyExplosionDamage
    -------------- Merge and Split IED
    rat_original_InventoryStack_SplitStack = InventoryStack.SplitStack
    rat_original_MoveItem = MoveItem
    rat_original_MergeStackIntoContainer = MergeStackIntoContainer
    rat_original_AddItemsToInventory = AddItemsToInventory
    -------------
    ratG_simple_ied_misfire = true
    -- deterministic FX rule ids (see FX_PlaceObj.lua); kept across mod reloads
    rat_fx_id_counter = 0
    -- landmine_original_UpdateTriggerRadiusFx = Landmine.UpdateTriggerRadiusFx
end
