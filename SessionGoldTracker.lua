--	-----------------------------------------------------------
--	Session Gold Tracker
--	Tracks gold earned/lost per session with extra stats
--	Authors: Exodius & Darkal
--	-----------------------------------------------------------

local ADDON_NAME = "SessionGoldTracker"

--	Helpers
local function GetCurrentMoney()
	return GetMoney() or 0
end

local function FormatMoney(copper)
	local sign = ""
	if copper	< 0 then
		sign	= "-"
		copper	= -copper
	end
	local gold   = math.floor(copper / 10000)
	local silver = math.floor((copper % 10000) / 100)
	local cop	 = copper % 100
	local parts  = {}
	if gold		> 0 then parts[#parts+1] = "|cffffd700" .. gold   .. "g|r" end
	if silver	> 0 then parts[#parts+1] = "|cffc7c7cf" .. silver .. "s|r" end
	if cop		> 0 or #parts == 0 then
		parts[#parts+1] = "|cffae8f6f" .. cop .. "c|r"
	end
	return sign .. table.concat(parts, " ")
end

local function FormatMoneyPlain(copper)
	-- Plain version without color codes, for history display
	local sign = ""
	if copper < 0 then sign = "-"; copper = -copper end
	local gold		= math.floor(copper / 10000)
	local silver	= math.floor((copper % 10000) / 100)
	local cop		= copper % 100
	local parts		= {}
	if gold		> 0 then parts[#parts+1] = gold   .. "g" end
	if silver	> 0 then parts[#parts+1] = silver .. "s" end
	if cop		> 0 or #parts == 0 then parts[#parts+1] = cop .. "c" end
	return sign .. table.concat(parts, " ")
end

local function FormatDuration(seconds)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %02dm %02ds", h, m, s)
	elseif m > 0 then
		return string.format("%dm %02ds", m, s)
	else
		return string.format("%ds", s)
	end
end

local function FormatDate(epoch)
	-- epoch from time() — format as DD/MM/YYYY HH:MM
	local t = date("*t", epoch)
	return string.format("%02d/%02d/%04d %02d:%02d", t.day, t.month, t.year, t.hour, t.min)
end

--	States
local sessionStart		= 0
local sessionStartTime	= 0
local sessionStartEpoch	= 0
local biggestGain		= 0
local biggestLoss		= 0
local lastMoney			= 0
local sessionNet		= 0
local sessionEarned		= 0
local sessionSpent		= 0
local isMiniMode		= false
local isExtraShown		= false
local isHistoryShown	= false

--	Main Frame
local frame = CreateFrame("Frame", "SGTFrame", UIParent, "BackdropTemplate")
frame:SetSize(230, 175)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
frame:SetBackdrop({
	bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	edgeSize = 16,
	insets   = { left=4, right=4, top=4, bottom=4 },
})
frame:SetBackdropColor(0, 0, 0, 0.75)
frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

--	Title
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
title:SetPoint("TOP", frame, "TOP", 0, -8)
title:SetText("|cffffd700Session Gold Tracker|r")

--	Line 1: Session Timer
local sessionTimerLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
sessionTimerLabel:SetPoint("TOP", title, "BOTTOM", 0, -4)
sessionTimerLabel:SetText("Session time: —")

--	Line 2: Started at <gold amount>
local startLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
startLabel:SetPoint("TOP", sessionTimerLabel, "BOTTOM", 0, -3)
startLabel:SetText("Started at: —")

--	Line 3: Current gold
local currentGoldLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
currentGoldLabel:SetPoint("TOP", startLabel, "BOTTOM", 0, -3)
currentGoldLabel:SetText("Current: —")

--	Line 4: Earned during session
local earnedLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
earnedLabel:SetPoint("TOP", currentGoldLabel, "BOTTOM", 0, -3)
earnedLabel:SetText("Earned: —")

--	Line 5: Spent during session
local spentLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
spentLabel:SetPoint("TOP", earnedLabel, "BOTTOM", 0, -3)
spentLabel:SetText("Spent: —")

--	Line 6: Net
local netLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
netLabel:SetPoint("TOP", spentLabel, "BOTTOM", 0, -3)
netLabel:SetText("Net: —")

--	Buttons
--	"Mini-mode" button (top-right corner)
local miniBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
miniBtn:SetSize(20, 18)
miniBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
miniBtn:SetText("M")

-- 2x2 button grid
-- Row 1, Top: Reset & Extra Data
local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
resetBtn:SetSize(100, 20)
resetBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 30)
resetBtn:SetText("Reset")

local extraBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
extraBtn:SetSize(100, 20)
extraBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 30)
extraBtn:SetText("Extra Data")

-- Row 2, Bottom: History & About
local historyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
historyBtn:SetSize(100, 20)
historyBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 6)
historyBtn:SetText("History")

local aboutBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
aboutBtn:SetSize(100, 20)
aboutBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 6)
aboutBtn:SetText("About")

--	Extra Data Panel
local extraFrame = CreateFrame("Frame", "SGTExtraFrame", UIParent, "BackdropTemplate")
extraFrame:SetSize(230, 90)
extraFrame:SetPoint("TOP", frame, "BOTTOM", 0, -4)
extraFrame:SetBackdrop({
	bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	edgeSize = 16,
	insets   = { left=4, right=4, top=4, bottom=4 },
})
extraFrame:SetBackdropColor(0, 0, 0, 0.75)
extraFrame:SetBackdropBorderColor(0.6, 0.5, 0.1, 1)
extraFrame:Hide()

local extraTitle = extraFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
extraTitle:SetPoint("TOP", extraFrame, "TOP", 0, -8)
extraTitle:SetText("|cffffd700Extra Data|r")

local rateLabel = extraFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
rateLabel:SetPoint("TOP", extraTitle, "BOTTOM", 0, -6)
rateLabel:SetText("Rate: —")

local gainLabel = extraFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
gainLabel:SetPoint("TOP", rateLabel, "BOTTOM", 0, -4)
gainLabel:SetText("Biggest gain: —")

local lossLabel = extraFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
lossLabel:SetPoint("TOP", gainLabel, "BOTTOM", 0, -4)
lossLabel:SetText("Biggest loss: —")

--	History Panel
local MAX_HISTORY	= 20
local ROW_HEIGHT	= 16
local HISTORY_ROWS	= 8  -- visible rows at once

local historyFrame = CreateFrame("Frame", "SGTHistoryFrame", UIParent, "BackdropTemplate")
historyFrame:SetSize(360, 36 + HISTORY_ROWS * ROW_HEIGHT)
historyFrame:SetClampedToScreen(true)
historyFrame:SetBackdrop({
	bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	edgeSize = 16,
	insets   = { left=4, right=4, top=4, bottom=4 },
})
historyFrame:SetBackdropColor(0, 0, 0, 0.75)
historyFrame:SetBackdropBorderColor(0.2, 0.6, 0.4, 1)
historyFrame:Hide()

-- Anchor history below extra if shown, else below main
local function UpdateHistoryAnchor()
	historyFrame:ClearAllPoints()
	if isExtraShown then
		historyFrame:SetPoint("TOP", extraFrame, "BOTTOM", 0, -4)
	else
		historyFrame:SetPoint("TOP", frame, "BOTTOM", 0, -4)
	end
end

local histTitle = historyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
histTitle:SetPoint("TOP", historyFrame, "TOP", 0, -8)
histTitle:SetText("|cffffd700Session History|r  (most recent first)")

--	Column headers
local hdrDate = historyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hdrDate:SetPoint("TOPLEFT", historyFrame, "TOPLEFT", 10, -22)
hdrDate:SetText("|cffffffffDate|r")

local hdrLen = historyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hdrLen:SetPoint("TOPLEFT", historyFrame, "TOPLEFT", 130, -22)
hdrLen:SetText("|cffffffffLength|r")

local hdrGold = historyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hdrGold:SetPoint("TOPLEFT", historyFrame, "TOPLEFT", 220, -22)
hdrGold:SetText("|cffffffffEarned|r")

--	Scrollable row area
local scrollFrame = CreateFrame("ScrollFrame", "SGTHistoryScroll", historyFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetSize(315, HISTORY_ROWS * ROW_HEIGHT)
scrollFrame:SetPoint("TOPLEFT", historyFrame, "TOPLEFT", 8, -34)

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetSize(310, HISTORY_ROWS * ROW_HEIGHT)
scrollFrame:SetScrollChild(scrollChild)

-- Pre-create row labels
local histRows = {}
for i = 1, MAX_HISTORY do
	local row = CreateFrame("Frame", nil, scrollChild)
	row:SetSize(295, ROW_HEIGHT)
	row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i-1) * ROW_HEIGHT)

	local dateStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	dateStr:SetPoint("LEFT", row, "LEFT", 2, 0)
	dateStr:SetWidth(118)
	dateStr:SetJustifyH("LEFT")
	dateStr:SetNonSpaceWrap(false)

	local lenStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	lenStr:SetPoint("LEFT", row, "LEFT", 122, 0)
	lenStr:SetWidth(88)
	lenStr:SetJustifyH("LEFT")
	lenStr:SetNonSpaceWrap(false)

	local goldStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	goldStr:SetPoint("LEFT", row, "LEFT", 212, 0)
	goldStr:SetWidth(120)
	goldStr:SetJustifyH("LEFT")
	goldStr:SetNonSpaceWrap(false)

	row:Hide()
	histRows[i] = { frame=row, date=dateStr, len=lenStr, gold=goldStr }
end

--	Clear history button
local clearHistBtn = CreateFrame("Button", nil, historyFrame, "UIPanelButtonTemplate")
clearHistBtn:SetSize(50, 18)
clearHistBtn:SetPoint("BOTTOMRIGHT", historyFrame, "BOTTOMRIGHT", -15, 137)
clearHistBtn:SetText("Clear")

--	About Panel
local aboutFrame = CreateFrame("Frame", "SGTAboutFrame", UIParent, "BackdropTemplate")
aboutFrame:SetSize(300, 145)
aboutFrame:SetPoint("TOP", frame, "BOTTOM", 0, -4)
aboutFrame:SetClampedToScreen(true)
aboutFrame:SetBackdrop({
	bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	edgeSize = 16,
	insets   = { left=4, right=4, top=4, bottom=4 },
})
aboutFrame:SetBackdropColor(0, 0, 0, 0.75)
aboutFrame:SetBackdropBorderColor(0.3, 0.3, 0.8, 1)
aboutFrame:Hide()

local aboutTitle = aboutFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
aboutTitle:SetPoint("TOP", aboutFrame, "TOP", 0, -8)
aboutTitle:SetText("|cffffd700Session Gold Tracker|r")

local aboutDesc = aboutFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
aboutDesc:SetPoint("TOP", aboutTitle, "BOTTOM", 0, -6)
aboutDesc:SetWidth(260)
aboutDesc:SetJustifyH("CENTER")
aboutDesc:SetNonSpaceWrap(true)
aboutDesc:SetText("Created with intent to be stand-alone,\nas lightweight as possible,\nand not force people to rely on plugins\n(f)or other addons that may be resource intensive.")

local aboutAuthors = aboutFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
aboutAuthors:SetPoint("TOP", aboutDesc, "BOTTOM", 0, -6)
aboutAuthors:SetText("|cffc7c7cfAuthors: Exodius & Darkal|r")

local githubBtn = CreateFrame("Button", nil, aboutFrame, "UIPanelButtonTemplate")
githubBtn:SetSize(120, 20)
githubBtn:SetPoint("TOP", aboutAuthors, "BOTTOM", 0, -8)
githubBtn:SetText("GitHub Page")

local githubEditBox = CreateFrame("EditBox", nil, aboutFrame, "InputBoxTemplate")
githubEditBox:SetSize(275, 20)
githubEditBox:SetPoint("TOP", githubBtn, "BOTTOM", 0, -6)
githubEditBox:SetAutoFocus(false)
githubEditBox:SetCursorPosition(0)
githubEditBox:SetJustifyH("CENTER")
githubEditBox:Hide()

-- Pressing Escape or Enter closes focus on the editbox
githubEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
githubEditBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

githubBtn:SetScript("OnClick", function()
	if githubEditBox:IsShown() then
		githubEditBox:Hide()
	else
		githubEditBox:SetText("https://github.com/Exodius/SessionGoldTracker")
		githubEditBox:Show()
		githubEditBox:SetFocus()
		githubEditBox:HighlightText()
	end
end)

local isAboutShown = false

local function UpdateAboutAnchor()
	aboutFrame:ClearAllPoints()
	if isHistoryShown then
		aboutFrame:SetPoint("TOP", historyFrame, "BOTTOM", 0, -4)
	elseif isExtraShown then
		aboutFrame:SetPoint("TOP", extraFrame, "BOTTOM", 0, -4)
	else
		aboutFrame:SetPoint("TOP", frame, "BOTTOM", 0, -4)
	end
end

--	"Mini-Mode" Frame
local miniFrame = CreateFrame("Frame", "SGTMiniFrame", UIParent, "BackdropTemplate")
miniFrame:SetSize(160, 28)
miniFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
miniFrame:SetMovable(true)
miniFrame:EnableMouse(true)
miniFrame:SetClampedToScreen(true)
miniFrame:RegisterForDrag("LeftButton")
miniFrame:SetBackdrop({
	bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	edgeSize = 16,
	insets   = { left=4, right=4, top=4, bottom=4 },
})
miniFrame:SetBackdropColor(0, 0, 0, 0.75)
miniFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
miniFrame:Hide()

local miniNetLabel = miniFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
miniNetLabel:SetPoint("LEFT", miniFrame, "LEFT", 8, 0)
miniNetLabel:SetText("SGT Net: —")

miniFrame:SetScript("OnMouseUp", function(self, btn)
	if btn == "LeftButton" and not self.dragging then
		isMiniMode = false
		miniFrame:Hide()
		frame:Show()
	end
end)
miniFrame:SetScript("OnDragStart", function(self)
	self.dragging = true
	self:StartMoving()
end)
miniFrame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	C_Timer.After(0.1, function() self.dragging = false end)
end)

--	Logic

local function RefreshHistoryRows()
	local history = SessionGoldTrackerDB and SessionGoldTrackerDB.history or {}
	for i = 1, MAX_HISTORY do
		local entry = history[i]
		if entry then
			local earned	= entry.net
			local color		= earned >= 0 and "|cff00ff00" or "|cffff4444"
			local sign		= earned >= 0 and "+" or "-"
			histRows[i].date:SetText(entry.date)
			histRows[i].len:SetText(FormatDuration(entry.length))
			histRows[i].gold:SetText(color .. sign .. FormatMoneyPlain(math.abs(earned)) .. "|r")
			histRows[i].frame:Show()
		else
			histRows[i].date:SetText("")
			histRows[i].len:SetText("")
			histRows[i].gold:SetText("")
			histRows[i].frame:Hide()
		end
	end
	-- Resize scroll child to actual content
	local count = #history
	scrollChild:SetHeight(math.max(count * ROW_HEIGHT, HISTORY_ROWS * ROW_HEIGHT))
end

local function SaveSessionToHistory()
	if not SessionGoldTrackerDB then SessionGoldTrackerDB = {} end
	if not SessionGoldTrackerDB.history then SessionGoldTrackerDB.history = {} end

	local elapsed = math.floor(GetTime() - sessionStartTime)
	local net = sessionNet

	-- Only save if session was at least 10 seconds long
	if elapsed < 10 then return end

	local entry = {
		date   = FormatDate(sessionStartEpoch),
		length = elapsed,
		net	= net,
	}

	table.insert(SessionGoldTrackerDB.history, 1, entry)

	-- Trim to max
	while #SessionGoldTrackerDB.history > MAX_HISTORY do
		table.remove(SessionGoldTrackerDB.history)
	end
end

local function UpdateExtraDisplay()
	local elapsed = math.floor(GetTime() - sessionStartTime)

	if elapsed > 0 then
		local net		= GetCurrentMoney() - sessionStart
		local perHour	= math.floor((net / elapsed) * 3600)
		rateLabel:SetText("Rate: " .. FormatMoney(perHour) .. "/hr")
	else
		rateLabel:SetText("Rate: —")
	end

	if biggestGain > 0 then
		gainLabel:SetText("Biggest gain: |cff00ff00+" .. FormatMoney(biggestGain) .. "|r")
	else
		gainLabel:SetText("Biggest gain: —")
	end

	if biggestLoss > 0 then
		lossLabel:SetText("Biggest loss: |cffff4444-" .. FormatMoney(biggestLoss) .. "|r")
	else
		lossLabel:SetText("Biggest loss: —")
	end
end

local function UpdateDisplay()
	local current = GetCurrentMoney()
	currentGoldLabel:SetText("Current: " .. FormatMoney(current))
	earnedLabel:SetText("Earned: |cff00ff00+" .. FormatMoney(sessionEarned) .. "|r")
	spentLabel:SetText("Spent: |cffff4444-" .. FormatMoney(sessionSpent) .. "|r")
	local net		= sessionEarned - sessionSpent
	local netColor	= net >= 0 and "|cff00ff00" or "|cffff4444"
	local netSign	= net >= 0 and "+" or ""
	netLabel:SetText("Net: " .. netColor .. netSign .. FormatMoney(net) .. "|r")
	miniNetLabel:SetText("SGT Net: " .. netColor .. netSign .. FormatMoney(math.abs(net)) .. "|r")
	if isExtraShown then UpdateExtraDisplay() end
end

local function StartSession(saveOld)
	if saveOld then SaveSessionToHistory() end
	sessionStart		= GetCurrentMoney()
	sessionStartTime	= GetTime()
	sessionStartEpoch	= time()
	lastMoney			= sessionStart
	biggestGain			= 0
	biggestLoss			= 0
	sessionNet			= 0
	sessionEarned		= 0
	sessionSpent		= 0
	startLabel:SetText("Started at: " .. FormatMoney(sessionStart))
	currentGoldLabel:SetText("Current: " .. FormatMoney(sessionStart))
	UpdateDisplay()
	if isExtraShown then UpdateExtraDisplay() end
	if isHistoryShown then RefreshHistoryRows() end
end

--	Ticker
local ticker = CreateFrame("Frame")
local tickElapsed = 0
ticker:SetScript("OnUpdate", function(self, elapsed)
	tickElapsed = tickElapsed + elapsed
	if tickElapsed >= 1 then
		tickElapsed = 0
		local secs = math.floor(GetTime() - sessionStartTime)
		sessionTimerLabel:SetText("Session time: " .. FormatDuration(secs))
		if isExtraShown then UpdateExtraDisplay() end
	end
end)

--	Events
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		if not SessionGoldTrackerDB then SessionGoldTrackerDB = {} end
		if not SessionGoldTrackerDB.history then SessionGoldTrackerDB.history = {} end
		StartSession(false)
		print("|cffffd700[Session Gold Tracker]|r Session started. Use /sgt for options.")
	elseif event == "PLAYER_LOGOUT" then
		SaveSessionToHistory()
	elseif event == "PLAYER_MONEY" then
		local current = GetCurrentMoney()
		local delta   = current - lastMoney
		if delta > 0 then
			sessionEarned = sessionEarned + delta
			if delta > biggestGain then biggestGain = delta end
		elseif delta < 0 then
			sessionSpent  = sessionSpent + (-delta)
			if (-delta) > biggestLoss then biggestLoss = -delta end
		end
		lastMoney  = current
		sessionNet = sessionEarned - sessionSpent
		UpdateDisplay()
	end
end)

--	Button Handlers
resetBtn:SetScript("OnClick", function()
	StartSession(true)  -- save current session before resetting
	print("|cffffd700[Session Gold Tracker]|r Session reset.")
end)

extraBtn:SetScript("OnClick", function()
	isExtraShown = not isExtraShown
	if isExtraShown then
		UpdateExtraDisplay()
		extraFrame:Show()
		extraBtn:SetText("Hide Extra")
	else
		extraFrame:Hide()
		extraBtn:SetText("Extra Data")
	end
	if isHistoryShown then UpdateHistoryAnchor() end
	if isAboutShown then UpdateAboutAnchor() end
end)

historyBtn:SetScript("OnClick", function()
	isHistoryShown = not isHistoryShown
	if isHistoryShown then
		UpdateHistoryAnchor()
		RefreshHistoryRows()
		historyFrame:Show()
		historyBtn:SetText("Hide Hist.")
	else
		historyFrame:Hide()
		historyBtn:SetText("History")
	end
	if isAboutShown then UpdateAboutAnchor() end
end)

aboutBtn:SetScript("OnClick", function()
	isAboutShown = not isAboutShown
	if isAboutShown then
		githubEditBox:Hide()
		UpdateAboutAnchor()
		aboutFrame:Show()
		aboutBtn:SetText("Close About")
	else
		aboutFrame:Hide()
		aboutBtn:SetText("About")
	end
end)

clearHistBtn:SetScript("OnClick", function()
	if SessionGoldTrackerDB then
		SessionGoldTrackerDB.history = {}
		RefreshHistoryRows()
		print("|cffffd700[Session Gold Tracker]|r History cleared.")
	end
end)

miniBtn:SetScript("OnClick", function()
	isMiniMode = true
	frame:Hide()
	extraFrame:Hide()
	historyFrame:Hide()
	aboutFrame:Hide()
	isExtraShown   = false
	isHistoryShown = false
	isAboutShown   = false
	extraBtn:SetText("Extra Data")
	historyBtn:SetText("History")
	aboutBtn:SetText("About")
	miniFrame:Show()
end)

--	Chat Commands
SLASH_SGT1 = "/sgt"
SlashCmdList["SGT"] = function(msg)
	msg = msg:lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "reset" then
		StartSession(true)
		print("|cffffd700[Session Gold Tracker]|r Session reset.")
	elseif msg == "show" then
		isMiniMode = false
		miniFrame:Hide()
		frame:Show()
	elseif msg == "hide" then
		frame:Hide()
		extraFrame:Hide()
		historyFrame:Hide()
		aboutFrame:Hide()
		miniFrame:Hide()
	elseif msg == "mini" then
		miniBtn:Click()
	else
		local net = GetCurrentMoney() - sessionStart
		print("|cffffd700[Session Gold Tracker]|r Net this session: " .. FormatMoney(net))
		print("  /sgt reset  – reset the session")
		print("  /sgt show   – show the tracker")
		print("  /sgt hide   – hide the tracker")
		print("  /sgt mini   – switch to mini-mode")
	end
end