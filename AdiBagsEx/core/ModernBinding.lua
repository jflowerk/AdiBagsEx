--[[
AdiBags - Modern Binding Detection Module
Copyright 2024 (modernization improvements)
Enhanced binding detection using modern WoW APIs

This module provides advanced item binding detection using modern WoW APIs
including support for warbound items, account binding, and improved detection
of various binding states.
--]]

local addonName, addon = ...

-- Fail-safe early return if core components aren't ready
if not addon or not addon.L then
	return
end

local L = addon.L

--<GLOBALS
local _G = _G
local C_Item = _G.C_Item
local C_Bank = _G.C_Bank
local C_Container = _G.C_Container
local Item = _G.Item
local Enum = _G.Enum
--GLOBALS>

--------------------------------------------------------------------------------
-- Modern Binding Detection Module
--------------------------------------------------------------------------------

---@class ModernBinding: AceModule
local modernBinding = addon:NewModule('ModernBinding')

---@class (exact) BindingInfo
---@field binding number BindingScope enum value
---@field bound boolean True if the item is bound to the player
---@field displayName string Human-readable binding name for UI

---@param itemLocation ItemLocationMixin|table
---@param bindType number|nil Enum.ItemBind value from GetItemInfo
---@return BindingInfo
function modernBinding:GetItemBinding(itemLocation, bindType)
	---@type BindingInfo
	local bindingInfo = {
		binding = Enum.BindingScope.UNKNOWN,
		bound = false,
		displayName = ""
	}

	-- Ensure we have a valid item location
	if not itemLocation then
		return bindingInfo
	end

	-- Get bag and slot information
	local bagID, slotID
	if type(itemLocation.GetBagAndSlot) == "function" then
		bagID, slotID = itemLocation:GetBagAndSlot()
	elseif type(itemLocation) == "table" and itemLocation.bagID and itemLocation.slotID then
		-- Handle simple table format
		bagID, slotID = itemLocation.bagID, itemLocation.slotID
	else
		return bindingInfo
	end

	local equipSlotIndex
	if type(itemLocation.GetEquipmentSlot) == "function" then
		equipSlotIndex = itemLocation:GetEquipmentSlot()
	end
	
	local isEquipped = false
	if type(itemLocation.IsEquipmentSlot) == "function" then
		isEquipped = itemLocation:IsEquipmentSlot() or false
	end

	-- Check if item is bound using modern API
	local isBound = false
	if C_Item and C_Item.IsBound then
		isBound = C_Item.IsBound(itemLocation)
	end

	if not isBound then
		-- Item is not bound, check the bind type for future binding
		if bindType == Enum.ItemBindType.LE_ITEM_BIND_NONE or bindType == 0 then
			bindingInfo.binding = Enum.BindingScope.NONBINDING
			bindingInfo.displayName = L["No Binding"] or "No Binding"
		elseif bindType == Enum.ItemBindType.LE_ITEM_BIND_ON_EQUIP or bindType == 2 then
			bindingInfo.binding = Enum.BindingScope.BOE
			bindingInfo.displayName = L["Bind on Equip"] or "Bind on Equip"
		elseif bindType == Enum.ItemBindType.LE_ITEM_BIND_ON_USE or bindType == 3 then
			bindingInfo.binding = Enum.BindingScope.BOU
			bindingInfo.displayName = L["Bind on Use"] or "Bind on Use"
		elseif bindType == Enum.ItemBindType.LE_ITEM_BIND_TO_BNETACCOUNT or bindType == 5 then
			-- This is for items like Hoard of Draconic Delicacies
			bindingInfo.binding = Enum.BindingScope.BNET
			bindingInfo.displayName = L["Battle.net Account Bound"] or "Battle.net Account Bound"
		end

		-- Check for Warbound until Equip (retail only)
		if addon.isRetail and C_Item.IsBoundToAccountUntilEquip then
			if C_Item.IsBoundToAccountUntilEquip(itemLocation) then
				bindingInfo.bound = true
				bindingInfo.binding = Enum.BindingScope.WUE
				bindingInfo.displayName = L["Warbound"] or "Warbound"
			end
		end
	else
		-- Item is bound
		bindingInfo.bound = true
		bindingInfo.binding = Enum.BindingScope.BOUND -- Default to generic "bound"
		bindingInfo.displayName = L["Bound"] or "Bound"

		-- Try to determine specific binding type for bound items
		-- Check if it's warbound (account bound) using retail APIs
		if addon.isRetail and C_Bank and C_Bank.IsItemAllowedInBankType then
			-- First check for soulbound (not allowed in account bank)
			if not C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, itemLocation) then
				bindingInfo.binding = Enum.BindingScope.SOULBOUND
				bindingInfo.displayName = L["Soulbound"] or "Soulbound"
			else
				-- Item is allowed in account bank, so it's warbound
				bindingInfo.binding = Enum.BindingScope.ACCOUNT
				bindingInfo.displayName = L["Warbound"] or "Warbound"
			end
		end

		-- Check for refundable items
		if C_Container and C_Container.GetContainerItemPurchaseInfo then
			if C_Container.GetContainerItemPurchaseInfo(bagID or 0, slotID or equipSlotIndex, isEquipped) then
				bindingInfo.binding = Enum.BindingScope.REFUNDABLE
				bindingInfo.displayName = L["Refundable"] or "Refundable"
			end
		end

		-- Check for quest items
		if bindType == Enum.ItemBindType.LE_ITEM_BIND_QUEST or bindType == 4 then
			bindingInfo.binding = Enum.BindingScope.QUEST
			bindingInfo.displayName = L["Quest Item"] or "Quest Item"
		end
	end

	return bindingInfo
end

---@param bagID number
---@param slotID number
---@param bindType number|nil Optional bindType from GetItemInfo
---@return BindingInfo
function modernBinding:GetItemBindingFromBagSlot(bagID, slotID, bindType)
	-- Create ItemLocation-like object
	local itemLocation = {
		bagID = bagID,
		slotID = slotID,
		GetBagAndSlot = function(self) return self.bagID, self.slotID end,
		IsEquipmentSlot = function() return false end,
		GetEquipmentSlot = function() return nil end
	}

	-- If we have modern Item API, use it for better compatibility
	if Item and Item.CreateFromBagAndSlot then
		local itemMixin = Item:CreateFromBagAndSlot(bagID, slotID)
		if itemMixin and itemMixin.GetItemLocation then
			local realItemLocation = itemMixin:GetItemLocation()
			if realItemLocation then
				return self:GetItemBinding(realItemLocation, bindType)
			end
		end
	end

	-- Fallback to our simple implementation
	return self:GetItemBinding(itemLocation, bindType)
end

-- Modern Bank API Support (Phase 2 enhancement)
---@param bagID number
---@return boolean
function modernBinding:IsItemAllowedInAccountBank(bagID, slotID)
	if not C_Bank or not C_Bank.IsItemAllowedInBankType then
		return false -- API not available
	end
	
	-- Create item location
	local itemLocation
	if Item and Item.CreateFromBagAndSlot then
		local itemMixin = Item:CreateFromBagAndSlot(bagID, slotID)
		if itemMixin and itemMixin.GetItemLocation then
			itemLocation = itemMixin:GetItemLocation()
		end
	end
	
	if not itemLocation then
		return false
	end
	
	-- Check if item is allowed in account bank
	return C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, itemLocation)
end

---@param bagID number
---@param slotID number  
---@return boolean
function modernBinding:IsItemBoundToAccount(bagID, slotID)
	if not addon.isRetail then
		return false -- Only available in retail
	end
	
	-- First check if it's allowed in account bank (more accurate)
	if self:IsItemAllowedInAccountBank(bagID, slotID) then
		return true
	end
	
	-- Fallback to binding detection
	local bindingInfo = self:GetItemBindingFromBagSlot(bagID, slotID)
	return bindingInfo.binding == Enum.BindingScope.ACCOUNT or 
	       bindingInfo.binding == Enum.BindingScope.WUE
end

---@param bagID number
---@return boolean
function modernBinding:IsBagAccountBank(bagID)
	return addon:IsAccountBankBag(bagID)
end

---@param bagID number
---@return string
function modernBinding:GetBagTypeName(bagID)
	if addon:IsAccountBankBag(bagID) then
		return "Warbank"
	elseif addon:IsRegularBankBag(bagID) then
		return "Bank"
	elseif addon:IsBackpackBag(bagID) then
		return "Backpack"
	else
		return "Unknown"
	end
end

function modernBinding:OnEnable()
	addon:Debug('ModernBinding', 'Modern binding detection enabled')
end

-- Add localization strings for binding types
if not L["No Binding"] then L["No Binding"] = true end
if not L["Bind on Use"] then L["Bind on Use"] = true end
if not L["Battle.net Account Bound"] then L["Battle.net Account Bound"] = true end
if not L["Bound"] then L["Bound"] = true end
if not L["Soulbound"] then L["Soulbound"] = true end
if not L["Refundable"] then L["Refundable"] = true end
if not L["Quest Item"] then L["Quest Item"] = true end