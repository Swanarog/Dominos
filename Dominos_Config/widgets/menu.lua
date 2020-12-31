local Addon = select(2, ...)
local Menu = Addon:CreateClass('Frame')
local L = LibStub('AceLocale-3.0'):GetLocale('Dominos-Config')

local nextName = Addon:CreateNameGenerator('Menu')

local MENU_WIDTH = 428
local MENU_HEIGHT = 320

function Menu:New(parent)
    local menu = self:Bind(CreateFrame('Frame', nextName(), parent or UIParent, "UIPanelDialogTemplate"))

    menu:Hide()
    menu:SetSize(MENU_WIDTH, MENU_HEIGHT)
    menu:EnableMouse(true)
    menu:SetToplevel(true)
    menu:SetMovable(true)
    menu:SetClampedToScreen(true)
    menu:SetFrameStrata('DIALOG')

    -- title region
    local tr = CreateFrame('Frame', nil, menu, 'TitleDragAreaTemplate')
    tr:SetAllPoints(menu:GetName() .. 'TitleBG')

    -- title text
    local text = menu:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    text:SetPoint('CENTER', tr)
    menu.text = text

    -- panels
    menu.panels = {}

    -- panel selector
    local panelSelector = Addon.PanelSelector:New(menu)
    panelSelector:SetPoint('TOPLEFT', tr, 'BOTTOMLEFT', 2, -4)
    panelSelector:SetPoint('BOTTOMRIGHT', menu, 'BOTTOMLEFT', 2 + 120, 10)
    panelSelector.OnSelect = function(_, id) menu:OnShowPanel(id) end
    menu.panelSelector = panelSelector

    -- panel container
    local panelContainer = Addon.ScrollableContainer:New(menu)
    panelContainer:SetPoint('TOPLEFT', panelSelector, 'TOPRIGHT', 2, 0)
    panelContainer:SetPoint('BOTTOMRIGHT', -4, 10)
    menu.panelContainer = panelContainer

    return menu
end

-- tells the panel what frame we're pointed to
function Menu:SetOwner(owner)
    if self.panels then
        for _, panel in pairs(self.panels) do
            panel:SetOwner(owner)
        end
    end

    self.text:SetFormattedText(L.BarSettings, owner:GetDisplayName())
    self:Anchor(owner)
end

function Menu:Anchor(frame)
    local ratio = UIParent:GetScale() / frame:GetEffectiveScale()
    local x = frame:GetLeft() / ratio
    local y = frame:GetTop() / ratio

    self:ClearAllPoints()
    self:SetPoint('TOPRIGHT', _G.UIParent, 'BOTTOMLEFT', x, y)
end

function Menu:NewPanel(id)
    self.panelSelector:AddPanel(id)

    local panel = Addon.Panel:New()

    self.panels[id] = panel

    return panel
end

function Menu:ShowPanel(id)
    return self.panelSelector:Select(id)
end

function Menu:OnShowPanel(id)
    if self.panels then
        for i, panel in pairs(self.panels) do
            if i == id then
                panel:Show()
                self.panelContainer:SetContent(panel)
            else
                panel:Hide()
            end
        end
    end
end

function Menu:AddLayoutPanel()
    local panel = self:NewPanel(L.Layout)

    panel:AddLayoutOptions()

    return panel
end

function Menu:AddAdvancedPanel(displayConditionsOnly)
    local panel = self:NewPanel(L.Advanced)

    panel:AddAdvancedOptions(displayConditionsOnly)

    return panel
end

function Menu:AddFadingPanel()
    local panel = self:NewPanel(L.Fading)

    panel:AddFadingOptions()

    return panel
end


do--advanced showstates
    local L
    local showStates = {}
    local function addStates(categoryName, stateType)
        L = L or LibStub('AceLocale-3.0'):GetLocale('Dominos-Config')
        local states =
            Dominos.BarStates:map(
            function(s)
                return s.type == stateType
            end
        )

        if #states == 0 then
            return
        end

        for _, state in ipairs(states) do
            local id = state.id
            local name = state.text
            local value = type(state.value) == "string" and state.value or state.value()

            if type(name) == 'function' then
                name = name()
            elseif not name then
                name = L['State_' .. id:upper()]
            end

            tinsert(showStates,  {value = value, text = name or id})
        end
    end


    do --advanced Display Conditions
        local showStates = {
            Hide = "hide;show",
            Show = "show;hide",
            Opacity = "100;50", --help newbies get started!
        }


        local function tIndexOf(tbl, item)
            for i, v in pairs(tbl) do
                if item == v then
                    return i;
                end
            end
        end

        local function tContains(tbl, item)
            return tIndexOf(tbl, item) ~= nil;
        end

        local function capitalize(word)
            if not word then return end
            if string.match(word, '%d+') then
                return word --don't change numbers
            end
            local first, rest = strsub(word, 1, 1) , strsub(word, 2)
            return strupper(first)..rest
        end

        function Menu:SplitShowStates(panel)
            local self = panel.owner
            local states = self:GetUserDisplayConditions()
            if (not states) or states == "" then return end
            states = strfind(states, "]") and gsub(states, "]", "]-") or states
            local splitIndex = strfind(states, ";")
            local a, b = splitIndex and strsub(states, 1, splitIndex-1) or a, splitIndex and strsub(states, splitIndex + 1) or b
            local aStates = {strsplit("-", a )}
            local bStates = {strsplit("-", b )}

            local stateA = aStates[#aStates], tremove(aStates, #aStates)
            local stateB = bStates[#bStates], tremove(bStates, #bStates)

            return stateA, aStates, stateB, bStates
        end

        function Menu:GetCurrentUserDisplayOptions(panel)
            local stateA, _, stateB, _ = self:SplitShowStates(panel)
            local self = panel.owner

            if not (stateA and stateB) then
                return {
                    {value = "disable", text = "Disable"},
                }
            end

            return {
                {value = stateA, text = capitalize(stateA)},
                {value = stateB, text = capitalize(stateB)},
                {value = "disable", text = "Disable"},
            }
        end

        function Menu:GetUserDisplayConditionState(panel, condition)
            local stateA, aStates, stateB, bStates = self:SplitShowStates(panel)
            local self = panel.owner

            if not (aStates and bStates) then return "disable" end


            if tContains(aStates, condition) then
                return stateA
            elseif tContains(bStates, condition) then
                return stateB
            else
                return "disable"
            end
        end

        function Menu:GetCurrentUserDisplay(panel)
            local stateA, _, stateB, _ = self:SplitShowStates(panel)
            local self = panel.owner

            if not (stateA and stateB) then return "disable" , self:SetUserDisplayConditions(nil) end

            local state = strjoin(";", stateA, stateB)

            if tContains(showStates, state) then
                return tIndexOf(showStates, state)
            elseif string.match(state, '%d+') then
                return "Opacity"
            end
                return "disable"
        end

        function Menu:SetCurrentUserDisplay(panel, state)
            local stateA, aStates, stateB, bStates = self:SplitShowStates(panel)
            local self = panel.owner

            local state = state and showStates[state]
            if not state then return self:SetUserDisplayConditions(nil) end

            local splitIndex = strfind(state, ";")
            local newStateA, newStateB = splitIndex and strsub(state, 1, splitIndex-1) or stateA, splitIndex and strsub(state, splitIndex + 1) or stateB
            local a, b = (aStates and strjoin("", unpack(aStates)) or "")..newStateA, (bStates and strjoin("", unpack(bStates)) or "")..newStateB

            return self:SetUserDisplayConditions(strjoin(";", a, b))
        end

        function Menu:UpdateUserDisplayCondition(panel, condition, state)
            local stateA, aStates, stateB, bStates = self:SplitShowStates(panel)
            local self = panel.owner

            if not (condition and stateA and stateB) then return end

            tDeleteItem(aStates, condition)
            tDeleteItem(bStates, condition)

            if state == stateA then
                tinsert(aStates, condition)
            elseif state == stateB then
                tinsert(bStates, condition)
            end

            if #aStates == 0 and #bStates == 0 then
                return self:SetUserDisplayConditions(nil)
            end

            local a, b = (strjoin("", unpack(aStates)) or "")..stateA, (strjoin("", unpack(bStates)) or "")..stateB

            return self:SetUserDisplayConditions(strjoin(";", a, b))
        end


       local function addStateGroup(menu, panel, categoryName, stateType)
            local states =
                Dominos.BarStates:map(
                function(s)
                    return s.type == stateType
                end
            )

            if #states == 0 then
                return
            end

            panel:NewHeader(categoryName)

            for _, state in ipairs(states) do
                local id = state.id
                local condition = type(state.value) == "string" and state.value or state.value()
                local id = state.id
                local name = state.text
                if type(name) == 'function' then
                    name = name()
                elseif not name then
                    name = L['State_' .. id:upper()]
                end

                tinsert(panel.menusToUpdate, panel:NewDropdown {
                    name = name,
                    items = {
                        {value = "disable", text = _G.DISABLE},
                        {value = "hide", text = _G.HIDE},
                        {value = "show", text = _G.SHOW},
                        {value = "opacity", text = "Opacity"},
                    },
                    get = function(self)
                        self.GetItems = function() return menu:GetCurrentUserDisplayOptions(panel) end
                        return menu:GetUserDisplayConditionState(panel, condition)
                    end,
                    set = function(_, value)
                        menu:UpdateUserDisplayCondition(panel, condition, value)

                        panel.showStatesEditBox.editBox:OnShow()
                    end
                })
            end
        end

        local skip
        function Menu:AddDisplayPanel(panel)
            local panel = panel or self:NewPanel("Display") --add to existing panel,or make a new one.
            L = L or LibStub('AceLocale-3.0'):GetLocale('Dominos-Config')

            panel.state = panel:NewDropdown{
                name = "Display",
                items = {
                    {value = "disable", text = _G.DISABLE},
                    {value = "Hide", text = _G.HIDE},
                    {value = "Show", text = _G.SHOW},
                    {value = "Opacity", text = "Opacity"},
                },
                get = function()
                    return self:GetCurrentUserDisplay(panel)
                end,
                set = function(_, value)
                    self:SetCurrentUserDisplay(panel, value)

                    panel.showStatesEditBox.editBox:OnShow()
                    for i , b in pairs(panel.menusToUpdate) do
                        b:OnShow()
                    end
                    panel.showStatesEditBox.editBox:ClearFocus()
                end
            }

            panel.showStatesEditBox = panel:NewTextInput{
                name = L.ShowStates,
                multiline = true,
                width = 268,
                height = 64,
                get = function() return panel.owner:GetUserDisplayConditions() end,
                set = function(_, value)
                    panel.owner:SetUserDisplayConditions(value)
                    panel.state:OnShow()
                    for i , b in pairs(panel.menusToUpdate) do
                        b:OnShow()
                    end

                    --panel.showStatesEditBox.editBox:ClearFocus()
                end
            }

            panel.menusToUpdate = {}
            addStateGroup(self, panel, UnitClass('player'), 'class')
            addStateGroup(self, panel, L.QuickPaging, 'page')
            addStateGroup(self, panel, L.Modifiers, 'modifier')
            addStateGroup(self, panel, L.Targeting, 'target')

            return panel
        end
    end
end



Addon.Menu = Menu
