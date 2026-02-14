--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2021 Adirelle (adirelle@gmail.com)
All rights reserved.

This file is part of AdiBags.

AdiBags is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

AdiBags is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with AdiBags.  If not, see <http://www.gnu.org/licenses/>.
--]]

local addonName = ...
---@class AdiBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)
local L = addon.L

-- Constants for detecting WoW version.
addon.isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
addon.isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
addon.isBCC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
addon.isWrath = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC
addon.isCata = WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC
addon.isMop = WOW_PROJECT_ID == (_G.WOW_PROJECT_MISTS_OF_PANDARIA_CLASSIC or 14)

--<GLOBALS
local _G = _G
local BACKPACK_CONTAINER = _G.BACKPACK_CONTAINER or ( Enum.BagIndex and Enum.BagIndex.Backpack ) or 0
-- MoP Classic has a bug where Enum.BagIndex.REAGENTBAG_CONTAINER=5 is defined even though MoP doesn't have reagent bags
-- This causes the enum value to be shifted. Exclude it for MoP Classic.
local REAGENTBAG_CONTAINER = ( not addon.isMop and Enum.BagIndex and Enum.BagIndex.REAGENTBAG_CONTAINER ) or 5
local BANK_CONTAINER = _G.BANK_CONTAINER or ( Enum.BagIndex and Enum.BagIndex.Bank ) or -1
local REAGENTBANK_CONTAINER = _G.REAGENTBANK_CONTAINER or ( Enum.BagIndex and Enum.BagIndex.Reagentbank ) or -3
-- Warbound Bank containers (added in WoW 11.0 - The War Within)
-- Using fallback values since enum names may vary between versions
local WARBOUND_BANK_CONTAINER_1 = ( Enum.BagIndex and Enum.BagIndex.AccountBankTab_1 ) or ( Enum.BagIndex and Enum.BagIndex.Warband1 ) or -5
local WARBOUND_BANK_CONTAINER_2 = ( Enum.BagIndex and Enum.BagIndex.AccountBankTab_2 ) or ( Enum.BagIndex and Enum.BagIndex.Warband2 ) or -6
local WARBOUND_BANK_CONTAINER_3 = ( Enum.BagIndex and Enum.BagIndex.AccountBankTab_3 ) or ( Enum.BagIndex and Enum.BagIndex.Warband3 ) or -7
local WARBOUND_BANK_CONTAINER_4 = ( Enum.BagIndex and Enum.BagIndex.AccountBankTab_4 ) or ( Enum.BagIndex and Enum.BagIndex.Warband4 ) or -8
local WARBOUND_BANK_CONTAINER_5 = ( Enum.BagIndex and Enum.BagIndex.AccountBankTab_5 ) or ( Enum.BagIndex and Enum.BagIndex.Warband5 ) or -9

-- Export account bank constants to addon namespace
addon.ACCOUNT_BANK_CONTAINER_1 = WARBOUND_BANK_CONTAINER_1
addon.ACCOUNT_BANK_CONTAINER_2 = WARBOUND_BANK_CONTAINER_2  
addon.ACCOUNT_BANK_CONTAINER_3 = WARBOUND_BANK_CONTAINER_3
addon.ACCOUNT_BANK_CONTAINER_4 = WARBOUND_BANK_CONTAINER_4
addon.ACCOUNT_BANK_CONTAINER_5 = WARBOUND_BANK_CONTAINER_5

-- Export other bag constants needed by modules
addon.BANK_CONTAINER = BANK_CONTAINER
addon.REAGENTBANK_CONTAINER = REAGENTBANK_CONTAINER
local NUM_BAG_SLOTS = _G.NUM_BAG_SLOTS or 4
local NUM_REAGENTBAG_SLOTS = _G.NUM_REAGENTBAG_SLOTS or 1
local NUM_TOTAL_EQUIPPED_BAG_SLOTS = _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4
local NUM_BANKBAGSLOTS = _G.NUM_BANKBAGSLOTS or 7
local TRADE_GOODS = _G.Enum.ItemClass.Tradegoods
local GetItemSubClassInfo = _G.C_Item.GetItemSubClassInfo
local pairs = _G.pairs
--GLOBALS>

-- Backpack and bags
local BAGS = { [BACKPACK_CONTAINER] = BACKPACK_CONTAINER }
local BANK = {}
local BANK_ONLY = {}
local REAGENTBANK_ONLY = {}
local ALL = {}

local BANK = {}
local BANK_ONLY = {}
local REAGENTBANK_ONLY = {}

if addon.isRetail then

	-- Bags
	for i = 1, NUM_TOTAL_EQUIPPED_BAG_SLOTS do BAGS[i] = i end

	-- Base bank bags
	BANK_ONLY = { [BANK_CONTAINER] = BANK_CONTAINER }
	for i = NUM_TOTAL_EQUIPPED_BAG_SLOTS + 1, NUM_TOTAL_EQUIPPED_BAG_SLOTS + NUM_BANKBAGSLOTS do BANK_ONLY[i] = i end

	--- Reagent bank bags (disabled in WoW 11.2.0+)
	local interfaceVersion = select(4, GetBuildInfo())
	if interfaceVersion < 110200 then
		REAGENTBANK_ONLY = { [REAGENTBANK_CONTAINER] = REAGENTBANK_CONTAINER }
	else
		REAGENTBANK_ONLY = {} -- Empty table for 11.2.0+
	end

	--- Warbound bank bags (added in WoW 11.0 - The War Within)
	WARBOUNDBANK_ONLY = {}
	if addon.isRetail and interfaceVersion >= 110000 then
		WARBOUNDBANK_ONLY = {
			[WARBOUND_BANK_CONTAINER_1] = WARBOUND_BANK_CONTAINER_1,
			[WARBOUND_BANK_CONTAINER_2] = WARBOUND_BANK_CONTAINER_2,
			[WARBOUND_BANK_CONTAINER_3] = WARBOUND_BANK_CONTAINER_3,
			[WARBOUND_BANK_CONTAINER_4] = WARBOUND_BANK_CONTAINER_4,
			[WARBOUND_BANK_CONTAINER_5] = WARBOUND_BANK_CONTAINER_5,
		}
	end

	-- All bank bags
	for _, bags in ipairs { BANK_ONLY, REAGENTBANK_ONLY, WARBOUNDBANK_ONLY } do
		for id in pairs(bags) do BANK[id] = id end
	end
else
	for i = 1, NUM_BAG_SLOTS do BAGS[i] = i end
	
	-- Bank bags for classic versions
	BANK = { [BANK_CONTAINER] = BANK_CONTAINER }
	BANK_ONLY = { [BANK_CONTAINER] = BANK_CONTAINER }
	for i = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do 
		BANK[i] = i 
		BANK_ONLY[i] = i
	end
	
	-- No reagent bank or warbound bank in classic versions
	REAGENTBANK_ONLY = {}
	WARBOUNDBANK_ONLY = {}
end

-- All bags
for _, bags in ipairs { BAGS, BANK } do
	for id in pairs(bags) do ALL[id] = id end
end

-- Modern bag type enumeration (Phase 2 enhancement)
---@enum BagKind
addon.BAG_KIND = {
  UNDEFINED = -1,
  BACKPACK = 0,
  BANK = 1,
}

-- Comprehensive bag definitions for modern WoW (based on BetterBags analysis)
if addon.isRetail then
  -- Account bank bags for retail
  addon.ACCOUNT_BANK_BAGS = {
    [WARBOUND_BANK_CONTAINER_1] = WARBOUND_BANK_CONTAINER_1,
    [WARBOUND_BANK_CONTAINER_2] = WARBOUND_BANK_CONTAINER_2,
    [WARBOUND_BANK_CONTAINER_3] = WARBOUND_BANK_CONTAINER_3,
    [WARBOUND_BANK_CONTAINER_4] = WARBOUND_BANK_CONTAINER_4,
    [WARBOUND_BANK_CONTAINER_5] = WARBOUND_BANK_CONTAINER_5,
  }

  -- Enhanced bank bag definitions
  addon.BANK_BAGS = {
    [BANK_CONTAINER] = BANK_CONTAINER,
  }
  -- Add regular bank bags
  for i = NUM_TOTAL_EQUIPPED_BAG_SLOTS + 1, NUM_TOTAL_EQUIPPED_BAG_SLOTS + NUM_BANKBAGSLOTS do 
    addon.BANK_BAGS[i] = i
  end

  -- Complete backpack definition
  addon.BACKPACK_BAGS = {
    [BACKPACK_CONTAINER] = BACKPACK_CONTAINER,
  }
  for i = 1, NUM_TOTAL_EQUIPPED_BAG_SLOTS do 
    addon.BACKPACK_BAGS[i] = i 
  end
  
  -- Add reagent bag if available
  -- Note: MoP Classic has a bug where Enum.BagIndex.ReagentBag=5 is defined even though it doesn't support reagent bags
  local interfaceVersion = select(4, GetBuildInfo())
  if interfaceVersion < 110200 and not addon.isMop and Enum.BagIndex.ReagentBag then
    addon.BACKPACK_BAGS[Enum.BagIndex.ReagentBag] = Enum.BagIndex.ReagentBag
  end

  -- Backpack-only bags (excluding main backpack)
  addon.BACKPACK_ONLY_BAGS = {}
  for i = 1, NUM_TOTAL_EQUIPPED_BAG_SLOTS do 
    addon.BACKPACK_ONLY_BAGS[i] = i 
  end
  if interfaceVersion < 110200 and not addon.isMop and Enum.BagIndex.ReagentBag then
    addon.BACKPACK_ONLY_BAGS[Enum.BagIndex.ReagentBag] = Enum.BagIndex.ReagentBag
  end

  -- Bank-only bags (excluding main bank)
  addon.BANK_ONLY_BAGS = {}
  for i = NUM_TOTAL_EQUIPPED_BAG_SLOTS + 1, NUM_TOTAL_EQUIPPED_BAG_SLOTS + NUM_BANKBAGSLOTS do 
    addon.BANK_ONLY_BAGS[i] = i
  end

  -- List versions for iteration
  addon.BACKPACK_ONLY_BAGS_LIST = {}
  for bagID in pairs(addon.BACKPACK_ONLY_BAGS) do
    table.insert(addon.BACKPACK_ONLY_BAGS_LIST, bagID)
  end

  addon.BANK_ONLY_BAGS_LIST = {}
  for bagID in pairs(addon.BANK_ONLY_BAGS) do
    table.insert(addon.BANK_ONLY_BAGS_LIST, bagID)
  end

  addon.ACCOUNT_BANK_BAGS_LIST = {}
  for bagID in pairs(addon.ACCOUNT_BANK_BAGS) do
    table.insert(addon.ACCOUNT_BANK_BAGS_LIST, bagID)
  end
else
  -- Classic versions - no account bank
  addon.ACCOUNT_BANK_BAGS = {}
  addon.ACCOUNT_BANK_BAGS_LIST = {}
  
  -- Simplified definitions for classic
  addon.BACKPACK_BAGS = BAGS
  addon.BANK_BAGS = BANK_ONLY
  addon.BACKPACK_ONLY_BAGS = {}
  addon.BANK_ONLY_BAGS = BANK_ONLY
  
  for i = 1, NUM_BAG_SLOTS do 
    addon.BACKPACK_ONLY_BAGS[i] = i 
  end
  
  addon.BACKPACK_ONLY_BAGS_LIST = {}
  for bagID in pairs(addon.BACKPACK_ONLY_BAGS) do
    table.insert(addon.BACKPACK_ONLY_BAGS_LIST, bagID)
  end
  
  addon.BANK_ONLY_BAGS_LIST = {}
  for bagID in pairs(addon.BANK_ONLY_BAGS) do
    table.insert(addon.BANK_ONLY_BAGS_LIST, bagID)
  end
end

-- Modern bag type detection functions (Phase 2 enhancement)
---@param bagID number
---@return number, number BagKind enum value and bag category
function addon:GetBagTypeFromBagID(bagID)
  -- Check if it's an account bank bag (warbank)
  if addon.ACCOUNT_BANK_BAGS and addon.ACCOUNT_BANK_BAGS[bagID] then
    return addon.BAG_KIND.BANK, 2 -- Account bank type
  end
  
  -- Check if it's a regular bank bag
  if addon.BANK_BAGS and addon.BANK_BAGS[bagID] then
    return addon.BAG_KIND.BANK, 1 -- Regular bank type
  end
  
  -- Check if it's a backpack bag
  if addon.BACKPACK_BAGS and addon.BACKPACK_BAGS[bagID] then
    return addon.BAG_KIND.BACKPACK, 0 -- Backpack type
  end
  
  -- Fallback - undefined bag type
  return addon.BAG_KIND.UNDEFINED, -1
end

---@param bagID number
---@return boolean
function addon:IsAccountBankBag(bagID)
  return addon.ACCOUNT_BANK_BAGS and addon.ACCOUNT_BANK_BAGS[bagID] ~= nil
end

---@param bagID number
---@return boolean  
function addon:IsRegularBankBag(bagID)
  return addon.BANK_BAGS and addon.BANK_BAGS[bagID] ~= nil and not addon:IsAccountBankBag(bagID)
end

---@param bagID number
---@return boolean
function addon:IsBackpackBag(bagID)
  return addon.BACKPACK_BAGS and addon.BACKPACK_BAGS[bagID] ~= nil
end

-- Enhanced bag detection using modern APIs (like BetterBags)
---@param bagID number
---@return number, number Item class and subclass of the bag itself
function addon:GetBagItemTypeFromBagID(bagID)
  if not C_Container or not C_Container.ContainerIDToInventoryID then
    return Enum.ItemClass.Container, 0 -- Fallback for older clients
  end
  
  local invID = C_Container.ContainerIDToInventoryID(bagID)
  local bagLink = GetInventoryItemLink("player", invID)
  
  if bagLink and invID then
    local class, subclass = select(6, C_Item.GetItemInfoInstant(bagLink))
    return class or Enum.ItemClass.Container, subclass or 0
  else
    return Enum.ItemClass.Container, 0
  end
end

-- Expansion names
addon.EXPANSION_MAP = {
	[_G.LE_EXPANSION_CLASSIC] = _G.EXPANSION_NAME0,
	[_G.LE_EXPANSION_BURNING_CRUSADE] = _G.EXPANSION_NAME1
}
if addon.isRetail or addon.isWrath or addon.isCata then
	addon.EXPANSION_MAP[_G.LE_EXPANSION_WRATH_OF_THE_LICH_KING] = _G.EXPANSION_NAME2
	addon.EXPANSION_MAP[_G.LE_EXPANSION_CATACLYSM] = _G.EXPANSION_NAME3
	addon.EXPANSION_MAP[_G.LE_EXPANSION_MISTS_OF_PANDARIA] = _G.EXPANSION_NAME4
	addon.EXPANSION_MAP[_G.LE_EXPANSION_WARLORDS_OF_DRAENOR] = _G.EXPANSION_NAME5
	addon.EXPANSION_MAP[_G.LE_EXPANSION_LEGION] = _G.EXPANSION_NAME6
	addon.EXPANSION_MAP[_G.LE_EXPANSION_BATTLE_FOR_AZEROTH] = _G.EXPANSION_NAME7
	addon.EXPANSION_MAP[_G.LE_EXPANSION_SHADOWLANDS] = _G.EXPANSION_NAME8
	addon.EXPANSION_MAP[_G.LE_EXPANSION_DRAGONFLIGHT] = _G.EXPANSION_NAME9
end

if addon.isRetail then
	addon.EXPANSION_MAP[_G.LE_EXPANSION_WAR_WITHIN] = _G.EXPANSION_NAME10
end

-- Tradeskill subclassID -> subclassName
-- Note that this differs from what GetItemSubClassInfo returns (in comments); non-retail client returns aren't obsoleted.
addon.TRADESKILL_MAP = {
	[ 0] = GetItemSubClassInfo(TRADE_GOODS, 0),  -- "Trade Goods (OBSOLETE)"
	[ 1] = L["Engineering"],                     -- "Parts"
	[ 2] = GetItemSubClassInfo(TRADE_GOODS, 2),  -- "Explosives (OBSOLETE)"
	[ 3] = GetItemSubClassInfo(TRADE_GOODS, 3),  -- "Devices (OBSOLETE)"
	[ 4] = GetItemSubClassInfo(TRADE_GOODS, 4),  -- "Jewelcrafting"
	[ 5] = L["Tailoring"],                       -- "Cloth"
	[ 6] = L["Leatherworking"],                  -- "Leather"
	[ 7] = L["Mining"],                          -- "Metal & Stone"
	[ 8] = GetItemSubClassInfo(TRADE_GOODS, 8),  -- "Cooking"
	[ 9] = L["Herbalism"],                       -- "Herb"
	[10] = GetItemSubClassInfo(TRADE_GOODS, 10), -- "Elemental"
	[11] = GetItemSubClassInfo(TRADE_GOODS, 11), -- "Other"
	[12] = GetItemSubClassInfo(TRADE_GOODS, 12), -- "Enchanting"
	[13] = GetItemSubClassInfo(TRADE_GOODS, 13), -- "Materials (OBSOLETE)"
	[14] = GetItemSubClassInfo(TRADE_GOODS, 14), -- "Item Enchantment (OBSOLETE)"
	[15] = GetItemSubClassInfo(TRADE_GOODS, 15), -- "Weapon Enchantment - Obsolete"
	[16] = GetItemSubClassInfo(TRADE_GOODS, 16), -- "Inscription"
	[17] = GetItemSubClassInfo(TRADE_GOODS, 17), -- "Explosives and Devices (OBSOLETE)"
	[18] = GetItemSubClassInfo(TRADE_GOODS, 18), -- "Optional Reagents"
	[19] = GetItemSubClassInfo(TRADE_GOODS, 19), -- "Finishing Reagents"
}

addon.BAG_IDS = {
	BAGS = addon.BACKPACK_BAGS or BAGS,
	BANK = addon.BANK_BAGS or BANK,
	BANK_ONLY = addon.BANK_ONLY_BAGS or BANK_ONLY,
	REAGENTBANK_ONLY = REAGENTBANK_ONLY,
	WARBOUNDBANK_ONLY = addon.ACCOUNT_BANK_BAGS or WARBOUNDBANK_ONLY,
	ALL = ALL
}

addon.FAMILY_TAGS = {
--@noloc[[
	[0x00001] = L["QUIVER_TAG"], -- Quiver
	[0x00002] = L["AMMO_TAG"], -- Ammo Pouch
	[0x00004] = L["SOUL_BAG_TAG"], -- Soul Bag
	[0x00008] = L["LEATHERWORKING_BAG_TAG"], -- Leatherworking Bag
	[0x00010] = L["INSCRIPTION_BAG_TAG"], -- Inscription Bag
	[0x00020] = L["HERB_BAG_TAG"], -- Herb Bag
	[0x00040] = L["ENCHANTING_BAG_TAG"] , -- Enchanting Bag
	[0x00080] = L["ENGINEERING_BAG_TAG"], -- Engineering Bag
	[0x00100] = L["KEYRING_TAG"], -- Keyring
	[0x00200] = L["GEM_BAG_TAG"], -- Gem Bag
	[0x00400] = L["MINING_BAG_TAG"], -- Mining Bag
	[0x00800] = L["REAGENT_BAG_TAG"], -- Reagent Bag
	[0x08000] = L["TACKLE_BOX_TAG"], -- Tackle Box
	[0x10000] = L["COOKING_BAR_TAG"], -- Refrigerator
--@noloc]]
}

addon.FAMILY_ICONS = {
	[0x00001] = [[Interface\Icons\INV_Misc_Ammo_Arrow_01]], -- Quiver
	[0x00002] = [[Interface\Icons\INV_Misc_Ammo_Bullet_05]], -- Ammo Pouch
	[0x00004] = [[Interface\Icons\INV_Misc_Gem_Amethyst_02]], -- Soul Bag
	[0x00008] = [[Interface\Icons\Trade_LeatherWorking]], -- Leatherworking Bag
	[0x00010] = [[Interface\Icons\INV_Inscription_Tradeskill01]], -- Inscription Bag
	[0x00020] = [[Interface\Icons\Trade_Herbalism]], -- Herb Bag
	[0x00040] = [[Interface\Icons\Trade_Engraving]], -- Enchanting Bag
	[0x00080] = [[Interface\Icons\Trade_Engineering]], -- Engineering Bag
	[0x00100] = [[Interface\Icons\INV_Misc_Key_14]], -- Keyring
	[0x00200] = [[Interface\Icons\INV_Misc_Gem_BloodGem_01]], -- Gem Bag
	[0x00400] = [[Interface\Icons\Trade_Mining]], -- Mining Bag
	[0x00800] = [[Interface\Icons\INV_10_Tailoring_CraftingOptionalReagent_ExtraPockets_Color2]], -- Reagent Bag
	[0x08000] = [[Interface\Icons\Trade_Fishing]], -- Tackle Box
	[0x10000] = [[Interface\Icons\INV_Misc_Bag_Cooking]], -- Refrigerator
}

addon.ITEM_SIZE = 37
addon.ITEM_SPACING = 4
addon.SECTION_SPACING = addon.ITEM_SIZE / 3 + addon.ITEM_SPACING
addon.BAG_INSET = 8
addon.TOP_PADDING = 32
addon.HEADER_SIZE = 14 + addon.ITEM_SPACING
addon.EMPTY_SLOT_FILE = [[Interface\BUTTONS\UI-EmptySlot]]

addon.BACKDROP = {
	bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
	edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
	tile = false,
	edgeSize = 16,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

addon.DEFAULT_SETTINGS = {
	profile = {
		enabled = true,
		bags = {
			["*"] = true,
		},
		positionMode = "manual",
		positions = {
			anchor = { point = "BOTTOMRIGHT", xOffset = -32, yOffset = 200 },
			Backpack = { point = "BOTTOMRIGHT", xOffset = -32, yOffset = 200 },
			Bank = { point = "TOPLEFT", xOffset = 32, yOffset = -104 },
			WarbandBank = { point = "TOPLEFT", xOffset = 250, yOffset = -104 },
		},
		scale = 1.0,
		columnWidth = {
			Backpack = 4,
			Bank = 6,
			WarbandBank = 6,
		},
		maxHeight = 0.60,
		qualityHighlight = true,
		qualityOpacity = 1.0,
		dimJunk = true,
		questIndicator = true,
		showBagType = true,
		filters = { ['*'] = true },
		filterPriorities = {},
		sortingOrder = 'default',
		modules = { ['*'] = true },
		virtualStacks = {
			['*'] = false,
			freeSpace = true,
			notWhenTrading = 1,
		},
		experiments = {},
		theme = {
			currentTheme = "default",
			backpack = {
				background = "Blizzard Dialog Background",
				border = "Blizzard Tooltip",
				borderWidth = 16,
				insets = 3,
				color = { 0, 0, 0, 1 },
				bagFont = addon.BagFontDefault,
				sectionFont = addon.SectionFontDefault,
			},
			bank = {
				background = "Blizzard Dialog Background",
				border = "Blizzard Tooltip",
				borderWidth = 16,
				insets = 3,
				color = { 0, 0, 0.0, 1 },
				bagFont = addon.BagFontDefault,
				sectionFont = addon.SectionFontDefault,
			},
			reagentBank = {
				background = "Blizzard Dialog Background",
				border = "Blizzard Tooltip",
				borderWidth = 16,
				insets = 3,
				color = { 0, 0.0, 0, 1 },
				bagFont = addon.BagFontDefault,
				sectionFont = addon.SectionFontDefault,
			},
			warboundBank = {
				background = "Blizzard Dialog Background",
				border = "Blizzard Tooltip",
				borderWidth = 16,
				insets = 3,
				color = { 0.5, 0, 0.5, 1 },
				bagFont = addon.BagFontDefault,
				sectionFont = addon.SectionFontDefault,
			},
			themes = {
				default = {
					backpack = {
						background = "Blizzard Dialog Background",
						border = "Blizzard Tooltip",
						borderWidth = 16,
						insets = 3,
						color = { 0, 0, 0, 1 },
						bagFont = addon.BagFontDefault,
						sectionFont = addon.SectionFontDefault,
					},
					bank = {
						background = "Blizzard Dialog Background",
						border = "Blizzard Tooltip",
						borderWidth = 16,
						insets = 3,
						color = { 0, 0, 0.0, 1 },
						bagFont = addon.BagFontDefault,
						sectionFont = addon.SectionFontDefault,

					},
					reagentBank = {
						background = "Blizzard Dialog Background",
						border = "Blizzard Tooltip",
						borderWidth = 16,
						insets = 3,
						color = { 0, 0.0, 0, 1 },
						bagFont = addon.BagFontDefault,
						sectionFont = addon.SectionFontDefault,
					},
					warboundBank = {
						background = "Blizzard Dialog Background",
						border = "Blizzard Tooltip",
						borderWidth = 16,
						insets = 3,
						color = { 0.5, 0, 0.5, 1 },
						bagFont = addon.BagFontDefault,
						sectionFont = addon.SectionFontDefault,
					},
				},
			},
		},
		rightClickConfig = true,
		autoOpen = true,
		hideAnchor = true,
		autoDeposit = false,
		compactLayout = false,
		gridLayout = false,
	},
	char = {
		collapsedSections = {
			['*'] = false,
		},
	},
}

--- Constants used by annotations that also can be used by the addon itself.

---@enum ItemBindType The binding types for items.
Enum.ItemBindType = {
  LE_ITEM_BIND_NONE = 0,
  LE_ITEM_BIND_ON_ACQUIRE = 1,
  LE_ITEM_BIND_ON_EQUIP = 2,
  LE_ITEM_BIND_ON_USE = 3,
  LE_ITEM_BIND_QUEST = 4,
  LE_ITEM_BIND_TO_BNETACCOUNT = 5, -- Warbound until equipped 
  LE_ITEM_BIND_TO_ACCOUNT = 6, -- Account bound
}

---@enum BindingScope Advanced binding scope for more detailed categorization
Enum.BindingScope = {
  UNKNOWN = -1,
  NONBINDING = 0,
  BOUND = 1,
  BOE = 2,
  BOU = 3,
  QUEST = 4,
  SOULBOUND = 5,
  REFUNDABLE = 6,
  ACCOUNT = 7,     -- Account bound (warband)
  BNET = 8,        -- Battle.net account bound
  WUE = 9,         -- Warbound until equipped
}

-- Note: Binding map moved to ModernBinding module to avoid circular dependencies

---@enum ExpansionType The expansion type for items.
Enum.ExpansionType = {
  LE_EXPANSION_CLASSIC = 0,
  LE_EXPANSION_BURNING_CRUSADE = 1,
  LE_EXPANSION_WRATH_OF_THE_LICH_KING = 2,
  LE_EXPANSION_CATACLYSM = 3,
  LE_EXPANSION_MISTS_OF_PANDARIA = 4,
  LE_EXPANSION_WARLORDS_OF_DRAENOR = 5,
  LE_EXPANSION_LEGION = 6,
  LE_EXPANSION_BATTLE_FOR_AZEROTH = 7,
  LE_EXPANSION_SHADOWLANDS = 8,
  LE_EXPANSION_DRAGONFLIGHT = 9,
  LE_EXPANSION_WAR_WITHIN = 10,
}

-- Initialize font defaults after Fonts.lua has loaded
function addon:InitializeFontDefaults()
	if not self.BagFontDefault then
		self.BagFontDefault = self:GetFontDefaults(GameFontHighlightLarge)
		self.BagFontDefault.r, self.BagFontDefault.g, self.BagFontDefault.b = 1, 1, 1
		self.SectionFontDefault = self:GetFontDefaults(GameFontNormalLeft)
	end
end
