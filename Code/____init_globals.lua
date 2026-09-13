if FirstLoad then
    original_ApplyExplosionDamage = ApplyExplosionDamage
    -------------- Merge and Split IED
    rat_original_InventoryStack_SplitStack = InventoryStack.SplitStack
    rat_original_MoveItem = MoveItem
    rat_original_MergeStackIntoContainer = MergeStackIntoContainer
    rat_original_AddItemsToInventory = AddItemsToInventory
    -------------
    ratG_simple_ied_misfire = true
    -- landmine_original_UpdateTriggerRadiusFx = Landmine.UpdateTriggerRadiusFx
end
