-- 애드온 기본 정보 등록
local addonName, addonTable = ...
local AdiBags = LibStub('AceAddon-3.0'):GetAddon('AdiBagsEx')

-- 필터 등록 (이름과 설명)
local filter = AdiBags:RegisterFilter('BindOnEquip', 90, 'ABEvent-1.0')
filter.uiName = "착귀템 · 전투귀속 · 공대거래템 · 내부전쟁 · 제작템 · 귀속 장비"
filter.uiDesc = "착용 시 귀속 / 착용 전 전투귀속 / 공대 거래 가능 아이템 / 내부전쟁 아이템 / 제작 아이템 / 착용 후 귀속 장비 분류"

-- 카테고리별 아이콘 설정
local categoryIcons = {
    ["착귀템"] = "Interface/ICONS/INV_Misc_Bandage_16",
    ["전투귀속"] = "Interface/ICONS/Achievement_BG_returnXflags_def_WSG",
    ["공대거래템"] = "Interface/ICONS/Achievement_GuildPerk_EverybodysFriend",
    ["2시즌"] = "Interface/ICONS/INV_Misc_Head_Human_02",
    ["무기"] = "Interface/ICONS/INV_Sword_05",
    ["방어구"] = "Interface/ICONS/INV_Chest_Cloth_17",
    ["장신구"] = "Interface/ICONS/INV_Jewelry_Ring_55",
    ["제작템"] = "Interface/ICONS/Trade_Engineering",
}

-- 내부전쟁 아이템 ID 목록
local internalWarItems = {
    [206350] = true, [246771] = true, [231768] = true, [224025] = true, [231757] = true, [231756] = true, [243191] = true,
    [244147] = true, [248410] = true, [224572] = true, [231769] = true, [210814] = true, [245653] = true,
    [248242] = true, [238920] = true, [212493] = true, [231767] = true, [240928] = true, [240927] = true,
    [245510] = true, [238407] = true, [244148] = true, [244149] = true, [240926] = true, [240931] = true, [240930] = true, [248017] = true
}

-- itemLink 기반 캐시 테이블 (메모리 최적화)
local itemCache = {}

-- 캐시 초기화 타이머 (30분 주기 실행)
local function StartCacheResetTimer()
    C_Timer.NewTicker(1800, function()
        wipe(itemCache)
    end)
end

-- 툴팁 프레임 재사용 (메모리 최소화)
local tooltip = CreateFrame("GameTooltip", "BindCheckTooltip", nil, "GameTooltipTemplate")
tooltip:SetOwner(UIParent, "ANCHOR_NONE")

-- 아이콘 제거 버전
local function GetCategoryWithIcon(category)
    return category
end

-- 공대거래 아이템 여부 판단
local function IsRaidTradable(slotData)
    if not slotData.bag or not slotData.slot then return false end

    if C_Item and C_Item.CanTradeTimeRemaining then
        local location = ItemLocation:CreateFromBagAndSlot(slotData.bag, slotData.slot)
        if location and C_Item.DoesItemExist(location) and C_Item.CanTradeTimeRemaining(location) then
            return true
        end
    end

    tooltip:ClearLines()
    tooltip:SetBagItem(slotData.bag, slotData.slot)
    for i = 1, tooltip:NumLines() do
        local line = _G["BindCheckTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and text:find("아이템 획득 자격이 있는 다른 플레이어와") then
                return true
            end
        end
    end

    return false
end

-- 귀속 상태 판별 함수
local function GetBindStatus(slotData)
    local itemLink = slotData.link
    if not itemLink then return "NONE" end

    local cached = itemCache[itemLink]
    if cached then
        return cached
    end

    tooltip:ClearLines()
    tooltip:SetBagItem(slotData.bag, slotData.slot)
    for i = 1, tooltip:NumLines() do
        local textObj = _G["BindCheckTooltipTextLeft"..i]
        if textObj then
            local lineText = textObj:GetText()
            if lineText then
                if lineText == ITEM_BIND_ON_EQUIP then
                    itemCache[itemLink] = "BIND_ON_EQUIP"
                    return "BIND_ON_EQUIP"
                elseif lineText:find("착용 전 전투귀속") then
                    itemCache[itemLink] = "BIND_BEFORE_USE"
                    return "BIND_BEFORE_USE"
                elseif lineText == ITEM_SOULBOUND or lineText == ITEM_BIND_ON_PICKUP then
                    itemCache[itemLink] = "SOULBOUND"
                    return "SOULBOUND"
                end
            end
        end
    end

    itemCache[itemLink] = "NONE"
    return "NONE"
end

-- 귀속된 아이템의 등급 및 타입 분류
local function GetItemTierAndTypeText(itemLink)
    local itemName, _, _, _, _, _, itemSubClassID, _, itemEquipLoc, _, _, itemClassID = GetItemInfo(itemLink)
    if not itemClassID then return nil end

    local tierSymbol = ""
    tooltip:ClearLines()
    tooltip:SetHyperlink(itemLink)
    for i = 1, tooltip:NumLines() do
        local textObj = _G["BindCheckTooltipTextLeft"..i]
        if textObj then
            local lineText = textObj:GetText() or ""
            if lineText:find("레벨 강화: 챔피언") then
                tierSymbol = "[C]"
                break
            elseif lineText:find("레벨 강화: 영웅") then
                tierSymbol = "[H]"
                break
            elseif lineText:find("레벨 강화: 신화") then
                tierSymbol = "[M]"
                break
            end
        end
    end

    if itemClassID == 2 then
        return "무기" .. tierSymbol
    elseif itemClassID == 4 then
        if itemEquipLoc == "INVTYPE_TRINKET" or itemEquipLoc == "INVTYPE_FINGER" or itemEquipLoc == "INVTYPE_NECK" then
            return "장신구" .. tierSymbol
        else
            return "방어구" .. tierSymbol
        end
    end

    return nil
end

-- 필터 활성화 시
function filter:OnEnable()
    self.updateScheduled = false
    self:RegisterEvent('BAG_UPDATE', 'OnBagUpdate')
    self:RegisterEvent('PLAYER_EQUIPMENT_CHANGED', function()
        wipe(itemCache)
    end)
    StartCacheResetTimer()
end

-- 필터 비활성화 시
function filter:OnDisable()
    self:UnregisterEvent('BAG_UPDATE')
    self:UnregisterEvent('PLAYER_EQUIPMENT_CHANGED')
    AdiBags:UpdateFilters()
end

-- Debounce 업데이트
local function DebouncedUpdate(self)
    if self.updateScheduled then return end
    self.updateScheduled = true
    C_Timer.After(0.3, function()
        AdiBags:UpdateFilters()
        self.updateScheduled = false
    end)
end

function filter:OnBagUpdate()
    DebouncedUpdate(self)
end

-- 필터 메인 로직
function filter:Filter(slotData)
    local itemLink = slotData.link
    if not itemLink then return end

    local itemId = tonumber(itemLink:match("item:(%d+):"))
    if not itemId then return end

    -- 내부전쟁 아이템
    if internalWarItems[itemId] then
        return GetCategoryWithIcon("3시즌")
    end

    -- 공대거래
    if IsRaidTradable(slotData) then
        return GetCategoryWithIcon("공대거래템")
    end

    -- 제작템 판단
    tooltip:ClearLines()
    tooltip:SetBagItem(slotData.bag, slotData.slot)
    for i = 1, tooltip:NumLines() do
        local textObj = _G["BindCheckTooltipTextLeft"..i]
        if textObj then
            local lineText = textObj:GetText() or ""
            if lineText:find("징조 제작") or lineText:find("행운 제작") or lineText:find("별빛 제작") then
                return GetCategoryWithIcon("제작템")
            end
        end
    end

    -- 귀속 상태 분류
    local bindStatus = GetBindStatus(slotData)
    if bindStatus == "BIND_BEFORE_USE" then
        return GetCategoryWithIcon("전투귀속")
    elseif bindStatus == "BIND_ON_EQUIP" then
        return GetCategoryWithIcon("착귀템")
    elseif bindStatus == "SOULBOUND" then
        local extraText = GetItemTierAndTypeText(itemLink)
        if extraText then
            return GetCategoryWithIcon(extraText)
        end
    end
end
