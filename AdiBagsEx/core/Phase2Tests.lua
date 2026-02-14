--[[
AdiBagsEx Phase 2 Implementation Test
Simple validation test for account bank support and modern binding detection
]]

local addonName = ...
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- Test function to validate Phase 2 implementation
function addon:TestPhase2Implementation()
    print("|cff00ff00AdiBagsEx Phase 2 Test:|r Starting validation...")
    
    local success = true
    local errors = {}
    
    -- Test 1: Verify account bank constants are defined
    if not addon.ACCOUNT_BANK_CONTAINER_1 then
        table.insert(errors, "ACCOUNT_BANK_CONTAINER_1 not defined")
        success = false
    end
    
    if not addon.ACCOUNT_BANK_BAGS then
        table.insert(errors, "ACCOUNT_BANK_BAGS not defined")
        success = false
    else
        -- Test that all 5 account bank tabs are included
        local tabCount = 0
        for bagId in pairs(addon.ACCOUNT_BANK_BAGS) do
            tabCount = tabCount + 1
        end
        if tabCount ~= 5 then
            table.insert(errors, "Expected 5 account bank tabs, found " .. tabCount)
            success = false
        end
    end
    
    -- Test 2: Verify BAG_IDS structure
    if not addon.BAG_IDS or not addon.BAG_IDS.WARBOUNDBANK_ONLY then
        table.insert(errors, "BAG_IDS.WARBOUNDBANK_ONLY not defined")
        success = false
    end
    
    -- Test 3: Verify ModernBinding module
    local modernBinding = addon:GetModule('ModernBinding', true)
    if not modernBinding then
        table.insert(errors, "ModernBinding module not found")
        success = false
    end
    
    -- Test 4: Verify WarbandBank module
    local warbandBank = addon:GetModule('WarbandBank', true)
    if not warbandBank then
        table.insert(errors, "WarbandBank module not found")
        success = false
    elseif not warbandBank.bagIds then
        table.insert(errors, "WarbandBank.bagIds not defined")
        success = false
    end
    
    -- Test 5: Verify account bank detection functions
    if type(addon.IsAccountBankBag) ~= "function" then
        table.insert(errors, "IsAccountBankBag function not defined")
        success = false
    end
    
    -- Report results
    if success then
        print("|cff00ff00AdiBagsEx Phase 2 Test:|r ✅ All tests passed! Phase 2 implementation is ready.")
        print("  - Account bank constants: ✅")
        print("  - ModernBinding module: ✅")
        print("  - WarbandBank integration: ✅")
        print("  - Detection functions: ✅")
        return true
    else
        print("|cffff0000AdiBagsEx Phase 2 Test:|r ❌ Tests failed:")
        for _, error in ipairs(errors) do
            print("  - " .. error)
        end
        return false
    end
end

-- Auto-run test if in debug mode
if addon.debug then
    C_Timer.After(1, function()
        addon:TestPhase2Implementation()
    end)
end