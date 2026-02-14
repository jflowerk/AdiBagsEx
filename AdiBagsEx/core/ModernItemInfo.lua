--[[
AdiBags - Modern Item Information Module
Copyright 2024 (modernization improvements)
Enhanced item information gathering using modern WoW APIs

This module provides modern item information gathering using C_Item APIs
for better performance, async loading, and more reliable data access.
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
local C_Container = _G.C_Container
local C_TooltipInfo = _G.C_TooltipInfo
local Item = _G.Item
local ItemLocation = _G.ItemLocation
local next = _G.next
local pairs = _G.pairs
local select = _G.select
local type = _G.type
--GLOBALS>

--------------------------------------------------------------------------------
-- Modern Item Information Module
--------------------------------------------------------------------------------

---@class ModernItemInfo: AceModule
local modernItemInfo = addon:NewModule('ModernItemInfo')

-- Item data cache for performance
local itemCache = {}
local pendingItems = {}

-- Constants for item information
local ITEM_QUALITY_COLORS = _G.ITEM_QUALITY_COLORS

---@class (exact) ItemData
---@field name string Item name
---@field link string Item link
---@field quality number Item quality (0-6)
---@field iLevel number Item level
---@field reqLevel number Required level
---@field class string Item class name
---@field subclass string Item subclass name
---@field maxStack number Maximum stack size
---@field equipSlot string Equipment slot
---@field texture number Texture ID
---@field vendorPrice number Vendor sell price
---@field classID number Item class ID
---@field subclassID number Item subclass ID
---@field bindType number Binding type
---@field expacID number Expansion ID
---@field setID number Item set ID
---@field isCraftingReagent boolean Is crafting reagent
---@field count number Stack count (for container items)
---@field bagID number Bag ID (for container items)
---@field slotID number Slot ID (for container items)

---Fast synchronous item info using C_Item.GetItemInfoInstant
---@param itemIDOrLink number|string Item ID or item link
---@return string|nil name Item name if available
---@return number|nil quality Item quality if available  
---@return number|nil classID Item class ID if available
---@return number|nil subclassID Item subclass ID if available
function modernItemInfo:GetItemInfoInstant(itemIDOrLink)
	if not itemIDOrLink then return nil end
	
	-- Use C_Item.GetItemInfoInstant for immediate data
	local name, _, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, classID, subclassID = C_Item.GetItemInfoInstant(itemIDOrLink)
	
	return name, quality, classID, subclassID, {
		name = name,
		quality = quality,
		iLevel = iLevel,
		reqLevel = reqLevel,
		class = class,
		subclass = subclass,
		maxStack = maxStack,
		equipSlot = equipSlot,
		texture = texture,
		classID = classID,
		subclassID = subclassID
	}
end

---Enhanced item info with caching and async support
---@param itemIDOrLink number|string Item ID or item link
---@param callback function|nil Optional callback for async loading
---@return ItemData|nil Full item data or nil if not available
function modernItemInfo:GetItemInfo(itemIDOrLink, callback)
	if not itemIDOrLink then return nil end
	
	local cacheKey = tostring(itemIDOrLink)
	
	-- Check cache first
	if itemCache[cacheKey] then
		if callback then callback(itemCache[cacheKey]) end
		return itemCache[cacheKey]
	end
	
	-- Try instant data first
	local name, quality, classID, subclassID, instant = self:GetItemInfoInstant(itemIDOrLink)
	if name and instant then
		-- Get full data from C_Item.GetItemInfo
		local fullName, link, fullQuality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice, fullClassID, fullSubclassID, bindType, expacID, setID, isCraftingReagent = C_Item.GetItemInfo(itemIDOrLink)
		
		if fullName then
			---@type ItemData
			local itemData = {
				name = fullName,
				link = link,
				quality = fullQuality or quality,
				iLevel = iLevel,
				reqLevel = reqLevel,
				class = class,
				subclass = subclass,
				maxStack = maxStack,
				equipSlot = equipSlot,
				texture = texture,
				vendorPrice = vendorPrice,
				classID = fullClassID or classID,
				subclassID = fullSubclassID or subclassID,
				bindType = bindType,
				expacID = expacID,
				setID = setID,
				isCraftingReagent = isCraftingReagent
			}
			
			-- Cache the result
			itemCache[cacheKey] = itemData
			
			if callback then callback(itemData) end
			return itemData
		end
	end
	
	-- If not available, set up async loading
	if callback and not pendingItems[cacheKey] then
		pendingItems[cacheKey] = { callback }
		
		-- Use Item object for async loading
		local item = Item:CreateFromItemID(itemIDOrLink)
		if item and item:IsItemEmpty() then
			item:ContinueOnItemLoad(function()
				self:ProcessPendingItem(cacheKey, itemIDOrLink)
			end)
		else
			-- Item is already loaded, process immediately
			self:ProcessPendingItem(cacheKey, itemIDOrLink)
		end
	elseif callback and pendingItems[cacheKey] then
		-- Add to existing pending callbacks
		table.insert(pendingItems[cacheKey], callback)
	end
	
	return nil
end

---Process a pending item after async loading
---@param cacheKey string Cache key for the item
---@param itemIDOrLink number|string Original item ID or link
function modernItemInfo:ProcessPendingItem(cacheKey, itemIDOrLink)
	-- Try to get full item info now
	local itemData = self:GetItemInfo(itemIDOrLink)
	
	if itemData and pendingItems[cacheKey] then
		-- Call all pending callbacks
		for _, callback in ipairs(pendingItems[cacheKey]) do
			callback(itemData)
		end
		pendingItems[cacheKey] = nil
	end
end

---Get container item information using modern APIs
---@param bagID number Bag ID
---@param slotID number Slot ID
---@return ItemData|nil Item data with container-specific info
function modernItemInfo:GetContainerItemInfo(bagID, slotID)
	if not bagID or not slotID then return nil end
	
	-- Use modern container APIs
	local itemID = C_Container.GetContainerItemID(bagID, slotID)
	local itemLink = C_Container.GetContainerItemLink(bagID, slotID)
	local containerInfo = C_Container.GetContainerItemInfo(bagID, slotID)
	
	if not itemID and not itemLink then return nil end
	
	-- Get base item info
	local itemData = self:GetItemInfo(itemLink or itemID)
	if not itemData then return nil end
	
	-- Add container-specific information
	if containerInfo then
		itemData.count = containerInfo.stackCount or 1
		itemData.quality = containerInfo.quality or itemData.quality
	else
		itemData.count = 1
	end
	
	itemData.bagID = bagID
	itemData.slotID = slotID
	
	-- Create ItemLocation for modern APIs
	if addon.isRetail then
		local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
		if itemLocation and itemLocation:IsValid() then
			itemData.itemLocation = itemLocation
			
			-- Use modern binding detection if available
			if addon.GetModule and addon:GetModule("ModernBinding", true) then
				local bindingModule = addon:GetModule("ModernBinding")
				local bindingInfo = bindingModule:GetItemBinding(itemLocation, itemData.bindType)
				itemData.bindingInfo = bindingInfo
			end
		end
	end
	
	return itemData
end

---Clear item cache (useful for testing or memory management)
function modernItemInfo:ClearCache()
	itemCache = {}
	pendingItems = {}
end

---Get cached item count
---@return number Number of cached items
function modernItemInfo:GetCacheSize()
	local count = 0
	for _ in pairs(itemCache) do
		count = count + 1
	end
	return count
end

-- Provide module reference to addon
addon.ModernItemInfo = modernItemInfo