--[[
AdiBags - Phase 3 Testing Module
Copyright 2024 (modernization improvements)
Testing module for modern item information APIs

This module tests the Phase 3 implementation of modern item information APIs
including C_Item.GetItemInfoInstant, caching, and async loading.
--]]

local addonName, addon = ...

-- Test module for Phase 3 implementation
local Phase3Tests = addon:NewModule('Phase3Tests')

function Phase3Tests:OnEnable()
	-- Use a simple timer instead of event registration for better compatibility
	C_Timer.After(3, function()
		self:RunTests()
	end)
end

function Phase3Tests:RunTests()
	local passed = 0
	local failed = 0
	
	local function test(name, func)
		local success, error = pcall(func)
		if success then
			print("|cff00ff00[Phase3] PASS:|r " .. name)
			passed = passed + 1
		else
			print("|cffff0000[Phase3] FAIL:|r " .. name .. " - " .. tostring(error))
			failed = failed + 1
		end
	end
	
	print("|cff00ffff=== Phase 3: Modern Item Information APIs Test ===|r")
	
	-- Test 1: ModernItemInfo module exists
	test("ModernItemInfo module loaded", function()
		assert(addon.ModernItemInfo, "ModernItemInfo module not found")
		assert(type(addon.ModernItemInfo.GetItemInfoInstant) == "function", "GetItemInfoInstant function not found")
		assert(type(addon.ModernItemInfo.GetItemInfo) == "function", "GetItemInfo function not found")
		assert(type(addon.ModernItemInfo.GetContainerItemInfo) == "function", "GetContainerItemInfo function not found")
	end)
	
	-- Test 2: GetItemInfoInstant works with known items
	test("GetItemInfoInstant functionality", function()
		-- Test with Hearthstone (item ID 6948) - always available
		local name, quality, classID, subclassID, data = addon.ModernItemInfo:GetItemInfoInstant(6948)
		assert(name, "Failed to get Hearthstone name")
		assert(quality ~= nil, "Failed to get Hearthstone quality")
		assert(data and data.name, "Failed to get Hearthstone data structure")
	end)
	
	-- Test 3: GetItemInfo with fallback
	test("GetItemInfo with fallback", function()
		local itemData = addon.ModernItemInfo:GetItemInfo(6948)
		-- Note: May return nil if item not cached, which is expected behavior
		if itemData then
			assert(itemData.name, "ItemData missing name")
			assert(itemData.quality ~= nil, "ItemData missing quality")
			assert(itemData.classID ~= nil, "ItemData missing classID")
		end
	end)
	
	-- Test 4: Cache functionality
	test("Item cache system", function()
		local initialSize = addon.ModernItemInfo:GetCacheSize()
		assert(type(initialSize) == "number", "Cache size should be a number")
		
		addon.ModernItemInfo:ClearCache()
		local clearedSize = addon.ModernItemInfo:GetCacheSize()
		assert(clearedSize == 0, "Cache should be empty after clearing")
	end)
	
	-- Test 5: Container item info (if player has items)
	test("Container item info functionality", function()
		-- Try to get info for backpack slot 1 if it exists
		if addon.isRetail and C_Container then
			local itemID = C_Container.GetContainerItemID(0, 1)
			if itemID then
				local itemData = addon.ModernItemInfo:GetContainerItemInfo(0, 1)
				if itemData then
					assert(itemData.bagID == 0, "Container item should have correct bagID")
					assert(itemData.slotID == 1, "Container item should have correct slotID")
					assert(itemData.count, "Container item should have count")
				end
			end
		end
	end)
	
	-- Test 6: Modern APIs integration
	test("Modern C_Item API integration", function()
		assert(C_Item, "C_Item API not available")
		assert(C_Item.GetItemInfoInstant, "C_Item.GetItemInfoInstant not available")
		assert(C_Item.GetItemInfo, "C_Item.GetItemInfo not available")
		
		if addon.isRetail then
			assert(ItemLocation, "ItemLocation not available in retail")
			assert(ItemLocation.CreateFromBagAndSlot, "ItemLocation.CreateFromBagAndSlot not available")
		end
	end)
	
	-- Test 7: Integration with ModernBinding
	test("ModernBinding integration", function()
		local modernBinding = addon:GetModule("ModernBinding", true)
		if modernBinding then
			assert(type(modernBinding.GetItemBinding) == "function", "ModernBinding.GetItemBinding not found")
		end
		-- Test passes even if ModernBinding not available
	end)
	
	-- Test 8: Performance comparison (basic check)
	test("Performance baseline", function()
		local startTime = debugprofilestop()
		
		-- Run multiple instant item info calls
		for i = 1, 100 do
			addon.ModernItemInfo:GetItemInfoInstant(6948)
		end
		
		local endTime = debugprofilestop()
		local duration = endTime - startTime
		
		-- Should complete reasonably quickly (less than 100ms for 100 calls)
		assert(duration < 100, "Performance test took too long: " .. duration .. "ms")
	end)
	
	-- Summary
	local total = passed + failed
	if failed == 0 then
		print("|cff00ff00[Phase3] All " .. total .. " tests PASSED! Modern Item Info APIs ready.|r")
	else
		print("|cffff0000[Phase3] " .. failed .. " of " .. total .. " tests FAILED. Check implementation.|r")
	end
	
	return failed == 0
end

-- Export for manual testing
addon.Phase3Tests = Phase3Tests