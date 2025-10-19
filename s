
-- Smart randomized speed adjustment
local function getSafeRandomSpeed()
	return math.random(21,28)
end


-- AutoFarm v5.4 (Optimized for MM2 & Error Handling): Collect Coins Across All Maps (GTA 6 Style UI)
-- Improvements: GTA 6 themed UI, dynamic coin detection, optional speed boost, anti-AFK, draggable UI.
-- Group Collection Logic: Now prioritizes the absolute closest uncollected coin to current position,
--                         which naturally clears out local clusters before moving further.
-- New Sections: Anti-AFK Toggle, UI Visibility Toggle, Continuous Jump Toggle, Movement Mode Toggle, and a Logging/Stats Frame.
-- ADVANCED V5.4 UPDATE: Enhanced PathfindingService for smarter coin navigation, with refined stuck detection,
--                       path.Blocked handling, explicit AgentParameters, AND optional TweenService movement.
-- NEW STATS: Time Running, Coins/Min, Distance Traveled.
-- MM2 OPTIMIZATION: Greatly improved coin finding efficiency to reduce crashes.
-- ERROR FIX: Added nil checks in FindCoins to prevent "attempt to index nil with 'IsA'" errors.

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService") -- NEW: TweenService
local UIS = game:GetService("UserInputService") -- ✅ put this here once
local Autofarm = {}
Autofarm.radius = 369 -- How far to search for coins
Autofarm.farmWalkspeed = 28 -- Speed while autofarming (optional, caution with anti-cheat)
Autofarm.originalWalkspeed = 16 -- Store original walkspeed to restore
Autofarm.touchedCoins = {}
Autofarm.isRunning = false
Autofarm.coinsCollected = 0
Autofarm.moveCoroutine = nil
Autofarm.afkToggle = true -- Enable/Disable anti-AFK
Autofarm.continuousJumpEnabled = false -- Enable/Disable continuous jumping
Autofarm.movementMode = "Tween" -- NEW: Default movement mode. Can be "Pathfinding" or "Tween"
Autofarm.startTime = 0 -- NEW: For tracking time running
Autofarm.totalDistanceTraveled = 0 -- NEW: For tracking distance traveled
Autofarm.lastHrpPosition = nil -- NEW: To track movement for distance calculation
Autofarm.autoRestartOnDeath = false -- NEW: Toggle auto-run after death
-- Add these new configuration variables
Autofarm.baseWalkspeed = 26     -- Base speed when not boosting (adjust as needed, safer range)
Autofarm.boostWalkspeed = 29    -- Speed during the boost (adjust as needed, can be high for short bursts)
Autofarm.boostDuration = 12    -- How long the speed boost lasts (in seconds)
Autofarm.boostCooldown = 5    -- How long to wait between boosts (in seconds)
Autofarm.lastBoostTime = nil      -- Tracks when the last boost occurred
Autofarm.AI = Autofarm.AI or {}
Autofarm.GameCount = 0
Autofarm.MaxGames = 5

getgenv().AutofarmState = {
	running = true,
	coinsCollected = Autofarm.coinsCollected,
	movementMode = Autofarm.selectedMode
}


local refreshTime = 30 -- 30 minutes in seconds

local CONFIG_FILE = "AutoFarmConfig.lua"
local currentMapName = "Unknown"
local roundStartTime = 0
local coinsCollected = 0
local HttpService = game:GetService("HttpService")
local cpmStatsFile = "BestCPMStats.json"
local bestCPMPerMap = {}  -- stores by map name internally
local Autofarm = Autofarm or {}

-- CONFIG
local COIN_CAP = 40 -- Change to 50 if you have Elite
local CHECK_INTERVAL = 2 -- seconds between coin checks
local WAIT_AFTER_FULL = 3 -- wait before hopping after full bag
local MAX_RETRIES = 10 -- how many servers it tries before stopping
local blackscreenEnabled = false
Autofarm.AI = {
	modeScores = {},
	performance = {},
	lastModeChange = tick(),
	modes = { "PathfindV2"}
}


-- UI Setup
local playerGui = player:WaitForChild("PlayerGui")



-- Create the AutoFarm UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoFarmUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

---- =========================================================
-- Device detection (PC stays intact; mobile gets overrides)
-- =========================================================
local UIS = game:GetService("UserInputService")
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
print("Device:", isMobile and "Mobile" or "PC")

-- ===========
-- PC UI (as-is)
-- ===========
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 280, 0, 250)
frame.Position = UDim2.new(0.5, -140, 0.5, -165)
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
frame.BackgroundTransparency = 0.0
frame.BorderSizePixel = 0
frame.Parent = screenGui
frame.ZIndex = 1

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 8)
frameCorner.Parent = frame

-- Title (TextButton)
local title = Instance.new("TextButton")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 0.0
title.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
title.Text = "AUTO-FARM SYSTEMS(MM2)"
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextColor3 = Color3.fromRGB(0, 255, 255)
title.TextStrokeTransparency = 0
title.TextWrapped = true
title.Parent = frame
title.ZIndex = 2
title.AutoButtonColor = false
title.Selectable = false

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = title

-- Status
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 25)
statusLabel.Position = UDim2.new(0, 10, 0, 40)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Idle"
statusLabel.Font = Enum.Font.SourceSans
statusLabel.TextSize = 16
statusLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = frame
statusLabel.ZIndex = 2

-- Coins
local coinsLabel = Instance.new("TextLabel")
coinsLabel.Size = UDim2.new(1, -20, 0, 25)
coinsLabel.Position = UDim2.new(0, 10, 0, 65)
coinsLabel.BackgroundTransparency = 1
coinsLabel.Text = "Coins Collected: 0"
coinsLabel.Font = Enum.Font.SourceSans
coinsLabel.TextSize = 16
coinsLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
coinsLabel.Parent = frame
coinsLabel.ZIndex = 2

-- Speed toggle
local speedToggle = Instance.new("TextButton")
speedToggle.Size = UDim2.new(0, 120, 0, 30)
speedToggle.Position = UDim2.new(0, 10, 0, 95)
speedToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
speedToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
speedToggle.Font = Enum.Font.GothamBold
speedToggle.TextSize = 16
speedToggle.Text = "SPEED: OFF"
speedToggle.BorderSizePixel = 0
speedToggle.Parent = frame
speedToggle.ZIndex = 2
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = speedToggle end

-- Start/Stop
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 120, 0, 30)
toggleButton.Position = UDim2.new(0, 140, 0, 95)
toggleButton.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
toggleButton.TextColor3 = Color3.new(0, 0, 0)
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 18
toggleButton.Text = "START"
toggleButton.BorderSizePixel = 0
toggleButton.Parent = frame
toggleButton.ZIndex = 2
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = toggleButton end

-- Anti-AFK
local antiAFKToggle = Instance.new("TextButton")
antiAFKToggle.Size = UDim2.new(0, 120, 0, 30)
antiAFKToggle.Position = UDim2.new(0, 10, 0, 135)
antiAFKToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
antiAFKToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
antiAFKToggle.Font = Enum.Font.GothamBold
antiAFKToggle.TextSize = 16
antiAFKToggle.Text = "ANTI-AFK: ON"
antiAFKToggle.BorderSizePixel = 0
antiAFKToggle.Parent = frame
antiAFKToggle.ZIndex = 2
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = antiAFKToggle end

-- BlackScreen
local uiVisibilityToggle = Instance.new("TextButton")
uiVisibilityToggle.Size = UDim2.new(0, 120, 0, 30)
uiVisibilityToggle.Position = UDim2.new(0, 140, 0, 135)
uiVisibilityToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
uiVisibilityToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
uiVisibilityToggle.Font = Enum.Font.GothamBold
uiVisibilityToggle.TextSize = 13
uiVisibilityToggle.Text = "BlackScreen: OFF"
uiVisibilityToggle.BorderSizePixel = 0
uiVisibilityToggle.Parent = frame
uiVisibilityToggle.ZIndex = 2
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = uiVisibilityToggle end

-- Jump
local continuousJumpToggle = Instance.new("TextButton")
continuousJumpToggle.Size = UDim2.new(0, 120, 0, 30)
continuousJumpToggle.Position = UDim2.new(0, 10, 0, 175)
continuousJumpToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
continuousJumpToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
continuousJumpToggle.Font = Enum.Font.GothamBold
continuousJumpToggle.TextSize = 16
continuousJumpToggle.Text = "JUMP: OFF"
continuousJumpToggle.BorderSizePixel = 0
continuousJumpToggle.Parent = frame
continuousJumpToggle.ZIndex = 2
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = continuousJumpToggle end

-- Movement Mode
local movementModeToggle = Instance.new("TextButton")
movementModeToggle.Size = UDim2.new(0, 260, 0, 30)
movementModeToggle.Position = UDim2.new(0, 10, 0, 215)
movementModeToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
movementModeToggle.TextColor3 = Color3.new(0, 0, 0)
movementModeToggle.Font = Enum.Font.GothamBold
movementModeToggle.TextSize = 16
movementModeToggle.Text = "MODE: PATHFINDING"
movementModeToggle.BorderSizePixel = 0
movementModeToggle.Parent = frame
movementModeToggle.ZIndex = 2
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = movementModeToggle end

-- Stats
local statsFrame = Instance.new("Frame")
statsFrame.Name = "StatsFrame"
statsFrame.Size = UDim2.new(1, 0, 0, 90)
statsFrame.Position = UDim2.new(0, 0, 0, 240)
statsFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
statsFrame.BackgroundTransparency = 0.0
statsFrame.BorderSizePixel = 0
statsFrame.Parent = frame
statsFrame.ZIndex = 1
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = statsFrame end

local timeRunningLabel = Instance.new("TextLabel")
timeRunningLabel.Size = UDim2.new(1, -20, 0, 25)
timeRunningLabel.Position = UDim2.new(0, 10, 0, 5)
timeRunningLabel.BackgroundTransparency = 1
timeRunningLabel.Text = "Time Running: 0h 0m 0s"
timeRunningLabel.Font = Enum.Font.SourceSans
timeRunningLabel.TextSize = 14
timeRunningLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
timeRunningLabel.TextXAlignment = Enum.TextXAlignment.Left
timeRunningLabel.Parent = statsFrame
timeRunningLabel.ZIndex = 2

local cpmLabel = Instance.new("TextLabel")
cpmLabel.Size = UDim2.new(1, -20, 0, 25)
cpmLabel.Position = UDim2.new(0, 10, 0, 30)
cpmLabel.BackgroundTransparency = 1
cpmLabel.Text = "Coins/Min: 0.00"
cpmLabel.Font = Enum.Font.SourceSans
cpmLabel.TextSize = 14
cpmLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
cpmLabel.TextXAlignment = Enum.TextXAlignment.Left
cpmLabel.Parent = statsFrame
cpmLabel.ZIndex = 2

local distanceLabel = Instance.new("TextLabel")
distanceLabel.Size = UDim2.new(1, -20, 0, 25)
distanceLabel.Position = UDim2.new(0, 10, 0, 55)
distanceLabel.BackgroundTransparency = 1
distanceLabel.Text = "Distance: 0 studs"
distanceLabel.Font = Enum.Font.SourceSans
distanceLabel.TextSize = 14
distanceLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
distanceLabel.TextXAlignment = Enum.TextXAlignment.Left
distanceLabel.Parent = statsFrame
distanceLabel.ZIndex = 2
-- ============================
-- LOW-REGISTER DRAG + MOBILE PERF
-- ============================
do
    local UIS = game:GetService("UserInputService")
    local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

    -- ---- Draggable (PC + Mobile) ----
    do
        local DR = {drag=false}
        local function hook(handle)
            handle.Active = true
            handle.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1
                or i.UserInputType == Enum.UserInputType.Touch then
                    DR.drag = true
                    DR.startInput = i.Position
                    DR.startPos = frame.Position
                    DR.input = i
                    i.Changed:Connect(function()
                        if i.UserInputState == Enum.UserInputState.End then
                            DR.drag = false
                        end
                    end)
                end
            end)
            handle.InputChanged:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseMovement
                or i.UserInputType == Enum.UserInputType.Touch then
                    DR.input = i
                end
            end)
        end
        local function update(i)
            if DR.drag and i == DR.input then
                local d = i.Position - DR.startInput
                frame.Position = UDim2.new(
                    DR.startPos.X.Scale, DR.startPos.X.Offset + d.X,
                    DR.startPos.Y.Scale, DR.startPos.Y.Offset + d.Y
                )
            end
        end
        hook(title); hook(frame)
        UIS.InputChanged:Connect(update)
    end

    if isMobile then
        -- ---- Title: keep full text, auto-fit (tiny locals) ----
        do
            local TS = game:GetService("TextService")
            title.Text = "AUTO-FARM SYSTEMS (MM2)"
            title.TextWrapped = true
            title.TextScaled = false
            title.Size = UDim2.new(1, 0, 0, 24)
            local function fit()
                local w = math.max(10, title.AbsoluteSize.X - 12)
                local h = math.max(10, title.AbsoluteSize.Y - 2)
                local s = 18
                while s > 10 do
                    local b = TS:GetTextSize(title.Text, s, title.Font, Vector2.new(w, 1e6))
                    if b.X <= w and b.Y <= h then break end
                    s -= 1
                end
                title.TextSize = s
            end
            fit()
            title:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
            frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
        end

        -- ---- Mobile Auto Performance (aggressive, no restore, low locals) ----
        do
            local L = game:GetService("Lighting")
            local function soften(o)
                local c = o.ClassName
                if c == "ParticleEmitter" or c == "Trail" or c == "Beam" then
                    o.Enabled = false
                elseif c == "Decal" or c == "Texture" then
                    o.Transparency = 1
                elseif c == "MeshPart" then
                    o.RenderFidelity = Enum.RenderFidelity.Automatic
                    o.Material = Enum.Material.SmoothPlastic
                elseif c == "SurfaceGui" then
                    o.Enabled = false
                elseif o:IsA("PostEffect") then
                    o.Enabled = false
                end
            end

            L.GlobalShadows = false
            for _, x in ipairs(L:GetChildren()) do
                if x:IsA("PostEffect") then x.Enabled = false end
            end
            for _, x in ipairs(workspace:GetDescendants()) do soften(x) end

            local cam = workspace.CurrentCamera or workspace:FindFirstChildOfClass("Camera")
            if not cam then
                workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
                cam = workspace.CurrentCamera
            end
            if cam then cam.FieldOfView = math.clamp(cam.FieldOfView - 10, 50, 90) end

            workspace.DescendantAdded:Connect(soften)
            game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function(ch)
                for _, x in ipairs(ch:GetDescendants()) do soften(x) end
            end)
        end
    end
end


local UIS = game:GetService("UserInputService")
if UIS.TouchEnabled and not UIS.KeyboardEnabled then
    -- shrink panel based on screen size
    local cam = workspace.CurrentCamera
    local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
    -- baseline your PC layout around ~1280x720; clamp so it never gets silly tiny
    local scale = math.clamp(math.min(vs.X/1280, vs.Y/720), 0.55, 0.9)

    local uiScale = Instance.new("UIScale")
    uiScale.Scale = scale
    uiScale.Parent = frame

    -- nudge to center after scaling
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)

    -- reduce text overflow risk
    title.TextScaled = true
    statusLabel.TextScaled = true
    coinsLabel.TextScaled = true
    cpmLabel.TextScaled = true
    timeRunningLabel.TextScaled = true
    distanceLabel.TextScaled = true

    -- shorten the longest strings (mobile-friendly)
    title.Text = "AUTO-FARM (MM2)"
    uiVisibilityToggle.Text = "BLACK: OFF"
    movementModeToggle.Text = "MODE: PATH"
end

-- LOG FRAME (Draggable)
local logFrame = Instance.new("Frame")
logFrame.Name = "LogFrame"
logFrame.Size = UDim2.new(0, 280, 0, 100)
logFrame.Position = UDim2.new(0.5, -140, 0.5, 275)
logFrame.AnchorPoint = Vector2.new(0.5, 0.5)
logFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
logFrame.BorderSizePixel = 0
logFrame.Parent = frame
logFrame.Visible = false 
local logFrameCorner = Instance.new("UICorner")
logFrameCorner.CornerRadius = UDim.new(0, 8)
logFrameCorner.Parent = logFrame

-- SCROLLING FRAME
local logScrollingFrame = Instance.new("ScrollingFrame")
logScrollingFrame.Name = "LogScroll"
logScrollingFrame.Size = UDim2.new(1, -4, 1, -4)
logScrollingFrame.Position = UDim2.new(0, 2, 0, 2)
logScrollingFrame.BackgroundTransparency = 1
logScrollingFrame.BorderSizePixel = 0
logScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- auto expand
logScrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
logScrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
logScrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 255)
logScrollingFrame.ClipsDescendants = true
logScrollingFrame.Parent = logFrame

-- TEXT LABEL (Auto grows in height)
local logTextLabel = Instance.new("TextLabel")
logTextLabel.Name = "LogText"
logTextLabel.Size = UDim2.new(1, 0, 0, 0)
logTextLabel.AutomaticSize = Enum.AutomaticSize.Y
logTextLabel.BackgroundTransparency = 1
logTextLabel.Text = ""
logTextLabel.TextWrapped = true
logTextLabel.Font = Enum.Font.SourceSans
logTextLabel.TextSize = 12
logTextLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
logTextLabel.TextXAlignment = Enum.TextXAlignment.Left
logTextLabel.TextYAlignment = Enum.TextYAlignment.Top
logTextLabel.Parent = logScrollingFrame

-- === GLOBAL UI STORAGE ===
_G.UI = _G.UI or {}

-- === CHANGELOG FRAME CREATION ===
do
    local frame = Instance.new("Frame")
    frame.Name = "ChangelogFrame"
    frame.Size = UDim2.new(0, 520, 0, 300)
    frame.Position = UDim2.new(0.5, -260, 0.5, -150)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    frame.BorderColor3 = Color3.fromRGB(0, 170, 255)
    frame.BorderSizePixel = 1
    frame.Visible = false
    _G.UI.ChangelogFrame = frame -- ✅ store globally
frame.Parent = autoFarmUI or screenGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "ChangelogScroll"
    scroll.Size = UDim2.new(1, -20, 1, -60)
    scroll.Position = UDim2.new(0, 10, 0, 10)
    scroll.BackgroundTransparency = 1
    scroll.CanvasSize = UDim2.new(0, 0, 0, 600)
    scroll.ScrollBarThickness = 4
    scroll.Parent = frame

    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, -10, 0, 600)
    text.Position = UDim2.new(0, 5, 0, 0)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.new(1,1,1)
    text.TextWrapped = true
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.TextYAlignment = Enum.TextYAlignment.Top
    text.Font = Enum.Font.Gotham
    text.TextSize = 15
    text.Text = [[
:jack_o_lantern: MM2 Halloween — v6.0.1 Update
@everyone

The spooky season update is here, fully synced with the latest MM2 patch! :spider_web:

:rotating_light: Important Disclaimer: MM2 Server Bug
Please be aware: There is a widespread MM2 server-side bug currently affecting many players. This bug is preventing candy from counting or being awarded correctly, even when playing without a script.

If you notice your candy count isn't increasing, this is most likely due to the official MM2 bug and not an issue with the script. We are monitoring the situation!

:jigsaw: Patch Notes
Updated to support the latest MM2 Halloween event.

Fixed CheckIsBagFull(): Now properly returns the correct value for auto-reset.

Updated crate arguments: Improved auto-open crate functionality.

Improved PathFindV2: For faster and more efficient movement.

General performance and stability improvements to background features.

:calendar_spiral: Developer Update
I'm making great progress on a few things!

I'm still hard at work on making a scripthub for 8 supported games. Details to follow soon!

I'm also actively improving this script and have started my first new project: a script for 9 Nights in the Forest! This new script will be 100% fully automated right from launch.

🎃 Version: v6.0.1 🗓️ Updated: October 19, 2025

⚠️ Note: The script may still experience some minor lag due to the necessary obfuscation.
]]
    text.Parent = scroll

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 100, 0, 30)
    closeBtn.Position = UDim2.new(1, -110, 1, -40)
    closeBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    closeBtn.Text = "Close"
    closeBtn.TextColor3 = Color3.new(1,1,1)
    closeBtn.TextSize = 16
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.BorderColor3 = Color3.fromRGB(0, 170, 255)
    closeBtn.Parent = frame

    closeBtn.MouseButton1Click:Connect(function()
        frame.Visible = false
    end)
-- === MOBILE FIT & DRAG FOR CHANGELOG (self-contained, nil-safe) ===
do
    local UIS = game:GetService("UserInputService")
    local GS  = game:GetService("GuiService")

    -- resolve changelog widgets even if we're in a new scope:
    local frame = (rawget(_G, "UI") and _G.UI.ChangelogFrame) or _G.ChangelogFrame or frame
    if not frame then
        -- try to find by name if saved globally not available
        local pg = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
        if pg then frame = pg:FindFirstChild("ChangelogFrame", true) end
    end
    if not frame then return end  -- nothing to tweak

    local scroll = frame:FindFirstChild("ChangelogScroll")
    local text   = (scroll and scroll:FindFirstChildOfClass("TextLabel")) or frame:FindFirstChildOfClass("TextLabel")

    -- local helpers (no _G.UIUtil required)
    local function makeDraggable(win, handle)
        if not (win and handle) then return end
        local dragging, startPos, startInput, currentInput
        handle.Active = true
        handle.InputBegan:Connect(function(i)
            local t = i.UserInputType
            if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
                dragging, startInput, startPos, currentInput = true, i.Position, win.Position, i
                i.Changed:Connect(function()
                    if i.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        handle.InputChanged:Connect(function(i)
            local t = i.UserInputType
            if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch then
                currentInput = i
            end
        end)
        game:GetService("UserInputService").InputChanged:Connect(function(i)
            if dragging and i == currentInput then
                local d = i.Position - startInput
                win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
    end

    local function safeCenter(win)
        if not win then return end
        local inset = Vector2.new(0,0)
        pcall(function()
            local v = GS:GetSafeAreaInsets()
            if typeof(v) == "Vector2" then inset = v end
        end)
        local cam = workspace.CurrentCamera
        if not cam then return end
        local vp = cam.ViewportSize
        local x = math.floor((vp.X - win.AbsoluteSize.X) * 0.5 + inset.X)
        local y = math.floor((vp.Y - win.AbsoluteSize.Y) * 0.5 + inset.Y)
        win.AnchorPoint = Vector2.new(0,0) -- using absolute offsets
        win.Position = UDim2.fromOffset(x, y)
    end

    local function mobileScale(win, minS, maxS)
        if not win then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local vpX = cam.ViewportSize.X
        local baseW = 400
        local s = math.clamp(vpX / baseW, minS or 0.6, maxS or 0.9)
        win.Size = UDim2.new(0, math.max(180, math.floor(win.Size.X.Offset * s)), 0, math.max(120, math.floor(win.Size.Y.Offset * s)))
    end

    -- Apply tweaks
    if UIS.TouchEnabled and not UIS.KeyboardEnabled then
        frame.Size = UDim2.new(0, 360, 0, 240) -- compact base for phones
        mobileScale(frame, 0.6, 0.9)
        safeCenter(frame)
        if scroll then scroll.ScrollBarThickness = 3 end
        if text then text.TextSize = 13 end
    end

    -- drag anywhere (works on PC + Mobile)
    makeDraggable(frame, frame)
end


-- Add this with your other UI buttons:
local liteModeToggle = Instance.new("TextButton", frame)
liteModeToggle.Size = UDim2.new(0, 120, 0, 30)
liteModeToggle.Position = UDim2.new(0, 140, 0, 175)
liteModeToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
liteModeToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
liteModeToggle.Font = Enum.Font.GothamBold
liteModeToggle.TextSize = 16
liteModeToggle.Text = "LITE MODE: OFF"
liteModeToggle.BorderSizePixel = 0
Instance.new("UICorner", liteModeToggle).CornerRadius = UDim.new(0, 6)

-- === Lite Mode Toggle Logic ===
liteModeToggle.MouseButton1Click:Connect(function()
	Autofarm.Settings.perfMode = not Autofarm.Settings.perfMode
	liteModeToggle.Text = "LITE MODE: " .. (Autofarm.Settings.perfMode and "ON" or "OFF")
	liteModeToggle.BackgroundColor3 = Autofarm.Settings.perfMode and Color3.fromRGB(0,255,150) or Color3.fromRGB(35,35,45)
	Autofarm:SaveConfig()
	Autofarm:Log("⚡ Performance mode " .. (Autofarm.Settings.perfMode and "enabled" or "disabled"))
end)

-- Function to hop to a different public server

-- Coin cap watcher
task.spawn(function()
	while true do
		task.wait(CHECK_INTERVAL)
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local coins = leaderstats:FindFirstChild("Coins")
			if coins and coins.Value >= COIN_CAP then
				print("✅ Full coin bag (" .. coins.Value .. "). Starting hop sequence...")
				task.wait(WAIT_AFTER_FULL)

				local tries = 0
				while tries < MAX_RETRIES do
					local servers = getPublicServers()
					if #servers == 0 then
						warn("⚠️ No valid servers found.")
						break
					end

					local selected = servers[math.random(1, #servers)]
					hopToServer(selected.id)
					tries += 1
					task.wait(5) -- wait to see if teleport goes through
				end

				break -- stop the main loop after hopping
			end
		end
	end
end)




-- Save config to file
function Autofarm:SaveConfig()
	local config = {
		-- Toggles
		speed        = (speedToggle.Text == "SPEED: ON"),
		antiAFK      = self.afkToggle,
		BlackScreen  = blackscreenEnabled,
		jump         = self.continuousJumpEnabled,
		movementMode = self.movementMode,
		autoRestart  = self.autoRestartOnDeath,
		performance  = self.lowEndMode,

		-- New stuff
		BaseSpeed    = self.Settings.BaseSpeed or 25, -- slider value
		Version      = self.Settings.Version or "v5.7,9 (Stable)", -- version dropdown
		LastJobId    = game.JobId or nil -- useful for server-hopping resume
	}

	local json = HttpService:JSONEncode(config)
	writefile(CONFIG_FILE, json)
	self:Log("💾 Config saved.")
end


-- always ensure blackoutGui exists
local blackoutGui = playerGui:FindFirstChild("BlackoutGui")
if not blackoutGui then
	blackoutGui = Instance.new("ScreenGui")
	blackoutGui.Name = "BlackoutGui"
	blackoutGui.IgnoreGuiInset = true
	blackoutGui.DisplayOrder = 1
	blackoutGui.Enabled = false
	blackoutGui.Parent = playerGui

	local blackFrame = Instance.new("Frame")
	blackFrame.Size = UDim2.new(1, 0, 1, 0)
	blackFrame.Position = UDim2.new(0, 0, 0, 0)
	blackFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	blackFrame.BackgroundTransparency = 0
	blackFrame.BorderSizePixel = 0
	blackFrame.Parent = blackoutGui
end

-- Update a toggle button’s UI
function Autofarm:UpdateToggle(button, state, label)
	if not button then
		warn("❌ Missing UI element for toggle: " .. tostring(label))
		return
	end

	button.Text = label .. (state and ": ON" or ": OFF")
	button.BackgroundColor3 = state and Color3.fromRGB(0, 255, 255) or Color3.fromRGB(35, 35, 45)
	button.TextColor3 = state and Color3.new(0, 0, 0) or Color3.fromRGB(240, 240, 240)
end

-- Load config from file
function Autofarm:LoadConfig()
	if not isfile(CONFIG_FILE) then
		Autofarm.Log("⚠️ No config file found. Using defaults.")
		return
	end

	local success, config = pcall(function()
		return HttpService:JSONDecode(readfile(CONFIG_FILE))
	end)

	if not success or type(config) ~= "table" then
		Autofarm.Log("❌ Failed to parse config file.")
		return
	end

	-- ✅ Ensure blackoutGui exists

	local blackoutGui = playerGui:FindFirstChild("BlackoutGui")
	if not blackoutGui then
		blackoutGui = Instance.new("ScreenGui")
		blackoutGui.Name = "BlackoutGui"
		blackoutGui.IgnoreGuiInset = true
		blackoutGui.DisplayOrder = 1
		blackoutGui.Enabled = false
		blackoutGui.Parent = playerGui

		local blackFrame = Instance.new("Frame")
		blackFrame.Size = UDim2.new(1, 0, 1, 0)
		blackFrame.Position = UDim2.new(0, 0, 0, 0)
		blackFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		blackFrame.BackgroundTransparency = 0
		blackFrame.BorderSizePixel = 0
		blackFrame.Parent = blackoutGui
	end

	-- Speed Toggle
	self.speedEnabled = config.speed == true
	self:UpdateToggle(speedToggle, self.speedEnabled, "SPEED")

	-- Anti-AFK
	self.afkToggle = config.antiAFK == true
	self:UpdateToggle(antiAFKToggle, self.afkToggle, "ANTI-AFK")

	-- BlackScreen
	blackscreenEnabled = config.BlackScreen == true
	blackoutGui.Enabled = blackscreenEnabled
	self:UpdateToggle(uiVisibilityToggle, blackscreenEnabled, "BLACKSCREEN")

	-- Jump
	self.continuousJumpEnabled = config.jump == true
	self:UpdateToggle(continuousJumpToggle, self.continuousJumpEnabled, "JUMP")

	-- Movement Mode
	self.movementMode = config.movementMode or "Pathfinding"
	movementModeToggle.Text = "MODE: " .. self.movementMode:upper()

	local modeColors = {
		Pathfinding = Color3.fromRGB(0, 255, 255),
		Tween       = Color3.fromRGB(255, 0, 255),
		SmartDash   = Color3.fromRGB(255, 165, 0),
		Follow      = Color3.fromRGB(0, 255, 127),
		ZigZag      = Color3.fromRGB(128, 0, 255),
		GlidePulse  = Color3.fromRGB(200, 100, 255),
		StrafeDash  = Color3.fromRGB(100, 255, 200),
	}
	movementModeToggle.BackgroundColor3 = modeColors[self.movementMode] or Color3.new(1, 1, 1)
	movementModeToggle.TextColor3 = Color3.new(0, 0, 0)

	-- Auto-Restart
	self.autoRestartOnDeath = config.autoRestart == true
	self:UpdateToggle(autoRestartToggle, self.autoRestartOnDeath, "AUTO-RESTART")

	-- Performance
	--self.lowEndMode = config.performance == true
	--self:UpdateToggle(performanceToggle, self.lowEndMode, "PERFORMANCE")

	-- === NEW: Farm Speed Slider ===
	self.Settings.BaseSpeed = tonumber(config.BaseSpeed) or 25
	if sliderLabel then
		sliderLabel.Text = "Farm Speed: " .. self.Settings.BaseSpeed
	end

	-- === NEW: Version Dropdown ===
	self.Settings.Version = config.Version or "v5.7,9 (Stable)"
	if versionDropdown then
		versionDropdown.Text = "Current: " .. self.Settings.Version
	end

	Autofarm.Log("✅ Config loaded.")
end


local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")


task.spawn(function()
	repeat task.wait() until game:IsLoaded()
	local Players = game:GetService("Players")
	local TeleportService = game:GetService("TeleportService")


	local localPlayer = Players.LocalPlayer
	local hrp = nil

	-- Wait for HumanoidRootPart
	repeat task.wait() until localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart")

	-- Require the Autofarm Module


	-- Detect if it's a new server (hop)
	local lastJobId = nil
	local teleportData = TeleportService:GetLocalPlayerTeleportData()
	if teleportData and teleportData.LastJobId then
		lastJobId = teleportData.LastJobId
	end

	local currentJobId = game.JobId
	local isHop = lastJobId and currentJobId ~= lastJobId

	-- Set TeleportData for next hop
	RunService.RenderStepped:Connect(function()
		pcall(function()
			TeleportService:SetTeleportData({ LastJobId = game.JobId })
		end)
	end)

	-- Delay + auto start
	task.delay(5, function()
		if isHop or not lastJobId then
			Autofarm:Start()
            statusLabel.Text = "Status: Waiting for round to start"
		end
	end)
end)

local localPlayer = Players.LocalPlayer
local hrp = nil

-- Wait for character to load
local function waitForCharacter()
	if not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then
		localPlayer.CharacterAdded:Wait()
		repeat task.wait() until localPlayer.Character:FindFirstChild("HumanoidRootPart")
	end
	hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart")
end

-- Autofarm start wrapper
function Autofarm:Start()
	if not self.startTime then
		self.startTime = tick()
	end

	-- Save autofarm running state globally
	getgenv().AutofarmState = {
		running = true,
		coinsCollected = self.coinsCollected or 0,
		movementMode = self.selectedMode or "Tween"
	}

	-- Server refresh loop
	task.spawn(function()
		while Autofarm.isRunning do
			task.wait(refreshTime)
			
		end
	end)

	-- Core stat resets
	self.coinsCollected = 0
	self.totalDistanceTraveled = 0
	self.GameCount = 0
	self.isRunning = true

	-- Autofarm routines
	self:TrackMurderer()
	self:CollectCoins(self:GetRootPart())
end

function Autofarm:TrackMurderer()
	local Players = game:GetService("Players")
	local Remotes = game:GetService("ReplicatedStorage").Remotes.Gameplay
	self.Murderer = nil

	-- Track confirmed killer via KillEvent
	Remotes.KillEvent.OnClientEvent:Connect(function(killer, _)
		if killer and killer:IsA("Player") then
			Autofarm.Log("🔪 Murderer identified via kill: " .. killer.Name)
			self.Murderer = killer
		end
	end)

	-- Live detection for knife reveals
	task.spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= Players.LocalPlayer and player.Character then
					local tool = player.Character:FindFirstChildOfClass("Tool")
					if tool and tool.Name == "Knife" then
						if not self.Murderer or self.Murderer ~= player then
							self.Murderer = player
							Autofarm.Log("⚠️ Murderer revealed knife: " .. player.Name)
						end
					end
				end
			end
			task.wait(0.3)
		end
	end)
end

-- Server hop detection
local lastJobId = nil
local teleportData = TeleportService:GetLocalPlayerTeleportData()
if teleportData and teleportData.LastJobId then
	lastJobId = teleportData.LastJobId
end

local currentJobId = game.JobId
local isHop = lastJobId and currentJobId ~= lastJobId

-- Auto-start logic
task.delay(5, function()
	waitForCharacter()

	if isHop or not lastJobId then
		print("🔁 Auto-starting autofarm after server hop or first load")
		Autofarm:Start()
	end
end)
function Autofarm:SaveAIMemory()
	local json = HttpService:JSONEncode(self.AI)
	writefile(AI_MEMORY_FILE, json)
	Autofarm.Log("💾 AI memory saved.")
end
-- Shared state
local offset = tickerFrame and tickerFrame.AbsoluteSize.X or 0
local frameCounter, lastCheck = 0, tick()





function Autofarm:IsMurdererNearby(radius)
	local localChar = player.Character
	if not self.HumanoidRootPart or not self.Character then
		self:Log("⚠️ Cannot check for murderer: character not ready.")
		return false
	end
	local hrp = localChar.HumanoidRootPart

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
			local tool = plr.Character:FindFirstChildOfClass("Tool")
			if tool and tool.Name == "Knife" then
				local distance = (plr.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
				if distance <= radius then
					Autofarm.Log("⚠️ Murderer nearby: " .. plr.Name .. " [" .. math.floor(distance) .. " studs]")
					return true, plr
				end
			end
		end
	end

	return false
end

-- LOGGING FUNCTION
local MAX_LOG_LINES = 100
function Autofarm.Log(message)
	local timestamp = os.date("[%H:%M:%S]")
	local newLogLine = timestamp .. " " .. message .. "\n"
	logTextLabel.Text = logTextLabel.Text .. newLogLine

	-- Trim old lines
	local lines = string.split(logTextLabel.Text, "\n")
	if #lines > MAX_LOG_LINES then
		table.remove(lines, 1)
		logTextLabel.Text = table.concat(lines, "\n")
	end

	-- Scroll to bottom after size update
	task.defer(function()
		logScrollingFrame.CanvasPosition = Vector2.new(0, logTextLabel.AbsoluteSize.Y)
	end)
end

local HttpService = game:GetService("HttpService")

local UserInputService = game:GetService("UserInputService")

-- Generic UI Draggability Function
local function makeDraggable(dragTarget, handle)
	handle = handle or dragTarget -- Fallback if no separate handle provided

	local isDragging = false
	local dragStart
	local startPos
	local connectionMove, connectionEnd

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isDragging = true
			dragStart = input.Position
			startPos = dragTarget.Position
			dragTarget.ZIndex = 10 -- Bring to front

			Autofarm.Log("Dragging '" .. dragTarget.Name .. "' started.")

			-- Start tracking movement
			connectionMove = UserInputService.InputChanged:Connect(function(moveInput)
				if isDragging and (moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch) then
					local delta = moveInput.Position - dragStart
					dragTarget.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
				end
			end)

			-- Stop tracking when input ends
			connectionEnd = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					isDragging = false
					dragTarget.ZIndex = 1 -- Reset ZIndex

					-- Disconnect connections
					if connectionMove then connectionMove:Disconnect() end
					if connectionEnd then connectionEnd:Disconnect() end

					Autofarm.Log("Dragging '" .. dragTarget.Name .. "' ended.")
				end
			end)
		end
	end)
end

-- Apply draggability to UI elements
makeDraggable(frame, title)       -- drag by title bar
makeDraggable(logFrame, logFrame) -- drag by entire log frame


-- Utility functions
-- === GLOBAL COIN BAG CHECK ===

-- 🌐 Universal Bag Full + Sheriff Logic (MM2)
-- Works on most executors (no syn-specific APIs)

local Players = game:GetService("Players")
local player = Players.LocalPlayer


-- 👜 Check if bag is full
local function isBagFull()
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then return false end

	local mainGui = gui:FindFirstChild("MainGUI")
	if not mainGui then return false end

	local gameGui = mainGui:FindFirstChild("Game")
	if not gameGui then return false end

	local coinBags = gameGui:FindFirstChild("CoinBags")
	if not coinBags then return false end

	local container = coinBags:FindFirstChild("Container")
	if not container then return false end

	local beachBall = container:FindFirstChild("Candy")
	if not beachBall then return false end

	local fullIcon = beachBall:FindFirstChild("FullBagIcon")
	return fullIcon and fullIcon.Visible == true
end

-- 🔫 Sheriff check
local function isSheriff()
	return player.Backpack:FindFirstChild("Revolver") or player.Character and player.Character:FindFirstChild("Revolver")
end

-- 👿 Find murderer (simple check — murderer has "Knife")
local function getMurderer()
	for _, plr in pairs(Players:GetPlayers()) do
		if plr ~= player and plr.Character then
			if plr.Backpack:FindFirstChild("Knife") or plr.Character:FindFirstChild("Knife") then
				return plr
			end
		end
	end
	return nil
end

-- 🏃 Reset if bag full and not sheriff
-- 🌍 Define once at top-level, not per-function
_G.FarmUtils = _G.FarmUtils or {}

if not _G.FarmUtils.Player then
    _G.FarmUtils.Player = game:GetService("Players").LocalPlayer
    _G.FarmUtils.Camera = workspace.CurrentCamera
    _G.FarmUtils.VIM = game:GetService("VirtualInputManager")
end

-- 🎯 Aim + shoot (no locals here)
function _G.FarmUtils.AimAndShoot(part)
    if not part then return end

    -- Aim camera directly
    _G.FarmUtils.Camera.CFrame = CFrame.new(
        _G.FarmUtils.Camera.CFrame.Position,
        part.Position
    )

    -- Mouse click
    _G.FarmUtils.VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    task.wait(0.05)
    _G.FarmUtils.VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)

    -- Backup activation
    local gun = _G.FarmUtils.Player.Character and _G.FarmUtils.Player.Character:FindFirstChild("Revolver")
    if gun then pcall(function() gun:Activate() end) end
end

-- 🔫 Sheriff attack loop (globalized)
function _G.FarmUtils.SheriffAttackLoop(murderer, gun)
    local char = _G.FarmUtils.Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    while murderer and murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart") do
        if not char or not hum or hum.Health <= 0 then break end
        if not gun or not gun.Parent then break end

        -- Auto equip
        if gun.Parent ~= char then
            gun.Parent = char
            task.wait(0.1)
        end

        -- Fire
        _G.FarmUtils.AimAndShoot(murderer.Character.HumanoidRootPart)
        task.wait(0.25)
    end
end

-- 🚀 Aggressive Fling (auto-reset after 6s if still flinging)
local function aggressiveFling(targetHrp)
    local char = player.Character
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not targetHrp or not hum then return end

    -- Force yourself onto the murderer
    hrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, -1)

    -- Create BodyVelocity (glue) + BodyAngularVelocity (cartwheel)
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp

    local bav = Instance.new("BodyAngularVelocity")
    bav.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bav.AngularVelocity = Vector3.new(0, 0, 2000) -- cartwheel spin on Z
    bav.Parent = hrp

    -- Rage fling loop
    task.spawn(function()
        local start = tick()
        local flinging = true

        while tick() - start < 3 do -- 3s rage window
            if not targetHrp.Parent then
                flinging = false
                break
            end

            -- Random chaotic velocity for instability
            bv.Velocity = Vector3.new(
                math.random(-1e4, 1e4),
                math.random(5e3, 2e4),
                math.random(-1e4, 1e4)
            )

            -- Stay glued to target
            hrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, -1)

            -- Spam jumping while cartwheeling
            hum.Jump = true

            task.wait(0.05)
        end

        -- Cleanup
        bv:Destroy()
        bav:Destroy()

        -- Auto reset if fling failed and lasted too long
        if flinging and tick() - start >= 6 then
            if hum and hum.Health > 0 then
                hum.Health = 0
                warn("⚠️ Auto-reset after failed fling (6s timeout)")
            end
        end
    end)
end



-- Modified resetIfBagFull with aggressive fling
-- 🧩 Auto Reset when Bag is Full (with AutoFarm restart)
local function resetIfBagFull()
	if isBagFull() then
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")

			if humanoid and humanoid.Health > 0 then
				print("[AutoFarm] 💰 Bag full detected — resetting...")

				-- Force stop autofarm before reset (if AutoFarm object exists)
				if AutoFarm then
					local success, err = pcall(function() AutoFarm:Stop() end)
					if success then
						print("[AutoFarm] ⛔ AutoFarm stopped before reset.")
					else
						-- Log the error, but continue the reset process
						warn("[AutoFarm] Failed to stop (Pre-Reset): " .. tostring(err))
					end
				end

				-- Perform reset
				humanoid.Health = 0
				-- Increase task.wait to 5 to give extra time for full respawn/loading, which is common in Roblox
				task.wait(5) 

				-- Force restart autofarm after respawn (if AutoFarm object exists)
				if AutoFarm then
					local success, err = pcall(function() AutoFarm:Start() end)
					if success then
						print("[AutoFarm] ✅ AutoFarm restarted after reset.")
					else
						-- Log the error
						warn("[AutoFarm] Failed to restart (Post-Reset): " .. tostring(err))
					end
				end
			end
		end
	end
end




-- 🔁 Loop check
RunService.Heartbeat:Connect(function()
	pcall(resetIfBagFull)
end)



function Autofarm:GetCharacter()
	local char = player.Character
	if not char or not char.PrimaryPart then
		char = player.CharacterAdded:Wait()
		char:WaitForChild("HumanoidRootPart", 5)
	end
	return char
end

function Autofarm:GetHumanoid()
	local char = self:GetCharacter()
	if char then
		local hum = char:WaitForChild("Humanoid", 5)
		return hum
	end
	return nil
end

function Autofarm:IsCoinTouched(coin)
    -- ✅ Check validity
    if not coin or not coin:IsA("BasePart") then
        return true -- treat invalid/non-part as already "touched"
    end
    
    -- ✅ Return whether we already marked it
    return self.touchedCoins[coin] == true
end


function Autofarm:MarkCoinTouched(coin)
	if not self:IsCoinTouched(coin) then
		self.touchedCoins[coin] = true

		-- ✅ Wait until the bag GUI confirms the coin was added
		local gui = player:FindFirstChild("PlayerGui")
		local mainGui = gui and gui:FindFirstChild("MainGUI")
		local gameGui = mainGui and mainGui:FindFirstChild("Game")
		local coinBags = gameGui and gameGui:FindFirstChild("CoinBags")
		local container = coinBags and coinBags:FindFirstChild("Container")

		if container then
			-- Count currently visible icons
			local visibleCount = 0
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("ImageLabel") and child.Visible then
					visibleCount += 1
				end
			end

			self.coinsCollected = visibleCount
			coinsLabel.Text = "Coins Collected: " .. self.coinsCollected
			Autofarm.Log("Collected a coin. Total: " .. self.coinsCollected)
		end

		-- ✅ Hide / disable the coin part for visuals
		if coin:IsA("BasePart") then
			pcall(function()
				coin.Transparency = 1
				coin.CanCollide = false
			end)
		end
	end
end



function Autofarm:IsValidPosition(vec)
	return typeof(vec) == "Vector3"
		and math.abs(vec.X) < 1e5
		and math.abs(vec.Y) < 1e5
		and math.abs(vec.Z) < 1e5
		and vec == vec -- not NaN
end

function Autofarm:IsValidGround(pos)
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {workspace}
	rayParams.FilterType = Enum.RaycastFilterType.Whitelist
	rayParams.IgnoreWater = true
	local hit = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -10, 0), rayParams)
	return hit and hit.Instance
end

function Autofarm:ClampSafeY(pos)
	local hit = self:IsValidGround(pos)
	if not hit then return nil end
	local y = hit.Position.Y + 2.5
	return Vector3.new(pos.X, y, pos.Z)
end

-- Optimized QuickFarm with Safe Coin Collection, Path Movement, and Anti-AFK

local VirtualUser = game:GetService("VirtualUser")

local function isValidVector3(v)
	return typeof(v) == "Vector3"
		and v == v
		and v.Magnitude < math.huge
		and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end

local function getSafeGroundY(pos)
	local origin = pos + Vector3.new(0, 50, 0)
	local direction = Vector3.new(0, -100, 0)
	local result = workspace:Raycast(origin, direction)
	if result and result.Position then
		return result.Position.Y + 3
	end
	return math.clamp(pos.Y, 3, 500)
end

local function clampToMapBounds(pos)
	local y = getSafeGroundY(pos)
	return Vector3.new(math.clamp(pos.X, -5000, 5000), y, math.clamp(pos.Z, -5000, 5000))
end

function Autofarm:IdleHumanize()
	self:Log("💤 Anti-AFK engaged.")
	if not self._antiAfkConnection then
		self._antiAfkConnection = game:GetService("Players").LocalPlayer.Idled:Connect(function()
			VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
			task.wait(1)
			VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
			self:Log("🔄 Anti-AFK triggered.")
		end)
	end
end

function Autofarm:QuickFarm(duration)
	if self.isRunning then
		self:Log("⚠️ QuickFarm is already running. Ignoring duplicate start.")
		return
	end

	local maxCoins = 40
	self:Log("⚡ Starting QuickFarm Mode (Max 40 coins or 50s)...")

	self.isRunning = true
	self.coinsCollected = 0
	local startTime = tick()
	local lastLogTime = 0

	self.movementMode = "Pathfinding"
	local originalSpeed = self.farmWalkspeed
	self.farmWalkspeed = 90
	self:IdleHumanize()

	local char = self:GetCharacter()
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or not isValidVector3(hrp.Position) then
		self:Log("❌ Invalid character position. Aborting QuickFarm.")
		self.isRunning = false
		return
	end

	while self.isRunning and (tick() - startTime) < duration and self.coinsCollected < maxCoins and not self:isBagFull() do
		local char = self:GetCharacter()
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp or not isValidVector3(hrp.Position) then
			self:Log("❌ Character lost or invalid during QuickFarm. Aborting.")
			break
		end

		if not self._lastCoinScan or tick() - self._lastCoinScan > 0.2 then

			self.cachedCoins = self:FindCoins()
			self._lastCoinScan = tick()
		end
		local coins = self.cachedCoins
		local validCoins = {}

		for _, coin in pairs(coins) do
			if coin and coin.Parent and (coin:IsA("BasePart") or coin:IsA("MeshPart")) and coin.Name:lower():find("coin") then
				if coin.Transparency < 0.9 and not self:IsCoinTouched(coin) then
					if coin.Position.Y > -500 and coin.Position.Y < 10000 then
						if isValidVector3(coin.Position) then
							table.insert(validCoins, coin)
						end
					else
						self:Log("⚠️ Skipping coin at extreme Y-position: " .. coin.Position.Y)
					end
				end
			end
		end

		if #validCoins == 0 then
			self:Log("🔍 No valid coins found in current scan. Breaking QuickFarm loop.")
			break
		end

		table.sort(validCoins, function(a, b)
			if not a or not b or not isValidVector3(a.Position) or not isValidVector3(b.Position) then return false end
			return (hrp.Position - a.Position).Magnitude < (hrp.Position - b.Position).Magnitude
		end)

		local targetCoin = validCoins[1]
		if targetCoin and targetCoin.Parent and isValidVector3(targetCoin.Position) and isValidVector3(hrp.Position) then
			if (targetCoin:IsA("BasePart") or targetCoin:IsA("MeshPart")) and targetCoin.Name:lower():find("coin") and targetCoin.Transparency < 0.9 and not self:IsCoinTouched(targetCoin) then
				local hoverPos = clampToMapBounds(targetCoin.Position + Vector3.new(0, 25, 0))
				self.Humanoid:MoveTo(hoverPos)
				self.Humanoid.MoveToFinished:Wait(2)

				-- Double check it's still valid
				if not targetCoin:IsDescendantOf(workspace) or targetCoin.Transparency >= 0.9 or self:IsCoinTouched(targetCoin) then
					self:Log("❌ Coin became invalid during hover check. Skipping.")
					continue
				end

				-- Move in for collection
				local safeTargetPos = clampToMapBounds(targetCoin.Position)
				self.Humanoid:MoveTo(safeTargetPos)

				local timeout = tick() + 4
				repeat
					task.wait(0.1)
				until not targetCoin:IsDescendantOf(workspace) or tick() > timeout

				if not targetCoin:IsDescendantOf(workspace) then
					self.coinsCollected = self.coinsCollected + 1
					self:Log("💰 Coin collected. Total: " .. self.coinsCollected)
				else
					self:Log("❌ Coin still exists after timeout. Likely blocked or fake.")
				end
			else
				self:Log("❌ Target coin became invalid before collection. Rescanning.")
			end
		else
			self:Log("❌ Target coin was nil or invalid. Rescanning.")
		end

		if tick() - lastLogTime > 1 then
			self:Log("QuickFarm running... " .. self.coinsCollected .. "/" .. maxCoins .. " coins")
			lastLogTime = tick()
		end

		task.wait()
	end

	self.farmWalkspeed = originalSpeed
	self.isRunning = false
	self:Log("✅ QuickFarm complete. Coins collected: " .. self.coinsCollected)
	self:SaveStats()
end


function Autofarm:isBagFull()
	local player = game:GetService("Players").LocalPlayer
	local fullIcon = player:FindFirstChild("PlayerGui") and
		player.PlayerGui:FindFirstChild("MainGUI") and
		player.PlayerGui.MainGUI:FindFirstChild("Game") and
		player.PlayerGui.MainGUI.Game:FindFirstChild("CoinBags") and
		player.PlayerGui.MainGUI.Game.CoinBags:FindFirstChild("Container") and
		player.PlayerGui.MainGUI.Game.CoinBags.Container:FindFirstChild("Coin") and
		player.PlayerGui.MainGUI.Game.CoinBags.Container.Coin:FindFirstChild("FullBagIcon")

	return fullIcon and fullIcon.Visible == true
end

-- Optimized FindCoins with caching (if applicable)
function Autofarm:FindCoins()
	local coinFolder = workspace:FindFirstChild("Coins") or workspace
	local coins = {}
	local char = self:GetCharacter()
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return {} end

	local charPos = hrp.Position

	for _, obj in ipairs(coinFolder:GetDescendants()) do
		if obj:IsA("BasePart") and obj.Name:lower():find("coin") and obj.Transparency < 0.9 then
			if not self:IsCoinTouched(obj) then
				local dist = (obj.Position - charPos).Magnitude
				if dist < self.radius then
					table.insert(coins, obj)
				end
			end
		end
	end

	table.sort(coins, function(a, b)
		return (a.Position - charPos).Magnitude < (b.Position - charPos).Magnitude
	end)

	return coins
end




-- Throttled log function
local lastPrintTime = 0
function Autofarm.Log(msg)
	if tick() - lastPrintTime >= 1 then

		lastPrintTime = tick()
	end
end



-- Godmode Logic
function Autofarm:ApplyGodmode()
	if not self.godmodeEnabled then return end
	local char = self:GetCharacter()
	if char then
		for _, v in pairs(char:GetDescendants()) do
			if v:IsA("BasePart") then
				v.CanCollide = false
			end
		end
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Name = "GodHumanoid"
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
			humanoid.Health = 100
			humanoid.MaxHealth = 1e6
		end
	end
end


function Autofarm:GetCoinCount()
	return self.currentCoinCount or 0
end
Autofarm.AI.pathSuccessRates = Autofarm.AI.pathSuccessRates or {}
function Autofarm:ShouldUseHybrid(startPos, endPos)
	local delta = (endPos - startPos).Unit * 10
	local rounded = Vector3int16.new(
		math.floor(delta.X + 0.5),
		math.floor(delta.Y + 0.5),
		math.floor(delta.Z + 0.5)
	)
	local key = tostring(rounded)
	local data = self.AI.pathSuccessRates and self.AI.pathSuccessRates[key]

	if not data then return false end -- no history, try normal

	local total = data.success + data.fail
	if total < 4 then return false end -- too few samples

	local failRate = data.fail / total
	return failRate >= 0.4 -- 📈 Consider "risky" if failure > 40%
end

function Autofarm:LogPathResult(startPos, endPos, success, reason)
	if not startPos or not endPos then return end

	local delta = (endPos - startPos).Unit * 10
	local rounded = Vector3int16.new(
		math.floor(delta.X + 0.5),
		math.floor(delta.Y + 0.5),
		math.floor(delta.Z + 0.5)
	)
	local key = tostring(rounded)

	self.AI = self.AI or {}
	self.AI.pathSuccessRates = self.AI.pathSuccessRates or {}
	local data = self.AI.pathSuccessRates[key] or { success = 0, fail = 0, failReasons = {} }
	if success then
		data.success += 1
	else
		data.fail += 1
		data.failReasons[reason or "Unknown"] = (data.failReasons[reason or "Unknown"] or 0) + 1
	end
	self.AI.pathSuccessRates[key] = data
end


function Autofarm:FilterValidCoins(coins)
	local validCoins = {}
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {workspace}
	rayParams.FilterType = Enum.RaycastFilterType.Whitelist
	rayParams.IgnoreWater = true

	for _, coin in ipairs(coins) do
		local ray = workspace:Raycast(coin.Position + Vector3.new(0, 2, 0), Vector3.new(0, -10, 0), rayParams)
		if ray and ray.Instance and coin.Position.Y > 5 then -- prevent underground/void
			table.insert(validCoins, coin)
		end
	end

	return validCoins
end


function Autofarm:GetPathScore(startPos, endPos)
	local key = tostring(Vector3int16.new((endPos - startPos).Unit * 10))
	local entry = self.AI.pathSuccessRates[key]
	if not entry then return 0 end
	return entry.success - entry.fail
end
function Autofarm:_InstantDoubleCoinMove(hrp, coin1, coin2)
	local offsetY = -3 -- Slightly under coin

	local pos1 = Vector3.new(coin1.Position.X, coin1.Position.Y + offsetY, coin1.Position.Z)
	local pos2 = Vector3.new(coin2.Position.X, coin2.Position.Y + offsetY, coin2.Position.Z)

	-- Make sure HumanoidRootPart can trigger touch
	hrp.CanCollide = true

	-- First coin
	hrp.CFrame = CFrame.new(pos1)
	hrp.Velocity = Vector3.new(0, -100, 0)
	task.wait(0.1)

	-- Second coin
	hrp.CFrame = CFrame.new(pos2)
	hrp.Velocity = Vector3.new(0, -100, 0)
	task.wait(0.1)

	-- Let collection system update
	task.wait(5)

	return true
end



--[[
function Autofarm:TweenMove(targetPos)
	local char = self:GetCharacter()
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
	if not (hrp and humanoid and humanoid.Health > 0) then return false end

	local tweenTime = math.clamp((hrp.Position - targetPos).Magnitude / 210, 0.2, 0.6)
	local tween = TweenService:Create(hrp, TweenInfo.new(tweenTime, Enum.EasingStyle.Sine), {
		CFrame = CFrame.new(targetPos)
	})

	local success = false
	tween.Completed:Connect(function() success = true end)
	tween:Play()

	local timeout = tick() + tweenTime + 0.3
	while not success and tick() < timeout do
		task.wait(0.03)
	end

	return success
end

]]
function Autofarm:FarmTwoCoins(hrp, coin1Pos, coin2Pos)
	-- Offset to go under the map
	local offsetY = -5

	-- Adjust both coin positions slightly under the map
	local pos1 = Vector3.new(coin1Pos.X, coin1Pos.Y + offsetY, coin1Pos.Z)
	local pos2 = Vector3.new(coin2Pos.X, coin2Pos.Y + offsetY, coin2Pos.Z)

	-- Instantly teleport to first coin
	hrp.CFrame = CFrame.new(pos1)
	task.wait(0.1) -- short delay for game to register

	-- Instantly teleport to second coin
	hrp.CFrame = CFrame.new(pos2)
	task.wait(0.1) -- short delay again

	-- Delay after farming both
	task.wait(5)
end

function Autofarm:MoveTo(targetPos)
	local maxRetries = 7
	local success = false

	for attempt = 1, maxRetries do
		if not self.isRunning then
			Autofarm.Log("🛑 Bot stopped.")
			break
		end

		local character = self:GetCharacter()
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")

		if not (hrp and humanoid and humanoid.Health > 0) then
			Autofarm.Log("❌ Invalid character state.")
			break
		end

		if (hrp.Position - targetPos).Magnitude < 1 then
			return true -- Already there
		end

		-- ⚠️ Void Check
		if self:IsVoidBelow(targetPos) then
			Autofarm.Log("⛔ Unsafe ground below target. Skipping.")
			break
		end

		-- ⚠️ Avoid Murderer
		if self:ShouldAvoid(targetPos) then
			Autofarm.Log("⚠️ Murderer too close! Aborting move.")
			break
		end


		local mode = self.movementMode
		Autofarm.Log("🚶 Moving using mode:", mode)

		if mode == "Tween" then
			success = self:_TweenMove(hrp, targetPos, humanoid.WalkSpeed)

		elseif mode == "Pathfinding" then
			success = self:_PathfindingMove(hrp, humanoid, targetPos)

		elseif mode == "InstantDoubleCoinTP" then
			local coin1, coin2 = self:GetTwoNearestCoins()
			if coin1 and coin2 then
				success = self:_InstantDoubleCoinMove(hrp, coin1, coin2)
			end


		elseif mode == "InstantHoverTP" then
			success = self:_InstantMove(targetPos)
elseif mode == "_TweenMove" then 
	success = self:_PathfindV2Move(hrp, targetPos)
		elseif mode == "PathfindV2(NEW!)" or mode == "PathfindV2" then
			success = self:_PathfindV2Move(hrp, targetPos)
	elseif mode == "_UndetectedMove"  then
			success = self:_UndetectedMove(hrp, targetPos)

		elseif mode == "HybridMove" then
			success = self:HybridMove(hrp, target)

		elseif mode == "JumpTweenHybrid" or mode == "3clipseHybrid" then
			success = self:JumpTweenHybridMove(targetPos)

		elseif mode == "MapAdaptive" then
			success = self:MapAdaptiveHybridMove(targetPos)

		else
			Autofarm.Log("❓ Unknown movement mode:", mode)
			break
		end

		-- Final arrival check (even if tween "completed")
		if success then
			local dist = (hrp.Position - targetPos).Magnitude
			if dist < 6 then
				Autofarm.Log("✅ Successfully arrived.")
				return true
			else
				Autofarm.Log("⚠️ Close but off-target. Distance: " .. math.floor(dist))
			end
		end

		Autofarm.Log("🔁 Retry attempt:", attempt)
	end

	Autofarm.Log("❌ MoveTo failed after all retries.")
	return false
end


---helper methods

function Autofarm:_TweenMove(hrp, targetPos, walkSpeed)
	local TweenService = game:GetService("TweenService")

	-- Move target position slightly under the map
	local offsetY = -3 -- Small Y offset below map
	local adjustedPos = Vector3.new(targetPos.X, targetPos.Y + offsetY, targetPos.Z)

	-- Increase fallback speed for faster farming
	local speed = (walkSpeed > 0 and walkSpeed or 12)
	local duration = (hrp.Position - adjustedPos).Magnitude / speed

	-- Tween setup
	local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = CFrame.new(adjustedPos) })
	local complete = false
	tween.Completed:Once(function() complete = true end)
	tween:Play()

	-- Wait loop with tighter checking for faster response
	local start = tick()
	while not complete and tick() - start < duration + 0.5 do
		task.wait(0.15) -- faster checking loop
	end

	return complete
end


-- Hook the :Kick() method
local mt = getrawmetatable(game)
setreadonly(mt, false)

local oldNamecall = mt.__namecall
mt.__namecall = newcclosure(function(self, ...)
	local method = getnamecallmethod()
	if method == "Kick" and tostring(...) == "Invalid Position" then
		warn("[Bypassed] Prevented invalid position kick.")
		return
	end
	return oldNamecall(self, ...)
end)


function Autofarm:_PathfindingMove(hrp, humanoid, targetPos)
	local PathfindingService = game:GetService("PathfindingService")

	local function computePath()
		local path = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
			AgentCanClimb = true
		})
		local success, errorMsg = pcall(function()
			path:ComputeAsync(hrp.Position, targetPos)
		end)
		if success and path.Status == Enum.PathStatus.Success then

			return path
		else
			warn("Pathfinding failed: " .. (errorMsg or "Unknown error"))
			return nil
		end
	end

	local path = computePath()
	if not path then
		-- fallback to direct movement
		humanoid:MoveTo(targetPos)
		return humanoid.MoveToFinished:Wait(3)
	end

	local blocked = false
	local conn = path.Blocked:Connect(function()
		blocked = true
	end)

	for _, waypoint in ipairs(path:GetWaypoints()) do
		if blocked then
			-- Try recalculating if path is blocked
			conn:Disconnect()
			return self:_PathfindingMove(hrp, humanoid, targetPos)
		end

		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end

		humanoid:MoveTo(waypoint.Position)
		local reached = humanoid.MoveToFinished:Wait(3)
		if not reached then
			conn:Disconnect()
			return false
		end
	end

	conn:Disconnect()
	return true
end

function Autofarm:DetectMurderer()
	for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
		if plr ~= game.Players.LocalPlayer then
			-- Method 1: Check for Knife in Backpack
			local knife = plr:FindFirstChild("Backpack") and plr.Backpack:FindFirstChild("Knife")
			if knife then return plr end

			-- Method 2: Check if they're holding Knife
			if plr.Character and plr.Character:FindFirstChildOfClass("Tool") and plr.Character:FindFirstChildOfClass("Tool").Name == "Knife" then
				return plr
			end

			-- Method 3: RoleTag in Character
			local tag = plr.Character and plr.Character:FindFirstChild("Role")
			if tag and tag.Value == "Murderer" then
				return plr
			end

			-- Method 4: ReplicatedStorage value
			local replicatedRole = game.ReplicatedStorage:FindFirstChild("Roles") and game.ReplicatedStorage.Roles:FindFirstChild(plr.Name)
			if replicatedRole and replicatedRole.Value == "Murderer" then
				return plr
			end
		end
	end
	return nil
end
function Autofarm:GetMurdererHRP()
	if not self.DetectMurderer then return nil end

	local murderer = self:DetectMurderer()
	if not murderer or not murderer.Character then return nil end

	local hrp = murderer.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		return hrp, murderer
	end

	return nil
end

local function getSafeFleePosition(origin, direction, distance)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = {workspace:FindFirstChild("CoinContainer"), origin.Parent}
	rayParams.IgnoreWater = true

	local targetPos = origin.Position + direction.Unit * distance
	local result = workspace:Raycast(origin.Position, direction.Unit * distance, rayParams)

	if result then
		-- Flee up slightly or sideways if blocked
		return origin.Position + (direction.Unit * (distance * 0.5)) + Vector3.new(0, 5, 0)
	end

	return targetPos
end
function Autofarm:GetMurderer()
	for _, player in pairs(game.Players:GetPlayers()) do
		if player ~= game.Players.LocalPlayer then
			local hasKnife = player.Backpack:FindFirstChild("Knife")
			local holdingKnife = player.Character and player.Character:FindFirstChild("Knife")
			if hasKnife or holdingKnife then
				return player
			end
		end
	end
	return nil
end

function Autofarm:ShouldAvoid(pos)
	local murderer = self:GetMurderer()
	if murderer and murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart") then
		return (murderer.Character.HumanoidRootPart.Position - pos).Magnitude < 20
	end
	return false
end


-- New Autofarm movement mode: Instant teleport with delay and hover under map
function Autofarm:GetRootPart()
	local character = game.Players.LocalPlayer.Character
	if character then
		return character:FindFirstChild("HumanoidRootPart")
	end
	return nil
end

function Autofarm:_InstantMove(hrp, coinPart)
	if not hrp or typeof(coinPart) ~= "Instance" or not coinPart:IsA("BasePart") then
		return false
	end

	local safeOffset = Vector3.new(0, 2.5, 0)
	local targetPos = coinPart.Position + safeOffset

	-- Anti-gravity float
	local float = Instance.new("BodyVelocity")
	float.Name = "AntiGravity"
	float.MaxForce = Vector3.new(1e6, 1e6, 1e6)
	float.Velocity = Vector3.new(0, 0, 0) -- hold in place
	float.P = 50000
	float.Parent = hrp

	-- Move player just slightly out of view (not deep under map)
	local hoverPos = Vector3.new(hrp.Position.X, hrp.Position.Y - 30, hrp.Position.Z)
	hrp.CFrame = CFrame.new(hoverPos)

	-- Optional: escape from threats if function exists
	if typeof(self.escapeFromThreat) == "function" then
		pcall(function()
			self:escapeFromThreat(hrp, float)
		end)
	end

	-- Short pause to simulate "safe travel"
	task.wait(3)

	-- Teleport directly onto coin
	hrp.CFrame = CFrame.new(targetPos)

	-- Cleanup
	float:Destroy()

	return true
end

-- define once outside so it’s not recreated every move
function Autofarm:escapeFromThreat(hrp, float, ESCAPE_DISTANCE)
	local murderer = self:GetMurderer()
	if not (murderer and murderer.Character) then return end
	local hrpMurderer = murderer.Character:FindFirstChild("HumanoidRootPart")
	if not hrpMurderer then return end

	local distance = (hrp.Position - hrpMurderer.Position).Magnitude
	if distance > 15 then return end

	-- LOS check
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = { hrp.Parent, murderer.Character }
	local dir = (hrpMurderer.Position - hrp.Position).Unit * distance
	local hit = workspace:Raycast(hrp.Position, dir, rayParams)
	local canSee = not hit or (hit.Instance and hit.Instance:IsDescendantOf(murderer.Character))

	if distance < 15 and canSee then
		local awayDir = (hrp.Position - hrpMurderer.Position).Unit
		local escapeTarget = hrp.Position + awayDir * ESCAPE_DISTANCE
		local safeY = hrp.Position.Y + 2

		if self.Log then self.Log("🏃 Escaping murderer!") end

		local TweenService = game:GetService("TweenService")
		local dur = (hrp.Position - escapeTarget).Magnitude / 25
		local tween = TweenService:Create(hrp, TweenInfo.new(dur, Enum.EasingStyle.Linear), {
			CFrame = CFrame.new(escapeTarget.X, safeY, escapeTarget.Z)
		})
		tween:Play()
	end
end

-- make sure Autofarm table exists


-- make sure Settings exists with defaults
Autofarm.Settings = Autofarm.Settings or {
	BaseSpeed = 28, -- default
	SlowSpeed = 26, -- default
}

-- CONFIG (read from settings if available)
local CFG = {
	FLOAT_HEIGHT = 2,
	FLOAT_SPEED = 28,
	BASE_SPEED = Autofarm.Settings.BaseSpeed or 28,
	SLOW_SPEED = Autofarm.Settings.SlowSpeed or 25,
	SLOW_RADIUS = 12,
	PROXIMITY_THRESHOLD = 5,
	FINAL_SWOOP_OFFSET = 1.5,
	MOVE_TIMEOUT = 6,
}
-- === SETTINGS FRAME (docked to right of main frame) ===
local settingsFrame = Instance.new("Frame")
settingsFrame.Size = UDim2.new(0, frame.Size.X.Offset, 0, frame.Size.Y.Offset)
settingsFrame.Position = UDim2.new(1, 10, 0, 0)
settingsFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
settingsFrame.BorderSizePixel = 0
settingsFrame.Visible = false
settingsFrame.Parent = frame
Instance.new("UICorner", settingsFrame).CornerRadius = UDim.new(0, 10)

-- === Title Bar ===
local titleBar = Instance.new("TextLabel", settingsFrame)
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
titleBar.Text = "⚙ SETTINGS ⚙"
titleBar.Font = Enum.Font.GothamBold
titleBar.TextSize = 16
titleBar.TextColor3 = Color3.fromRGB(255, 0, 255)
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

-- === Disclaimer ===
local disclaimer = Instance.new("TextLabel", settingsFrame)
disclaimer.Size = UDim2.new(1, -20, 0, 20)
disclaimer.Position = UDim2.new(0, 10, 0, 35)
disclaimer.BackgroundTransparency = 1
disclaimer.Text = "🚧 Experimental Features 🚧"
disclaimer.Font = Enum.Font.GothamBold
disclaimer.TextSize = 14
disclaimer.TextColor3 = Color3.fromRGB(255, 200, 0)
disclaimer.TextWrapped = true
disclaimer.TextXAlignment = Enum.TextXAlignment.Center

-- === Performance Toggle ===
local performanceToggle = Instance.new("TextButton", settingsFrame)
performanceToggle.Size = UDim2.new(1, -20, 0, 35)
performanceToggle.Position = UDim2.new(0, 10, 0, 60)
performanceToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
performanceToggle.Font = Enum.Font.GothamBold
performanceToggle.TextSize = 14
Instance.new("UICorner", performanceToggle).CornerRadius = UDim.new(0, 6)

-- Load last state
if Autofarm.lowEndMode then
	performanceToggle.Text = "PERFORMANCE: ON"
	performanceToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
	performanceToggle.TextColor3 = Color3.new(0, 0, 0)
else
	performanceToggle.Text = "PERFORMANCE: OFF"
	performanceToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
	performanceToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
end

performanceToggle.MouseButton1Click:Connect(function()
	Autofarm.lowEndMode = not Autofarm.lowEndMode

	if Autofarm.lowEndMode then
		performanceToggle.Text = "PERFORMANCE: ON"
		performanceToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
		performanceToggle.TextColor3 = Color3.new(0, 0, 0)
		Autofarm:Log("Low-End Performance Mode ENABLED.")
		Autofarm.UpdateInterval = 0.3
		Autofarm.SkipExtraChecks = true
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
	else
		performanceToggle.Text = "PERFORMANCE: OFF"
		performanceToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		performanceToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
		Autofarm:Log("Low-End Performance Mode DISABLED.")
		Autofarm.UpdateInterval = 0.1
		Autofarm.SkipExtraChecks = false
		settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
	end

	Autofarm:SaveConfig()
end)

-- === Speed Slider ===
local sliderLabel = Instance.new("TextLabel", settingsFrame)
sliderLabel.Size = UDim2.new(1, -20, 0, 20)
sliderLabel.Position = UDim2.new(0, 10, 0, 105)
sliderLabel.BackgroundTransparency = 1
sliderLabel.Text = "Farm Speed: " .. (Autofarm.Settings.BaseSpeed or 25)
sliderLabel.Font = Enum.Font.GothamBold
sliderLabel.TextSize = 14
sliderLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
sliderLabel.TextXAlignment = Enum.TextXAlignment.Left

local sliderFrame = Instance.new("Frame", settingsFrame)
sliderFrame.Size = UDim2.new(1, -20, 0, 20)
sliderFrame.Position = UDim2.new(0, 10, 0, 130)
sliderFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
sliderFrame.BorderSizePixel = 0

local sliderBar = Instance.new("Frame", sliderFrame)
sliderBar.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
sliderBar.BorderSizePixel = 0

local sliderButton = Instance.new("TextButton", sliderFrame)
sliderButton.Size = UDim2.new(0, 20, 1, 0)
sliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sliderButton.Text = ""

local dragging = false
sliderButton.MouseButton1Down:Connect(function() dragging = true end)
UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)

local function updateSliderFromMouse()
	local mouseX = UIS:GetMouseLocation().X
	local sliderX, sliderW = sliderFrame.AbsolutePosition.X, sliderFrame.AbsoluteSize.X
	local pos = math.clamp(mouseX - sliderX, 0, sliderW)
	sliderButton.Position = UDim2.new(0, pos - 10, 0, 0)
	sliderBar.Size = UDim2.new(0, pos, 1, 0)
	local value = math.floor((pos / sliderW) * 24)
	Autofarm.Settings.BaseSpeed = value
	sliderLabel.Text = "Farm Speed: " .. value
	Autofarm:SaveConfig()
end

RunService.RenderStepped:Connect(function()
	if dragging then updateSliderFromMouse() end
	local sliderW = sliderFrame.AbsoluteSize.X
	local value = math.clamp(Autofarm.Settings.BaseSpeed or 22, 0, 24)
	local pos = (value / 24) * sliderW
	sliderButton.Position = UDim2.new(0, pos - 10, 0, 0)
	sliderBar.Size = UDim2.new(0, pos, 1, 0)
	sliderLabel.Text = "Farm Speed: " .. value
end)
-- === Version Launcher ===
local versionLabel = Instance.new("TextLabel", settingsFrame)
versionLabel.Size = UDim2.new(1, -20, 0, 20)
versionLabel.Position = UDim2.new(0, 10, 0, 165) -- moved lower
versionLabel.BackgroundTransparency = 1
versionLabel.Text = "Select Version:"
versionLabel.Font = Enum.Font.GothamBold
versionLabel.TextSize = 14
versionLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
versionLabel.TextXAlignment = Enum.TextXAlignment.Left

local currentVersion = Autofarm.Settings.Version or "v5.7,9 (Stable)"
local versionDropdown = Instance.new("TextButton", settingsFrame)
versionDropdown.Size = UDim2.new(1, -20, 0, 30)
versionDropdown.Position = UDim2.new(0, 10, 0, 190)
versionDropdown.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
versionDropdown.Text = "Current: " .. currentVersion
versionDropdown.Font = Enum.Font.GothamBold
versionDropdown.TextSize = 14
versionDropdown.TextColor3 = Color3.fromRGB(240, 240, 240)
Instance.new("UICorner", versionDropdown).CornerRadius = UDim.new(0, 6)

local versionList = Instance.new("Frame", settingsFrame)
versionList.Size = UDim2.new(1, -20, 0, 90)
versionList.Position = UDim2.new(0, 10, 0, 225)
versionList.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
versionList.BorderSizePixel = 0
versionList.Visible = false
Instance.new("UICorner", versionList).CornerRadius = UDim.new(0, 6)

local versions = {"v5.7,9 (Stable)", "v6.0P (Performance)", "v7.0 (Beta)"}
for i, vName in ipairs(versions) do
	local btn = Instance.new("TextButton", versionList)
	btn.Size = UDim2.new(1, -10, 0, 25)
	btn.Position = UDim2.new(0, 5, 0, (i - 1) * 30 + 5)
	btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
	btn.Text = vName
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 14
	btn.TextColor3 = Color3.fromRGB(240, 240, 240)
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	btn.MouseButton1Click:Connect(function()
		currentVersion = vName
		Autofarm.Settings.Version = vName
		versionDropdown.Text = "Current: " .. vName
		versionList.Visible = false
		Autofarm:SaveConfig()
		Autofarm:Log("🔀 Switched to " .. vName)
	end)
end
versionDropdown.MouseButton1Click:Connect(function()
	versionList.Visible = not versionList.Visible

	-- Move disclaimer under whichever is visible
	if versionList.Visible then
		versionDisclaimer.Position = UDim2.new(0, 10, 0, 225 + 95) -- under expanded list
	else
		versionDisclaimer.Position = UDim2.new(0, 10, 0, 225 + 5) -- just under dropdown
	end
end)

local versionDisclaimer = Instance.new("TextLabel", settingsFrame)
versionDisclaimer.Size = UDim2.new(1, -20, 0, 55) -- taller (was 35)
versionDisclaimer.Position = UDim2.new(0, 10, 0, 320)
versionDisclaimer.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
versionDisclaimer.BackgroundTransparency = 0.1
versionDisclaimer.Text = "⚠ These version options are placeholders and do not yet change functionality ⚠"
versionDisclaimer.Font = Enum.Font.GothamBold
versionDisclaimer.TextSize = 14
versionDisclaimer.TextColor3 = Color3.fromRGB(255, 220, 0)
versionDisclaimer.TextStrokeTransparency = 0.3
versionDisclaimer.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
versionDisclaimer.TextWrapped = true
versionDisclaimer.TextXAlignment = Enum.TextXAlignment.Center
versionDisclaimer.TextYAlignment = Enum.TextYAlignment.Center

-- add rounded corners
Instance.new("UICorner", versionDisclaimer).CornerRadius = UDim.new(0, 8)

-- optional: let text auto-fit the height
local textConstraint = Instance.new("UITextSizeConstraint", versionDisclaimer)
textConstraint.MaxTextSize = 16 -- prevent it from shrinking too small


-- round corners
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = settingsFrame


-- StealthFast movement: very fast, but broken into micro-hops to avoid anticheat
function Autofarm:_StealthFastMove(hrp, targetPos)

	if not hrp or not targetPos then return false end

	local totalDist = (hrp.Position - targetPos).Magnitude
	if totalDist < 2 then return true end

	local steps = math.clamp(math.floor(totalDist / 5), 5, 25) -- 5–25 hops depending on distance
	local dir = (targetPos - hrp.Position).Unit

	for i = 1, steps do
		if not hrp.Parent then return false end

		-- Calculate next hop
		local stepDist = totalDist / steps
		local nextPos = hrp.Position + (dir * stepDist)

		-- Smooth "hop"
		hrp.CFrame = CFrame.new(nextPos)

		-- Small delay to look like legit movement
		RunService.Heartbeat:Wait()
	end

	-- Final snap to target
	hrp.CFrame = CFrame.new(targetPos)
	return true
end

-- === PathfindV2Move with safe coin validation & auto retarget ===
function Autofarm:_PathfindV2Move(hrp, target)
    local TweenService = game:GetService("TweenService")
    local RunService = game:GetService("RunService")
    local PathfindingService = game:GetService("PathfindingService")
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer

    -- If we're paused, do nothing except keep countdown text updated
    if self:IsPaused() then
        if self._pausedUntil and self.StatusLabel then
            local remain = math.max(0, math.ceil(self._pausedUntil - tick()))
            self.StatusLabel.Text = (remain > 0)
                and ("Status: Farmer Restarted (%ds)"):format(remain)
                or "Status: Farmer Restarted"
        end
        return false, "paused"
    end

    -- ========== Candy GUI helpers ==========
    self._candyState = self._candyState or { last = 0 }

    local function getCandyProgress(plr)
        local gui = plr:FindFirstChild("PlayerGui");            if not gui then return 0, 40, false end
        local mainGui = gui:FindFirstChild("MainGUI");           if not mainGui then return 0, 40, false end
        local gameGui = mainGui:FindFirstChild("Game");          if not gameGui then return 0, 40, false end
        local coinBags = gameGui:FindFirstChild("CoinBags");     if not coinBags then return 0, 40, false end
        local container = coinBags:FindFirstChild("Container");  if not container then return 0, 40, false end
        local candy = container:FindFirstChild("Candy");         if not candy then return 0, 40, false end

        local cur, max
        for _,d in ipairs(candy:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local a,b = tostring(d.Text or ""):match("(%d+)%s*/%s*(%d+)")
                if a and b then cur, max = tonumber(a), tonumber(b); break end
            end
        end
        max = tonumber(max) or 40
        cur = tonumber(cur) or 0
        if cur > max then cur = max end

        local fullIcon = candy:FindFirstChild("FullBagIcon")
        local isFull = (fullIcon and fullIcon.Visible == true) or (cur >= max)
        return cur, max, isFull
    end

    local function hitExactly10(plr)
        local cur, max, isFull = getCandyProgress(plr)
        local last = self._candyState.last or 0
        local fired = (cur == 10 and last ~= 10) or (last < 10 and cur > 10)
        self._candyState.last = cur
        return fired, cur, max, isFull
    end

    -- ========== Your original config / move logic ==========
    local config = {
        baseSpeed = self.Settings.BaseSpeed or 28,
        floatHeight = self.Settings.FloatHeight or -5,
        hoverHeight = self.Settings.HoverHeight or -5,
        maxDistance = self.Settings.MaxDistance or 2000,
        timeout = self.Settings.Timeout or 8,
        maxRetries = self.Settings.MaxRetries or 5,
        targetTime = self.Settings.TargetTime,
        usePathfinding = self.Settings.UsePathfinding or false,
        optimizeFloat = self.Settings.OptimizeFloat or true,
        minTweenDuration = self.Settings.MinTweenDuration or 0.1,
        maxTweenDuration = self.Settings.MaxTweenDuration or 10
    }

    local function safeGetPosition(obj)
        if not obj then return nil end
        local ok, result = pcall(function()
            if typeof(obj) == "Vector3" then
                return obj
            elseif typeof(obj) == "Instance" then
                if obj:IsA("BasePart") and obj:IsDescendantOf(workspace) and obj.Parent then
                    return obj.Position
                elseif obj:IsA("Model") and obj.PrimaryPart and obj:IsDescendantOf(workspace) then
                    return obj.PrimaryPart.Position
                end
            end
            return nil
        end)
        return ok and result or nil
    end

    -- Float (your style)
    local float = hrp:FindFirstChild("FloatVelocity")
    if not float then
        float = Instance.new("BodyVelocity")
        float.MaxForce = Vector3.new(0, math.huge, 0)
        float.Name = "FloatVelocity"
        float.Parent = hrp
    end
    float.Velocity = Vector3.zero

    local lastFloatUpdate = 0
    local function updateFloat()
        local now = tick()
        if config.optimizeFloat and (now - lastFloatUpdate) < 0.1 then return end
        lastFloatUpdate = now
        local currentY = hrp.Position.Y
        local targetY = currentY + config.floatHeight
        local deltaY = targetY - currentY
        local velocity = math.clamp(deltaY * 3, -30, 30)
        float.Velocity = Vector3.new(0, velocity, 0)
    end

    local function calculateSpeed(distance)
        local speed = config.baseSpeed
        if config.targetTime and self.RoundStartTime then
            local elapsed = tick() - self.RoundStartTime
            local remaining = config.targetTime - elapsed
            if remaining > 0 and remaining < 20 then
                local urgency = math.max(0, (20 - remaining) / 20)
                local boostFactor = 1 + (urgency * urgency * 2)
                speed = config.baseSpeed * math.min(boostFactor, 4)
            end
        end
        if distance < 10 then
            speed = speed * 0.7
        elseif distance > 100 then
            speed = speed * 1.3
        end
        return speed
    end

    local function getPathWaypoints(startPos, endPos)
        if not config.usePathfinding then
            return {endPos}
        end
        local ok, result = pcall(function()
            local path = PathfindingService:CreatePath({
                AgentRadius = 3,
                AgentHeight = 6,
                AgentCanJump = true,
                WaypointSpacing = 8
            })
            path:ComputeAsync(startPos, endPos)
            if path.Status == Enum.PathStatus.Success then
                local waypoints = path:GetWaypoints()
                local positions = {}
                for i = 2, #waypoints do
                    table.insert(positions, waypoints[i].Position + Vector3.new(0, config.hoverHeight, 0))
                end
                return #positions > 0 and positions or {endPos}
            end
            return {endPos}
        end)
        return ok and result or {endPos}
    end

    local function tweenToTarget(targetPos, targetInstance)
        local waypoints = getPathWaypoints(hrp.Position, targetPos)
        for i, waypointPos in ipairs(waypoints) do
            local currentPos = hrp.Position
            local distance = (currentPos - waypointPos).Magnitude
            if distance < 2 then continue end
            if i == #waypoints and not safeGetPosition(targetInstance) then
                return "retry"
            end

            local speed = calculateSpeed(distance)
            local duration = math.clamp(distance / speed, config.minTweenDuration, config.maxTweenDuration)

            local tweenInfo = TweenInfo.new(
                duration,
                distance < 10 and Enum.EasingStyle.Quad or Enum.EasingStyle.Linear,
                Enum.EasingDirection.Out
            )
            local tween = TweenService:Create(hrp, tweenInfo, { CFrame = CFrame.new(waypointPos) })
            tween:Play()

            local startTime = tick()
            local lastDistanceCheck = 0
            local stuckCounter = 0

            while tween.PlaybackState == Enum.PlaybackState.Playing do
                local now = tick()
                if now - startTime > config.timeout then
                    tween:Cancel()
                    return "timeout"
                end
                if now - lastDistanceCheck > 0.5 then
                    if i == #waypoints and not safeGetPosition(targetInstance) then
                        tween:Cancel()
                        return "retry"
                    end
                    local currentDistance = (hrp.Position - waypointPos).Magnitude
                    if currentDistance > distance * 0.9 then
                        stuckCounter = stuckCounter + 1
                        if stuckCounter > 3 then
                            tween:Cancel()
                            return "stuck"
                        end
                    else
                        stuckCounter = 0
                    end
                    lastDistanceCheck = now
                end
                RunService.Heartbeat:Wait()
            end

            local finalDistance = (hrp.Position - waypointPos).Magnitude
            if finalDistance > 5 then
                return "incomplete"
            end
        end
        return "success"
    end

    -- Main execution
    local floatConnection = RunService.Heartbeat:Connect(updateFloat)
    local attempts, success, lastError = 0, false, nil

    while not success and attempts < config.maxRetries do
        attempts += 1
        if self.StatusLabel then
            self.StatusLabel.Text = string.format("🔄 Moving... (Attempt %d/%d)", attempts, config.maxRetries)
        end

        local targetPos = safeGetPosition(target)
        if not targetPos then
            target = self:GetClosestCoin() and self:GetClosestCoin() or nil
            if not target then lastError = "No valid targets found"; break end
            continue
        end

        local distance = (hrp.Position - targetPos).Magnitude
        if distance > config.maxDistance then
            lastError = "Target too far away"
            target = self:GetClosestCoin() and self:GetClosestCoin() or nil
            if not target then break end
            continue
        end

        local finalTargetPos = targetPos + Vector3.new(0, config.hoverHeight, 0)
        local result = tweenToTarget(finalTargetPos, target)

        if result == "success" then
            -- After a successful coin: check candy and trigger pause at 10 / full (40)
            local hit10, cur, max, isFull = hitExactly10(player)
            if hit10 or isFull or (cur >= max) then
                self:Pause(5, hrp)            -- moves under map + starts countdown
                if floatConnection then floatConnection:Disconnect() end
                pcall(function() if float and float.Parent then float:Destroy() end end)
                return false, "restart"       -- exit so outer loop won't chase new coins
            end

            success = true
            if self.StatusLabel then self.StatusLabel.Text = "✅ Target reached!" end

        elseif result == "retry" or result == "timeout" or result == "stuck" then
            lastError = result
            target = self:GetClosestCoin() and self:GetClosestCoin() or nil
            if not target then lastError = "No more targets available"; break end
        end

        if not success and attempts < config.maxRetries then
            RunService.Heartbeat:Wait()
        end
    end

    if floatConnection then floatConnection:Disconnect() end
    pcall(function() if float and float.Parent then float:Destroy() end end)

    if not success and self.StatusLabel then
        self.StatusLabel.Text = string.format("❌ Failed: %s", lastError or "Movement failed")
    end

    return success, lastError
end

-- === Autofarm Pause/Resume API (add once to your Autofarm module) ===
function Autofarm:IsPaused()
    -- auto-expire the pause window
    if self.Paused and self._pausedUntil and tick() >= self._pausedUntil then
        self.Paused = false
        self._pausedUntil = nil
        if self.StatusLabel then
            self.StatusLabel.Text = "Status: Farmer Restarted"
        end
    end
    return self.Paused == true
end

function Autofarm:Pause(seconds, hrp)
    local TweenService = game:GetService("TweenService")
    local RunService = game:GetService("RunService")

    if self.Paused then return end
    seconds = tonumber(seconds) or 5

    self.Paused = true
    self._pausedUntil = tick() + seconds

    -- Move under the map once (if we have HRP)
    if hrp and hrp.Parent then
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { hrp.Parent }

        local origin = hrp.Position + Vector3.new(0, 5, 0)
        local rc = workspace:Raycast(origin, Vector3.new(0, -1000, 0), params)
        local targetY = rc and rc.Position and (rc.Position.Y - 40) or (hrp.Position.Y - 60)

        TweenService:Create(
            hrp,
            TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            { CFrame = CFrame.new(hrp.Position.X, targetY, hrp.Position.Z) }
        ):Play()
    end

    -- Countdown updater
    task.spawn(function()
        while self.Paused and tick() < (self._pausedUntil or 0) do
            local remain = math.max(0, math.ceil((self._pausedUntil or 0) - tick()))
            if self.StatusLabel then
                self.StatusLabel.Text = (remain > 0)
                    and ("Status: Farmer Restarted (%ds)"):format(remain)
                    or "Status: Farmer Restarted"
            end
            RunService.Heartbeat:Wait()
        end
        -- finalize
        self.Paused, self._pausedUntil = false, nil
        if self.StatusLabel then
            self.StatusLabel.Text = "Status: Farmer Restarted"
        end
    end)
end

function Autofarm:Resume()
    self.Paused = false
    self._pausedUntil = nil
    if self.StatusLabel then
        self.StatusLabel.Text = "Status: Farmer Restarted"
    end
end



local TweenService = game:GetService("TweenService")

function Autofarm:_TweenMove(hrp, targetPos, speed)
    if not hrp or not targetPos then return false, "No HRP/Target" end

    -- pick speed
    local distance = (targetPos - hrp.Position).Magnitude
    local duration = distance / (speed or (self.Settings.MaxSpeed or 22))

    -- safe guard for too-fast tweens
    if duration < 0.05 then
        hrp.CFrame = CFrame.new(targetPos)
        return true, "Instant"
    end

    -- build tween
    local tweenInfo = TweenInfo.new(
        duration,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.InOut,
        0, false, 0
    )
    local tween = TweenService:Create(hrp, tweenInfo, {
        CFrame = CFrame.new(targetPos)
    })

    tween:Play()
    tween.Completed:Wait()

    return true, "Tweened"
end

function Autofarm:_UndetectedMove(hrp, target)
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")

    local config = {
        maxSpeed = self.Settings.MaxSpeed or 25,
        minSpeed = self.Settings.MinSpeed or 20,
        pauseChance = self.Settings.PauseChance or 0.002,
        reactionTime = self.Settings.ReactionTime or 0.001,
        maxDistance = self.Settings.MaxDistance or 2500,
        timeout = self.Settings.Timeout or 2,
        grabRadius = 1,             -- bigger for underfloor
        chainGrabRadius = 15,       -- sweep more aggressively
        recheckInterval = 0.07,
        retargetInterval = 0.01,
        underOffset = self.Settings.UnderOffset or 6, -- how far under map
        boostMultiplier = 2.7,
    }

    local boostMode = false
    local positionCache, cacheTimeout = {}, 0.2

    local function safeGetPosition(obj)
        if not obj then return nil end
        local objId = tostring(obj)
        local cached = positionCache[objId]
        if cached and (os.clock() - cached.time) < cacheTimeout then
            return cached.position
        end
        local ok, result = pcall(function()
            if typeof(obj) == "Vector3" then
                return obj
            elseif typeof(obj) == "Instance" then
                if obj:IsA("BasePart") and obj:IsDescendantOf(Workspace) then
                    return obj.Position
                elseif obj:IsA("Model") and obj.PrimaryPart then
                    return obj.PrimaryPart.Position
                end
            end
            return nil
        end)
        if ok and result then
            positionCache[objId] = {position = result, time = os.clock()}
        end
        return ok and result or nil
    end

    local function glideMove(initialTarget, urgency)
    local targetObj = initialTarget
    local coinPos = safeGetPosition(targetObj)
    if not coinPos then return "invalid" end

    -- 👇 Use raycast to find the floor under the coin
    local ray = Ray.new(coinPos + Vector3.new(0, 5, 0), Vector3.new(0, -20, 0))
    local part, floorPos = workspace:FindPartOnRay(ray, hrp.Parent)
    local floorY = floorPos and floorPos.Y or coinPos.Y

    -- stay slightly under floor but not too deep under the coin
    local yOffset = math.min(config.underOffset, math.max(2, coinPos.Y - floorY - 0.5))
    local targetPos = Vector3.new(coinPos.X, coinPos.Y - yOffset, coinPos.Z)

    local baseGrab = config.grabRadius
    local startTime, lastCheck = os.clock(), 0
    local startPos = hrp.Position
    local speed = math.clamp(
        config.maxSpeed * (1 + urgency * 0.6) * (boostMode and config.boostMultiplier or 1),
        config.minSpeed,
        config.maxSpeed * (boostMode and config.boostMultiplier or 1)
    )
    local duration = (targetPos - startPos).Magnitude / speed

    task.wait(config.reactionTime)

    while os.clock() - startTime < duration do
        local now = os.clock()

        -- recheck
        if now - lastCheck > config.recheckInterval then
            lastCheck = now
            coinPos = safeGetPosition(targetObj)
            if not coinPos then
                boostMode = true
                return "lost"
            end
            -- recompute floor-safe target
            local ray2 = Ray.new(coinPos + Vector3.new(0, 5, 0), Vector3.new(0, -20, 0))
            local _, floor2 = workspace:FindPartOnRay(ray2, hrp.Parent)
            local floorY2 = floor2 and floor2.Y or coinPos.Y
            yOffset = math.min(config.underOffset, math.max(2, coinPos.Y - floorY2 - 0.5))
            targetPos = Vector3.new(coinPos.X, coinPos.Y - yOffset, coinPos.Z)
        end

        -- move
        local progress = math.clamp((now - startTime) / duration, 0, 1)
        local newPos = startPos:Lerp(targetPos, progress)
        hrp.CFrame = CFrame.new(newPos, targetPos)

        -- success: actually overlap
        if (hrp.Position - coinPos).Magnitude < baseGrab then
            boostMode = false
            return "success"
        end

        RunService.Heartbeat:Wait()
    end

    return "timeout"
end


    local function executeMovement(targetInstance)
        local coinPos = safeGetPosition(targetInstance)
        if not coinPos then return false, "Invalid" end
        if (hrp.Position - coinPos).Magnitude > config.maxDistance then
            return false, "Too far"
        end

        local urgency = 0
        if self.RoundStartTime and self.Settings.TargetTime then
            urgency = math.clamp((os.clock() - self.RoundStartTime) / self.Settings.TargetTime, 0, 1)
        end

        local result = glideMove(targetInstance, urgency)
        if result == "timeout" then return false, "Timeout" end
        if result == "lost" then return false, "Lost" end
        if result == "invalid" then return false, "Invalid" end
        return true, "Done"
    end

    -- main
    if self.StatusLabel then self.StatusLabel.Text = "✨ Underfloor Glide" end
    local attempts, success, lastError = 0, false, nil
    while not success and attempts < 5 do
        attempts += 1
        local currentTarget = safeGetPosition(target) and target or self:GetClosestCoin()
        if not currentTarget then
            lastError = "No targets"
            break
        end

        local ok, err = executeMovement(currentTarget)
        if ok then
            success = true
            if self.StatusLabel then self.StatusLabel.Text = "✅ Coin Collected (Underfloor)" end
        else
            lastError = err
        end
    end

    if not success and self.StatusLabel then
        self.StatusLabel.Text = "❌ Failed: " .. (lastError or "Unknown")
    end
    return success, lastError
end




-- ✅ Missing Helpers (add these once in your Autofarm module)

-- Get the closest coin to HRP
function Autofarm:GetClosestCoin()
    local player = game.Players.LocalPlayer
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local closest, shortestDist = nil, math.huge
    local container = workspace:FindFirstChild("Coins") or workspace

    for _, coin in ipairs(container:GetDescendants()) do
        if coin:IsA("BasePart") and coin.Name == "Coin" then
            local dist = (coin.Position - hrp.Position).Magnitude
            if dist < shortestDist then
                closest, shortestDist = coin, dist
            end
        end
    end

    return closest
end

-- Count nearby coins within radius
function Autofarm:GetNearbyTargetCount(radius)
    radius = radius or 30
    local player = game.Players.LocalPlayer
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0 end

    local count = 0
    local container = workspace:FindFirstChild("Coins") or workspace

    for _, coin in ipairs(container:GetDescendants()) do
        if coin:IsA("BasePart") and coin.Name == "Coin" then
            if (coin.Position - hrp.Position).Magnitude <= radius then
                count += 1
            end
        end
    end
    return count
end

-- Optional: return all coins (for debugging or multi-target systems)
function Autofarm:GetAllTargets()
    local container = workspace:FindFirstChild("Coins") or workspace
    local coins = {}
    for _, coin in ipairs(container:GetDescendants()) do
        if coin:IsA("BasePart") and coin.Name == "Coin" then
            table.insert(coins, coin)
        end
    end
    return coins
end



function Autofarm:HybridMove(hrp, target)
	local TweenService = game:GetService("TweenService")


	-- === Safe Position Resolver ===
	local function safeGetPosition(t)
		if not t then return nil end
		if typeof(t) == "Vector3" then
			return t
		elseif typeof(t) == "Instance" then
			if t:IsA("BasePart") and t:IsDescendantOf(workspace) then
				return t.Position
			elseif t:IsA("Model") and t.PrimaryPart and t:IsDescendantOf(workspace) then
				return t.PrimaryPart.Position
			end
		end
		return nil
	end
-- ✅ Count coins within a given radius of the player
function Autofarm:GetNearbyTargetCount(radius)
    radius = radius or 30 -- default radius if not provided

    local player = game.Players.LocalPlayer
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0 end

    local count = 0
    -- ⚡ If coins are stored in workspace.Coins, use that for performance
    local coinContainer = workspace:FindFirstChild("Coins") or workspace

    for _, coin in ipairs(coinContainer:GetDescendants()) do
        if coin:IsA("BasePart") and coin.Name == "Coin" then
            local dist = (coin.Position - hrp.Position).Magnitude
            if dist <= radius then
                count += 1
            end
        end
    end

    return count
end

	-- === Ground Check ===
	local function isGrounded(pos)
		local ray = Ray.new(pos + Vector3.new(0, 2, 0), Vector3.new(0, -6, 0))
		local hit = workspace:FindPartOnRay(ray)
		return hit and hit.CanCollide
	end

	-- === Clamp Position to Map Bounds ===
	local function clampPosition(pos)
		return Vector3.new(
			math.clamp(pos.X, -500, 500),
			pos.Y,
			math.clamp(pos.Z, -500, 500)
		)
	end

	-- === Obstacle Detection ===
	local function isPathClear(hrp, targetPos)
		local direction = (targetPos - hrp.Position)
		local ray = Ray.new(hrp.Position, direction.Unit * direction.Magnitude)
		local hit = workspace:FindPartOnRay(ray, hrp.Parent)
		return not hit
	end

	-- === Tween Movement ===
	local function tweenMove(hrp, targetPos, targetInstance)
		local dist = (hrp.Position - targetPos).Magnitude
		if dist < 0.5 then return true end

		local speed = Autofarm.Settings.BaseSpeed or 25
		local duration = math.clamp(dist / speed, 0.03, 0.3)

		local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
			CFrame = CFrame.new(targetPos)
		})
		tween:Play()

		local start = tick()
		local frameCounter = 0

		while tween.PlaybackState == Enum.PlaybackState.Playing do
			frameCounter += 1
			if frameCounter % 3 == 0 and not safeGetPosition(targetInstance) then
				tween:Cancel()
				return false
			end
			if math.random() < 0.05 then
				hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(math.random(-2, 2)), 0)
			end
			if tick() - start > 6 then
				tween:Cancel()
				return false
			end
			RunService.Heartbeat:Wait()
		end
		return true
	end

	-- === Safe Teleport ===
	local function safeTeleport(hrp, targetPos)
		if not isGrounded(targetPos) then return false end
		local safePos = clampPosition(targetPos + Vector3.new(0, 2, 0))
		hrp.CFrame = CFrame.new(safePos)
		return true
	end

	-- === Float Stabilizer ===
	local float = hrp:FindFirstChild("FloatVelocity") or Instance.new("BodyVelocity")
	float.MaxForce = Vector3.new(0, math.huge, 0)
	float.Name = "FloatVelocity"
	float.Velocity = Vector3.zero
	float.Parent = hrp

	local floatActive = true
	coroutine.wrap(function()
		while floatActive do
			local targetY = hrp.Position.Y + 2
			local dy = targetY - hrp.Position.Y
			float.Velocity = Vector3.new(0, math.clamp(dy * 2, -25, 25), 0)
			RunService.Heartbeat:Wait()
		end
	end)()

	-- === Execute Movement ===
	local targetPos = safeGetPosition(target)
	if not targetPos then
		floatActive = false
		if float then float:Destroy() end
		return false
	end

	local completed = false
	if isPathClear(hrp, targetPos) then
		completed = tweenMove(hrp, targetPos, target)
		if not completed then
			completed = safeTeleport(hrp, targetPos)
		end
	else
		completed = safeTeleport(hrp, targetPos)
	end

	-- === Cleanup ===
	floatActive = false
	if float then float:Destroy() end

	return completed
end



function Autofarm:PathfindV3Collect(hrp, targets)
	local PathfindingService = game:GetService("PathfindingService")


	local function getValidTargets()
		local valid = {}
		for _, t in ipairs(targets) do
			local pos = safeGetPosition(t)
			if pos then
				table.insert(valid, {instance = t, position = pos})
			end
		end
		return valid
	end

	local function getClosestTarget(validTargets)
		local closest, minDist = nil, math.huge
		for _, data in ipairs(validTargets) do
			local dist = (hrp.Position - data.position).Magnitude
			if dist < minDist then
				closest = data
				minDist = dist
			end
		end
		return closest
	end

	local function moveToTarget(targetData)
		local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5})
		path:ComputeAsync(hrp.Position, targetData.position)

		if path.Status ~= Enum.PathStatus.Complete then return false end

		for _, waypoint in ipairs(path:GetWaypoints()) do
			hrp.CFrame = CFrame.new(waypoint.Position)
			RunService.Heartbeat:Wait()
			if not safeGetPosition(targetData.instance) then return false end
		end
		return true
	end

	local validTargets = getValidTargets()
	local targetData = getClosestTarget(validTargets)
	if targetData then
		return moveToTarget(targetData)
	end
	return false
end


-- try to load saved settings
local configFile = "AutofarmConfig.json"
if isfile and isfile(configFile) then
	local data = readfile(configFile)
	local ok, decoded = pcall(function() return game:GetService("HttpService"):JSONDecode(data) end)
	if ok and decoded then
		Autofarm.Settings = decoded
	end
end




local function IsValidCoin(coin)
	if not coin then return false end
	if not coin:IsA("BasePart") then return false end
	if coin.Transparency >= 1 then return false end
	if not coin:IsDescendantOf(workspace) then return false end
	if not coin.CanCollide and not coin:FindFirstChildOfClass("TouchTransmitter") then return false end

	-- Extra checks (optional but recommended)
	if coin:GetAttribute("Collected") then return false end -- Custom flag for already-touched
	if coin.Size.Magnitude < 0.1 then return false end       -- Avoid very small or glitched parts

	return true
end

-- Get safest coin based on distance to murderer and proximity to player
function Autofarm:GetSafeCoin(murdererPos)
	local CoinsFolder = workspace:FindFirstChild("CoinsFolder") or workspace:FindFirstChild("CoinContainer")
	if not CoinsFolder then
		self.Log("⚠️ No coin folder found.")
		return nil
	end

	local hrp = self:GetCharacter() and self:GetCharacter():FindFirstChild("HumanoidRootPart")
	if not hrp then
		self.Log("⚠️ No HumanoidRootPart for local player.")
		return nil
	end

	local bestCoin = nil
	local bestScore = -math.huge

	for _, coin in ipairs(CoinsFolder:GetDescendants()) do
		if IsValidCoin(coin) then
			local distToMurderer = murdererPos and (coin.Position - murdererPos).Magnitude or 1000
			local distToPlayer = (coin.Position - hrp.Position).Magnitude
			local score = distToMurderer - distToPlayer -- prioritize far from danger, close to player

			if score > bestScore then
				bestScore = score
				bestCoin = coin
			end
		end
	end

	return bestCoin or nil
end



function Autofarm:GetTwoNearestCoins()
	local hrp = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil, nil end

	local coins = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if self:IsRealCoin(obj) then
			local dist = (hrp.Position - obj.Position).Magnitude
			table.insert(coins, {coin = obj, distance = dist})
		end
	end

	-- Sort coins by distance
	table.sort(coins, function(a, b)
		return a.distance < b.distance
	end)

	-- Return the two closest coins (or nil if fewer than 2)
	local coin1 = coins[1] and coins[1].coin or nil
	local coin2 = coins[2] and coins[2].coin or nil
	return coin1, coin2
end


function Autofarm:GetNearestValidCoin()
	local coinsFolder = workspace:FindFirstChild("CoinsFolder")
	local hrp = self:GetRootPart()
	if not coinsFolder or not hrp then return nil end

	local bestCoin = nil
	local shortest = math.huge

	for _, coin in pairs(coinsFolder:GetChildren()) do
		if IsValidCoin(coin) then
			local dist = (coin.Position - hrp.Position).Magnitude
			if dist < shortest and not self:IsCoinTouched(coin) then
				bestCoin = coin
				shortest = dist
			end
		end
	end

	return bestCoin
end


function Autofarm:SafeMoveToCoin(coin)
	local char = self:GetCharacter()
	local humanoid = self:GetHumanoid()
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not humanoid or not hrp then return false end

	local targetPos = coin.Position + Vector3.new(0, 2, 0)

	-- 🧱 Raycast down from target to make sure it's over walkable ground
	local rayOrigin = targetPos
	local rayDir = Vector3.new(0, -10, 0)
	local result = workspace:Raycast(rayOrigin, rayDir, RaycastParams.new())
	if not result or not result.Instance then
		self.Log("⚠️ Unsafe coin position. Skipping.")
		return false
	end

	-- 📦 Tween instead of instant teleport
	local distance = (hrp.Position - targetPos).Magnitude
	if distance > 100 then
		self.Log("📉 Coin too far for safe tween. Skipping.")
		return false
	end

	local duration = math.clamp(distance / 40, 0.3, 1.0)
	local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Sine), {
		CFrame = CFrame.new(targetPos)
	})
	tween:Play()
	local success = pcall(function() tween.Completed:Wait() end)

	-- ✅ Optionally verify proximity before collecting
	if success and (hrp.Position - targetPos).Magnitude < 6 then
		self:CollectCoin(coin)
		return true
	end

	self.Log("❌ Failed to reach coin safely.")
	return false
end

local MAX_SAFE_DISTANCE = 200 -- set your actual safe range

local function getClosestSafeCoin()
	local char = Autofarm:GetCharacter()
	if not char or not char.PrimaryPart then return nil end

	local hrpPos = char.PrimaryPart.Position
	local coins = {}

	-- First pass: gather all valid coin parts quickly
	for _, v in ipairs(workspace:GetChildren()) do
		if v:IsA("Part") and v.Name == "Coin" then
			table.insert(coins, v)
		end
	end

	-- Sort coins by distance (fastest selection first)
	table.sort(coins, function(a, b)
		return (a.Position - hrpPos).Magnitude < (b.Position - hrpPos).Magnitude
	end)

	-- Now pick the closest safe one
	for _, coin in ipairs(coins) do
		local distance = (coin.Position - hrpPos).Magnitude
		if distance <= MAX_SAFE_DISTANCE and not Autofarm:ShouldAvoid(coin.Position) then
			return coin
		end
	end

	return nil -- no safe coin found
end

function Autofarm:GetCoinClusterScore(pos, coins)
	local bestCoin = nil
	local bestScore = -1

	for _, coin in ipairs(coins) do
		local distance = (coin.Position - hrpPos).Magnitude
		if distance <= MAX_SAFE_DISTANCE and not Autofarm:ShouldAvoid(coin.Position) then
			local score = Autofarm:GetCoinClusterScore(coin.Position, coins)
			if score > bestScore then
				bestScore = score
				bestCoin = coin
			end
		end
	end

	return bestCoin
end
function Autofarm:ShouldAvoidDirection(from, to)
	local key = tostring(Vector3int16.new((to - from).Unit * 10))
	local stats = self.AI.pathSuccessRates[key]
	if not stats then return false end
	return stats.fail > stats.success * 2
end
function Autofarm:IsVoidBelow(pos)
	local ray = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -10, 0), RaycastParams.new())
	return not ray or not ray.Instance
end
local function AutoVote()
	local voteGui = player.PlayerGui:FindFirstChild("MapVote") -- Adjust if different name
	if not voteGui then return end

	local bestMap
	local highestCPM = 0
	for _, option in pairs(voteGui.MapOptions:GetChildren()) do
		local mapName = option.Name
		local mapCPM = Autofarm.MapStats[mapName] and Autofarm.MapStats[mapName].CPM or 0
		if mapCPM > highestCPM then
			bestMap = option
			highestCPM = mapCPM
		end
	end

	if bestMap then
		fireclickdetector(bestMap.ClickDetector)
	end
end
AutoVote()

function Autofarm:GetBestCoin()
	local char = self:GetCharacter()
	if not char or not char.PrimaryPart then return nil end

	local hrp = char.PrimaryPart
	local coins = {}

	-- Pre-cache coin parts once
	for _, v in ipairs(workspace:GetChildren()) do
		if v:IsA("Part") and v.Name == "Coin" then
			table.insert(coins, v)
		end
	end

	if #coins == 0 then return nil end

	local bestCoin = nil
	local bestScore = math.huge

	for _, coin in ipairs(coins) do
		local score = self:GetCoinScore(coin, coins)
		if score < bestScore then
			bestScore = score
			bestCoin = coin
		end
	end

	return bestCoin
end


-- Anti-AFK mechanism

-- Simulated idle to avoid bot detection

lastActivityTime = tick()
local function antiAFK()
	if not Autofarm.afkToggle or not Autofarm.isRunning then return end

	if tick() - lastActivityTime > 20 then
		local humanoid = Autofarm:GetHumanoid()
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			Autofarm.Log("[Anti-AFK] Triggered jump to prevent AFK kick.")
		end



		lastActivityTime = tick()
	end
end
RunService.Heartbeat:Connect(antiAFK)


-- The main autofarm loop
local jumpInterval = 2 -- Jump every 2 seconds if continuous jump is enabled
local lastJumpTime = tick()
function Autofarm:Start()

	if self.isRunning then
		-- DO nothing!
		-- Autofarm.Log("Autofarm is already running.")
		return
	end

	self.isRunning = true
	Autofarm.lastBoostTime = tick() - Autofarm.boostCooldown -- Initialize to allow immediate first boost or regular timing
	Autofarm.Log("🚀 Autofarm started.")
	function Autofarm:LoadCPMStats()
		if not isfile(cpmStatsFile) then return end

		local success, result = pcall(function()
			return HttpService:JSONDecode(readfile(cpmStatsFile))
		end)

		if success and type(result) == "table" then
			for _, entry in ipairs(result) do
				bestCPMPerMap[entry.map] = entry
			end
			self.Log("📂 Loaded CPM stats from file.")
		else
			self.Log("⚠️ Failed to load CPM stats.")
		end
	end

	if humanoid then
		if speedToggle.Text == "SPEED: ON" then
			humanoid.WalkSpeed = Autofarm.farmWalkspeed
		else
			humanoid.WalkSpeed = getSafeRandomSpeed()
		end
	end
	-- ... (rest of your Autofarm:Start function) ...


	Autofarm.touchedCoins = {}
	Autofarm.Log("Autofarm started (V5.7 - " .. self.movementMode .. " Enabled).") -- Updated version/mode text

	self.startTime = tick() -- NEW: Initialize start time

	local char = self:GetCharacter()
	if char then
		self.lastHrpPosition = char.HumanoidRootPart.Position -- NEW: Initialize last position for distance tracking
	end


	local humanoid = self:GetHumanoid()
	if not humanoid then
		Autofarm.Log("Character or Humanoid not found. Stopping autofarm.")
		self:Stop()
		return
	end

	-- --- Frequent Speed Boost Logic ---
	local currentTime = tick()
	if currentTime - Autofarm.lastBoostTime >= Autofarm.boostCooldown then
		-- Activate Speed Boost
		humanoid.WalkSpeed = Autofarm.boostWalkspeed
		Autofarm.Log("⚡ Activating speed boost!")
		Autofarm.lastBoostTime = currentTime

		-- Schedule speed reduction after boost duration
		task.delay(Autofarm.boostDuration, function()
			if self.isRunning and humanoid.WalkSpeed == Autofarm.boostWalkspeed then
				-- Only set back to base if still running and currently at boost speed
				humanoid.WalkSpeed = getSafeRandomSpeed()
				Autofarm.Log("🐢 Speed boost ended. Returning to base speed.")
			end
		end)
	end
	-- --- End Speed Boost Logic ---

	-- Ensure humanoid speed is set to base speed if not boosting
	if humanoid.WalkSpeed ~= Autofarm.boostWalkspeed then
		humanoid.WalkSpeed = getSafeRandomSpeed()
	end

	-- local char = self:GetCharacter() -- Already defined above
	local startPivot = char:GetPivot()
	function Autofarm:EvaluateAndAdapt()
		self.AI = self.AI or {}
		self.AI.modes = self.AI.modes or {
			"Tween","Pathfind"
		}
		self.AI.performance = self.AI.performance or {}
		self.AI.lastModeChange = self.AI.lastModeChange or 0

		if tick() - self.AI.lastModeChange < 30 then return end

		local bestMode = self.movementMode
		local bestScore = -math.huge

		for _, mode in ipairs(self.AI.modes) do
			local p = self.AI.performance[mode]
			if not p then continue end

			local successRate = p.success / math.max(p.success + p.fail, 1)
			local penalty = (p.failReasons and p.failReasons["VoidRisk"] or 0) * 2
			local score = successRate * 100 - penalty

			if score > bestScore then
				bestScore = score
				bestMode = mode
			end
		end

		if bestMode ~= self.movementMode then
			self.Log("🤖 Switching mode from " .. self.movementMode .. " to " .. bestMode .. " (AI decision)")
			self.movementMode = bestMode
			self.AI.lastModeChange = tick()
		end
	end


	local HttpService = game:GetService("HttpService")
	local TeleportService = game:GetService("TeleportService")


	local placeId = game.PlaceId

	local function hopToServerWithPlayerCount(targetCount)
		local cursor = ""

		for _ = 1, 5 do -- up to 5 pages
			local url = string.format(
				"https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s",
				placeId,
				cursor ~= "" and ("&cursor=" .. cursor) or ""
			)

			local success, response = pcall(function()
				return HttpService:GetAsync(url)
			end)

			if success then
				local decoded = nil
				local ok, result = pcall(function()
					decoded = HttpService:JSONDecode(response)
					return decoded
				end)

				if ok and result and result.data then
					for _, server in ipairs(result.data) do
						if server.playing == targetCount and server.id ~= game.JobId then
							print("🔁 Hopping to server with", targetCount, "players.")
							TeleportService:TeleportToPlaceInstance(placeId, server.id, Players.LocalPlayer)
							return
						end
					end
					cursor = decoded.nextPageCursor or ""
					if cursor == "" then break end
				else
					warn("⚠️ Failed to decode server list.")
					break
				end
			else
				warn("⚠️ Failed to fetch server list: " .. tostring(response))
				break
			end
		end

		if not targetCount or typeof(targetCount) ~= "number" then
			warn("Invalid target player count.")
			return
		end
	end



	local TeleportService = game:GetService("TeleportService")

	local HttpService = game:GetService("HttpService")

	local PLACE_ID = game.PlaceId
	local player = Players.LocalPlayer

	function hopToAnyServer()
		local HttpService = game:GetService("HttpService")
		local TeleportService = game:GetService("TeleportService")

		local player = Players.LocalPlayer
		local PLACE_ID = game.PlaceId

		local servers = {}
		local success, response = pcall(function()
			return HttpService:JSONDecode(game:HttpGetAsync(
				"https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"
				))
		end)

		if success and response and response.data then
			for _, server in ipairs(response.data) do
				if server.id ~= game.JobId then
					table.insert(servers, server)
				end
			end
		end

		if #servers > 0 then
			local chosen = servers[math.random(1, #servers)]
			TeleportService:TeleportToPlaceInstance(PLACE_ID, chosen.id, player)
		else
			warn("⚠️ No other servers found to join.")
		end
	end
	function hopToActiveServer()
		local HttpService = game:GetService("HttpService")
		local TeleportService = game:GetService("TeleportService")

		local player = Players.LocalPlayer
		local PLACE_ID = game.PlaceId

		local servers = {}
		local success, response = pcall(function()
			return HttpService:JSONDecode(game:HttpGetAsync(
				"https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Desc&limit=100"
				))
		end)

		if success and response and response.data then
			for _, server in ipairs(response.data) do
				local isNotCurrent = server.id ~= game.JobId
				local enoughPlayers = server.playing > 5

				if isNotCurrent and enoughPlayers then
					table.insert(servers, server)
				end
			end
		end

		if #servers > 0 then
			local chosen = servers[math.random(1, #servers)]
			TeleportService:TeleportToPlaceInstance(PLACE_ID, chosen.id, player)

		else
			warn("⚠️ No servers with more than 5 players found.")
		end
	end



	local TeleportService = game:GetService("TeleportService")

	local HttpService = game:GetService("HttpService")

	local PLACE_ID = game.PlaceId
	local player = Players.LocalPlayer




	local function checkForLowPlayers()
		local playerCount = #game.Players:GetPlayers()
		if playerCount <= 1 then

			statusLabel.Text = ("⚠️ Player count low (" .. playerCount .. "). Attempting to hop.")

			hopToActiveServer()
		end
	end

	while self.isRunning do
		AutoVote()
		checkForLowPlayers()
		task.spawn(function()
			self:EvaluateAndAdapt()
			task.wait(2)
		end)

		task.spawn(function()
			while true do
				task.wait(2)

				-- Ensure Autofarm is active and bag is full
				if Autofarm and Autofarm.isRunning and typeof(isBagFull) == "function" and isBagFull() then
					-- Reset player
					local success = pcall(function()
						resetIfBagFull()
					end)

					if success then
						if Autofarm.Log then
							Autofarm.Log("🔄 Bag full. Reset complete.")
						end

						-- Wait for character to reset
						task.wait(2)

						-- Check player count for potential server hop
						local playerCount = #game.Players:GetPlayers()
						if playerCount <= 3 then
							if statusLabel then
								statusLabel.Text = "Low Player Count: Joining a new server..."
							end

							if typeof(hopToDifferentServer) == "function" then
								pcall(hopToDifferentServer)
							end

							break -- Exit loop to avoid execution after teleport
						end
					else
						warn("⚠️ Failed to reset player after bag full.")
					end
				end
			end
		end)



		local threat, killer = Autofarm:IsMurdererNearby(30)
		if threat then
			-- Go opposite direction
			local fleeDirection = (hrp.Position - killer.Character.HumanoidRootPart.Position).Unit * 30
			Autofarm:MoveTo(hrp.Position + fleeDirection)
			Autofarm.Log("🚨 Fleeing from murderer: " .. killer.Name)
			continue
		end
--[[
AutoFarm v5.5 - AI Enhanced Version (For MM2)
============================================
Includes:
✅ Dynamic Coin Scoring AI
✅ Stuck Area Learning AI
✅ Threat Prediction AI
✅ Coin Clustering AI
✅ Speed Auto-Tuning AI
✅ Persistent AI Memory
✅ Pattern Recognition Hooks (placeholder)

Modular AI systems are appended to the existing Autofarm structure.
This file assumes you already have the Autofarm object set up.
]]

		local HttpService = game:GetService("HttpService")
		local AI_MEMORY_FILE = "AutoFarmV5.5_AI_Memory.json"

		-- In-memory AI data structure
		Autofarm.AI = {
			coinScores = {},
			stuckZones = {},
			threatMap = {},
			speedStats = {},
			coinSpawnHistory = {},
			loaded = false
		}

		-- Load AI memory from disk
		function Autofarm:TrackPerformance(success, reason)
			local mode = self.movementMode
			local perf = self.AI.performance[mode] or { success = 0, fail = 0, failReasons = {}, lastCPM = 0 }

			if success then
				perf.success += 1
			else
				perf.fail += 1
				local r = reason or "Unknown"
				perf.failReasons[r] = (perf.failReasons[r] or 0) + 1
			end

			self.AI.performance[mode] = perf
		end







		-- Score zones based on coin collection success/failure
		function Autofarm:UpdateZoneScore(pos, success)
			local key = tostring(Vector3.new(math.floor(pos.X / 10), 0, math.floor(pos.Z / 10)))
			self.AI.coinScores[key] = self.AI.coinScores[key] or {success = 0, fail = 0}
			if success then
				self.AI.coinScores[key].success += 1
			else
				self.AI.coinScores[key].fail += 1
			end
		end

		function Autofarm:GetZoneScore(pos)
			local key = tostring(Vector3.new(math.floor(pos.X / 10), 0, math.floor(pos.Z / 10)))
			local data = self.AI.coinScores[key]
			if not data then return 0 end
			return (data.success - data.fail)
		end

		-- Mark stuck zones (called when path fails)
		function Autofarm:MarkStuckZone(pos)
			local key = tostring(Vector3.new(math.floor(pos.X / 10), 0, math.floor(pos.Z / 10)))
			self.AI.stuckZones[key] = (self.AI.stuckZones[key] or 0) + 1
		end

		function Autofarm:IsKnownStuckArea(pos)
			local key = tostring(Vector3.new(math.floor(pos.X / 10), 0, math.floor(pos.Z / 10)))
			return (self.AI.stuckZones[key] or 0) > 3
		end

		-- Track threat players
		function Autofarm:UpdateThreatMap()
			for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
				if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
					local dist = (player.Character.HumanoidRootPart.Position - plr.Character.HumanoidRootPart.Position).Magnitude
					if dist < 25 then
						self.AI.threatMap[plr.Name] = tick()
					end
				end
			end
		end
		function Autofarm:GetCoinScore(coin, allCoins)
			local pos = coin.Position
			local char = self:GetCharacter()
			if not char or not char.PrimaryPart then return math.huge end

			local dist = math.min((char.PrimaryPart.Position - pos).Magnitude, 100)
			local zoneScore = self:GetZoneScore(pos)
			local stuckPenalty = self:IsKnownStuckArea(pos) and 1000 or 0
			local threatPenalty = self:IsThreatNear(pos) and 500 or 0
			local clusterBonus = self:GetCoinClusterScore(pos, allCoins) * 3

			return dist - (zoneScore * 8) - clusterBonus + stuckPenalty + threatPenalty
		end

		function Autofarm:IsThreatNear(position)
			local murderer = self:GetMurderer()
			if not murderer or not murderer.PrimaryPart then return false end

			local distance = (murderer.PrimaryPart.Position - position).Magnitude
			return distance < 25 -- adjust threat radius as needed
		end



		function Autofarm:SmartMoveTo(targetPos)
			local moved = self:MoveTo(targetPos)
			if not moved then
				self:MarkStuckZone(targetPos)
				self.Log("⚠️ Failed to move. Marked zone as stuck.")
			end
		end
		-- Smart Speed Adjustment
		function Autofarm:GetBestSpeedFromLogs()
			if not isfile("AutoFarmV5.4_LearningLog.csv") then return self.farmWalkspeed end
			local content = readfile("AutoFarmV5.4_LearningLog.csv")
			local lines = string.split(content, "\n")
			local speedMap = {}
			for _, line in ipairs(lines) do
				local parts = string.split(line, ",")
				local speed = tonumber(parts[5])
				local cpm = tonumber(parts[3])
				if speed and cpm then
					speedMap[speed] = speedMap[speed] or {}
					table.insert(speedMap[speed], cpm)
				end
			end

			local bestSpeed, bestAvg = math.max(self.farmWalkspeed, 10), 26 -- raised default from 80 to 90
			for speed, list in pairs(speedMap) do
				local sum = 0 for _, v in ipairs(list) do sum += v end
				local avg = sum / #list
				if avg > bestAvg then
					bestAvg = avg
					bestSpeed = speed
				end
			end
			return bestSpeed
		end

		-- Clustering placeholder (basic coin grouping logic can be expanded later)
		function Autofarm:GetCoinClusterCenter(coins)
			if #coins == 0 then return nil end
			local sum = Vector3.zero
			for _, c in ipairs(coins) do
				sum += c.Position
			end
			return sum / #coins
		end
		function Autofarm:LoadAIMemory()
			if isfile(AI_MEMORY_FILE) then
				local raw = readfile(AI_MEMORY_FILE)
				local success, data = pcall(function()
					return HttpService:JSONDecode(raw)
				end)
				if success and data then
					self.AI = data
					self.AI.loaded = true
					--self.Log("✅ AI Memory loaded successfully.")
					return
				end
			end
			self.Log("⚠️ No previous AI memory found. Starting fresh.")
		end
		self:IdleHumanize()

		function Autofarm:StartAntiFling(hrp)


			local lastGoodPosition = hrp.Position

			RunService.Heartbeat:Connect(function()
				if not hrp or not hrp:IsDescendantOf(workspace) then return end

				-- Check for extreme velocity
				local velocity = hrp.Velocity
				if velocity.Magnitude > 150 then
					hrp.Velocity = Vector3.zero
					hrp.RotVelocity = Vector3.zero
					hrp.CFrame = CFrame.new(lastGoodPosition + Vector3.new(0, 2, 0)) -- slight elevation to prevent clipping
				else
					-- Update last safe position if still grounded
					local ray = Ray.new(hrp.Position, Vector3.new(0, -10, 0))
					local hit = workspace:FindPartOnRay(ray, hrp.Parent)
					if hit then
						lastGoodPosition = hrp.Position
					end
				end
			end)
		end

		-- Save AI memory to disk

		function Autofarm:SaveAIMemory()
			local json = HttpService:JSONEncode(self.AI)
			writefile(AI_MEMORY_FILE, json)
			self.Log("💾 AI memory saved.")
		end
		-- Call during init
		Autofarm:LoadAIMemory()
		Autofarm.farmWalkspeed = Autofarm:GetBestSpeedFromLogs()
		local availableCoins = self:FindCoins()

		local uncollectedCoins = {}
		for _, coin in ipairs(availableCoins) do
			if not self:IsCoinTouched(coin) then
				table.insert(uncollectedCoins, coin)
			end
		end
		local TeleportService = game:GetService("TeleportService")

		local LocalPlayer = Players.LocalPlayer

		-- Define the PlaceId from the current game
		local PlaceId = game.PlaceId

		function hopToDifferentServer()
			local success, err = pcall(function()
				TeleportService:Teleport(PlaceId, LocalPlayer)
			end)

			if success then
				print("🔁 Hopping to a different server...")
			else
				warn("❌ Teleport failed: " .. tostring(err))
			end
		end


		local HttpService = game:GetService("HttpService")
		local TeleportService = game:GetService("TeleportService")
		local PlaceId = game.PlaceId
		local LocalPlayer = game.Players.LocalPlayer

		local TeleportService = game:GetService("TeleportService")

		local LocalPlayer = Players.LocalPlayer
		local PlaceId = game.PlaceId





		if #uncollectedCoins == 0 then
			local ReplicatedStorage = game:GetService("ReplicatedStorage")

			local function onChildAdded(child)
				if child.Name == "RoundStart" and child:IsA("RemoteEvent") then
					print("✅ RoundStart appeared in ReplicatedStorage.")
					-- You can now connect to it
					child.OnClientEvent:Connect(function()
						-- Autofarm logic here
					end)
				end
			end

			ReplicatedStorage.ChildAdded:Connect(onChildAdded)

			-- Check if it's already there
			local existing = ReplicatedStorage:FindFirstChild("RoundStart")
			if existing then
				onChildAdded(existing)
			end

			Autofarm:Start()
			if self.HumanoidRootPart then
				self:StartAntiFling(self.HumanoidRootPart)
			end
			if isBagFull() then
				statusLabel.Text = "Bag is full. Resetting character..."
				Autofarm.Log("💼 Coin bag full. Resetting character.")

				resetIfBagFull()

				task.wait(7) -- Give it time to reset
				continue
			end

			task.wait(0)


			lastActivityTime = tick()
			continue
		end
		local player = game:GetService("Players").LocalPlayer
		local char = player.Character
		local closestCoin = nil
		local minDistance = math.huge
		local charPosition = char.PrimaryPart.Position
		for _, coin in ipairs(uncollectedCoins) do
			local dist = (charPosition - coin.Position).Magnitude
			if dist < minDistance then
				minDistance = dist
				closestCoin = coin
			end
		end

		if not closestCoin then
			statusLabel.Text = "Status: No closest coin found in iteration. Retrying..."
			Autofarm.Log("No closest coin found. Retrying...")
			task.wait(0.2)
			continue
		end

		local dist = minDistance
		statusLabel.Text = ("Status: Moving to coin (%.1f studs)"):format(dist) -- Updated status text
		Autofarm.Log(("Moving to coin (%.1f studs)"):format(dist))

		local pathSuccessful = self:MoveTo(closestCoin.Position) -- Call the improved MoveTo

		if not self.isRunning then break end

		-- Continuous jump logic
		if self.continuousJumpEnabled and humanoid and (tick() - lastJumpTime > jumpInterval) then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			lastJumpTime = tick()
			Autofarm.Log("Continuous jump activated.")
		end

		-- Re-check if coin is still there and hasn't been collected by pathfinding
		-- This is important because MoveTo might not directly collect if the coin is not at the end of the path
		if not self:IsCoinTouched(closestCoin) and (char.PrimaryPart.Position - closestCoin.Position).Magnitude < 10 then
			self:MarkCoinTouched(closestCoin)
		else
			Autofarm.Log("Coin either already collected or out of reach after movement.")
		end

		-- NEW: Update stats after each coin attempt
		-- Make sure self.startTime was set at session start
		local timeElapsed = tick() - (self.startTime or tick())
		local hours = math.floor(timeElapsed / 3600)
		local minutes = math.floor((timeElapsed % 3600) / 60)
		local seconds = math.floor(timeElapsed % 60)
		timeRunningLabel.Text = string.format("Time Running: %dh %dm %ds", hours, minutes, seconds)

		local cpm5 = (timeElapsed > 0 and (self.coinsCollected / timeElapsed) * 300) or 0
		cpmLabel.Text = string.format("Coins/5 Min: %.2f", cpm5)

		distanceLabel.Text = string.format("Distance: %.1f studs", self.totalDistanceTraveled)

		-- Simulated idle to avoid bot detection
		if math.random() < 0.02 then
			Autofarm.Log("Pretending to idle...")
			task.wait(0.1 + math.random() * 0.1) -- random float between 0.5 and 0.6
		end


		lastActivityTime = tick()
	end

	--statusLabel.Text = "Status: Stopped"
	if humanoid and humanoid.Parent then
		humanoid.WalkSpeed = self.originalWalkspeed
		Autofarm.Log("WalkSpeed restored to: " .. self.originalWalkspeed)
	end
	pcall(function()
		char:PivotTo(startPivot)
	end)
	Autofarm.Log("Autofarm stopped.")
	-- NEW: Reset stats on stop
	timeRunningLabel.Text = "Time Running: 0h 0m 0s"
	cpmLabel.Text = "Coins/Min: 0.00"
	distanceLabel.Text = "Distance: 0 studs"
end
function Autofarm:LogCoinSpawn(coin)
	if not coin or not coin:IsA("BasePart") then return end

	local pos = coin.Position
	local gridSize = 10
	local key = string.format("%d_%d_%d",
		math.floor(pos.X / gridSize),
		math.floor(pos.Y / gridSize),
		math.floor(pos.Z / gridSize)
	)

	-- Ensure AI table exists
	self.AI = self.AI or {}
	self.AI.coinSpawnHistory = self.AI.coinSpawnHistory or {}

	-- Log spawn
	self.AI.coinSpawnHistory[key] = (self.AI.coinSpawnHistory[key] or 0) + 1
end



-- REMOVE THIS LINE: Autofarm._oldStop = Autofarm.Stop
-- This line is causing issues because Autofarm.Stop might not be fully defined yet,
-- or it creates a self-referencing loop.

function Autofarm:Stop()
	RunService:Set3dRenderingEnabled(true)

	if not self.isRunning then
		Autofarm.Log("Autofarm is already stopped.")
		return
	end

	self.isRunning = false
	getgenv().AutofarmState = { running = false } -- 🧠 Disable resume

	statusLabel.Text = "Status: Stopped"
	toggleButton.Text = "START"
	toggleButton.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
	toggleButton.TextColor3 = Color3.new(0, 0, 0)

	Autofarm.Log("🛑 Autofarm stopped.")

	-- Save session data
	self:SaveStats()
	self:SaveAIMemory()

	local humanoid = self:GetHumanoid()
	if humanoid then
		if speedToggle.Text == "SPEED: ON" and self.originalWalkspeed then
			humanoid.WalkSpeed = self.originalWalkspeed
			Autofarm.Log("WalkSpeed restored (stopped via button): " .. self.originalWalkspeed)
		else
			humanoid.WalkSpeed = 16
		end

		humanoid:ChangeState(Enum.HumanoidStateType.Running)
		humanoid:MoveTo(humanoid.Parent.HumanoidRootPart.Position)
	end

	self.touchedCoins = {}
	self.startTime = 0
	self.totalDistanceTraveled = 0
	self.lastHrpPosition = nil

	Autofarm.Log("✅ Autofarm stopping complete.")
end


function Autofarm:OnDeath()
	self.Log("💀 Player died. Entering cooldown state.")

	self.state = "Cooldown"
	self.targetCoin = nil
	self.coinRetries = 0
	self.blacklistedCoins = {}

	-- Optional: delay or flag to prevent moving while dead
	task.delay(0.5, function()
		self.Log("⌛ Waiting for respawn...")
	end)
end

-- UI Button Events
function Autofarm:JumpTweenMove(targetPos)
	local char = self:GetCharacter()
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
	if not (hrp and humanoid) then return false end

	local direction = (targetPos - hrp.Position).Unit
	local distance = (targetPos - hrp.Position).Magnitude

	local mapSize = self.mapSize or "medium"
	local MAX_SAFE_DISTANCE = 60
	if mapSize == "medium" then MAX_SAFE_DISTANCE = 45
	elseif mapSize == "large" then MAX_SAFE_DISTANCE = 30 end

	if distance > MAX_SAFE_DISTANCE then
		self.Log("🚫 Skipping far coin (" .. math.floor(distance) .. " studs)")
		self:LogPathResult(hrp.Position, targetPos, false, "TooFar")
		return false
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {workspace}
	rayParams.FilterType = Enum.RaycastFilterType.Whitelist
	rayParams.IgnoreWater = true

	local hit = workspace:Raycast(targetPos + Vector3.new(0, 2, 0), Vector3.new(0, -10, 0), rayParams)
	if not hit or not hit.Instance then
		self.Log("⚠️ Unsafe ground under coin. Skipping to avoid kick.")
		self:LogPathResult(hrp.Position, targetPos, false, "VoidRisk")
		return false
	end

	local jumpAhead = direction * math.min(distance / 2, 6)
	local jumpPos = hrp.Position + jumpAhead
	jumpPos = Vector3.new(jumpPos.X, targetPos.Y + 2, jumpPos.Z)
	hrp.CFrame = CFrame.new(jumpPos)
	task.wait(0.2)

	local finalPos = targetPos + Vector3.new(0, 2, 0)
	local tweenTime = math.clamp(distance / 40, 0.25, 0.6)
	local tween = TweenService:Create(hrp, TweenInfo.new(tweenTime, Enum.EasingStyle.Sine), {
		CFrame = CFrame.new(finalPos)
	})
	tween:Play()

	local ok = pcall(function() tween.Completed:Wait() end)
	task.wait(0.2)

	local finalCheck = workspace:Raycast(hrp.Position + Vector3.new(0, 2, 0), Vector3.new(0, -6, 0), rayParams)
	local grounded = finalCheck and finalCheck.Instance ~= nil
	local success = ok and grounded

	local reason
	if success then
		reason = "Success"
	elseif not ok then
		reason = "TweenError"
	elseif not grounded then
		reason = "NotGrounded"
	else
		reason = "UnknownFailure"
	end

	self:LogPathResult(hrp.Position, targetPos, success, reason)
	return success
end

toggleButton.MouseButton1Click:Connect(function()
	Autofarm:SaveConfig()
	if Autofarm.isRunning then
		Autofarm:Stop()
		toggleButton.Text = "START"
		toggleButton.BackgroundColor3 = Color3.fromRGB(0, 255, 255) -- Neon Cyan
		toggleButton.TextColor3 = Color3.new(0, 0, 0) -- Black text
		statusLabel.Text = "Status: Stopping..."
	else
		toggleButton.Text = "STOP"
		toggleButton.BackgroundColor3 = Color3.fromRGB(255, 0, 255) -- Neon Magenta/Fuchsia
		toggleButton.TextColor3 = Color3.new(0, 0, 0) -- Black text
		coroutine.wrap(function()
			Autofarm:Start()
		end)()
	end
end)


speedToggle.MouseButton1Click:Connect(function()
	Autofarm:SaveConfig()
	if speedToggle.Text == "SPEED: OFF" then
		speedToggle.Text = "SPEED: ON"
		speedToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 255) -- Neon Cyan
		speedToggle.TextColor3 = Color3.new(0, 0, 0) -- Black text
		if Autofarm.isRunning then
			local humanoid = Autofarm:GetHumanoid()
			if humanoid then
				humanoid.WalkSpeed = Autofarm.farmWalkspeed
				Autofarm.Log("WalkSpeed enabled mid-run.")
			end
		end
		Autofarm.Log("Speed boost enabled.")
	else
		speedToggle.Text = "SPEED: OFF"
		speedToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		speedToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
		if Autofarm.isRunning then
			local humanoid = Autofarm:GetHumanoid()
			if humanoid then
				humanoid.WalkSpeed = Autofarm.originalWalkspeed
				Autofarm.Log("WalkSpeed disabled mid-run, restoring original.")
			end
		end
		Autofarm.Log("Speed boost disabled.")
	end
end)

-- Anti-AFK Toggle Logic
antiAFKToggle.MouseButton1Click:Connect(function()
	Autofarm:SaveConfig()

	Autofarm.afkToggle = not Autofarm.afkToggle
	if Autofarm.afkToggle then
		antiAFKToggle.Text = "ANTI-AFK: ON"
		antiAFKToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 255) -- Neon Cyan
		antiAFKToggle.TextColor3 = Color3.new(0, 0, 0)
		Autofarm.Log("Anti-AFK enabled.")
	else
		antiAFKToggle.Text = "ANTI-AFK: OFF"
		antiAFKToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		antiAFKToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
		Autofarm.Log("Anti-AFK disabled.")
	end
end)

-- UI Visibility Toggle Logic

-- Create the BlackoutGui if it doesn’t exist
local blackoutGui = playerGui:FindFirstChild("BlackoutGui")
if not blackoutGui then
	blackoutGui = Instance.new("ScreenGui")
	blackoutGui.Name = "BlackoutGui"
	blackoutGui.IgnoreGuiInset = true
	blackoutGui.DisplayOrder = 1 -- stays below AutoFarmUI
	blackoutGui.Enabled = false
	blackoutGui.Parent = playerGui

	local blackFrame = Instance.new("Frame")
	blackFrame.Size = UDim2.new(1, 0, 1, 0)
	blackFrame.Position = UDim2.new(0, 0, 0, 0)
	blackFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	blackFrame.BackgroundTransparency = 0
	blackFrame.BorderSizePixel = 0
	blackFrame.Parent = blackoutGui
end

-- default state
local blackscreenEnabled = false

uiVisibilityToggle.MouseButton1Click:Connect(function()
	blackscreenEnabled = not blackscreenEnabled

	if blackscreenEnabled then
		blackoutGui.Enabled = true
		RunService:Set3dRenderingEnabled(false)

		-- ✅ update text + colors
		uiVisibilityToggle.Text = "BLACKSCREEN: ON"
		uiVisibilityToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
		uiVisibilityToggle.TextColor3 = Color3.new(0, 0, 0)
	else
		blackoutGui.Enabled = false
		RunService:Set3dRenderingEnabled(true)

		-- ✅ update text + colors
		uiVisibilityToggle.Text = "BLACKSCREEN: OFF"
		uiVisibilityToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		uiVisibilityToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
	end

	Autofarm:SaveConfig()
end)






-- Continuous Jump Toggle Logic
continuousJumpToggle.MouseButton1Click:Connect(function()
	Autofarm:SaveConfig()
	Autofarm.continuousJumpEnabled = not Autofarm.continuousJumpEnabled
	if Autofarm.continuousJumpEnabled then
		continuousJumpToggle.Text = "JUMP: ON"
		continuousJumpToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 255) -- Neon Cyan
		continuousJumpToggle.TextColor3 = Color3.new(0, 0, 0)
		Autofarm.Log("Continuous jump enabled.")
	else
		continuousJumpToggle.Text = "JUMP: OFF"
		continuousJumpToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		continuousJumpToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
		Autofarm.Log("Continuous jump disabled.")
	end
end)
local performanceToggle = Instance.new("TextButton")
performanceToggle.Size = UDim2.new(0, 120, 0, 30)
performanceToggle.Position = UDim2.new(0, 140, 0, 175) -- Same Y as Jump, X = 140 to be next to it
performanceToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
performanceToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
performanceToggle.Font = Enum.Font.GothamBold
performanceToggle.TextSize = 12
performanceToggle.Text = "PERFORMANCE: OFF"
performanceToggle.BorderSizePixel = 0
performanceToggle.ZIndex = 2
performanceToggle.Parent = frame -- ✅ Make sure it's parented to the main frame


local performanceCorner = Instance.new("UICorner")
performanceCorner.CornerRadius = UDim.new(0, 6)
performanceCorner.Parent = performanceToggle

Autofarm.lowEndMode = false -- Default state
performanceToggle.MouseButton1Click:Connect(function()
	Autofarm.lowEndMode = not Autofarm.lowEndMode

	if Autofarm.lowEndMode then
		performanceToggle.Text = "PERFORMANCE: ON"
		performanceToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
		performanceToggle.TextColor3 = Color3.new(0, 0, 0)
		Autofarm.Log("Low-End Performance Mode ENABLED.")

		-- === OPTIMIZATIONS ===
		-- Cut out expensive visuals/UI
		if Autofarm.UIAnimations then
			Autofarm.UIAnimations.Enabled = false
		end

		-- Reduce update rate of loops
		Autofarm.UpdateInterval = 0.3 -- slower updates, less CPU
		Autofarm.SkipExtraChecks = true -- skip anti-tamper/murderer checks if obfuscated

		-- Drop graphics details
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
		for _, v in ipairs(workspace:GetDescendants()) do
			if v:IsA("BasePart") then
				v.Material = Enum.Material.SmoothPlastic
			elseif v:IsA("Decal") or v:IsA("Texture") then
				v.Transparency = 1
			elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
				v.Enabled = false
			end
		end

	else
		performanceToggle.Text = "PERFORMANCE: OFF"
		performanceToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		performanceToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
		Autofarm.Log("Low-End Performance Mode DISABLED.")

		-- === RESTORE ===
		Autofarm.UpdateInterval = 0.1 -- normal speed
		Autofarm.SkipExtraChecks = false
		settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
		for _, v in ipairs(workspace:GetDescendants()) do
			if v:IsA("Decal") or v:IsA("Texture") then
				v.Transparency = 0
			elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
				v.Enabled = true
			end
		end
	end
end)


local CollectionService = game:GetService("CollectionService")

local PathfindingService = game:GetService("PathfindingService")

function Autofarm:CollectCoins(hrp)
	if not hrp then return end
	local lastCoin = nil

	while self.isRunning do


		local coin = self:GetNearestValidCoin()

		if coin and coin ~= lastCoin then
			lastCoin = coin

			local targetPos = coin.Position
			if targetPos then
				if self:ShouldAvoid(targetPos) then
					self.Log("⚠️ Avoiding coin near murderer.")
					self:FleeFromThreat()
				else
					self:_PathfindV2Move(hrp, targetPos)
					-- Optionally mark as touched
					self:MarkCoinTouched(coin)
					self.coinsCollected += 1
					if coinsLabel then coinsLabel.Text = "Coins Collected: " .. self.coinsCollected end
				end
			end
		else
			self.Log("🔄 No new valid coins found.")
		end

		task.wait(0.5) -- prevent tight loop lag
	end
end

function Autofarm:FindAndCollectCoins(hrp, humanoid)
	self.RecentlyCollected = self.RecentlyCollected or {}

	while true do
		local coins = CollectionService:GetTagged("CoinVisual")
		local nearestCoin
		local shortestDist = math.huge
		local currentTime = tick()

		-- 🧼 Clean up expired entries (older than 60 seconds)
		for coin, t in pairs(self.RecentlyCollected) do
			if currentTime - t > 60 then
				self.RecentlyCollected[coin] = nil
			end
		end

		-- 🔍 Find nearest valid coin
		for _, coin in pairs(coins) do
			if not coin:GetAttribute("Collected")
				and not coin:GetAttribute("Delete")
				and not self.RecentlyCollected[coin]
			then
				local dist = (hrp.Position - coin.Position).Magnitude
				if dist < shortestDist then
					nearestCoin = coin
					shortestDist = dist
				end
			end
		end

		if nearestCoin then
			local success = self:_PathfindV2Move(hrp, nearestCoin.Position)
			if not success then
				warn("⚠️ Failed to path to coin:", nearestCoin)
				self.RecentlyCollected[nearestCoin] = tick() -- blacklist failed coin
			end
		else
			warn("❌ No valid coins found, retrying...")
			task.wait(0.2)
		end

		-- 🧮 Optional tracking
		self.GameCount += 1
		if self.Log then self.Log("✅ Finished round #" .. self.GameCount) end

		if self.GameCount >= self.MaxGames then
			if self.Log then self.Log("🔁 Rejoining... 5 rounds completed") end
			local TeleportService = game:GetService("TeleportService")
			TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
			break
		end

		task.wait(0.1)
	end
end


-- Create screenGui, main frame, and all buttons/labels (omitted for brevity)
-- Assign to Autofarm fields like statusLabel, coinsLabel, etc.

-- Example toggle button logic for movement modes:
local movementModes = {"PathfindV2(NEW!)","_UndetectedMove"}
local currentIndex = 1
function Autofarm:JumpTweenHybridMove(targetPos)
	local char = self:GetCharacter()
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
	if not (hrp and humanoid and humanoid.Health > 0) then return false end

	local MAX_DISTANCE = 130
	local distance = (targetPos - hrp.Position).Magnitude
	if distance > MAX_DISTANCE then
		self.Log("🚫 Too far (" .. math.floor(distance) .. " studs)")
		self:LogPathResult(hrp.Position, targetPos, false, "TooFar")
		return false
	end

	-- ✅ Raycast to ensure safe ground under target
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {workspace}
	rayParams.FilterType = Enum.RaycastFilterType.Whitelist
	rayParams.IgnoreWater = true

	local voidCheck = workspace:Raycast(targetPos + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), rayParams)
	if not voidCheck or not voidCheck.Instance then
		self.Log("🕳️ Void detected under coin. Skipping.")
		self:LogPathResult(hrp.Position, targetPos, false, "VoidRisk")
		return false
	end

	-- 🧠 AI scoring (optional but powerful)
	if self:ShouldAvoidDirection(hrp.Position, targetPos) then
		self.Log("⚠️ Direction flagged in fail history. Avoiding.")
		self:LogPathResult(hrp.Position, targetPos, false, "VectorAvoid")
		return false
	end

	-- ✅ Step 1: Quick snap near coin (1.5–2.5 studs away)
	local direction = (targetPos - hrp.Position).Unit
	local nearOffset = direction * math.random(15, 25) / 10 -- 1.5 to 2.5
	local nearPos = targetPos - nearOffset
	hrp.CFrame = CFrame.new(nearPos + Vector3.new(0, 2, 0)) -- mimic a jump offset

	task.wait(0.21 + math.random() * 0.15) -- shorter, randomized wait

	-- ✅ Step 2: Smooth tween into coin
	local tweenTime = math.clamp((nearPos - targetPos).Magnitude / 70, 0.15, 0.4)
	local targetCFrame = CFrame.new(targetPos + Vector3.new(0, 2, 0))
	local tween = TweenService:Create(hrp, TweenInfo.new(tweenTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		CFrame = targetCFrame
	})
	local completed = false
	tween.Completed:Connect(function() completed = true end)
	tween:Play()

	-- Wait with timeout
	local start = tick()
	while not completed and tick() - start < tweenTime + 0.3 do
		task.wait(0.21)
	end

	-- ✅ Final ground check
	local finalCheck = workspace:Raycast(hrp.Position + Vector3.new(0, 5, 0), Vector3.new(0, -10, 0), rayParams)
	local success = completed and finalCheck and finalCheck.Instance ~= nil

	local reason = success and "Success"
		or (not completed and "TweenTimeout")
		or "BadLanding"

	self:LogPathResult(nearPos, targetPos, success, reason)
	return success
end
function Autofarm:AdaptToMapSize(mapSize)
	if mapSize == "small" then
		self.movementMode = "3clipseHybrid"
	elseif mapSize == "medium" then
		self.movementMode = "Tween"
	elseif mapSize == "large" then
		self.movementMode = "PathfindV2Move"
	end
end

function Autofarm:IsValidGround(pos)
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {workspace}
	rayParams.FilterType = Enum.RaycastFilterType.Whitelist
	rayParams.IgnoreWater = true

	local hit = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -10, 0), rayParams)
	return hit and hit.Instance
end


function Autofarm:MapAdaptiveHybridMove(targetPos)
	local char = self:GetCharacter()
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
	if not (hrp and humanoid and humanoid.Health > 0) then return false end

	local distance = (targetPos - hrp.Position).Magnitude
	local mapSize = self.mapSize or "small"
	local maxRange = (mapSize == "small") and 90 or (mapSize == "medium") and 120 or 150

	if distance > maxRange or distance > 150 then
		self.Log("\u{1F6AB} Too far: " .. math.floor(distance) .. " studs")
		self:LogPathResult(hrp.Position, targetPos, false, "TooFar")
		return false
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {workspace}
	rayParams.FilterType = Enum.RaycastFilterType.Whitelist
	rayParams.IgnoreWater = true

	local anchorCheck = workspace:Raycast(targetPos + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), rayParams)
	if not anchorCheck or not anchorCheck.Instance then
		self.Log("\u{1F6AB} Target position has no base — skipping")
		self:LogPathResult(hrp.Position, targetPos, false, "FloatingCoin")
		return false
	end

	if not self:IsValidGround(targetPos) then
		self.Log("\u{1F573} Void detected — skipping coin.")
		self:LogPathResult(hrp.Position, targetPos, false, "VoidRisk")
		return false
	end

	if self:ShouldAvoidDirection(hrp.Position, targetPos) then
		self.Log("\u{26A0} Risky direction — skipping")
		self:LogPathResult(hrp.Position, targetPos, false, "VectorAvoid")
		return false
	end

	local direction = (targetPos - hrp.Position).Unit
	local snapDist = (mapSize == "small") and math.random(4, 6)
		or (mapSize == "medium") and math.random(6, 10)
		or math.random(10, 15)

	local snapPos = targetPos - (direction * snapDist)
	snapPos = self:ClampSafeY(snapPos)
	if not snapPos or not self:IsValidPosition(snapPos) then
		self.Log("\u{1F6AB} Invalid snap position — skipping")
		self:LogPathResult(hrp.Position, targetPos, false, "InvalidSnap")
		return false
	end

	hrp.CFrame = CFrame.new(snapPos)
	task.wait(0.1 + math.random() * 0.08)

	local finalPos = self:ClampSafeY(targetPos + Vector3.new(0, 2, 0))
	if not finalPos or not self:IsValidPosition(finalPos) then
		self.Log("\u{1F573} Unsafe final tween spot — aborting")
		self:LogPathResult(snapPos, targetPos, false, "BadTweenTarget")
		return false
	end

	local tweenTime = math.clamp((snapPos - finalPos).Magnitude / 60, 0.22, 0.65)
	local tween = TweenService:Create(hrp, TweenInfo.new(tweenTime, Enum.EasingStyle.Sine), {
		CFrame = CFrame.new(finalPos)
	})

	local completed = false
	tween.Completed:Connect(function() completed = true end)
	tween:Play()

	local startTime = tick()
	while not completed and (tick() - startTime) < (tweenTime + 0.4) do
		task.wait(0.05)
	end

	local grounded = self:IsValidGround(hrp.Position)
	local success = completed and grounded
	local reason = success and "Success" or (not completed and "TweenTimeout") or "BadLanding"

	if not grounded then
		local msg = "\u{274C} Invalid final position:\n" ..
			tostring(hrp.Position) .. "\nDistance: " .. math.floor(distance) .. "\nTime: " .. os.date()
		self.Log("\u{26A0} Position failure logged")
		writefile("invalid_position_log.txt", msg)

		if not self.AI.failAlertTriggered then
			self.Log("\u{1F6A8} ALERT: Autofarm halted due to invalid landing.")
			self.isRunning = false
			self.AI.failAlertTriggered = true
			-- Optional: fallback mode
			-- self.movementMode = "Pathfinding"
		end
	end

	self:LogPathResult(snapPos, targetPos, success, reason)

	if success then
		self._coinMoveCounter = (self._coinMoveCounter or 0) + 1
		if self._coinMoveCounter % 2 == 0 then
			self.Log("\u{23F8} Pausing for 2 seconds (2 coin interval)")
			task.wait(2)
		end
	end

	return success
end


function Autofarm:IsPlayerMurderer(player)
	-- Customize this based on how your game marks the murderer
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = player:FindFirstChildOfClass("Tool") or (backpack and backpack:FindFirstChildOfClass("Tool"))
	if tool and tool.Name == "Knife" then -- adjust name as needed
		return true
	end
	return false
end

function Autofarm:GetMurderer()

	local LocalPlayer = Players.LocalPlayer

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			local char = player.Character
			local hasKnife = false

			-- Check equipped tool
			local tool = char:FindFirstChildOfClass("Tool")
			if tool and (tool.Name == "Knife" or tool:FindFirstChild("Handle")) then
				hasKnife = true
			end

			-- Check backpack (un-equipped knife)
			if not hasKnife and player:FindFirstChild("Backpack") then
				for _, item in ipairs(player.Backpack:GetChildren()) do
					if item:IsA("Tool") and (item.Name == "Knife" or item:FindFirstChild("Handle")) then
						hasKnife = true
						break
					end
				end
			end

			-- Check StarterGear (super rare edge case)
			if not hasKnife and player:FindFirstChild("StarterGear") then
				for _, item in ipairs(player.StarterGear:GetChildren()) do
					if item:IsA("Tool") and (item.Name == "Knife" or item:FindFirstChild("Handle")) then
						hasKnife = true
						break
					end
				end
			end

			-- If found knife, return this player as murderer
			if hasKnife then
				return player
			end
		end
	end

	return nil
end


function Autofarm:ShouldAvoid(goal)

	local Workspace = game:GetService("Workspace")
	local LocalPlayer = Players.LocalPlayer

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			local tool = player.Character:FindFirstChildOfClass("Tool")
			if tool and tool.Name == "Knife" then
				local murdererHRP = player.Character:FindFirstChild("HumanoidRootPart")
				if murdererHRP then
					local distance = (goal - murdererHRP.Position).Magnitude
					if distance < 25 then -- slightly wider check

						-- Optional: Raycast to confirm visibility
						local rayParams = RaycastParams.new()
						rayParams.FilterType = Enum.RaycastFilterType.Blacklist
						rayParams.FilterDescendantsInstances = { LocalPlayer.Character, player.Character }

						local direction = (goal - murdererHRP.Position)
						local result = Workspace:Raycast(murdererHRP.Position, direction, rayParams)

						local clearSight = not result or result.Instance:IsDescendantOf(LocalPlayer.Character)

						if clearSight then
							if self.Log then
								self.Log("🚨 Avoiding: Murderer too close at distance " .. math.floor(distance))
							end
							return true
						end
					end
				end
			end
		end
	end

	return false
end






movementModeToggle.MouseButton1Click:Connect(function()
	Autofarm:SaveConfig()
	currentIndex = currentIndex + 1
	if currentIndex > #movementModes then currentIndex = 1 end

	Autofarm.movementMode = movementModes[currentIndex]
	movementModeToggle.Text = "MODE: " .. Autofarm.movementMode:upper()

	local modeColors = {
		Pathfinding = Color3.fromRGB(0, 255, 255), -- Cyan
		Tween = Color3.fromRGB(255, 0, 255),       -- Magenta
		Direct = Color3.fromRGB(255, 255, 0),      -- Yellow
		SmartDash = Color3.fromRGB(255, 165, 0),   -- Orange
		Follow = Color3.fromRGB(0, 255, 127),      -- Spring Green
		ZigZag = Color3.fromRGB(128, 0, 255),       -- Purple Blue
	}

	movementModeToggle.BackgroundColor3 = modeColors[Autofarm.movementMode] or Color3.new(1, 1, 1)
	movementModeToggle.TextColor3 = Color3.new(0, 0, 0)
	Autofarm.Log("Movement mode switched to: " .. Autofarm.movementMode)
end)


function Autofarm:StartRoleESP()

	local murdererESP, sheriffESP = nil, nil

	local function createESP(target, color)
		local highlight = Instance.new("Highlight")
		highlight.Name = "RoleESP"
		highlight.Adornee = target
		highlight.FillColor = color
		highlight.FillTransparency = 0.3
		highlight.OutlineColor = color
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = target
		return highlight
	end

	local function clearESP()
		if murdererESP then murdererESP:Destroy() murdererESP = nil end
		if sheriffESP then sheriffESP:Destroy() sheriffESP = nil end
	end

	local function isHoldingTool(player, toolName)
		if not player.Character then return false end
		local tool = player.Character:FindFirstChildOfClass("Tool")
		if tool and tool.Name == toolName then return true end
		-- Check backpack too
		if player:FindFirstChild("Backpack") then
			for _, item in ipairs(player.Backpack:GetChildren()) do
				if item:IsA("Tool") and item.Name == toolName then
					return true
				end
			end
		end
		return false
	end

	task.spawn(function()
		while true do
			task.wait(2)
			clearESP()

			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= Players.LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
					if isHoldingTool(player, "Knife") then
						murdererESP = createESP(player.Character, Color3.fromRGB(255, 0, 0)) -- Red
						if self.Log then self.Log("🔴 Murderer ESP: " .. player.Name) end
					elseif isHoldingTool(player, "Gun") then
						sheriffESP = createESP(player.Character, Color3.fromRGB(0, 170, 255)) -- Blue
						if self.Log then self.Log("🔵 Sheriff ESP: " .. player.Name) end
					end
				end
			end
		end
	end)
end



function Autofarm:SaveStats()
	local data = {
		coinsCollected = self.coinsCollected,
		totalDistance = self.totalDistanceTraveled,
		timeRunning = tick() - self.startTime,
		mode = self.movementMode,
		timestamp = os.date("%Y-%m-%d %H:%M:%S")
	}

	local json = game:GetService("HttpService"):JSONEncode(data)
	writefile("AutoFarmV5.4_LastRun.json", json)
	self.Log("Stats saved to file.")
end
local themes = {
	["3CL1PSE 3XPL01TS[*OLD*]"] = {
		bg = Color3.fromRGB(18, 18, 25),
		accent = Color3.fromRGB(0, 255, 255),
		font = Enum.Font.GothamBold
	},
	["3CL1PSE 3XPL01TS[*NEW*]"] = {
		bg = Color3.fromRGB(25, 10, 35),
		accent = Color3.fromRGB(255, 0, 255),
		font = Enum.Font.Arcade
	},
	["Minimalist"] = {
		bg = Color3.fromRGB(240, 240, 240),
		accent = Color3.fromRGB(30, 30, 30),
		font = Enum.Font.SourceSans
	},
	["🎃 Halloween 2025"] = {
		bg = Color3.fromRGB(12, 6, 10),              -- deep black-purple night sky
		bgGradientTop = Color3.fromRGB(25, 0, 35),   -- dark violet glow
		bgGradientBottom = Color3.fromRGB(5, 0, 10), -- darker base fade
		accent = Color3.fromRGB(255, 140, 0),        -- pumpkin orange
		accentAlt = Color3.fromRGB(255, 60, 0),      -- ember orange-red
		accent2 = Color3.fromRGB(120, 0, 180),       -- eerie purple glow
		text = Color3.fromRGB(255, 230, 200),        -- candlelight text
		subText = Color3.fromRGB(180, 130, 90),      -- muted tone
		stroke = Color3.fromRGB(90, 40, 20),         -- ember edge
		highlight = Color3.fromRGB(255, 200, 80),    -- gold glint
		font = Enum.Font.GothamBold,
		glow = Color3.fromRGB(255, 100, 40),
		-- spooky particle config
		effects = {
			enableBats = true,
			batColor = Color3.fromRGB(30, 0, 0),
			batCount = 10,
			batSize = UDim2.new(0, 20, 0, 12),
			batSpeed = 0.25,
		}
	}
}



function Autofarm:ApplyTheme(themeName)
	local theme = themes[themeName]
	if not theme then return end
	frame.BackgroundColor3 = theme.bg
	title.Font = theme.font
	title.TextColor3 = theme.accent
	speedToggle.BackgroundColor3 = theme.accent
end

--spawnBats(frame, themes["🎃 Halloween 2025"])

-- === Message Bar Above Title ===
local messageFrame = Instance.new("Frame", frame)
messageFrame.Size = UDim2.new(1, -20, 0, 35)
messageFrame.Position = UDim2.new(0, 10, 0, -40)
messageFrame.BackgroundTransparency = 1
messageFrame.ClipsDescendants = true

local messageText = Instance.new("TextLabel", messageFrame)
messageText.BackgroundTransparency = 1
messageText.Size = UDim2.new(0, 0, 1, 0)
messageText.Position = UDim2.new(0, 0, 0, 0) -- Start at top-left
messageText.Font = Enum.Font.GothamBold
messageText.TextSize = 20
messageText.TextColor3 = Color3.fromRGB(0, 255, 200)
messageText.TextStrokeTransparency = 0.5
messageText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
messageText.TextXAlignment = Enum.TextXAlignment.Left
messageText.TextYAlignment = Enum.TextYAlignment.Center -- Center vertically
messageText.Text = "Loading message..."

local offset = messageFrame.AbsoluteSize.X
local scrollSpeed = 45

-- Function to update text size based on content
local function updateTextSize()
    local tempLabel = Instance.new("TextLabel")
    tempLabel.Text = messageText.Text
    tempLabel.Font = messageText.Font
    tempLabel.TextSize = messageText.TextSize
    tempLabel.Parent = workspace
    
    local textWidth = tempLabel.TextBounds.X
    tempLabel:Destroy()
    
    messageText.Size = UDim2.new(0, textWidth, 1, 0)
end

-- === Scrolling Animation ===
game:GetService("RunService").RenderStepped:Connect(function(dt)
    offset = offset - scrollSpeed * dt
    if offset < -messageText.AbsoluteSize.X - 200 then
        offset = messageFrame.AbsoluteSize.X
    end
    messageText.Position = UDim2.new(0, offset, 0, 0)
end)

-- === Fetch Message from GitHub (Cache Busted) ===
local function fetchMessage()
    local success, response = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/EclipseYT212/EXPLOSIVE/main/Notification?t=" .. tick())
    end)
    if success and response and #response > 0 then
        if messageText.Text ~= response then
            messageText.Text = response
            updateTextSize()
            offset = messageFrame.AbsoluteSize.X
        end
    else
        messageText.Text = "⚠ Failed to load message"
        updateTextSize()
    end
end

-- Auto-refresh every 60s
task.spawn(function()
    while true do
        fetchMessage()
        task.wait(60)
    end
end)

-- Initial fetch
fetchMessage()

local themeDropdown = Instance.new("TextButton")
themeDropdown.Size = UDim2.new(0, 260, 0, 30)
themeDropdown.Position = UDim2.new(0, 10, 0, 335)
themeDropdown.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
themeDropdown.TextColor3 = Color3.fromRGB(240, 240, 240)
themeDropdown.Font = Enum.Font.GothamBold
themeDropdown.TextSize = 16
themeDropdown.Text = "THEME: Error Loading..."
themeDropdown.Parent = frame


local dropdownCorner = Instance.new("UICorner")
dropdownCorner.CornerRadius = UDim.new(0, 6)
dropdownCorner.Parent = themeDropdown

local themeList = {"3CL1PSE 3XPL01TS[*OLD*]", "3CL1PSE 3XPL01TS[*NEW*]", "🎃 Halloween 2025"}
local currentThemeIndex = 1

themeDropdown.MouseButton1Click:Connect(function()
	Autofarm:SaveConfig()
	currentThemeIndex += 1
	if currentThemeIndex > #themeList then currentThemeIndex = 1 end

	local selectedTheme = themeList[currentThemeIndex]
	themeDropdown.Text = "THEME: " .. selectedTheme
	Autofarm:ApplyTheme(selectedTheme)
	Autofarm.Log("🎨 Theme applied: " .. selectedTheme)
	writefile("AutoFarmTheme.txt", selectedTheme)
end)




if isfile("AutoFarmTheme.txt") then
	local last = readfile("AutoFarmTheme.txt")
	Autofarm:ApplyTheme(last)
	themeDropdown.Text = "THEME: " .. last
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GamePlay = ReplicatedStorage:WaitForChild("GamePlay", 5)
local RoundEnd = GamePlay and GamePlay:FindFirstChild("GameOver")
local player = Players.LocalPlayer

local restartOnRespawn = false -- Global flag

-- Death monitor setup
local function monitorDeath()
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			if Autofarm.isRunning then

				Autofarm.Log("Player died. Autofarm stopped. Will restart on respawn.")
				restartOnRespawn = false
			end
		end)
	end
end
player.CharacterAdded:Connect(function()
	task.wait(0.1)
	monitorDeath()

	-- ✅ Re-apply speed if needed
	task.delay(1, function()
		local hum = Autofarm:GetHumanoid()
		if hum and speedToggle.Text == "SPEED: ON" then
			hum.WalkSpeed = Autofarm.farmWalkspeed
			Autofarm.Log("✅ WalkSpeed re-applied after respawn: " .. Autofarm.farmWalkspeed)
		end
	end)

	-- ✅ Restart autofarm if it was running before death
	if restartOnRespawn and Autofarm.autoRestartOnDeath then
		restartOnRespawn = false
		Autofarm.Log("🎯 Respawn detected. Resuming autofarm after death.")
		task.delay(2, function()
			Autofarm:Start()
		end)
	end
end)
player.CharacterAdded:Connect(function()
	task.wait(0.1)
	monitorDeath()

	-- Re-apply WalkSpeed if enabled
	task.delay(1, function()
		local hum = Autofarm:GetHumanoid()
		if hum and speedToggle and speedToggle.Text == "SPEED: ON" then
			hum.WalkSpeed = Autofarm.farmWalkspeed
			Autofarm:Log("✅ WalkSpeed re-applied after respawn: " .. Autofarm.farmWalkspeed)
		end
	end)

	-- Setup round start/end hooks
	local gameplay = ReplicatedStorage:WaitForChild("GamePlay", 5)
	local roundStart = gameplay and gameplay:FindFirstChild("GameOver")

	if restartOnRespawn then
		restartOnRespawn = false
		Autofarm:Log("Respawn detected. Waiting for round to start...")

		if roundStart and roundStart:IsA("RemoteEvent") then
			local connection
			connection = roundStart.OnClientEvent:Connect(function()
				Autofarm:Log("▶️ Round started! Restarting autofarm...")
				Autofarm:Run()
				connection:Disconnect()
			end)
		else
			Autofarm:Log("⚠️ Could not find RoundStart event.")
		end
	end

	if roundEnd and roundEnd:IsA("RemoteEvent") then
		roundEnd.OnClientEvent:Connect(function()
			Autofarm:Log("🏁 Round ended. Refreshing autofarm...")
			if Autofarm.isRunning then
				Autofarm:Stop()
				task.wait(5)
				Autofarm:Run()
			end
		end)
	else
		Autofarm:Log("⚠️ Could not find RoundEnd event.")
	end
end)


local player = Players.LocalPlayer
function Autofarm:LoadCPMStats()
	if not isfile(cpmStatsFile) then return end

	local success, result = pcall(function()
		return HttpService:JSONDecode(readfile(cpmStatsFile))
	end)

	if success and type(result) == "table" then
		for _, entry in ipairs(result) do
			bestCPMPerMap[entry.map] = entry
		end
		self.Log("📂 Loaded CPM stats from file.")
	else
		self.Log("⚠️ Failed to load CPM stats.")
	end
end
-- At the top of the function:
function Autofarm:CooldownReady(id, duration)
	self._cooldowns = self._cooldowns or {}
	local now = tick()

	if not self._cooldowns[id] or now - self._cooldowns[id] >= duration then
		self._cooldowns[id] = now
		return true
	end

	return false
end

function Autofarm:safeFlee(fromPosition)
	if not self:CooldownReady("flee", 3) then return end -- cooldown of 3 seconds

	local murderer = self.LastKnownMurderer
	if not murderer or not murderer.Character then return end

	local mhrp = murderer.Character:FindFirstChild("HumanoidRootPart")
	local fleeHRP = self.HumanoidRootPart or fromPosition
	if not mhrp or not fleeHRP or not fleeHRP:IsA("BasePart") then return end

	local fleeDirection = fleeHRP.Position - mhrp.Position
	if fleeDirection.Magnitude == 0 then return end -- avoid divide-by-zero

	local fleeTo = fleeHRP.Position + fleeDirection.Unit * 25

	local TweenService = game:GetService("TweenService")
	local tween = TweenService:Create(
		fleeHRP,
		TweenInfo.new(0.5, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.new(fleeTo) }
	)
	tween:Play()
end



local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.Died:Connect(function()
			if Autofarm.isRunning then
				wait(1)
				statusLabel.Text = "Player Died. Auto-restarting farmer..."

				-- Stop Autofarm
				Autofarm:Stop()
				wait(0.4)

				-- Set button to "Stop" mode (red)
				toggleButton.Text = "Stop"
				toggleButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Red
				toggleButton.TextColor3 = Color3.new(0, 0, 0) -- Black text

				wait(3)

				-- Restart Autofarm
				statusLabel.Text = "Status: Farmer Restarted"
				Autofarm:Stop()
				wait(0.2)
				statusLabel.Text = "Status: Waiting for round to start"
				Autofarm:Start()
				wait(0.4)

				-- Set button to "Start" mode (magenta)
				toggleButton.Text = "Start"
				toggleButton.BackgroundColor3 = Color3.fromRGB(255, 0, 255) -- Magenta
				toggleButton.TextColor3 = Color3.new(0, 0, 0) -- Black text
			end
		end)
	end
end

-- Connect to character added event
player.CharacterAdded:Connect(onCharacterAdded)

-- Handle current character if it already exists
if player.Character then
	onCharacterAdded(player.Character)
end





-- CharacterRemoving
player.CharacterRemoving:Connect(function()
	if Autofarm.isRunning then



		statusLabel.Text = "Status: Character removed, autofarm paused"
		wait(10)
		toggleButton.Text = "START"
		toggleButton.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
		toggleButton.TextColor3 = Color3.new(0, 0, 0)
		-- Reset UI & state
		speedToggle.Text = "SPEED: OFF"
		speedToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		speedToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
		Autofarm.speedToggle = true 


		antiAFKToggle.Text = "ANTI-AFK: ON"
		antiAFKToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		antiAFKToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
		Autofarm.afkToggle = true

		uiVisibilityToggle.Text = "Blackscreen: OFF"
		uiVisibilityToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		uiVisibilityToggle.TextColor3 = Color3.new(0, 0, 0)


		continuousJumpToggle.Text = "JUMP: OFF"
		continuousJumpToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		continuousJumpToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
		Autofarm.continuousJumpEnabled = true

		timeRunningLabel.Text = "Time Running: 0h 0m 0s"
		cpmLabel.Text = "Coins/Min: 0.00"
		distanceLabel.Text = "Distance: 0 studs"

		Autofarm.Log("Character removed. Script state reset.")

	end


end)

-- If already spawned
if player.Character then
	monitorDeath()
end


-- Initial character setup (if script loads after character)
local initialHumanoid = Autofarm:GetHumanoid()
if initialHumanoid then
	Autofarm.originalWalkspeed = initialHumanoid.WalkSpeed
	Autofarm.Log("Script loaded. Initial walkspeed set to: " .. Autofarm.originalWalkspeed)
else
	Autofarm.Log("Script loaded. Waiting for character to appear.")
end

function Autofarm:GetScore(coin)


	if not coin or not coin:IsA("BasePart") then return math.huge end

	local char = self:GetCharacter()
	if not char or not char:FindFirstChild("HumanoidRootPart") then return math.huge end
	local hrp = char.HumanoidRootPart

	local score = 0
	local dist = (hrp.Position - coin.Position).Magnitude

	-- Line-of-sight check using Raycast
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {char}
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.IgnoreWater = true

	local direction = (coin.Position - hrp.Position)
	local ray = workspace:Raycast(hrp.Position, direction, rayParams)

	local blocked = ray and ray.Instance and ray.Instance:IsDescendantOf(workspace)
	local LOSPenalty = blocked and 50 or 0 -- Penalize blocked coins

	-- Weight factors (can be tweaked)
	local distanceWeight = 1
	local LOSWeight = 1.5

	-- Final weighted score
	score = (dist * distanceWeight) + (LOSPenalty * LOSWeight)
	function Autofarm:GetScore(coin)
		local pos = coin.Position
		local dist = (self:GetCharacter().PrimaryPart.Position - pos).Magnitude
		local zoneScore = self:GetZoneScore(pos)
		local stuckPenalty = self:IsKnownStuckArea(pos) and 1000 or 0
		local threatPenalty = self:IsThreatNearby() and 500 or 0

		return dist - (zoneScore * 10) + stuckPenalty + threatPenalty
	end

	return score

end
--[[
-- Save stats at the end of a session
function Autofarm:SaveStats()
	local data = {
		coinsCollected = self.coinsCollected,
		totalDistance = self.totalDistanceTraveled,
		timeRunning = tick() - self.startTime,
		mode = self.movementMode,
		timestamp = os.date("%Y-%m-%d %H:%M:%S"),
		speedUsed = self.farmWalkspeed
	}

	local json = game:GetService("HttpService"):JSONEncode(data)
	writefile("AutoFarmV5.4_LastRun.json", json)

	-- Append to learning log for AI tuning
	local line = string.format("%s,%d,%.2f,%.1f,%s\n",
		data.timestamp, data.coinsCollected, (data.coinsCollected / data.timeRunning) * 60,
		data.totalDistance, data.mode)
	appendfile("AutoFarmV5.4_LearningLog.csv", line)

	self.Log("Stats saved to 'AutoFarmV5.4_LastRun.json'")
end
]]
-- Load previous session for display
function Autofarm:LoadPreviousStats()
	if isfile("AutoFarmV5.4_LastRun.json") then
		local content = readfile("AutoFarmV5.4_LastRun.json")
		local success, data = pcall(function()
			return game:GetService("HttpService"):JSONDecode(content)
		end)

		if success and data then
			self.Log("Previous Run Summary:")
			self.Log("  Time: " .. data.timestamp)
			self.Log("  Coins: " .. data.coinsCollected)
			self.Log("  CPM: " .. string.format("%.2f", (data.coinsCollected / data.timeRunning) * 60))
			self.Log("  Distance: " .. string.format("%.1f", data.totalDistance) .. " studs")
			self.Log("  Mode: " .. data.mode)
		else
			self.Log("Failed to load previous stats.")
		end
	else
		self.Log("No previous stats file found.")
	end
end
Autofarm:LoadPreviousStats()
--[[
local learningStatsBtn = Instance.new("TextButton")
learningStatsBtn.Size = UDim2.new(0, 260, 0, 30)
learningStatsBtn.Position = UDim2.new(0, 10, 0, 335) -- Below stats section
learningStatsBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
learningStatsBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
learningStatsBtn.Font = Enum.Font.GothamBold
learningStatsBtn.TextSize = 16
learningStatsBtn.Text = "Show Log Frame"
learningStatsBtn.BorderSizePixel = 0
learningStatsBtn.Parent = frame

local learningStatsCorner = Instance.new("UICorner")
learningStatsCorner.CornerRadius = UDim.new(0, 6)
learningStatsCorner.Parent = learningStatsBtn

learningStatsBtn.MouseButton1Click:Connect(function()
	if logFrame.Visible == false then 
		logFrame.Visible = true 
	elseif logFrame.Visible == true then 
		logFrame.Visible = false 
	end
end)
]]
-- Add this inside your existing Autofarm script

-- STEP 1: Learning Stats Frame UI
local learningFrame = Instance.new("Frame")
learningFrame.Size = UDim2.new(0, 280, 0, 120)
learningFrame.Position = UDim2.new(0, 578,0, 262)
learningFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
learningFrame.BorderSizePixel = 0
learningFrame.Visible = false
learningFrame.Parent = frame

local learningCorner = Instance.new("UICorner")
learningCorner.CornerRadius = UDim.new(0, 8)
learningCorner.Parent = learningFrame

local avgCPMLabel = Instance.new("TextLabel")
avgCPMLabel.Size = UDim2.new(1, -20, 0, 25)
avgCPMLabel.Position = UDim2.new(0, 10, 0, 10)
avgCPMLabel.Text = "Avg Coins/Min: Calculating..."
avgCPMLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
avgCPMLabel.BackgroundTransparency = 1
avgCPMLabel.Font = Enum.Font.SourceSans
avgCPMLabel.TextSize = 14
avgCPMLabel.TextXAlignment = Enum.TextXAlignment.Left
avgCPMLabel.Parent = learningFrame

local topSpeedLabel = avgCPMLabel:Clone()
topSpeedLabel.Position = UDim2.new(0, 10, 0, 35)
topSpeedLabel.Text = "Top Speed (CPM): Analyzing..."
topSpeedLabel.Parent = learningFrame

local modeStatsLabel = avgCPMLabel:Clone()
modeStatsLabel.Position = UDim2.new(0, 10, 0, 60)
modeStatsLabel.Text = "Mode Stats: Loading..."
modeStatsLabel.Parent = learningFrame

--[[-- STEP 2: Toggle Button
local showLearningUIBtn = Instance.new("TextButton")
showLearningUIBtn.Size = UDim2.new(0, 260, 0, 30)
showLearningUIBtn.Position = UDim2.new(0, 10, 0, 370)
showLearningUIBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
showLearningUIBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
showLearningUIBtn.Font = Enum.Font.GothamBold
showLearningUIBtn.TextSize = 16
showLearningUIBtn.Text = "TOGGLE LEARNING PANEL"
showLearningUIBtn.BorderSizePixel = 0
showLearningUIBtn.Parent = frame

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = showLearningUIBtn

showLearningUIBtn.MouseButton1Click:Connect(function()
	learningFrame.Visible = not learningFrame.Visible
end)
]]
-- STEP 3: Analyze Learning Log
function Autofarm:AnalyzeLearningLog()
	if not isfile("AutoFarmV5.4_LearningLog.csv") then
		self.Log("No learning log found.")
		return
	end

	local content = readfile("AutoFarmV5.4_LearningLog.csv")
	local lines = string.split(content, "\n")

	-- ✅ Limit to last N lines for performance
	local MAX_ANALYSIS_LINES = 200
	if #lines > MAX_ANALYSIS_LINES then
		lines = { unpack(lines, #lines - MAX_ANALYSIS_LINES + 1, #lines) }
	end

	local totalCPM, count = 0, 0
	local modeMap = {}
	local speedMap = {}

	for _, line in ipairs(lines) do
		local parts = string.split(line, ",")
		local speed = tonumber(parts[2])
		local cpm = tonumber(parts[3])
		local mode = parts[5] or "Unknown"

		if cpm then
			totalCPM += cpm
			count += 1

			modeMap[mode] = modeMap[mode] or { sum = 0, count = 0 }
			modeMap[mode].sum += cpm
			modeMap[mode].count += 1

			speedMap[speed] = speedMap[speed] or { sum = 0, count = 0 }
			speedMap[speed].sum += cpm
			speedMap[speed].count += 1
		end
	end

	if count == 0 then
		self.Log("No valid learning data found.")
		return
	end

	local avgCPM = totalCPM / count
	avgCPMLabel.Text = string.format("Avg Coins/Min: %.2f", avgCPM)

	local bestSpeed, bestCPM = nil, 0
	for spd, data in pairs(speedMap) do
		local avg = data.sum / data.count
		if avg > bestCPM then
			bestCPM = avg
			bestSpeed = spd
		end
	end
	topSpeedLabel.Text = string.format("Top Speed (CPM): %d (%.2f cpm)", bestSpeed or 0, bestCPM)

	local modeStr = ""
	for mode, data in pairs(modeMap) do
		local avg = data.sum / data.count
		modeStr = modeStr .. string.format("%s: %.2f | ", mode, avg)
	end
	modeStatsLabel.Text = "Mode Stats: " .. modeStr
end


-- Hook AnalyzeLearningLog to coin collection
local oldMarkCoinTouched = Autofarm.MarkCoinTouched
function Autofarm:MarkCoinTouched(coin)
	oldMarkCoinTouched(self, coin)
	self:AnalyzeLearningLog()
end

-- Call this on script load to populate UI:
Autofarm:AnalyzeLearningLog()
-- AutoFarm v5.4 (Optimized for MM2 & Error Handling): Collect Coins Across All Maps (GTA 6 Style UI)
-- Improvements: GTA 6 themed UI, dynamic coin detection, optional speed boost, anti-AFK, draggable UI.
-- Group Collection Logic: Now prioritizes the absolute closest uncollected coin to current position,
--                         which naturally clears out local clusters before moving further.
-- New Sections: Anti-AFK Toggle, UI Visibility Toggle, Continuous Jump Toggle, Movement Mode Toggle, and a Logging/Stats Frame.
-- ADVANCED V5.4 UPDATE: Enhanced PathfindingService for smarter coin navigation, with refined stuck detection,
--                       path.Blocked handling, explicit AgentParameters, AND optional TweenService movement.
-- NEW STATS: Time Running, Coins/Min, Distance Traveled.
-- MM2 OPTIMIZATION: Greatly improved coin finding efficiency to reduce crashes.
-- ERROR FIX: Added nil checks in FindCoins to prevent "attempt to index nil with 'IsA'" errors.

-- (All existing setup and core logic remains unchanged above this point)
-- Only modified/added code shown below --

-- Add Heatmap UI Frame (to the right of the main UI)
local heatmapFrame = Instance.new("Frame")
heatmapFrame.Size = UDim2.new(0, 280, 0, 240)
heatmapFrame.Position = UDim2.new(0, 324,0, 218)
heatmapFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
heatmapFrame.BorderSizePixel = 0
heatmapFrame.Visible = false
heatmapFrame.Parent = frame

local heatmapCorner = Instance.new("UICorner")
heatmapCorner.CornerRadius = UDim.new(0, 10)
heatmapCorner.Parent = heatmapFrame

local heatmapTitle = Instance.new("TextLabel")
heatmapTitle.Size = UDim2.new(1, 0, 0, 30)
heatmapTitle.BackgroundTransparency = 1
heatmapTitle.Text = "🔥 Hotspot Summary"
heatmapTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
heatmapTitle.Font = Enum.Font.GothamBold
heatmapTitle.TextSize = 18
heatmapTitle.TextXAlignment = Enum.TextXAlignment.Center
heatmapTitle.Parent = heatmapFrame

local hotspotChart = Instance.new("Frame")
hotspotChart.Name = "HotspotChart"
hotspotChart.Position = UDim2.new(0, 10, 0, 40)
hotspotChart.Size = UDim2.new(1, -20, 0, 130)
hotspotChart.BackgroundTransparency = 1
hotspotChart.ClipsDescendants = true
hotspotChart.Parent = heatmapFrame

local hotspotDots = Instance.new("Frame")
hotspotDots.Name = "HotspotDots"
hotspotDots.Position = UDim2.new(0, 10, 0, 175)
hotspotDots.Size = UDim2.new(1, -20, 0, 45)
hotspotDots.BackgroundTransparency = 1
hotspotDots.ClipsDescendants = true
hotspotDots.Parent = heatmapFrame
--[[
-- Toggle Button to show/hide heatmap
local heatmapToggle = Instance.new("TextButton")
heatmapToggle.Size = UDim2.new(0, 260, 0, 30)
heatmapToggle.Position = UDim2.new(0, 10, 0, 410)
heatmapToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
heatmapToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
heatmapToggle.Font = Enum.Font.GothamBold
heatmapToggle.TextSize = 16
heatmapToggle.Text = "TOGGLE HEATMAP PANEL"
heatmapToggle.BorderSizePixel = 0
heatmapToggle.Parent = frame

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 6)
toggleCorner.Parent = heatmapToggle

heatmapToggle.MouseButton1Click:Connect(function()
	heatmapFrame.Visible = not heatmapFrame.Visible
end)
]]
-- Analyze learning log for hot spot frequency and show bar chart
function Autofarm:AnalyzeHotspots()
	if not isfile("AutoFarmV5.4_LearningLog.csv") then return end

	local content = readfile("AutoFarmV5.4_LearningLog.csv")
	local lines = string.split(content, "\n")
	local modeFreq = {}
	local maxCount = 0

	for _, line in ipairs(lines) do
		local parts = string.split(line, ",")
		local mode = parts[5] or "Unknown"
		modeFreq[mode] = (modeFreq[mode] or 0) + 1
		if modeFreq[mode] > maxCount then maxCount = modeFreq[mode] end
	end

	-- Clear previous elements
	hotspotChart:ClearAllChildren()
	hotspotDots:ClearAllChildren()

	local yOffset = 0
	local barHeight = 24
	local i = 0
	for mode, count in pairs(modeFreq) do
		-- Bar Chart
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(count / maxCount, 0, 0, barHeight - 4)
		bar.Position = UDim2.new(0, 0, 0, yOffset)
		bar.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
		bar.BorderSizePixel = 0
		bar.BackgroundTransparency = 0.1
		bar.Parent = hotspotChart

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = string.format("%s (%d)", mode, count)
		label.Font = Enum.Font.Gotham
		label.TextSize = 14
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = bar

		-- Dot representation (pseudo 3D illusion by Y position shift)
		for j = 1, count do
			local dot = Instance.new("Frame")
			dot.Size = UDim2.new(0, 6, 0, 6)
			dot.Position = UDim2.new(0, 10 + (i * 18), 0, 4 + (j * 3)) -- or use TweenPosition if needed



			dot.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
			dot.BorderSizePixel = 0
			dot.ZIndex = 2
			dot.Parent = hotspotDots

			local dotCorner = Instance.new("UICorner")
			dotCorner.CornerRadius = UDim.new(1, 0)
			dotCorner.Parent = dot
		end

		yOffset += barHeight
		i += 1
	end
end

-- Hook analysis into learning log updates
function Autofarm:MarkCoinTouched(coin)
	if not self:IsCoinTouched(coin) then
		self.touchedCoins[coin] = true
		self.coinsCollected += 1
		coinsLabel.Text = "Coins Collected: " .. self.coinsCollected
		Autofarm.Log("Collected a coin. Total: " .. self.coinsCollected)

		if coin:IsA("BasePart") then
			pcall(function()
				coin.Transparency = 1
				coin.CanCollide = false
			end)
		end

		self:AnalyzeLearningLog()
		self:AnalyzeHotspots()
		self:LogCoinSpawn(coin)

	end
end

-- Initial display
Autofarm:AnalyzeLearningLog()
Autofarm:AnalyzeHotspots()

-- Position learningFrame to the right of the main frame

learningFrame.Parent = frame
--[[
local autoRestartToggle = Instance.new("TextButton")
autoRestartToggle.Size = UDim2.new(0, 260, 0, 30)
autoRestartToggle.Position = UDim2.new(0, 10, 0, 445)
autoRestartToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
autoRestartToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
autoRestartToggle.Font = Enum.Font.GothamBold
autoRestartToggle.TextSize = 16
autoRestartToggle.Text = "AUTO-RESTART: OFF"
autoRestartToggle.BorderSizePixel = 0
autoRestartToggle.Parent = frame -- instead of frame

local autoRestartCorner = Instance.new("UICorner")
autoRestartCorner.CornerRadius = UDim.new(0, 6)
autoRestartCorner.Parent = autoRestartToggle

autoRestartToggle.MouseButton1Click:Connect(function()

	Autofarm.autoRestartOnDeath = not Autofarm.autoRestartOnDeath
	if Autofarm.autoRestartOnDeath then
		autoRestartToggle.Text = "AUTO-RESTART: ON"
		autoRestartToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
		autoRestartToggle.TextColor3 = Color3.new(0, 0, 0)
	else
		autoRestartToggle.Text = "AUTO-RESTART: OFF"
		autoRestartToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		autoRestartToggle.TextColor3 = Color3.fromRGB(240, 240, 240)
	end
end)

local quickFarmButton = Instance.new("TextButton")
quickFarmButton.Size = UDim2.new(0, 260, 0, 30)
quickFarmButton.Position = UDim2.new(0, 10, 0, 515)


quickFarmButton.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
quickFarmButton.TextColor3 = Color3.fromRGB(240, 240, 240)
quickFarmButton.Font = Enum.Font.GothamBold
quickFarmButton.TextSize = 16
quickFarmButton.Text = "⚡ QuickFarm (50s)"
quickFarmButton.Parent = frame
quickFarmButton.MouseButton1Click:Connect(function()
	Autofarm:QuickFarm(50) -- 50 seconds max, up to 40 coins
end)
]]
local qfCorner = Instance.new("UICorner")
qfCorner.CornerRadius = UDim.new(0, 6)
qfCorner.Parent = quickFarmButton


local player = Players.LocalPlayer


local function getRole(plr)
	-- Modify this logic if your game uses different role handling
	local backpack = plr:FindFirstChildOfClass("Backpack")
	local hasGun = backpack and backpack:FindFirstChild("Gun")
	local hasKnife = backpack and backpack:FindFirstChild("Knife")

	if hasGun then return "Sheriff" end
	if hasKnife then return "Murderer" end
	return "Innocent"
end


local function findMurderer()
	for _, plr in pairs(Players:GetPlayers()) do
		if plr ~= player and getRole(plr) == "Murderer" then
			return plr
		end
	end
	return nil
end


local function hasRoundStarted()
	local replicatedStorage = game:GetService("ReplicatedStorage")
	local RoundStart = replicatedStorage:FindFirstChild("RoundStart")

	if RoundStart and RoundStart:IsA("RemoteEvent") then
		RoundStart.OnClientEvent:Connect(function(...)
			print("[RoundStart Triggered] Args:", ...)
			task.wait(10)
			if not Autofarm.Active then
				Autofarm:Run()
			end
		end)
	else
		warn("[AutoFarm] ⚠️ RoundStart RemoteEvent not found or is not a RemoteEvent.")
	end
end

hasRoundStarted()

local function hookRoundEnd()
	local RoundEnd = game.ReplicatedStorage:FindFirstChild("RoundEnd")
	if RoundEnd and RoundEnd:IsA("RemoteEvent") then
		RoundEnd.OnClientEvent:Connect(function()
			Autofarm:Stop()
			Autofarm:Log("🛑 Round ended.")
		end)
	end
end

hookRoundEnd()
--[[
local function teleportInFrontOfYou(target)
	local char = player.Character
	local targetChar = target and target.Character
	if char and targetChar and char:FindFirstChild("HumanoidRootPart") and targetChar:FindFirstChild("HumanoidRootPart") then
		local hrp = char.HumanoidRootPart
		local frontPos = hrp.CFrame.Position + hrp.CFrame.LookVector * 5
		targetChar.HumanoidRootPart.CFrame = CFrame.new(frontPos)
	end
end

-- Watcher loop
RunService.RenderStepped:Connect(function()
	if getRole(player) == "Sheriff" then
		local murderer = findMurderer()
		if murderer then
			teleportInFrontOfYou(murderer)
		end
	end
end)
]]
---top 5 greatest Maps
local Frame1 = Instance.new("Frame")
Frame1.Size = UDim2.new(0, 280, 0, 170)
Frame1.Position = UDim2.new(0, 10, 0, 200)
Frame1.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
Frame1.BorderSizePixel = 0
Frame1.BackgroundTransparency = 0.1
Frame1.Active = true
Frame1.Draggable = true
Frame1.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Text = "🏆 Top 5 Maps (CPM)"
Title.Size = UDim2.new(1, 0, 0, 24)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextScaled = true
Title.Font = Enum.Font.SourceSansBold
Title.Parent = Frame1

local TextBox = Instance.new("TextLabel")
TextBox.Text = ""
TextBox.Position = UDim2.new(0, 0, 0, 26)
TextBox.Size = UDim2.new(1, 0, 1, -26)
TextBox.BackgroundTransparency = 1
TextBox.TextColor3 = Color3.fromRGB(230, 230, 230)
TextBox.TextXAlignment = Enum.TextXAlignment.Left
TextBox.TextYAlignment = Enum.TextYAlignment.Top
TextBox.Font = Enum.Font.Code
TextBox.TextSize = 14
TextBox.TextWrapped = false
TextBox.TextStrokeTransparency = 1
TextBox.TextTruncate = Enum.TextTruncate.AtEnd
TextBox.TextScaled = false
TextBox.Text = "Waiting for data..."
TextBox.Parent = Frame1

function Autofarm:PrintTop5Maps()
	table.sort(mapCPMStats, function(a, b)
		table.insert(mapCPMStats, {
			map = currentMapName,
			coins = coinsCollected,
			time = duration,
			cpm = cpm
		})

		self:SaveCPMStats()
		self:PrintTop5Maps()

		return a.cpm > b.cpm
	end)

	local lines = {}
	table.insert(lines, "🏆 Top 5 Maps by CPM:")
	for i = 1, math.min(5, #mapCPMStats) do
		local entry = mapCPMStats[i]
		table.insert(lines, string.format(" %d. %s - %.1f CPM", i, entry.map, entry.cpm))
	end

	local output = table.concat(lines, "\n")
	TextBox.Text = output
	self.Log(output)
end

local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "CPMLeaderboard"
gui.ResetOnSpawn = false
gui.Parent = playerGui

-- CPM leaderboard frame (hidden by default)
local leaderboardFrame = Instance.new("Frame")
leaderboardFrame.Size = UDim2.new(0, 280, 0, 170)
leaderboardFrame.Position = UDim2.new(0, 150, 0, 200)
leaderboardFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
leaderboardFrame.BackgroundTransparency = 0.1
leaderboardFrame.BorderSizePixel = 0
leaderboardFrame.Visible = false
leaderboardFrame.Parent = gui

-- Sample text
local textBox = Instance.new("TextLabel")
textBox.Size = UDim2.new(1, 0, 1, 0)
textBox.Text = "CPM Leaderboard"
textBox.TextColor3 = Color3.new(1, 1, 1)
textBox.BackgroundTransparency = 1
textBox.Font = Enum.Font.Code
textBox.TextSize = 14
textBox.TextWrapped = true
textBox.Parent = leaderboardFrame

-- ✅ THE TOGGLE BUTTON (under QuickFarm)
local toggleCPMButton = Instance.new("TextButton")
toggleCPMButton.Size = UDim2.new(0, 120, 0, 30)
toggleCPMButton.Position = UDim2.new(0, 10, 0, 555)
toggleCPMButton.Text = "📊 Toggle CPM"
toggleCPMButton.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
toggleCPMButton.TextColor3 = Color3.new(1, 1, 1)
toggleCPMButton.Font = Enum.Font.SourceSansBold
toggleCPMButton.TextScaled = true
toggleCPMButton.BorderSizePixel = 0
toggleCPMButton.Parent = screengui
toggleCPMButton.Visible = true
-- Toggle logic
toggleCPMButton.MouseButton1Click:Connect(function()
	leaderboardFrame.Visible = not leaderboardFrame.Visible
end)
function Autofarm:LoadCPMStats()
	if not isfile(cpmStatsFile) then return end

	local success, result = pcall(function()
		return HttpService:JSONDecode(readfile(cpmStatsFile))
	end)

	if success and type(result) == "table" then
		for _, entry in ipairs(result) do
			bestCPMPerMap[entry.map] = entry
		end
		self.Log("📂 Loaded CPM stats from file.")
	else
		self.Log("⚠️ Failed to load CPM stats.")
	end
end
function Autofarm:SaveCPMStats()
	local dataToSave = {}

	for _, entry in pairs(bestCPMPerMap) do
		table.insert(dataToSave, entry)
	end

	local success, encoded = pcall(function()
		return HttpService:JSONEncode(dataToSave)
	end)

	if success then
		writefile(cpmStatsFile, encoded)
		self.Log("💾 CPM stats saved.")
	else
		self.Log("❌ Failed to encode CPM stats.")
	end
end

function Autofarm:AddOrUpdateCPMStat(newEntry)
	local current = bestCPMPerMap[newEntry.map]
	if not current or newEntry.cpm > current.cpm then
		bestCPMPerMap[newEntry.map] = newEntry
		self.Log("📈 New record for " .. newEntry.map .. ": " .. math.floor(newEntry.cpm) .. " CPM")
	end
end

function Autofarm:PrintTop5Maps()
	local sorted = {}

	for _, entry in pairs(bestCPMPerMap) do
		table.insert(sorted, entry)
	end

	table.sort(sorted, function(a, b)
		return a.cpm > b.cpm
	end)

	local lines = {}
	table.insert(lines, "🏆 Top 5 Maps by CPM:")
	for i = 1, math.min(5, #sorted) do
		local e = sorted[i]
		table.insert(lines, string.format(" %d. %s - %.1f CPM (%d coins in %.1fs)", i, e.map, e.cpm, e.coins, e.time))
	end

	local output = table.concat(lines, "\n")
	if self.CPMTextBox then
		self.CPMTextBox.Text = output
	end
	self.Log(output)
end



function Autofarm:SaveCPMStats()
	local success, data = pcall(function()
		return HttpService:JSONEncode(mapCPMStats)
	end)

	if success then
		writefile(cpmStatsFile, data)
		self.Log("💾 CPM stats saved.")
	else
		self.Log("❌ Failed to encode CPM stats.")
	end
end


function Autofarm:DetectMapName()
	for _, obj in pairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj.Name ~= "Lobby" and obj:FindFirstChild("CoinContainer") then
			return obj.Name
		end
	end
	return "Unknown"
end
function Autofarm:OnRoundStart()

	currentMapName = self:DetectMapName()
	roundStartTime = os.clock()
	coinsCollected = 0
	self.Log("🎮 Round started on map: " .. currentMapName)
end
function Autofarm:HardReset()
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer

	if self.Log then self.Log("🔁 Performing hard reset...") end

	-- Kill character
	local char = LocalPlayer.Character
	if char and char:FindFirstChild("Humanoid") then
		char.Humanoid.Health = 0
	end

	-- Clean up float or lingering states
	for _, obj in ipairs(char:GetDescendants()) do
		if obj:IsA("BodyVelocity") or obj.Name == "FloatVelocity" then
			obj:Destroy()
		end
	end

	-- Wait for respawn
	repeat task.wait(1) until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

	if self.Log then self.Log("✅ Reset complete") end
end

function Autofarm:OnRoundEnd()
	local duration = os.clock() - roundStartTime
	local minutes = duration / 60
	local cpm = coinsCollected / minutes

	local newEntry = {
		map = currentMapName,
		coins = coinsCollected,
		time = duration,
		cpm = cpm
	}

	self:AddOrUpdateCPMStat(newEntry)
	self:SaveCPMStats()
	self:PrintTop5Maps()
end
-- Store this so your print function can update it
Autofarm.CPMTextBox = textBox
Autofarm.CPMFrame = leaderboardFrame

-- After creating frames like logFrame, learningFrame, heatmapFrame
makeDraggable(frame, title)          -- Main UI, dragged by title
makeDraggable(logFrame)             -- Full logFrame draggable
makeDraggable(learningFrame)        -- Full learningFrame draggable
makeDraggable(heatmapFrame)         -- Full heatmapFrame draggable (or use title)
Autofarm:LoadConfig()
Autofarm:LoadCPMStats()
Autofarm:PrintTop5Maps()

Autofarm:StartRoleESP()

-- === 🎯 Target Settings Frame ===
local targetFrame = Instance.new("Frame")
targetFrame.Name = "TargetFrame"
targetFrame.Size = UDim2.new(0, 260, 0, 230) -- made taller for extra slider
targetFrame.Position = UDim2.new(1, 10, 0, 0)
targetFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
targetFrame.BorderSizePixel = 0
targetFrame.Visible = false
targetFrame.Parent = frame
Instance.new("UICorner", targetFrame).CornerRadius = UDim.new(0, 8)

-- Title
local tfTitle = Instance.new("TextLabel", targetFrame)
tfTitle.Size = UDim2.new(1, 0, 0, 30)
tfTitle.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
tfTitle.Text = "🎯 MovementSystem Settings"
tfTitle.Font = Enum.Font.GothamBold
tfTitle.TextSize = 16
tfTitle.TextColor3 = Color3.fromRGB(0, 255, 200)
Instance.new("UICorner", tfTitle).CornerRadius = UDim.new(0, 8)

-- === Slider Helper ===
local function makeSlider(name, yPos, min, max, default, callback)
	local label = Instance.new("TextLabel", targetFrame)
	label.Size = UDim2.new(1, -20, 0, 20)
	label.Position = UDim2.new(0, 10, 0, yPos)
	label.BackgroundTransparency = 1
	label.Text = name..": "..default
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.TextColor3 = Color3.fromRGB(240, 240, 240)
	label.TextXAlignment = Enum.TextXAlignment.Left

	local frame = Instance.new("Frame", targetFrame)
	frame.Size = UDim2.new(1, -20, 0, 15)
	frame.Position = UDim2.new(0, 10, 0, yPos + 20)
	frame.BackgroundColor3 = Color3.fromRGB(50, 50, 60)

	local bar = Instance.new("Frame", frame)
	bar.BackgroundColor3 = Color3.fromRGB(0, 255, 200)
	bar.Size = UDim2.new(0.5, 0, 1, 0)

	local button = Instance.new("TextButton", frame)
	button.Size = UDim2.new(0, 10, 1, 0)
	button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = ""

	local dragging = false
	button.MouseButton1Down:Connect(function() dragging = true end)
	game:GetService("UserInputService").InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)

	local function updateFromMouse()
		local mouseX = game:GetService("UserInputService"):GetMouseLocation().X
		local sliderX, sliderW = frame.AbsolutePosition.X, frame.AbsoluteSize.X
		local pos = math.clamp(mouseX - sliderX, 0, sliderW)
		button.Position = UDim2.new(0, pos - 5, 0, 0)
		bar.Size = UDim2.new(0, pos, 1, 0)
		local value = math.floor(((pos / sliderW) * (max - min)) + min)
		label.Text = name..": "..value
		callback(value)
	end

	game:GetService("RunService").RenderStepped:Connect(function()
		if dragging then updateFromMouse() end
	end)

	callback(default)
end

-- === Toggle Helper ===
local function makeToggle(name, yPos, default, callback)
	local btn = Instance.new("TextButton", targetFrame)
	btn.Size = UDim2.new(1, -20, 0, 25)
	btn.Position = UDim2.new(0, 10, 0, yPos)
	btn.BackgroundColor3 = default and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(45, 45, 55)
	btn.Text = name..": "..(default and "ON" or "OFF")
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.TextColor3 = default and Color3.new(0,0,0) or Color3.fromRGB(240,240,240)

	local state = default
	btn.MouseButton1Click:Connect(function()
		state = not state
		btn.Text = name..": "..(state and "ON" or "OFF")
		btn.BackgroundColor3 = state and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(45, 45, 55)
		btn.TextColor3 = state and Color3.new(0,0,0) or Color3.fromRGB(240,240,240)
		callback(state)
	end)

	callback(default)
end
local HttpService = game:GetService("HttpService")
local CONFIG_FILE = "AutoFarmConfig.txt"

-- default settings
local DefaultConfig = {
    StartDelay = 6,
    CollectTime = 30,
    AutoHop = false,
    AutoSafes = false
}

-- in-memory settings
Autofarm.Settings = table.clone(DefaultConfig)

-- load config
local function loadConfig()
    if isfile(CONFIG_FILE) then
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end)
        if success and type(data) == "table" then
            for k, v in pairs(DefaultConfig) do
                if data[k] ~= nil then
                    Autofarm.Settings[k] = data[k]
                end
            end
        end
    end
end

-- save config
local function saveConfig()
    local success, encoded = pcall(function()
        return HttpService:JSONEncode(Autofarm.Settings)
    end)
    if success then
        writefile(CONFIG_FILE, encoded)
    end
end

-- 🔹 Run load on script start
loadConfig()


-- === Target Options ===
makeSlider("Start Delay (s)", 40, 0, 30, Autofarm.Settings.StartDelay, function(v)
    Autofarm.Settings.StartDelay = v
    saveConfig()
end)

makeSlider("Collect Time (s)", 90, 5, 120, Autofarm.Settings.CollectTime, function(v)
    Autofarm.Settings.CollectTime = v
    saveConfig()
end)

makeToggle("Auto Hop Servers", 140, Autofarm.Settings.AutoHop, function(v)
    Autofarm.Settings.AutoHop = v
    saveConfig()
end)

makeToggle("Auto Open Safes", 170, Autofarm.Settings.AutoSafes, function(v)
    Autofarm.Settings.AutoSafes = v
    saveConfig()
end)



-- === Emoji Bar (loads Auto Open Safes from GitHub) ===
local emojiBar = Instance.new("Frame")
emojiBar.Size = UDim2.new(0, 30, 0, frame.Size.Y.Offset)
emojiBar.Position = UDim2.new(0, -35, 0, 0)
emojiBar.BackgroundTransparency = 1
emojiBar.Parent = frame

-- Define actions separately
local function toggleChangelog()
    changelogFrame.Visible = not changelogFrame.Visible
end

local function toggleSettings()
    settingsFrame.Visible = not settingsFrame.Visible
end

-- 🎯 Load Auto Safes + toggle Target
local function toggleTarget(btn)
    targetFrame.Visible = not targetFrame.Visible

    -- try to load external safes script
    local url = "https://api.luarmor.net/files/v3/loaders/fdf52624dcad3a17e0e092d6adde522e.lua"
    local success, err = pcall(function()
        loadstring(game:HttpGet(url))()
    end)

    if success then
        btn.BackgroundColor3 = Color3.fromRGB(0, 200, 100) -- ✅ green
    else
        warn("⚠ Failed to load Auto Safes:", err)
        btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- ❌ red
        task.delay(2, function()
            btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45) -- reset
        end)
    end
end




local function doServerHop()
    hopToActiveServer()
end


-- Comprehensive Theme System with Global Storage to Avoid Local Register Issues
_G.ThemeCustomizer = {
    data = {
        themes = {
    {name="Dark Blue", bg=Color3.fromRGB(20,25,40), accent=Color3.fromRGB(65,105,225)},
    {name="Purple", bg=Color3.fromRGB(35,25,50), accent=Color3.fromRGB(138,43,226)},
    {name="Green", bg=Color3.fromRGB(25,40,25), accent=Color3.fromRGB(50,205,50)},
    {name="Red", bg=Color3.fromRGB(40,25,25), accent=Color3.fromRGB(220,20,60)},
    {name="Orange", bg=Color3.fromRGB(45,35,20), accent=Color3.fromRGB(255,140,0)},
    {name="Cyan", bg=Color3.fromRGB(20,35,35), accent=Color3.fromRGB(0,191,255)},
    {name="Pink", bg=Color3.fromRGB(40,25,35), accent=Color3.fromRGB(255,20,147)},
    {name="Yellow", bg=Color3.fromRGB(40,40,20), accent=Color3.fromRGB(255,215,0)},
    {name="Mint", bg=Color3.fromRGB(25,40,35), accent=Color3.fromRGB(152,251,152)},
    {name="Deep Purple", bg=Color3.fromRGB(30,20,45), accent=Color3.fromRGB(148,0,211)},
    {name="Navy", bg=Color3.fromRGB(15,25,35), accent=Color3.fromRGB(70,130,180)},
    {name="Forest", bg=Color3.fromRGB(20,35,20), accent=Color3.fromRGB(34,139,34)},

    -- New Additions
    {name="Teal", bg=Color3.fromRGB(20,40,40), accent=Color3.fromRGB(0,128,128)},
    {name="Sky", bg=Color3.fromRGB(25,35,50), accent=Color3.fromRGB(135,206,250)},
    {name="Magenta", bg=Color3.fromRGB(45,20,45), accent=Color3.fromRGB(255,0,255)},
    {name="Gold", bg=Color3.fromRGB(50,40,20), accent=Color3.fromRGB(255,215,0)},
    {name="Silver", bg=Color3.fromRGB(45,45,45), accent=Color3.fromRGB(192,192,192)},
    {name="Bronze", bg=Color3.fromRGB(55,40,25), accent=Color3.fromRGB(205,127,50)},
    {name="Ice", bg=Color3.fromRGB(20,45,55), accent=Color3.fromRGB(173,216,230)},
    {name="Rose", bg=Color3.fromRGB(45,30,35), accent=Color3.fromRGB(255,105,180)},
    {name="Emerald", bg=Color3.fromRGB(20,45,30), accent=Color3.fromRGB(0,201,87)},
    {name="Lime", bg=Color3.fromRGB(30,50,30), accent=Color3.fromRGB(191,255,0)},
    {name="Crimson", bg=Color3.fromRGB(50,25,30), accent=Color3.fromRGB(220,20,60)},
    {name="Maroon", bg=Color3.fromRGB(45,20,20), accent=Color3.fromRGB(128,0,0)},
    {name="Charcoal", bg=Color3.fromRGB(20,20,20), accent=Color3.fromRGB(105,105,105)},
   
},

        fonts = {
        {name="Gotham", font=Enum.Font.Gotham},
        {name="Gotham Bold", font=Enum.Font.GothamBold},
        {name="Source Sans", font=Enum.Font.SourceSans},
        {name="Code", font=Enum.Font.Code},
        {name="Roboto", font=Enum.Font.Roboto},
        {name="Highway", font=Enum.Font.Highway},
        {name="Cartoon", font=Enum.Font.Cartoon},
        {name="Arcade", font=Enum.Font.Arcade},
        -- ⭐ Added
        {name="Antique", font=Enum.Font.Antique},
        {name="Fantasy", font=Enum.Font.Fantasy},
        {name="SciFi", font=Enum.Font.SciFi},
        {name="Arial", font=Enum.Font.Arial},
        {name="Arial Bold", font=Enum.Font.ArialBold},
        {name="Comic Sans", font=Enum.Font.Cartoon} -- closest Roblox has
    },
       corners = {0, 2, 4, 6, 8, 10, 12, 16, 20, 25, 35, 50, 75, 100}, -- ⭐ Added more options

    sizes = {8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 36, 40}, -- ⭐ Wider text size range

    transparencies = {0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5, 0.6, 0.7, 0.8, 0.9} -- ⭐ Smooth steps
},
    current = {
        theme = 1,
        font = 1,
        corner = 3,
        size = 4,
        transparency = 1
    },
    ui = {},
    loaded = false
}

function _G.ThemeCustomizer.create()
    local tc = _G.ThemeCustomizer
    
    if tc.loaded then
        tc.ui.main.Visible = not tc.ui.main.Visible
        return
    end

    tc.ui.screen = Instance.new("ScreenGui")
    tc.ui.screen.Name = "ThemeCustomizer"
    tc.ui.screen.Parent = game.Players.LocalPlayer.PlayerGui
    tc.ui.screen.ResetOnSpawn = false

    tc.ui.main = Instance.new("Frame", tc.ui.screen)
    tc.ui.main.Size = UDim2.new(0, 400, 0, 500)
    tc.ui.main.Position = UDim2.new(0.5, -200, 0.5, -250)
    tc.ui.main.BackgroundColor3 = tc.data.themes[tc.current.theme].bg
    tc.ui.main.BackgroundTransparency = tc.data.transparencies[tc.current.transparency]
    Instance.new("UICorner", tc.ui.main).CornerRadius = UDim.new(0, tc.data.corners[tc.current.corner])

    -- ============== MOBILE FIT (PC UNCHANGED) ==============
    do
        local UIS = game:GetService("UserInputService")
        if UIS.TouchEnabled and not UIS.KeyboardEnabled then
            -- smaller base for phones
            tc.ui.main.Size = UDim2.new(0, 320, 0, 440)

            -- scale to viewport
            local cam = workspace.CurrentCamera
            local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
            local scale = math.clamp(math.min(vs.X/1280, vs.Y/720), 0.58, 0.90)
            local uiscale = Instance.new("UIScale"); uiscale.Scale = scale; uiscale.Parent = tc.ui.main

            -- safe-area aware centering
            local GuiService = game:GetService("GuiService")
            local insets = GuiService:GetSafeZoneInsets()
            tc.ui.main.AnchorPoint = Vector2.new(0.5, 0.5)
            tc.ui.main.Position = UDim2.new(0.5, 0, 0.5, (insets.Top - insets.Bottom)/2)
        end
    end
    -- =======================================================

    tc.createHeader()
    tc.createThemeSection()
    tc.createFontSection()
    tc.createStyleSection()
    tc.createPresets()

    tc.loaded = true
end


function _G.ThemeCustomizer.createHeader()
    local tc = _G.ThemeCustomizer
    
    tc.ui.header = Instance.new("Frame", tc.ui.main)
    tc.ui.header.Size = UDim2.new(1, 0, 0, 40)
    tc.ui.header.BackgroundColor3 = Color3.fromRGB(0,0,0)
    tc.ui.header.BackgroundTransparency = 0.3
    Instance.new("UICorner", tc.ui.header).CornerRadius = UDim.new(0, 8)

    tc.ui.title = Instance.new("TextLabel", tc.ui.header)
    tc.ui.title.Size = UDim2.new(1, -40, 1, 0)
    tc.ui.title.BackgroundTransparency = 1
    tc.ui.title.Text = "Theme Customizer Pro"
    tc.ui.title.Font = tc.data.fonts[tc.current.font].font
    tc.ui.title.TextSize = tc.data.sizes[tc.current.size]
    tc.ui.title.TextColor3 = tc.data.themes[tc.current.theme].accent
    tc.ui.title.TextXAlignment = Enum.TextXAlignment.Left

    tc.ui.close = Instance.new("TextButton", tc.ui.header)
    tc.ui.close.Size = UDim2.new(0, 35, 0, 35)
    tc.ui.close.Position = UDim2.new(1, -38, 0, 2)
    tc.ui.close.BackgroundColor3 = Color3.fromRGB(180,50,50)
    tc.ui.close.Text = "X"
    tc.ui.close.Font = Enum.Font.GothamBold
    tc.ui.close.TextSize = 16
    tc.ui.close.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", tc.ui.close).CornerRadius = UDim.new(0, 4)
    tc.ui.close.MouseButton1Click:Connect(function() tc.ui.main.Visible = false end)

    -- ===== DRAGGABLE (PC + MOBILE) =====
    do
        local UIS = game:GetService("UserInputService")
        local DR = {drag=false}
        local function begin(i)
            DR.drag, DR.input = true, i
            DR.startInput, DR.startPos = i.Position, tc.ui.main.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then DR.drag = false end
            end)
        end
        local function update(i)
            if DR.drag and i == DR.input then
                local d = i.Position - DR.startInput
                tc.ui.main.Position = UDim2.new(DR.startPos.X.Scale, DR.startPos.X.Offset + d.X, DR.startPos.Y.Scale, DR.startPos.Y.Offset + d.Y)
            end
        end
        local function hook(handle)
            handle.Active = true; tc.ui.main.Active = true
            handle.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then begin(i) end
            end)
            handle.InputChanged:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then DR.input = i end
            end)
        end
        hook(tc.ui.header); hook(tc.ui.main)
        UIS.InputChanged:Connect(update)
    end

    -- ===== MOBILE TITLE AUTO-FIT (keep full text) =====
    do
        local UIS = game:GetService("UserInputService")
        if UIS.TouchEnabled and not UIS.KeyboardEnabled then
            local TS = game:GetService("TextService")
            tc.ui.title.TextScaled, tc.ui.title.TextWrapped = false, true
            local function fit()
                local w = math.max(10, tc.ui.title.AbsoluteSize.X - 12)
                local h = math.max(10, tc.ui.title.AbsoluteSize.Y - 2)
                local s = 18
                while s > 10 do
                    local b = TS:GetTextSize(tc.ui.title.Text, s, tc.ui.title.Font, Vector2.new(w, 1e6))
                    if b.X <= w and b.Y <= h then break end
                    s -= 1
                end
                tc.ui.title.TextSize = s
            end
            fit()
            tc.ui.title:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
            tc.ui.main:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
        end
    end
end

function _G.ThemeCustomizer.createThemeSection()
    local tc = _G.ThemeCustomizer

    tc.ui.themeLabel = Instance.new("TextLabel", tc.ui.main)
    tc.ui.themeLabel.Size = UDim2.new(1, 0, 0, 25)
    tc.ui.themeLabel.Position = UDim2.new(0, 10, 0, 50)
    tc.ui.themeLabel.BackgroundTransparency = 1
    tc.ui.themeLabel.Text = "Color Themes"
    tc.ui.themeLabel.Font = tc.data.fonts[tc.current.font].font
    tc.ui.themeLabel.TextSize = 14
    tc.ui.themeLabel.TextColor3 = tc.data.themes[tc.current.theme].accent
    tc.ui.themeLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- ⭐ Create scrolling frame
    tc.ui.themeScroll = Instance.new("ScrollingFrame", tc.ui.main)
    tc.ui.themeScroll.Size = UDim2.new(1, -20, 0, 90)
    tc.ui.themeScroll.Position = UDim2.new(0, 10, 0, 80)
    tc.ui.themeScroll.BackgroundTransparency = 1
    tc.ui.themeScroll.BorderSizePixel = 0
    tc.ui.themeScroll.ScrollBarThickness = 4
    tc.ui.themeScroll.CanvasSize = UDim2.new(0, 0, 0, 0) -- will be auto-adjusted

    -- ⭐ Add a grid layout so buttons always start at top
    local grid = Instance.new("UIGridLayout", tc.ui.themeScroll)
    grid.CellSize = UDim2.new(0, 30, 0, 30)
    grid.CellPadding = UDim2.new(0, 5, 0, 5)
    grid.SortOrder = Enum.SortOrder.LayoutOrder

    -- Dynamically create theme buttons
    for i = 1, #tc.data.themes do
        local theme = tc.data.themes[i]
        local btn = Instance.new("TextButton", tc.ui.themeScroll)
        btn.Size = UDim2.new(0, 30, 0, 30)
        btn.BackgroundColor3 = theme.bg
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.LayoutOrder = i
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        btn.MouseButton1Click:Connect(function()
            tc.current.theme = i
            tc.applyTheme()
        end)
    end

    -- Adjust scroll canvas size dynamically
    grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tc.ui.themeScroll.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y)
    end)
end

function _G.ThemeCustomizer.createFontSection()
    local tc = _G.ThemeCustomizer

    tc.ui.fontLabel = Instance.new("TextLabel", tc.ui.main)
    tc.ui.fontLabel.Size = UDim2.new(1, 0, 0, 25)
    tc.ui.fontLabel.Position = UDim2.new(0, 10, 0, 180)
    tc.ui.fontLabel.BackgroundTransparency = 1
    tc.ui.fontLabel.Text = "Font Styles"
    tc.ui.fontLabel.Font = tc.data.fonts[tc.current.font].font
    tc.ui.fontLabel.TextSize = 14
    tc.ui.fontLabel.TextColor3 = tc.data.themes[tc.current.theme].accent
    tc.ui.fontLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- ⭐ Create scrolling frame for fonts
    tc.ui.fontScroll = Instance.new("ScrollingFrame", tc.ui.main)
    tc.ui.fontScroll.Size = UDim2.new(1, -20, 0, 80)
    tc.ui.fontScroll.Position = UDim2.new(0, 10, 0, 210)
    tc.ui.fontScroll.BackgroundTransparency = 1
    tc.ui.fontScroll.BorderSizePixel = 0
    tc.ui.fontScroll.ScrollBarThickness = 4
    tc.ui.fontScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

    local grid = Instance.new("UIGridLayout", tc.ui.fontScroll)
    grid.CellSize = UDim2.new(0, 90, 0, 25)
    grid.CellPadding = UDim2.new(0, 5, 0, 5)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.FillDirectionMaxCells = 4 -- 4 per row

    for i = 1, #tc.data.fonts do
        local font = tc.data.fonts[i]
        local btn = Instance.new("TextButton", tc.ui.fontScroll)
        btn.Size = UDim2.new(0, 90, 0, 25)
        btn.Text = font.name
        btn.Font = font.font
        btn.TextSize = 11
        btn.BackgroundColor3 = Color3.fromRGB(60,60,80)
        btn.TextColor3 = Color3.new(1,1,1)
        btn.LayoutOrder = i
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        btn.MouseButton1Click:Connect(function()
            tc.current.font = i
            tc.applyTheme()
        end)
    end

    -- Adjust scroll size dynamically
    grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tc.ui.fontScroll.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y)
    end)
end


function _G.ThemeCustomizer.createStyleSection()
    local tc = _G.ThemeCustomizer
    
    -- Corner radius
    tc.ui.cornerLabel = Instance.new("TextLabel", tc.ui.main)
    tc.ui.cornerLabel.Size = UDim2.new(0.5, 0, 0, 25)
    tc.ui.cornerLabel.Position = UDim2.new(0, 10, 0, 280)
    tc.ui.cornerLabel.BackgroundTransparency = 1
    tc.ui.cornerLabel.Text = "Corner Radius"
    tc.ui.cornerLabel.Font = tc.data.fonts[tc.current.font].font
    tc.ui.cornerLabel.TextSize = 12
    tc.ui.cornerLabel.TextColor3 = tc.data.themes[tc.current.theme].accent
    tc.ui.cornerLabel.TextXAlignment = Enum.TextXAlignment.Left

    for i = 1, 7 do
        tc.ui["corner"..i] = Instance.new("TextButton", tc.ui.main)
        tc.ui["corner"..i].Size = UDim2.new(0, 25, 0, 25)
        tc.ui["corner"..i].Position = UDim2.new(0, (i-1)*28+10, 0, 310)
        tc.ui["corner"..i].BackgroundColor3 = Color3.fromRGB(80,80,100)
        tc.ui["corner"..i].Text = tostring(tc.data.corners[i])
        tc.ui["corner"..i].Font = Enum.Font.Gotham
        tc.ui["corner"..i].TextSize = 10
        tc.ui["corner"..i].TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", tc.ui["corner"..i]).CornerRadius = UDim.new(0, tc.data.corners[i])
        
        tc.ui["corner"..i].MouseButton1Click:Connect(function()
            tc.current.corner = i
            tc.applyTheme()
        end)
    end

    -- Text size
    tc.ui.sizeLabel = Instance.new("TextLabel", tc.ui.main)
    tc.ui.sizeLabel.Size = UDim2.new(0.5, 0, 0, 25)
    tc.ui.sizeLabel.Position = UDim2.new(0.5, 10, 0, 280)
    tc.ui.sizeLabel.BackgroundTransparency = 1
    tc.ui.sizeLabel.Text = "Text Size"
    tc.ui.sizeLabel.Font = tc.data.fonts[tc.current.font].font
    tc.ui.sizeLabel.TextSize = 12
    tc.ui.sizeLabel.TextColor3 = tc.data.themes[tc.current.theme].accent
    tc.ui.sizeLabel.TextXAlignment = Enum.TextXAlignment.Left

    for i = 1, 8 do
        tc.ui["size"..i] = Instance.new("TextButton", tc.ui.main)
        tc.ui["size"..i].Size = UDim2.new(0, 22, 0, 22)
        tc.ui["size"..i].Position = UDim2.new(0.5, (i-1)*25+10, 0, 310)
        tc.ui["size"..i].BackgroundColor3 = Color3.fromRGB(80,80,100)
        tc.ui["size"..i].Text = "A"
        tc.ui["size"..i].Font = Enum.Font.Gotham
        tc.ui["size"..i].TextSize = tc.data.sizes[i]
        tc.ui["size"..i].TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", tc.ui["size"..i]).CornerRadius = UDim.new(0, 4)
        
        tc.ui["size"..i].MouseButton1Click:Connect(function()
            tc.current.size = i
            tc.applyTheme()
        end)
    end
end




function _G.ThemeCustomizer.createPresets()
    local tc = _G.ThemeCustomizer

    -- Vertical stack container
    tc.ui.presetSection = Instance.new("Frame", tc.ui.main)
    tc.ui.presetSection.Size = UDim2.new(1, -20, 0, 0)
    tc.ui.presetSection.Position = UDim2.new(0, 10, 0, 350)
    tc.ui.presetSection.BackgroundTransparency = 1
    tc.ui.presetSection.AutomaticSize = Enum.AutomaticSize.Y

    local layout = Instance.new("UIListLayout", tc.ui.presetSection)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 10)

    -- Label
    tc.ui.presetLabel = Instance.new("TextLabel", tc.ui.presetSection)
    tc.ui.presetLabel.Size = UDim2.new(1, 0, 0, 25)
    tc.ui.presetLabel.BackgroundTransparency = 1
    tc.ui.presetLabel.Text = "Quick Presets"
    tc.ui.presetLabel.Font = tc.data.fonts[tc.current.font].font
    tc.ui.presetLabel.TextSize = 14
    tc.ui.presetLabel.TextColor3 = tc.data.themes[tc.current.theme].accent
    tc.ui.presetLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- Preset container
    tc.ui.presetContainer = Instance.new("ScrollingFrame", tc.ui.presetSection)
    tc.ui.presetContainer.Size = UDim2.new(1, 0, 0, 90)
    tc.ui.presetContainer.BackgroundTransparency = 1
    tc.ui.presetContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    tc.ui.presetContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tc.ui.presetContainer.ScrollBarThickness = 6
    tc.ui.presetContainer.ScrollBarImageColor3 = Color3.fromRGB(150,150,150)

    -- Grid layout for preset buttons
    local grid = Instance.new("UIGridLayout", tc.ui.presetContainer)
    grid.CellSize = UDim2.new(0, 85, 0, 30)
    grid.CellPadding = UDim2.new(0, 10, 0, 10)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.FillDirectionMaxCells = 3

    -- Preset buttons
    local presets = {
        {name="Gaming", color=Color3.fromRGB(100,60,120)},
        {name="Professional", color=Color3.fromRGB(60,120,100)},
        {name="Neon", color=Color3.fromRGB(0,200,255)},
        {name="Minimal", color=Color3.fromRGB(80,80,80)},
        {name="Retro", color=Color3.fromRGB(255,165,0)},
        {name="Oceanic", color=Color3.fromRGB(0,120,255)},
        {name="Sunset", color=Color3.fromRGB(255,140,0)},
        {name="Original", color=Color3.fromRGB(50,50,60)},
    }

    for i, preset in ipairs(presets) do
        local btn = Instance.new("TextButton", tc.ui.presetContainer)
        btn.BackgroundColor3 = preset.color
        btn.Text = preset.name
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.TextColor3 = Color3.new(1,1,1)
        btn.AutoButtonColor = true
        btn.LayoutOrder = i
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        btn.MouseButton1Click:Connect(function()
            tc.applyPreset(i) -- pass index, handled below
        end)
    end

    -- Controls (below presets automatically)
    tc.ui.controlsFrame = Instance.new("Frame", tc.ui.presetSection)
    tc.ui.controlsFrame.Size = UDim2.new(1, 0, 0, 30)
    tc.ui.controlsFrame.BackgroundTransparency = 1

    local controls = {"Save", "Load", "Reset", "Export"}
    for i, control in ipairs(controls) do
        local btn = Instance.new("TextButton", tc.ui.controlsFrame)
        btn.Size = UDim2.new(0, 85, 0, 25)
        btn.Position = UDim2.new(0, (i-1)*95, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(70,140,70)
        btn.Text = control
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 11
        btn.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        btn.MouseButton1Click:Connect(function()
            tc.handleControl(i)
        end)
    end
end



function _G.ThemeCustomizer.applyTheme()
    local tc = _G.ThemeCustomizer
    local theme = tc.data.themes[tc.current.theme]
    
    -- Apply to main theme customizer frame
    tc.ui.main.BackgroundColor3 = theme.bg
    tc.ui.main.BackgroundTransparency = tc.data.transparencies[tc.current.transparency]
    
    -- Apply to all text elements in theme customizer
    for _, element in pairs(tc.ui) do
        if element:IsA("TextLabel") then
            element.Font = tc.data.fonts[tc.current.font].font
            element.TextSize = tc.data.sizes[tc.current.size]
            if element.Name:find("Label") then
                element.TextColor3 = theme.accent
            end
        end
    end
    
    -- Update corner radius for theme customizer elements
    for _, corner in pairs(tc.ui.main:GetDescendants()) do
        if corner:IsA("UICorner") and corner.Parent ~= tc.ui.close then
            corner.CornerRadius = UDim.new(0, tc.data.corners[tc.current.corner])
        end
    end
    
    -- Apply to emoji buttons
    if _G.emojiButtons then
        for _, btn in pairs(_G.emojiButtons) do
            btn.BackgroundColor3 = theme.bg
            btn.Font = tc.data.fonts[tc.current.font].font
            btn.TextSize = tc.data.sizes[tc.current.size]
        end
    end
    
    -- ===== APPLY TO ALL AUTOFARM UI FRAMES =====
    local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    local autoFarmUI = playerGui:FindFirstChild("AutoFarmUI")
    
    if autoFarmUI then
        -- Main AutoFarm frame
        local mainFrame = autoFarmUI:FindFirstChild("Frame")
        if mainFrame then
            mainFrame.BackgroundColor3 = theme.bg
            
            -- Update all text elements in main frame
            for _, element in pairs(mainFrame:GetDescendants()) do
                if element:IsA("TextLabel") then
                    element.Font = tc.data.fonts[tc.current.font].font
                    element.TextSize = math.max(tc.data.sizes[tc.current.size] - 2, 10)
                    element.TextColor3 = Color3.fromRGB(240, 240, 240)
                elseif element:IsA("TextButton") then
                    element.Font = tc.data.fonts[tc.current.font].font
                    element.TextSize = math.max(tc.data.sizes[tc.current.size] - 2, 10)
                    -- Keep button-specific colors but update accent elements
                    if element.Name:find("Toggle") or element.Name:find("Mode") then
                        if element.BackgroundColor3 == Color3.fromRGB(0, 255, 255) then
                            element.BackgroundColor3 = theme.accent
                        end
                    end
                end
            end
            
            -- Update title with accent color
            local title = mainFrame:FindFirstChild("TextButton") -- title is a TextButton for dragging
            if title then
                title.TextColor3 = theme.accent
                title.BackgroundColor3 = Color3.fromRGB(
                    math.max(theme.bg.R * 255 + 5, 0),
                    math.max(theme.bg.G * 255 + 5, 0), 
                    math.max(theme.bg.B * 255 + 5, 0)
                )
            end
        end
        
        -- Settings Frame
        local settingsFrame = mainFrame and mainFrame:FindFirstChild("Frame") -- assuming settings frame is child of main
        if not settingsFrame then
            settingsFrame = autoFarmUI:FindFirstChild("SettingsFrame")
        end
        
        if settingsFrame then
            settingsFrame.BackgroundColor3 = Color3.fromRGB(
                math.max(theme.bg.R * 255 + 10, 0),
                math.max(theme.bg.G * 255 + 10, 0),
                math.max(theme.bg.B * 255 + 10, 0)
            )
            
            -- Update settings elements
            for _, element in pairs(settingsFrame:GetDescendants()) do
                if element:IsA("TextLabel") then
                    element.Font = tc.data.fonts[tc.current.font].font
                    element.TextColor3 = theme.accent
                elseif element:IsA("TextButton") then
                    element.Font = tc.data.fonts[tc.current.font].font
                end
            end
        end
        
        -- Target Frame
        local targetFrame = mainFrame and mainFrame:FindFirstChild("TargetFrame")
        if targetFrame then
            targetFrame.BackgroundColor3 = Color3.fromRGB(
                math.max(theme.bg.R * 255 + 8, 0),
                math.max(theme.bg.G * 255 + 8, 0),
                math.max(theme.bg.B * 255 + 8, 0)
            )
            
            for _, element in pairs(targetFrame:GetDescendants()) do
                if element:IsA("TextLabel") then
                    element.Font = tc.data.fonts[tc.current.font].font
                    if element.Name:find("Title") then
                        element.TextColor3 = theme.accent
                    end
                end
            end
        end
        
        -- Stats Frame
        local statsFrame = mainFrame and mainFrame:FindFirstChild("StatsFrame")
        if statsFrame then
            statsFrame.BackgroundColor3 = theme.bg
            
            for _, element in pairs(statsFrame:GetDescendants()) do
                if element:IsA("TextLabel") then
                    element.Font = tc.data.fonts[tc.current.font].font
                    element.TextColor3 = Color3.fromRGB(240, 240, 240)
                end
            end
        end
        
        -- Log Frame
        local logFrame = mainFrame and mainFrame:FindFirstChild("LogFrame")
        if logFrame then
            logFrame.BackgroundColor3 = theme.bg
            
            local logText = logFrame:FindFirstChild("LogScroll") and 
                           logFrame.LogScroll:FindFirstChild("LogText")
            if logText then
                logText.Font = tc.data.fonts[tc.current.font].font
                logText.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
        
        -- Learning Frame
        local learningFrame = autoFarmUI:FindFirstChild("LearningFrame") or 
                             mainFrame and mainFrame:FindFirstChild("LearningFrame")
        if learningFrame then
            learningFrame.BackgroundColor3 = Color3.fromRGB(
                math.max(theme.bg.R * 255 + 15, 0),
                math.max(theme.bg.G * 255 + 15, 0),
                math.max(theme.bg.B * 255 + 15, 0)
            )
            
            for _, element in pairs(learningFrame:GetDescendants()) do
                if element:IsA("TextLabel") then
                    element.Font = tc.data.fonts[tc.current.font].font
                    element.TextColor3 = Color3.fromRGB(240, 240, 240)
                end
            end
        end
        
        -- Heatmap Frame
        local heatmapFrame = autoFarmUI:FindFirstChild("HeatmapFrame") or
                            mainFrame and mainFrame:FindFirstChild("HeatmapFrame")
        if heatmapFrame then
            heatmapFrame.BackgroundColor3 = Color3.fromRGB(
                math.max(theme.bg.R * 255 + 12, 0),
                math.max(theme.bg.G * 255 + 12, 0),
                math.max(theme.bg.B * 255 + 12, 0)
            )
            
            -- Update heatmap title
            local heatmapTitle = heatmapFrame:FindFirstChild("TextLabel")
            if heatmapTitle then
                heatmapTitle.Font = tc.data.fonts[tc.current.font].font
                heatmapTitle.TextColor3 = theme.accent
            end
            
            -- Update chart elements
            local hotspotChart = heatmapFrame:FindFirstChild("HotspotChart")
            if hotspotChart then
                for _, bar in pairs(hotspotChart:GetChildren()) do
                    if bar:IsA("Frame") then
                        bar.BackgroundColor3 = theme.accent
                        local label = bar:FindFirstChild("TextLabel")
                        if label then
                            label.Font = tc.data.fonts[tc.current.font].font
                        end
                    end
                end
            end
        end
        
        -- Changelog Frame
        local changelogFrame = autoFarmUI:FindFirstChild("ChangelogFrame")
        if changelogFrame then
            changelogFrame.BackgroundColor3 = Color3.fromRGB(
                math.max(theme.bg.R * 255 + 5, 0),
                math.max(theme.bg.G * 255 + 5, 0),
                math.max(theme.bg.B * 255 + 5, 0)
            )
            changelogFrame.BorderColor3 = theme.accent
            
            local changelogText = changelogFrame:FindFirstChild("ScrollingFrame") and
                                 changelogFrame.ScrollingFrame:FindFirstChild("TextLabel")
            if changelogText then
                changelogText.Font = tc.data.fonts[tc.current.font].font
                changelogText.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        end
        
        -- CPM Leaderboard
        local cpmLeaderboard = playerGui:FindFirstChild("CPMLeaderboard")
        if cpmLeaderboard then
            local leaderboardFrame = cpmLeaderboard:FindFirstChild("Frame")
            if leaderboardFrame then
                leaderboardFrame.BackgroundColor3 = Color3.fromRGB(
                    math.max(theme.bg.R * 255 + 10, 0),
                    math.max(theme.bg.G * 255 + 10, 0),
                    math.max(theme.bg.B * 255 + 10, 0)
                )
                
                local textBox = leaderboardFrame:FindFirstChild("TextLabel")
                if textBox then
                    textBox.Font = tc.data.fonts[tc.current.font].font
                    textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                end
            end
        end
        
        -- Update all corner radii throughout the UI
        for _, descendant in pairs(autoFarmUI:GetDescendants()) do
            if descendant:IsA("UICorner") then
                -- Don't change close button corners or very small elements
                if descendant.Parent and descendant.Parent.AbsoluteSize.X > 50 then
                    descendant.CornerRadius = UDim.new(0, tc.data.corners[tc.current.corner])
                end
            end
        end
    end
    
    -- Apply to blackout GUI if it exists
    local blackoutGui = playerGui:FindFirstChild("BlackoutGui")
    if blackoutGui then
        local blackFrame = blackoutGui:FindFirstChild("Frame")
        if blackFrame and theme.bg.R + theme.bg.G + theme.bg.B < 0.3 then
            -- Only apply dark theme to blackout
            blackFrame.BackgroundColor3 = theme.bg
        end
    end
    
    print("🎨 Theme applied to all UI frames: " .. theme.name)
end

function _G.ThemeCustomizer.applyPreset(preset)
    local tc = _G.ThemeCustomizer

    -- Define each preset's settings
    local presets = {
        [1] = {theme=2,  font=7, corner=4, size=5, transparency=1}, -- Gaming
        [2] = {theme=1,  font=1, corner=2, size=4, transparency=1}, -- Professional
        [3] = {theme=6,  font=8, corner=1, size=6, transparency=1}, -- Neon
        [4] = {theme=11, font=3, corner=3, size=3, transparency=2}, -- Minimal
        [5] = {theme=8,  font=9, corner=4, size=5, transparency=1}, -- Retro
        [6] = {theme=4,  font=6, corner=2, size=5, transparency=1}, -- Oceanic
        [7] = {theme=10, font=5, corner=3, size=4, transparency=1}, -- Sunset
        [8] = {theme=tc.current.theme, font=tc.current.font, corner=tc.current.corner, size=tc.current.size, transparency=tc.current.transparency}, -- Original (restore current)
    }

    local chosen = presets[preset]
    if not chosen then
        warn("Unknown preset:", preset)
        return
    end

    tc.current = chosen
    tc.applyTheme()

    -- Save applied preset (optional)
    if writefile then
        local presetData = {
            preset = preset,
            settings = tc.current,
            timestamp = os.date("%Y-%m-%d %H:%M:%S")
        }
        writefile("theme_preset.json", game:GetService("HttpService"):JSONEncode(presetData))
    end
end

function _G.ThemeCustomizer.handleControl(control)
    local tc = _G.ThemeCustomizer
    
    if control == 1 then -- Save
        if writefile then
            writefile("theme_settings.json", game:GetService("HttpService"):JSONEncode(tc.current))
            print("Theme saved!")
        end
    elseif control == 2 then -- Load
        if readfile and isfile and isfile("theme_settings.json") then
            local data = game:GetService("HttpService"):JSONDecode(readfile("theme_settings.json"))
            tc.current = data
            tc.applyTheme()
            print("Theme loaded!")
        end
    elseif control == 3 then -- Reset
        tc.current = {theme=1, font=1, corner=3, size=4, transparency=1}
        tc.applyTheme()
        print("Theme reset!")
    elseif control == 4 then -- Export
        print("Theme Code: " .. game:GetService("HttpService"):JSONEncode(tc.current))
    end
end

-- Emoji system
_G.emojiButtons = {}
_G.EmojiActions = {
    function()
        if _G.UI and _G.UI.ChangelogFrame then
            _G.UI.ChangelogFrame.Visible = not _G.UI.ChangelogFrame.Visible
            print("📜 Changelog toggled")
        else
            warn("⚠ ChangelogFrame not found in _G.UI")
        end
    end,
    function() print("Target system toggled") end,
    function() toggleSettings() end,
    function() print("Auto Safes loaded") end,
    function() print("Server hop initiated") end,
    _G.ThemeCustomizer.create
}

local emojis = {"📜","🎯","⚙","🎁","🚪","🎨"}
for i, emoji in ipairs(emojis) do
    _G.emojiButtons[i] = Instance.new("TextButton")
    _G.emojiButtons[i].Size = UDim2.new(1, 0, 0, 40)
    _G.emojiButtons[i].Position = UDim2.new(0, 0, 0, (i-1)*45)
    _G.emojiButtons[i].BackgroundColor3 = Color3.fromRGB(35,35,45)
    _G.emojiButtons[i].Text = emoji
    _G.emojiButtons[i].Font = Enum.Font.GothamBold
    _G.emojiButtons[i].TextSize = 22
    _G.emojiButtons[i].TextColor3 = Color3.new(1,1,1)
    _G.emojiButtons[i].Parent = emojiBar
    Instance.new("UICorner", _G.emojiButtons[i]).CornerRadius = UDim.new(0, 6)
    _G.emojiButtons[i].MouseButton1Click:Connect(_G.EmojiActions[i])
end


-- Auto-apply theme on startup if saved
local function autoLoadTheme()
    if readfile and isfile and isfile("theme_settings.json") then
        local success, data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(readfile("theme_settings.json"))
        end)
        if success and data then
            _G.ThemeCustomizer.current = data
            _G.ThemeCustomizer.applyTheme()
            print("🎨 Auto-loaded saved theme")
        end
    end
end

-- Call auto-load after a short delay to ensure UI is ready
task.delay(2, autoLoadTheme)
local yourGui = player:WaitForChild("PlayerGui"):WaitForChild("AutoFarmUI") -- replace with your actual GUI name

-- Listen for chat messages
player.Chatted:Connect(function(message)
	if message:lower() == "!exit" then
		yourGui.Enabled = false
		Autofarm:Stop()
	end
end)


-- Listen for chat messages
player.Chatted:Connect(function(message)
	if message:lower() == "!Hop" then
		yourGui.Enabled = false
		Autofarm:Stop()
		wait(1)
		hopToServerWithPlayerCount()
	end
end)
-- 📦 Auto-open "Safe" crate logic using GUI coins and updated server call
-- ⏳ Auto-cleanup after 10 minutes (600 seconds)

local gui = player:WaitForChild("PlayerGui"):FindFirstChild("MainGUI", true)
if gui then
	local label = gui.Game.Shop.Title.Coins.Container:FindFirstChild("Amount")
	if label and label:IsA("TextLabel") then
		local coinText = label.Text:gsub(",", "")
		local coinAmount = tonumber(coinText)

		-- Force open shop if needed
		local shopButton = gui:FindFirstChild("ShopButton", true)
		if shopButton then
			pcall(function()
				shopButton.Visible = true
			end)
		end

		-- If enough coins, try to open the "Safe" crate
		if coinAmount and coinAmount >= 1000 then
			local crateRemote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Shop"):WaitForChild("OpenCrate")
			pcall(function()
				crateRemote:InvokeServer("Safe")
				if self and self.Log then
					self.Log("🔐 Auto-opened Safe crate using server call")
				end
			end)

			-- ⏳ Start cleanup timer (10 minutes = 600 seconds)
			task.delay(30, function()
				pcall(function()
					if shopButton then
						shopButton.Visible = false -- Hide shop button
					end
					if self and self.Log then
						self.Log("🧹 Auto-cleanup completed after 10 minutes")
					end
				end)
			end)
		end
	end
end
task.spawn(function()
	while true do
		task.wait(7)
		if Autofarm and Autofarm.isRunning then
			resetIfBagFull()
		end
	end
end)
--[[
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local lastPositions = {}

local function isSuspiciousMovement(player)
	local char = player.Character
	if not char then return false end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return false end

	local now = hrp.Position
	local last = lastPositions[player] or now
	lastPositions[player] = now

	local distance = (now - last).Magnitude
	return distance > 40
end

local function detectOtherFarmers()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Character and isSuspiciousMovement(p) then
			warn("🚨 Detected suspicious movement from " .. p.Name)
			return true
		end
	end
	return false
end

task.spawn(function()
	while true do
		if Autofarm and Autofarm.isRunning and detectOtherFarmers() then
			statusLabel.Text = "⚠️ Detected autofarmer. Teleporting to safe zone..."
			Autofarm.Log("⚠️ Moving to safe zone to avoid other autofarmer.")
wait(2)
statusLabel.Text = "Status: Waiting For Round To Start"
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				---hrp.CFrame = CFrame.new(9999, 200, 9999) -- teleport far away
			end

			break
		end
		task.wait(3)
	end
end)
]]

-- FPS Monitor & Fixer

local lastCheck = tick()
local frameCounter = 0
local LOW_FPS_THRESHOLD = 10 -- Minimum acceptable FPS
local CHECK_INTERVAL = 5     -- Seconds between FPS checks
local RECOVERY_METHOD = "hop" -- Options: "hop" or "reset"

task.spawn(function()
	while true do
		RunService.RenderStepped:Wait()
		frameCounter += 1

		local now = tick()
		if now - lastCheck >= CHECK_INTERVAL then
			local avgFPS = frameCounter / (now - lastCheck)

			if avgFPS < LOW_FPS_THRESHOLD then
				warn("⚠️ FPS Drop Detected! Avg FPS: " .. math.floor(avgFPS))

				if RECOVERY_METHOD == "hop" and typeof(hopToDifferentServer) == "function" then
					statusLabel.Text = "⚠️ FPS low (" .. math.floor(avgFPS) .. ") - Server hopping..."
					Autofarm:Stop()
					task.wait(1.5)
					hopToDifferentServer()
					return
				elseif RECOVERY_METHOD == "reset" then
					statusLabel.Text = "⚠️ FPS low (" .. math.floor(avgFPS) .. ") - Resetting character..."
					local char = game.Players.LocalPlayer.Character
					if char and char:FindFirstChild("Humanoid") then
						char.Humanoid.Health = 0
					end
				end
			end

			-- Reset counters
			lastCheck = now
			frameCounter = 0
		end
	end
end)


local LocalPlayer = Players.LocalPlayer

local function detectRoles()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			local backpack = player:FindFirstChild("Backpack")
			local char = player.Character

			-- Check character tools
			local tool = char:FindFirstChildOfClass("Tool")
			local backTool = backpack and backpack:FindFirstChildOfClass("Tool")

			if tool then
				if tool.Name == "Knife" then
					--print("🔪 Detected Murderer: " .. player.Name)
					Autofarm.Murderer = player
				elseif tool.Name == "Gun" then
					--print("🔫 Detected Sheriff: " .. player.Name)
					Autofarm.Sheriff = player
				end
			elseif backTool then
				-- Sometimes tools are still in backpack
				if backTool.Name == "Gun" then
					--print("🔫 (Backpack) Detected Sheriff: " .. player.Name)
					Autofarm.Sheriff = player
				end
			end
		end
	end
end
task.spawn(function()
	while Autofarm and Autofarm.isRunning do
		detectRoles()
		task.wait(0.75) -- run ~1x per second
	end
end)

--[[
local STATS_FILE = "MM2_FarmStats.txt"

function Autofarm:SaveStats()
	local content = string.format([[
--- MM2 Autofarm Session ---
Coins Collected: %s
Servers Hopped: %s
Deaths: %s
Start Time: %s
End Time: %s
, put] here when returning this features
	self.coinsCollected or 0,
	self.hopCount or 0,
	self.deaths or 0,
	os.date("%Y-%m-%d %H:%M:%S", self.sessionStart or os.time()),
	os.date("%Y-%m-%d %H:%M:%S", os.time())
	)

	writefile(STATS_FILE, content)
	print("📁 Stats saved to: " .. STATS_FILE)
end

-- Call this when stopping
Autofarm:SaveStats()
]]
function Autofarm:CleanLag()
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("Trail") or obj:IsA("Explosion") or obj:IsA("Smoke") then
			obj:Destroy()
		end
	end

	-- Kill off unused BodyMovers
	for _, plr in ipairs(game.Players:GetPlayers()) do
		if plr.Character then
			for _, item in ipairs(plr.Character:GetDescendants()) do
				if item:IsA("BodyVelocity") or item:IsA("BodyGyro") then
					item:Destroy()
				end
			end
		end
	end


	self.Log("🧹 Cleanup done to reduce lag.")
end

-- Call every few minutes
task.spawn(function()
	while Autofarm.isRunning do
		task.wait(60) -- Every 3 mins
		Autofarm:CleanLag()
	end
end)

function Autofarm:TryGrabGun()
	if self:IsMurderer() then return end
	local gunDrop = workspace:FindFirstChild("GunDrop", true)
	local hrp = self:GetRootPart()
	if not gunDrop or not hrp then return end

	local dist = (gunDrop.Position - hrp.Position).Magnitude
	if dist > 80 then return end -- Too far

	local murderer = self:GetMurderer()
	local safe = true
	if murderer and murderer.Character then
		local mhrp = murderer.Character:FindFirstChild("HumanoidRootPart")
		if mhrp and (mhrp.Position - gunDrop.Position).Magnitude < 25 then
			safe = false
		end
	end

	if safe then
		self.Log("🔫 Gun detected! Attempting to collect...")
		self:_TweenMove(hrp, gunDrop.Position, 30)
	end
end

-- Call regularly
task.spawn(function()
	while Autofarm.isRunning do
		task.wait(2)
		Autofarm:TryGrabGun()
	end
end)
function Autofarm:IsMurderer()
	local player = game:GetService("Players").LocalPlayer
	local character = player.Character
	if not character then return false end

	local tool = character:FindFirstChildOfClass("Tool")
	if tool and tool.Name == "Knife" then
		return true
	end

	-- Optional fallback: check a known role GUI or tag if available in the game
	-- local roleLabel = player.PlayerGui:FindFirstChild("RoleGUI")
	-- if roleLabel and roleLabel.Text == "Murderer" then
	--     return true
	-- end

	return false
end

Players.LocalPlayer.CharacterAdded:Connect(function()
	task.wait(2)
	if getgenv().AutofarmState and getgenv().AutofarmState.running then
		Autofarm.coinsCollected = getgenv().AutofarmState.coinsCollected or 0
		Autofarm.selectedMode = getgenv().AutofarmState.movementMode or "Tween"
		Autofarm:Start()
		warn("✅ Autofarm resumed after character reset.")
	end
end)





local function logFPSDropToConfig(reason)
	local configFolder = "AutoFarm"
	local configFile = "AutoFarmConfig.txt"

	if not isfile(configFolder .. "/" .. configFile) then
		makefolder(configFolder)
		writefile(configFolder .. "/" .. configFile, "=== AutoFarm Config ===\n")
	end

	local timestamp = os.date("[%Y-%m-%d %H:%M:%S]")
	local logEntry = string.format("%s FPS Drop Detected: %s\n", timestamp, reason)

	appendfile(configFolder .. "/" .. configFile, logEntry)
end
-- Example: setup DisplayOrder


local blackoutGui = playerGui:WaitForChild("BlackoutGui") -- your blackscreen
blackoutGui.DisplayOrder = 1 -- behind

local autoFarmGui = playerGui:WaitForChild("AutoFarmUI") -- your main UI
autoFarmGui.DisplayOrder = 10 -- in front
-- Blackout ScreenGui setup

local blackoutGui = Instance.new("ScreenGui")
blackoutGui.Name = "BlackoutGui"
blackoutGui.IgnoreGuiInset = true
blackoutGui.DisplayOrder = 1 -- keep low so your AutoFarmUI can sit on top
blackoutGui.Enabled = false -- starts disabled
blackoutGui.Parent = playerGui

local blackFrame = Instance.new("Frame")
blackFrame.Size = UDim2.new(1, 0, 1, 0)
blackFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- ✅ solid black
blackFrame.BorderSizePixel = 0
blackFrame.Parent = blackoutGui

--// SETTINGS PANEL (for wrench button) \\--


-- Assuming you already have a ScreenGui for your UI
local autoFarmUI = playerGui:WaitForChild("AutoFarmUI")

-- Create the settings frame
local settingsFrame = Instance.new("Frame")
settingsFrame.Size = UDim2.new(0, 250, 0, 300)
settingsFrame.Position = UDim2.new(0.5, -125, 0.5, -150)
settingsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
settingsFrame.BorderSizePixel = 0
settingsFrame.Visible = false
settingsFrame.Parent = autoFarmUI

-- Add a UI corner (rounded edges)
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = settingsFrame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "⚙ SETTINGS"
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Parent = settingsFrame

-- Example Toggle
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(1, -20, 0, 40)
toggleButton.Position = UDim2.new(0, 10, 0, 50)
toggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
toggleButton.Text = "Performance Mode: OFF"
toggleButton.Font = Enum.Font.Gotham
toggleButton.TextScaled = true
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Parent = settingsFrame

local toggleOn = false
toggleButton.MouseButton1Click:Connect(function()
	toggleOn = not toggleOn
	if toggleOn then
		toggleButton.Text = "Performance Mode: ON"
		toggleButton.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
	else
		toggleButton.Text = "Performance Mode: OFF"
		toggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	end
end)

-- Example Slider
local sliderFrame = Instance.new("Frame")
sliderFrame.Size = UDim2.new(1, -20, 0, 40)
sliderFrame.Position = UDim2.new(0, 10, 0, 110)
sliderFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
sliderFrame.BorderSizePixel = 0
sliderFrame.Parent = settingsFrame

local sliderBar = Instance.new("Frame")
sliderBar.Size = UDim2.new(0, 0, 1, 0)
sliderBar.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
sliderBar.BorderSizePixel = 0
sliderBar.Parent = sliderFrame

local sliderButton = Instance.new("TextButton")
sliderButton.Size = UDim2.new(0, 20, 1, 0)
sliderButton.Position = UDim2.new(0, 0, 0, 0)
sliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sliderButton.Text = ""
sliderButton.Parent = sliderFrame

-- Slider logic

local dragging = false

sliderButton.MouseButton1Down:Connect(function()
	dragging = true
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

game:GetService("RunService").RenderStepped:Connect(function()
	if dragging then
		local mouseX = UserInputService:GetMouseLocation().X
		local sliderX = sliderFrame.AbsolutePosition.X
		local sliderW = sliderFrame.AbsoluteSize.X
		local pos = math.clamp(mouseX - sliderX, 0, sliderW)

		sliderButton.Position = UDim2.new(0, pos - 10, 0, 0)
		sliderBar.Size = UDim2.new(0, pos, 1, 0)

		local value = math.floor((pos / sliderW) * 24) -- percentage
		title.Text = "⚙ SETTINGS ("..value..")" -- just showing value in title for now
	end
end)


-- // Advanced AutoFarm Detector & Server Hopper (Persistent)
if not game:IsLoaded() then game.Loaded:Wait() end


local PLACE_ID = game.PlaceId
local JOB_ID = game.JobId

-- 🔹 Change this to your hosted script or raw script text
local MY_SCRIPT_URL = "https://raw.githubusercontent.com/EclipseYT212/EXPLOSIVE/refs/heads/main/3CL1PSE3XPL01TSmm2"

-- 🌀 Server hop with persistence
local function ServerHop()
    print("🌍 Searching for a new server...")

    local success, result = pcall(function()
        return HttpService:JSONDecode(
            game:HttpGetAsync(("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(PLACE_ID))
        )
    end)
    if not success then return end

    for _, server in ipairs(result.data) do
        if server.playing < server.maxPlayers and server.id ~= JOB_ID then
            print("➡️ Hopping to server:", server.id)

            -- ✅ Queue script so it runs again after teleport
            if queue_on_teleport then
                queue_on_teleport(('loadstring(game:HttpGet("%s"))()'):format(MY_SCRIPT_URL))
            else
                warn("⚠️ Your executor does not support queue_on_teleport, use AutoExec instead.")
            end

            TeleportService:TeleportToPlaceInstance(PLACE_ID, server.id, LocalPlayer)
            return
        end
    end
end

-- ⚡ Detect AutoFarmers
local function IsAutoFarmer(plr)
    if not plr.Character then return false end
    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return false end

    -- Carrier/seat farming
    if hum.Sit and (plr.Character:FindFirstChild("Carrier") or plr.Character:FindFirstChildWhichIsA("Seat")) then
        return true
    end

    -- Velocity / Body movers
    for _, obj in ipairs(hrp:GetChildren()) do
        if obj:IsA("BodyVelocity") or obj:IsA("BodyGyro") or obj:IsA("AlignPosition") then
            return true
        end
    end

    -- Teleport jumps
    local lastPos = hrp:GetAttribute("LastPos")
    if lastPos then
        local dist = (hrp.Position - lastPos).Magnitude
        if dist > 70 then -- sudden suspicious jump
            return true
        end
    end
    hrp:SetAttribute("LastPos", hrp.Position)

    return false
end

-- Count AutoFarmers
local function CountAutoFarmers()
    local count = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and IsAutoFarmer(plr) then
            count += 1
        end
    end
    return count
end
--[[
-- 🚀 Background loop
task.spawn(function()
    while task.wait(10) do
        local farmers = CountAutoFarmers()
        print("🔍 AutoFarmers detected:", farmers)
        if farmers >= 3 then
            warn("⚠️ Too many AutoFarmers! Auto-hopping...")
            ServerHop()
            break
        end
    end
end)
]]

local function teleportAbove(part, offset)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    local pos = part.Position + Vector3.new(0, part.Size.Y/2 + offset, 0)
    hrp.CFrame = CFrame.new(pos)
end

-- detect map load
Workspace.ChildAdded:Connect(function(child)
    -- MM2 maps are usually Models with lots of Parts
    if child:IsA("Model") and child:FindFirstChildWhichIsA("BasePart") then
        task.wait(1) -- let it finish loading
        local size, center = child:GetBoundingBox()
        print("⚡ New map detected:", child.Name)

        -- teleport above the whole map
        teleportAbove({Position = center.Position, Size = size}, 50)
    end
end)
-- Queue on Teleport Auto-Loader
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

-- Your script URL
local SCRIPT_URL = "https://api.luarmor.net/files/v3/loaders/fdf52624dcad3a17e0e092d6adde522e.lua"

-- Function to load the script
local function loadScript()
    local success, err = pcall(function()
        loadstring(game:HttpGet(SCRIPT_URL))()
    end)
    
    if success then
        print("✅ Auto-loaded script successfully")
    else
        warn("❌ Failed to auto-load script:", err)
    end
end

-- Queue the script to load on teleport
local teleportData = {
    action = "loadScript",
    url = SCRIPT_URL,
    timestamp = tick()
}

-- Set the teleport data
TeleportService:SetTeleportGui(nil)
pcall(function()
    TeleportService:SetTeleportData(HttpService:JSONEncode(teleportData))
end)

-- Check if we just teleported and should auto-load
task.spawn(function()
    task.wait(2) -- Small delay to let game load
    
    local success, teleportDataReceived = pcall(function()
        return TeleportService:GetTeleportData()
    end)
    
    if success and teleportDataReceived then
        local data = HttpService:JSONDecode(teleportDataReceived)
        if data and data.action == "loadScript" and data.url then
            print("🔄 Detected teleport - auto-loading script...")
            loadScript()
        end
    else
        -- First time running, just load normally
        print("🔄 First time running - loading script...")
        loadScript()
    end
end)

-- Remove this line to prevent double loading:
-- loadScript()
-- ============================================
-- MOBILE PANEL TOGGLE (ADD AFTER ALL UI)
-- ============================================
if isMobile then
    local pt = Instance.new("TextButton", frame)
    pt.Size, pt.Position, pt.ZIndex = UDim2.new(0, 35, 0, 22), UDim2.new(1, -40, 0, 5), 3
    pt.BackgroundColor3, pt.Text, pt.TextSize, pt.Font = Color3.fromRGB(50,50,60), "📊", 14, Enum.Font.GothamBold
    pt.TextColor3 = Color3.new(1,1,1)
    do local c = Instance.new("UICorner", pt); c.CornerRadius = UDim.new(0, 4) end
    local pv = false
    pt.MouseButton1Click:Connect(function()
        pv = not pv
        if logFrame then logFrame.Visible = pv end
        pt.Text, pt.BackgroundColor3 = pv and "✖️" or "📊", pv and Color3.fromRGB(255,100,100) or Color3.fromRGB(50,50,60)
    end)
end

print("=" .. string.rep("=", 50) .. "=\n  MM2 AUTOFARM - " .. (isMobile and "MOBILE" or "PC") .. " MODE\n")


-- ==== MOBILE FIT/DRAG UTILS (low-register, reusable) ====
_G.UIUtil = _G.UIUtil or {}

function _G.UIUtil.isMobile()
    local UIS = game:GetService("UserInputService")
    return UIS.TouchEnabled and not UIS.KeyboardEnabled
end

function _G.UIUtil.mobileScale(guiObj, minS, maxS)
    if not _G.UIUtil.isMobile() then return end
    local cam = workspace.CurrentCamera
    local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local scale = math.clamp(math.min(vs.X/1280, vs.Y/720), minS or 0.55, maxS or 0.9)
    local s = Instance.new("UIScale"); s.Scale = scale; s.Parent = guiObj
end

function _G.UIUtil.safeCenter(guiObj)
    if not _G.UIUtil.isMobile() then return end
    local GuiService = game:GetService("GuiService")
    local insets = GuiService:GetSafeZoneInsets()
    guiObj.AnchorPoint = Vector2.new(0.5, 0.5)
    guiObj.Position = UDim2.new(0.5, 0, 0.5, (insets.Top - insets.Bottom)/2)
end

function _G.UIUtil.makeDraggable(handle, target)
    local UIS = game:GetService("UserInputService")
    local DR = {drag=false}
    local function begin(i)
        DR.drag = true; DR.input = i
        DR.startInput = i.Position; DR.startPos = target.Position
        i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then DR.drag = false end
        end)
    end
    local function update(i)
        if DR.drag and i == DR.input then
            local d = i.Position - DR.startInput
            target.Position = UDim2.new(DR.startPos.X.Scale, DR.startPos.X.Offset + d.X, DR.startPos.Y.Scale, DR.startPos.Y.Offset + d.Y)
        end
    end
    handle.Active = true; target.Active = true
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then begin(i) end
    end)
    handle.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then DR.input = i end
    end)
    UIS.InputChanged:Connect(update)
end

function _G.UIUtil.fitLabelToBar(labelObj, maxSize, minSize, padX)
    if not _G.UIUtil.isMobile() then return end
    local TS = game:GetService("TextService")
    labelObj.TextScaled, labelObj.TextWrapped = false, true
    local function fit()
        local w = math.max(10, labelObj.AbsoluteSize.X - (padX or 12))
        local h = math.max(10, labelObj.AbsoluteSize.Y - 2)
        local s = maxSize or 18
        while s > (minSize or 10) do
            local b = TS:GetTextSize(labelObj.Text, s, labelObj.Font, Vector2.new(w, 1e6))
            if b.X <= w and b.Y <= h then break end
            s -= 1
        end
        labelObj.TextSize = s
    end
    fit()
    labelObj:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
end
warn("Loaded")
