local CFG = getgenv().Setting or {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CommF_Remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
pcall(function() CommF_Remote:InvokeServer("SetTeam", CFG["Team"]) end)

local LocalPlayer = game:GetService("Players").LocalPlayer
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = LocalPlayer

-- Đợi character load
player.Character = player.Character or player.CharacterAdded:Wait()

-- =============================================
-- TẢI VÀ CẤU HÌNH FASTATTACK MODULE
-- =============================================
loadstring(game:HttpGet("https://raw.githubusercontent.com/jayetcixgaming2010/UI/refs/heads/main/UI.lua"))()
local FastAttack = getgenv().rz_FastAttack
if FastAttack then
    -- Ghi đè hàm tìm kẻ địch gần nhất để chỉ tấn công target hiện tại
    FastAttack.GetClosestEnemy = function(self, ...)
        local targ = getgenv().targ
        if targ and targ.Character and targ.Character:FindFirstChild("HumanoidRootPart") then
            return targ.Character.HumanoidRootPart
        end
        return nil
    end
    print("✅ FastAttack loaded and configured")
end

-- =============================================
-- M1 AUTO ATTACK
-- =============================================
local m1Enabled = true

-- Danh sách fruit KHÔNG có M1 (Elemental / Logia)
local NO_M1_FRUITS = {
    ["Smoke"]   = true, ["Sand"]    = true, ["Dark"]    = true,
    ["Light"]   = true, ["Magma"]   = true, ["Ice"]     = true,
    ["Diamond"] = true, ["Rumble"]  = true, ["Gravity"] = true,
    ["Flame"]   = true, ["Quake"]   = true, ["Blizzard"]= true,
    ["Spider"]  = true,
}

-- GUI thông báo "Fruit No Support M1"
local m1NotifGui = Instance.new("ScreenGui")
m1NotifGui.Name = "M1FruitNotif"
m1NotifGui.ResetOnSpawn = false
m1NotifGui.Parent = CoreGui

local m1NotifFrame = Instance.new("Frame", m1NotifGui)
m1NotifFrame.Size = UDim2.new(0, 320, 0, 60)
m1NotifFrame.Position = UDim2.new(0.5, -160, 0, 80)
m1NotifFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
m1NotifFrame.BackgroundTransparency = 0.25
m1NotifFrame.BorderSizePixel = 0
m1NotifFrame.Visible = false
Instance.new("UICorner", m1NotifFrame).CornerRadius = UDim.new(0, 8)
local m1NotifStroke = Instance.new("UIStroke", m1NotifFrame)
m1NotifStroke.Color = Color3.fromRGB(255, 80, 80)
m1NotifStroke.Thickness = 2

local m1NotifIcon = Instance.new("TextLabel", m1NotifFrame)
m1NotifIcon.Size = UDim2.new(0, 40, 1, 0)
m1NotifIcon.Position = UDim2.new(0, 8, 0, 0)
m1NotifIcon.BackgroundTransparency = 1
m1NotifIcon.Text = "🚫"
m1NotifIcon.TextSize = 26
m1NotifIcon.Font = Enum.Font.RobotoMono
m1NotifIcon.TextColor3 = Color3.fromRGB(255, 255, 255)

local m1NotifTitle = Instance.new("TextLabel", m1NotifFrame)
m1NotifTitle.Size = UDim2.new(1, -60, 0, 28)
m1NotifTitle.Position = UDim2.new(0, 52, 0, 6)
m1NotifTitle.BackgroundTransparency = 1
m1NotifTitle.Text = "Fruit No Support M1"
m1NotifTitle.TextSize = 15
m1NotifTitle.Font = Enum.Font.RobotoMono
m1NotifTitle.TextColor3 = Color3.fromRGB(255, 80, 80)
m1NotifTitle.TextXAlignment = Enum.TextXAlignment.Left

local m1NotifSub = Instance.new("TextLabel", m1NotifFrame)
m1NotifSub.Size = UDim2.new(1, -60, 0, 22)
m1NotifSub.Position = UDim2.new(0, 52, 0, 32)
m1NotifSub.BackgroundTransparency = 1
m1NotifSub.Text = "..."
m1NotifSub.TextSize = 12
m1NotifSub.Font = Enum.Font.RobotoMono
m1NotifSub.TextColor3 = Color3.fromRGB(200, 200, 200)
m1NotifSub.TextXAlignment = Enum.TextXAlignment.Left

local m1NotifShowing = false
local lastNoM1Fruit = ""

local function showM1Notif(fruitName)
    if m1NotifShowing and lastNoM1Fruit == fruitName then return end
    lastNoM1Fruit = fruitName
    m1NotifShowing = true
    m1NotifSub.Text = "[ " .. fruitName .. " ] is Elemental type"
    m1NotifFrame.Visible = true
    -- Auto ẩn sau 3 giây
    task.delay(3, function()
        m1NotifFrame.Visible = false
        m1NotifShowing = false
        lastNoM1Fruit = ""
    end)
end

-- Kiểm tra fruit đang cầm có dùng M1 được không
local function canUseM1()
    local char = player.Character
    if not char then return true end

    -- Check tool Blox Fruit đang cầm trong tay
    for _, tool in pairs(char:GetChildren()) do
        if tool:IsA("Tool") and tool.ToolTip == "Blox Fruit" then
            if NO_M1_FRUITS[tool.Name] then
                showM1Notif(tool.Name)
                return false
            end
            return true
        end
    end

    -- Fallback: check qua Data nếu fruit chưa equip
    local fruitData = player:FindFirstChild("Data") and player.Data:FindFirstChild("DevilFruit")
    if fruitData and fruitData.Value ~= "" and NO_M1_FRUITS[fruitData.Value] then
        showM1Notif(fruitData.Value)
        return false
    end

    return true
end

task.spawn(function()
    while task.wait() do
        pcall(function()
            if not m1Enabled then return end
            if not canUseM1() then return end
            local targ = getgenv().targ
            if not targ or not targ.Character then return end
            local char = player.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then return end
            local hum = char:FindFirstChild("Humanoid")
            if not hum or hum.Health <= 0 then return end
            local hrp = char.HumanoidRootPart
            local targHRP = targ.Character:FindFirstChild("HumanoidRootPart")
            if not targHRP then return end
            local dist = (targHRP.Position - hrp.Position).Magnitude
            if dist < 15 then
                -- Quay mặt về phía target trước khi M1
                hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(targHRP.Position.X, hrp.Position.Y, targHRP.Position.Z))
                if FastAttack then
                    FastAttack:M1()
                else
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                    task.wait(0.05)
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                end
            end
        end)
    end
end)

-- =============================================
-- BIẾN TOÀN CỤC
-- =============================================
getgenv().weapon = nil
getgenv().targ = nil
getgenv().checked = {}
getgenv().killed = nil
getgenv().hopserver = false
getgenv().dangerCount = {}
getgenv().dangerBlacklist = {}
getgenv().ServerBlacklist = getgenv().ServerBlacklist or {}

-- =============================================
-- AUTO CONFIRM TELEPORT POPUP
-- =============================================
task.spawn(function()
    local function autoConfirmTeleport(gui)
        if not gui then return end
        for _, btn in pairs(gui:GetDescendants()) do
            if (btn:IsA("TextButton") or btn:IsA("ImageButton")) then
                local t = string.lower(btn.Text or "")
                if t == "ok" or t == "yes" or t == "teleport" or t == "confirm" or t == "leave" then
                    pcall(function() btn:activate() end)
                    pcall(function() btn.MouseButton1Click:Fire() end)
                end
            end
        end
    end

    local promptGui = CoreGui:WaitForChild("RobloxPromptGui", 10)
    if promptGui then
        local overlay = promptGui:FindFirstChild("promptOverlay")
        if overlay then
            overlay.ChildAdded:Connect(function(child)
                task.wait(0.1)
                autoConfirmTeleport(overlay)
            end)
            autoConfirmTeleport(overlay)
        end
    end

    CoreGui.ChildAdded:Connect(function(child)
        task.wait(0.2)
        autoConfirmTeleport(child)
    end)

    player.PlayerGui.ChildAdded:Connect(function(child)
        task.wait(0.2)
        autoConfirmTeleport(child)
    end)

    while task.wait(0.5) do
        pcall(function() autoConfirmTeleport(CoreGui) end)
        pcall(function() autoConfirmTeleport(player.PlayerGui) end)
    end
end)

-- =============================================
-- DANGER BLACKLIST
-- =============================================
local dangerCooldown = {}

local function checkDangerAndBlacklist()
    local cfg = CFG.Another and CFG.Another.DangerBlacklist
    if not cfg or not cfg.Enable then return end
    if not getgenv().targ then return end

    local myChar = player.Character
    if not myChar then return end
    local myHum = myChar:FindFirstChild("Humanoid")
    if not myHum then return end

    local myHealth = myHum.Health
    local myMaxHealth = myHum.MaxHealth
    if myMaxHealth <= 0 then return end

    local healthPct = myHealth / myMaxHealth
    local targName = getgenv().targ.Name

    if healthPct <= cfg.DangerHealthPct then
        if not dangerCooldown[targName] then
            dangerCooldown[targName] = true
            getgenv().dangerCount[targName] = (getgenv().dangerCount[targName] or 0) + 1
            if getgenv().dangerCount[targName] >= cfg.MaxAttempts then
                getgenv().dangerBlacklist[targName] = true
                if getgenv().SkipPlayer then getgenv().SkipPlayer() end
            end
        end
    else
        dangerCooldown[targName] = nil
    end
end

-- =============================================
-- GUI (DARKNESS X STYLE)
-- =============================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DarknessX_AutoBounty"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Nút Toggle
local ToggleBtn = Instance.new("ImageButton")
ToggleBtn.Parent = ScreenGui
ToggleBtn.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
ToggleBtn.BackgroundTransparency = 0.2
ToggleBtn.Position = UDim2.new(0, 30, 0, 30)
ToggleBtn.Size = UDim2.new(0, 45, 0, 45)
ToggleBtn.Image = "rbxassetid://101138166721164"
ToggleBtn.Draggable = true
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 4)
local ToggleStroke = Instance.new("UIStroke", ToggleBtn)
ToggleStroke.Color = Color3.fromRGB(255, 255, 255)
ToggleStroke.Thickness = 2

-- Khung chính
local MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MainFrame.BackgroundTransparency = 0.3
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
MainFrame.Size = UDim2.new(0, 400, 0, 300)
MainFrame.Visible = true
MainFrame.ClipsDescendants = true

local BgImage = Instance.new("ImageLabel", MainFrame)
BgImage.Size = UDim2.new(1, 0, 1, 0)
BgImage.BackgroundTransparency = 1
BgImage.Image = "rbxassetid://101138166721164"
BgImage.ImageTransparency = 0.6
BgImage.ScaleType = Enum.ScaleType.Slice

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = Color3.fromRGB(255, 255, 255)
MainStroke.Thickness = 2
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 6)

-- Kéo thả MainFrame
local dragging, dragInput, dragStart, startPos
local function update(input)
    local delta = input.Position - dragStart
    MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then update(input) end
end)

-- Kéo thả ToggleBtn
local toggleDragging, toggleDragInput, toggleDragStart, toggleStartPos
local function updateToggle(input)
    local delta = input.Position - toggleDragStart
    ToggleBtn.Position = UDim2.new(toggleStartPos.X.Scale, toggleStartPos.X.Offset + delta.X, toggleStartPos.Y.Scale, toggleStartPos.Y.Offset + delta.Y)
end
ToggleBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        toggleDragging = true
        toggleDragStart = input.Position
        toggleStartPos = ToggleBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then toggleDragging = false end
        end)
    end
end)
ToggleBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        toggleDragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == toggleDragInput and toggleDragging then updateToggle(input) end
end)

-- TextLabels
local function CreateText(text, yPos)
    local lbl = Instance.new("TextLabel", MainFrame)
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 25, 0, yPos)
    lbl.Size = UDim2.new(1, -50, 0, 30)
    lbl.Font = Enum.Font.RobotoMono
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextSize = 18
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    return lbl
end

local Title = CreateText("DARKNESS X • AUTO BOUNTY", 15)
Title.TextSize = 22
Title.Font = Enum.Font.RobotoMono

local BountyLbl = CreateText("Bounty Earn: 0", 60)
local ExecLbl = CreateText("Executor: Check...", 95)
local TimeLbl = CreateText("Time Player: 00:00:00", 130)
local TargetLbl = CreateText("Target: Searching...", 175)
local DistLbl = CreateText("Distance: 0m", 210)

-- Buttons
local function CreateBtn(text, xPos)
    local btn = Instance.new("TextButton", MainFrame)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundTransparency = 0.9
    btn.Position = UDim2.new(xPos, 0, 0.83, 0)
    btn.Size = UDim2.new(0.4, 0, 0, 40)
    btn.Font = Enum.Font.RobotoMono
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 16
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1.5
    return btn
end

local SkipBtn = CreateBtn("SKIP PLAYER", 0.07)
local HopBtn = CreateBtn("HOP SERVER", 0.53)

-- Nút M1 Toggle
local M1Btn = Instance.new("TextButton", MainFrame)
M1Btn.BackgroundColor3 = Color3.fromRGB(0, 200, 80)
M1Btn.BackgroundTransparency = 0.3
M1Btn.Position = UDim2.new(0.3, 0, 0.65, 0)
M1Btn.Size = UDim2.new(0.4, 0, 0, 35)
M1Btn.Font = Enum.Font.RobotoMono
M1Btn.Text = "M1: ON"
M1Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
M1Btn.TextSize = 16
Instance.new("UICorner", M1Btn).CornerRadius = UDim.new(0, 6)
local m1Stroke = Instance.new("UIStroke", M1Btn)
m1Stroke.Color = Color3.fromRGB(0, 255, 100)
m1Stroke.Thickness = 1.5

M1Btn.MouseButton1Click:Connect(function()
    m1Enabled = not m1Enabled
    if m1Enabled then
        M1Btn.Text = "M1: ON"
        M1Btn.BackgroundColor3 = Color3.fromRGB(0, 200, 80)
        m1Stroke.Color = Color3.fromRGB(0, 255, 100)
    else
        M1Btn.Text = "M1: OFF"
        M1Btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        m1Stroke.Color = Color3.fromRGB(255, 80, 80)
    end
end)

-- Sự kiện nút
HopBtn.MouseButton1Click:Connect(function()
    HopBtn.Text = "HOPPING..."
    getgenv().hopserver = true
    getgenv().autoHopLoop = true
    task.spawn(function()
        while getgenv().autoHopLoop do
            if getgenv().HopServer then
                pcall(function() getgenv().HopServer() end)
            end
            task.wait(3)
        end
    end)
    task.delay(3, function() HopBtn.Text = "HOP SERVER" end)
end)

SkipBtn.MouseButton1Click:Connect(function()
    SkipBtn.Text = "SKIPPING..."
    if getgenv().SkipPlayer then
        getgenv().SkipPlayer()
    end
    task.delay(0.5, function() SkipBtn.Text = "SKIP PLAYER" end)
end)

-- Toggle ẩn/hiện
ToggleBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Update loop (RenderStepped)
local uiStartTime = os.time()
local initialBounty = nil
task.spawn(function()
    task.wait(3)
    if player and player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Bounty/Honor") then
        initialBounty = player.leaderstats["Bounty/Honor"].Value
    end
    ExecLbl.Text = "Executor: " .. ((identifyexecutor and identifyexecutor()) or "Unknown")
end)

RunService.RenderStepped:Connect(function()
    pcall(function()
        -- Bounty earn
        if player and player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Bounty/Honor") and initialBounty then
            local earned = player.leaderstats["Bounty/Honor"].Value - initialBounty
            BountyLbl.Text = "Bounty Earn: " .. tostring(earned)
        end
        -- Timer
        local diff = os.time() - uiStartTime
        local h = math.floor(diff / 3600)
        local m = math.floor((diff % 3600) / 60)
        local s = diff % 60
        TimeLbl.Text = string.format("Time Player: %02d:%02d:%02d", h, m, s)
        -- Target & Distance
        local targ = getgenv().targ
        if targ and targ.Character and targ.Character:FindFirstChild("HumanoidRootPart") then
            TargetLbl.Text = "Target: " .. targ.Name
            local myChar = player.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local dist = (myRoot.Position - targ.Character.HumanoidRootPart.Position).Magnitude
                DistLbl.Text = "Distance: " .. math.floor(dist) .. " m"
                DistLbl.TextColor3 = dist < 50 and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 255, 255)
            end
        else
            TargetLbl.Text = "Target: Searching..."
            DistLbl.Text = "Distance: 0 m"
            DistLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end)
end)

-- =============================================
-- WORLD DETECTION (kick nếu sai game)
-- =============================================
local placeId = game.PlaceId
local validPlaces = {
    [2753915549]=true, [85211729168715]=true,  -- World 1
    [4442272183]=true, [79091703265657]=true,  -- World 2
    [7449423635]=true, [100117331123089]=true, -- World 3
}
if not validPlaces[placeId] then
    player:Kick("❌ Not Support Game ❌")
    return
end

local p2 = Players  -- alias
local lp = player

local tween = nil
function to(Pos)
    pcall(function()
        if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") and lp.Character:FindFirstChild("Humanoid") and lp.Character.Humanoid.Health > 0 then
            local hrp = lp.Character.HumanoidRootPart
            local Distance = (Pos.Position - hrp.Position).Magnitude

            if not hrp:FindFirstChild("Hold") then
                local Hold = Instance.new("LinearVelocity", hrp)
                Hold.Name = "Hold"
                Hold.MaxForce = math.huge
                Hold.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
                Hold.VectorVelocity = Vector3.new(0, 0, 0)
                Hold.RelativeTo = Enum.ActuatorRelativeTo.World
                local att = Instance.new("Attachment", hrp)
                att.Name = "HoldAtt"
                Hold.Attachment0 = att
            end

            if lp.Character.Humanoid.Sit == true then
                lp.Character.Humanoid.Sit = false
            end

            if Distance <= 250 then
                if tween then tween:Cancel() end
                hrp.CFrame = Pos
                return
            end

            local Speed = Distance < 1000 and 340 or 320

            if tween then tween:Cancel() end

            tween = TweenService:Create(
                hrp,
                TweenInfo.new(Distance / Speed, Enum.EasingStyle.Linear),
                {CFrame = Pos}
            )
            tween:Play()

            if lp.Character.Humanoid.Sit == true then
                lp.Character.Humanoid.Sit = false
            end
        end
    end)
end

function down(use, waitTime)
    pcall(function()
        if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
            VirtualInputManager:SendKeyEvent(true, use, false, lp.Character.HumanoidRootPart)
            task.wait(waitTime or 0.1)
            VirtualInputManager:SendKeyEvent(false, use, false, lp.Character.HumanoidRootPart)
        end
    end)
end

-- Vòng lặp chống xuyên tường
task.spawn(function()
    while task.wait() do
        pcall(function()
            if lp.Character then
                for _, v in pairs(lp.Character:GetChildren()) do
                    if v:IsA("BasePart") then
                        v.CanCollide = false
                    end
                end
            end
        end)
    end
end)

-- Tối ưu đồ họa
if CFG.Another and CFG.Another.FPSBoost then
    local g = game
    local w = g.Workspace
    local l = g.Lighting
    local t = w.Terrain
    t.WaterWaveSize = 0
    t.WaterWaveSpeed = 0
    t.WaterReflectance = 0
    t.WaterTransparency = 0
    l.GlobalShadows = false
    l.FogEnd = 9e9
    l.Brightness = 0.8
    settings().Rendering.QualityLevel = "Level10"
end
RunService:Set3dRenderingEnabled(true)

function hasValue(array, targetString)
    if not array then return false end
    for _, value in ipairs(array) do
        if value == targetString then
            return true
        end
    end
    return false
end

-- Hack CombatFramework
local y = nil
pcall(function()
    if lp:FindFirstChild("PlayerScripts") then
        local success, result = pcall(function()
            return require(lp.PlayerScripts:FindFirstChild("CombatFramework"))
        end)
        if success and result then
            local getCombatFramework = result
            local getCombatFrameworkR = debug.getupvalues(getCombatFramework)[2]
            y = getCombatFrameworkR
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if y and typeof(y) == "table" then
        pcall(function()
            if y.activeController then
                y.activeController.hitboxMagnitude = 80
                y.activeController.active = false
                y.activeController.timeToNextBlock = 0
                y.activeController.focusStart = 1655503339.0980349
                y.activeController.increment = 1
                y.activeController.blocking = false
                y.activeController.attacking = false
                if y.activeController.humanoid then
                    y.activeController.humanoid.AutoRotate = true
                end
            end
        end)
    end
end)

-- Hop khi cần: chờ hết combat timer rồi mới hop
local starthop = false

task.spawn(function()
    while task.wait() do
        if getgenv().hopserver then
            starthop = true
        end
    end
end)

task.spawn(function()
    while task.wait() do
        if starthop then
            -- Chờ hết in-combat nếu cần
            local ok, inCombat = pcall(function()
                return lp.PlayerGui.Main.BottomHUDList.InCombat.Visible
                    and string.find(string.lower(lp.PlayerGui.Main.BottomHUDList.InCombat.Text), "risk")
            end)
            if ok and inCombat then
                repeat
                    task.wait()
                    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                        to(lp.Character.HumanoidRootPart.CFrame * CFrame.new(0, math.random(500, 2000), 0))
                    end
                until not (pcall(function()
                    return lp.PlayerGui.Main.BottomHUDList.InCombat.Visible
                        and string.find(string.lower(lp.PlayerGui.Main.BottomHUDList.InCombat.Text), "risk")
                end))
            end
            starthop = false
            HopServer()
        end
    end
end)

function HopServer(counts)
    local S = game.JobId
    table.insert(getgenv().ServerBlacklist, S)
    local T, U = pcall(function()
        local V = HttpService
        local W = TeleportService
        local X = string.format("https://games.roblox.com/v1/games/%d/servers/Public?limit=100", game.PlaceId)
        local Y = V:JSONDecode(game:HttpGet(X))
        local Z = nil
        for _, _0 in ipairs(Y.data) do
            if _0.playing and _0.maxPlayers and _0.playing > 5 and _0.playing < _0.maxPlayers - 2 then
                local _1 = _0.id
                local _2 = false
                for _, _3 in ipairs(getgenv().ServerBlacklist) do
                    if _3 == _1 then _2 = true break end
                end
                if not _2 then Z = _0 break end
            end
        end
        if not Z then
            for _, _0 in ipairs(Y.data) do
                if _0.playing and _0.maxPlayers and _0.playing > 10 and _0.playing < _0.maxPlayers then
                    local _1 = _0.id
                    local _2 = false
                    for _, _3 in ipairs(getgenv().ServerBlacklist) do
                        if _3 == _1 then _2 = true break end
                    end
                    if not _2 then Z = _0 break end
                end
            end
        end
        if not Z and #Y.data > 0 then
            for _, _0 in ipairs(Y.data) do
                local _1 = _0.id
                local _2 = false
                for _, _3 in ipairs(getgenv().ServerBlacklist) do
                    if _3 == _1 then _2 = true break end
                end
                if not _2 then Z = _0 break end
            end
        end
        if not Z and #Y.data > 0 then Z = Y.data[1] end
        if Z and Z.id then
            W:TeleportToPlaceInstance(game.PlaceId, Z.id)
        else
            W:Teleport(game.PlaceId)
        end
    end)
    if not T or U then TeleportService:Teleport(game.PlaceId) end
end
getgenv().HopServer = HopServer

local skipping = false
local safehealth = false

function SkipPlayer()
    if skipping then return end
    skipping = true
    getgenv().killed = getgenv().targ
    if getgenv().targ then
        table.insert(getgenv().checked, getgenv().targ)
    end
    getgenv().targ = nil
    print("None")
    if getgenv().target then
        getgenv().target()
    end
    task.spawn(function()
        task.wait(0.5)
        skipping = false
    end)
end
getgenv().SkipPlayer = SkipPlayer

-- Kiểm tra SafeZone
function CheckSafeZone(nitga)
    local safeZones = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("SafeZones")
    if not safeZones then return false end
    for r, v in pairs(safeZones:GetChildren()) do
        if v and v:IsA("Part") then
            if (v.Position - nitga.Position).Magnitude <= 400 then
                return true
            end
        end
    end
    return false
end

-- =============================================
-- HÀM KIỂM TRA target hợp lệ
-- =============================================
local function isValidBountyTarget(v)
    -- Cơ bản
    if not v or v == lp then return false end
    if not v.Character then return false end
    local vHRP = v.Character:FindFirstChild("HumanoidRootPart")
    if not vHRP then return false end
    local vHum = v.Character:FindFirstChild("Humanoid")
    if not vHum or vHum.Health <= 0 then return false end

    -- Cần có Data và leaderstats
    if not v:FindFirstChild("Data") then return false end
    if not v:FindFirstChild("leaderstats") then return false end
    if not v.leaderstats:FindFirstChild("Bounty/Honor") then return false end

    -- Bounty range
    local bounty = v.leaderstats["Bounty/Honor"].Value
    local minB = CFG.Hunt and CFG.Hunt.Min or 0
    local maxB = CFG.Hunt and CFG.Hunt.Max or math.huge
    if bounty < minB or bounty > maxB then return false end

    -- Level check: không đánh target thấp hơn mình quá 250 level
    if lp:FindFirstChild("Data") and lp.Data:FindFirstChild("Level") and v.Data:FindFirstChild("Level") then
        if (tonumber(lp.Data.Level.Value) - 250) >= tonumber(v.Data.Level.Value) then return false end
    end

    -- Team check: target phải KHÁC team với mình
    -- Trong Blox Fruits: tostring(player.Team) trả về tên team
    local myTeam = tostring(lp.Team)
    local vTeam  = tostring(v.Team)
    -- Nếu cùng team thì skip (friendly)
    if myTeam == vTeam then return false end

    -- Skip theo config
    if CFG.Skip then
        if CFG.Skip.RaceV4 and v.Character:FindFirstChild("RaceTransformed") then return false end
        if CFG["Skip Race V4"] and v.Character:FindFirstChild("RaceTransformed") then return false end
        if CFG.Skip.Fruit and v.Data:FindFirstChild("DevilFruit") then
            if hasValue(CFG.Skip.FruitList or {}, v.Data.DevilFruit.Value) then return false end
        end
        if CFG.Skip.SafeZone then
            local inSafe = false
            pcall(function() inSafe = CheckSafeZone(vHRP) end)
            if inSafe then return false end
        end
    end

    -- Blacklist / checked
    if getgenv().dangerBlacklist[v.Name] then return false end
    if hasValue(getgenv().checked, v) then return false end

    -- Không đánh target đang bay quá cao (đang thoát)
    if vHRP.Position.Y > 12000 then return false end

    return true
end

-- Hàm tìm target
function target()
    pcall(function()
        if not lp.Character or not lp.Character:FindFirstChild("HumanoidRootPart") then return end
        local d = math.huge
        local p = nil
        getgenv().targ = nil

        local allPlayers = Players:GetPlayers()
        print("🔍 Scanning " .. #allPlayers .. " players | MyTeam: " .. tostring(lp.Team))

        for _, v in pairs(allPlayers) do
            if v ~= lp then
                local ok = isValidBountyTarget(v)
                if not ok then
                    -- Debug: in lý do fail cho từng player
                    local reason = "unknown"
                    if not v.Character then reason = "no character"
                    elseif not v:FindFirstChild("leaderstats") then reason = "no leaderstats"
                    elseif not v.leaderstats:FindFirstChild("Bounty/Honor") then reason = "no bounty stat"
                    elseif tostring(lp.Team) == tostring(v.Team) then reason = "same team (" .. tostring(v.Team) .. ")"
                    elseif hasValue(getgenv().checked, v) then reason = "already checked"
                    end
                    print("  ❌ " .. v.Name .. " → " .. reason)
                else
                    local dist = (v.Character.HumanoidRootPart.Position - lp.Character.HumanoidRootPart.Position).Magnitude
                    if dist < d and not getgenv().hopserver then
                        p = v
                        d = dist
                    end
                end
            end
        end

        -- Gửi chat 1 lần duy nhất sau khi đã chọn xong target
        if p ~= nil and CFG.Chat and #CFG.Chat > 0 then
            local chatMsg = CFG.Chat[math.random(1, #CFG.Chat)]
            if chatMsg then
                pcall(function()
                    ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents"):FindFirstChild("SayMessageRequest"):FireServer(chatMsg, "All")
                end)
            end
        end

        if p == nil then
            if CFG.Another and CFG.Another.HopAfterAllPlayers then
                local hasRemainingValidPlayer = false
                for _, v in pairs(Players:GetPlayers()) do
                    if v ~= lp and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                        if v:FindFirstChild("Data") and v:FindFirstChild("leaderstats") and v.leaderstats["Bounty/Honor"] then
                            local bounty = v.leaderstats["Bounty/Honor"].Value
                            if bounty >= (CFG.Hunt and CFG.Hunt.Min or 0) and bounty <= (CFG.Hunt and CFG.Hunt.Max or 1e9) then
                                if lp.Data and lp.Data.Level then
                                    if (tonumber(lp.Data.Level.Value) - 250) < v.Data.Level.Value then
                                        if not hasValue(getgenv().checked, v) and not getgenv().dangerBlacklist[v.Name] then
                                            hasRemainingValidPlayer = true
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                if hasRemainingValidPlayer then
                    print("⏳ [HopAfterAllPlayers] Còn player đủ điều kiện, chờ...")
                else
                    print("✅ [HopAfterAllPlayers] Đã xử lý hết player trong server → Hop!")
                    getgenv().checked = {}
                    HopServer()
                end
            else
                HopServer()
            end
        else
            print("🎯 Đã tìm thấy mục tiêu: " .. p.Name)
        end
        getgenv().targ = p
    end)
end
getgenv().target = target

-- =============================================
-- EQUIP FRUIT: giữ Blox Fruit trong tay liên tục
-- =============================================
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            if not lp.Character then return end
            -- Kiểm tra đã cầm fruit chưa
            local hasFruit = false
            for _, tool in pairs(lp.Character:GetChildren()) do
                if tool:IsA("Tool") and tool.ToolTip == "Blox Fruit" then
                    hasFruit = true
                    break
                end
            end
            if not hasFruit then
                local hum = lp.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    for _, item in pairs(lp.Backpack:GetChildren()) do
                        if item:IsA("Tool") and item.ToolTip == "Blox Fruit" then
                            hum:EquipTool(item)
                            break
                        end
                    end
                end
            end
        end)
    end
end)

-- =============================================
-- FLY TO TARGET: teleport liên tục bám sát target
-- =============================================
task.spawn(function()
    while task.wait() do
        pcall(function()
            if safehealth then return end
            local targ = getgenv().targ
            if not targ or not targ.Character then return end
            local targHRP = targ.Character:FindFirstChild("HumanoidRootPart")
            if not targHRP then return end
            if not lp.Character or not lp.Character:FindFirstChild("HumanoidRootPart") then return end
            local hrp = lp.Character.HumanoidRootPart
            local dist = (targHRP.Position - hrp.Position).Magnitude

            -- Nếu còn xa thì bay đến, dừng lại cách 10 studs
            if dist > 12 then
                local dir = (targHRP.Position - hrp.Position).Unit
                local goalCF = CFrame.new(targHRP.Position - dir * 10)
                -- Teleport thẳng nếu gần (<300), tween nếu xa
                if dist <= 300 then
                    hrp.CFrame = goalCF
                else
                    if tween then pcall(function() tween:Cancel() end) end
                    tween = TweenService:Create(
                        hrp,
                        TweenInfo.new(dist / 400, Enum.EasingStyle.Linear),
                        {CFrame = goalCF}
                    )
                    tween:Play()
                end
            end
        end)
    end
end)

-- =============================================
-- AURA: bật Ken + Buso liên tục khi có target
-- =============================================
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            if not getgenv().targ or not lp.Character then return end
            -- Buso (Hardening)
            if not lp.Character:FindFirstChild("HasBuso") then
                pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("Buso") end)
            end
            -- Ken (Observation / Dodge)
            if not (lp:FindFirstChild("PlayerGui") and lp.PlayerGui:FindFirstChild("ScreenGui") and lp.PlayerGui.ScreenGui:FindFirstChild("ImageLabel")) then
                VirtualUser:CaptureController()
                VirtualUser:SetKeyDown("0x65")
                VirtualUser:SetKeyUp("0x65")
            end
        end)
    end
end)

-- Bật PVP + auto V3/V4
task.spawn(function()
    while task.wait(3) do
        pcall(function()
            pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("EnablePvp") end)

            if getgenv().targ and getgenv().targ.Character and lp.Character and
               lp.Character:FindFirstChild("HumanoidRootPart") and
               (getgenv().targ.Character.HumanoidRootPart.Position - lp.Character.HumanoidRootPart.Position).Magnitude < 50 then

                local alreadyTransformed = lp.Character:FindFirstChild("RaceTransformed") ~= nil
                local myHum = lp.Character:FindFirstChild("Humanoid")

                if CFG.Another and CFG.Another.V3 then
                    local shouldV3 = false
                    if CFG.Another.CustomHealth then
                        if myHum and myHum.Health <= (CFG.Another.Health or 4700) then
                            shouldV3 = true
                        end
                    else
                        shouldV3 = true
                    end
                    if shouldV3 and not alreadyTransformed then
                        down("T", 0.1)
                    end
                end

                if CFG.Another and CFG.Another.V4 then
                    if not alreadyTransformed then
                        down("Y", 0.1)
                    end
                end
            end
        end)
    end
end)

-- Hook mở rộng: sửa vị trí remote về phía target
local oldNamecall
pcall(function()
    local mt = getrawmetatable(game)
    if not mt then return end
    oldNamecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        -- Nếu là FireServer và có target, thử sửa vị trí
        if method == "FireServer" and getgenv().targ and getgenv().targ.Character and getgenv().targ.Character:FindFirstChild("HumanoidRootPart") then
            -- Danh sách các remote thường chứa vị trí (có thể mở rộng)
            local remoteNames = {
                "UpdateMousePos", "MousePos", "Click", "LeftClick", "RightClick",
                "Activate", "Deactivate", "Skill", "SkillActivate", "Ability",
                "Z", "X", "C", "V", "F", -- các phím skill
                "RemoteEvent", "RemoteFunction"
            }
            local remoteName = tostring(self)
            for _, name in ipairs(remoteNames) do
                if remoteName:find(name) then
                    -- Thử tìm argument là Vector3 và thay bằng vị trí target
                    for i = 1, #args do
                        if type(args[i]) == "Vector3" then
                            args[i] = getgenv().targ.Character.HumanoidRootPart.Position
                        elseif type(args[i]) == "CFrame" then
                            args[i] = CFrame.new(getgenv().targ.Character.HumanoidRootPart.Position) * (args[i] - args[i].Position)
                        elseif type(args[i]) == "table" then
                            -- Có thể đệ quy nếu cần, nhưng tạm thời bỏ qua
                        end
                    end
                    break
                end
            end
            return oldNamecall(self, unpack(args))
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end)

-- Vòng lặp chính: tìm target + kiểm tra safezone/skip
task.spawn(function()
    while task.wait() do
        if safehealth then task.wait(0.5) continue end
        if not getgenv().targ or not getgenv().targ.Character then
            getgenv().target()
        end
        if not getgenv().targ then
            getgenv().hopserver = true
        end
        pcall(function()
            local targ = getgenv().targ
            if not targ or not targ.Character or not targ.Character:FindFirstChild("HumanoidRootPart") then return end
            if not lp.Character or not lp.Character:FindFirstChild("HumanoidRootPart") then return end
            local dist = (targ.Character.HumanoidRootPart.Position - lp.Character.HumanoidRootPart.Position).Magnitude

            if dist < 40 then
                -- Kiểm tra safezone
                local inSafe = false
                pcall(function()
                    inSafe = CheckSafeZone(targ.Character.HumanoidRootPart)
                        or (lp.PlayerGui.Main and lp.PlayerGui.Main["[OLD]SafeZone"] and lp.PlayerGui.Main["[OLD]SafeZone"].Visible)
                        or targ.Character.Humanoid.Sit == true
                end)
                if inSafe then SkipPlayer() return end

                -- Kiểm tra thông báo skip
                for _, v in pairs(lp.PlayerGui.Notifications:GetChildren()) do
                    if v:IsA("TextLabel") then
                        local text = string.lower(v.Text)
                        for _, kw in pairs({
                            "player died recently", "you can't attack them yet", "cannot attack",
                            "nguoi choi vua tu tran", "người chơi vừa tử trận",
                            "died recently", "can't attack them", "cannot attack this player", "skill locked",
                        }) do
                            if string.find(text, kw) then
                                SkipPlayer()
                                pcall(function() v:Destroy() end)
                                break
                            end
                        end
                    end
                end
            end
        end)
    end
end)

-- =============================================
-- SAFE HEALTH
-- =============================================
local function getHealthPct()
    local hum = lp.Character and lp.Character:FindFirstChild("Humanoid")
    if not hum or hum.MaxHealth <= 0 then return 1 end
    return hum.Health / hum.MaxHealth
end

local function getSafeHealthPct()
    local hum = lp.Character and lp.Character:FindFirstChild("Humanoid")
    if not hum or hum.MaxHealth <= 0 then return 0.3 end
    local safeVal = CFG.SafeHealth and CFG.SafeHealth.Health or 0.3
    if safeVal <= 1 then
        return safeVal
    else
        return safeVal / hum.MaxHealth
    end
end

local function isLowHealth()
    local pct = getHealthPct()
    local safePct = getSafeHealthPct()
    local hum = lp.Character and lp.Character:FindFirstChild("Humanoid")
    return hum and hum.Health > 0 and pct <= safePct
end

task.spawn(function()
    while task.wait(0.05) do
        if isLowHealth() then
            safehealth = true
            checkDangerAndBlacklist()
            pcall(function()
                if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                    local hrp = lp.Character.HumanoidRootPart
                    local flyHeight = math.random(8000, 15000)
                    hrp.CFrame = hrp.CFrame * CFrame.new(0, flyHeight, 0)
                end
            end)
            repeat
                task.wait(0.5)
            until not isLowHealth() or not lp.Character
            safehealth = false
            print("💚 [SafeHealth] Máu đã hồi, tiếp tục hunt!")
        else
            safehealth = false

        end
    end
end)

-- Xử lý lỗi prompt
CoreGui.RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
    if not getgenv().hopserver and child.Name == 'ErrorPrompt' and child:FindFirstChild('MessageArea') and child.MessageArea:FindFirstChild("ErrorFrame") then
        TeleportService:Teleport(game.PlaceId)
    end
end)

-- Webhook kill
function sendKillWebhook(targetName, bountyEarned, currentBounty)
    if not CFG.Webhook or not CFG.Webhook.Enable or CFG.Webhook.Url == "" then return end
    local url = CFG.Webhook.Url
    local p = lp
    local function formatBounty(bounty)
        if bounty >= 1000000 then
            return string.format("%.1fM", bounty / 1000000)
        elseif bounty >= 1000 then
            return string.format("%.1fK", bounty / 1000)
        else
            return tostring(bounty)
        end
    end
    local data = {
        ["embeds"] = {{
            ["title"] = "BOUNTY HUNTER NOTIFICATION",
            ["description"] = "Kill Player",
            ["color"] = 0x67eb34,
            ["fields"] = {
                {["name"] = "Target", ["value"] = "```" .. targetName .. "```", ["inline"] = true},
                {["name"] = "Bounty Earned", ["value"] = "```" .. formatBounty(bountyEarned) .. "```", ["inline"] = true},
                {["name"] = "Current Bounty", ["value"] = "```" .. formatBounty(currentBounty) .. "```", ["inline"] = true},
                {["name"] = "👤 Hunter", ["value"] = "```" .. p.Name .. "```", ["inline"] = true},
                {["name"] = "Level", ["value"] = "```" .. tostring(p.Data and p.Data.Level and p.Data.Level.Value or "?") .. "```", ["inline"] = true},
                {["name"] = "Time", ["value"] = "```" .. os.date("%H:%M:%S %d/%m/%Y") .. "```", ["inline"] = true}
            },
            ["footer"] = {["text"] = "By Lo Hub Emorima"},
            ["thumbnail"] = {["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. p.UserId .. "&width=420&height=420&format=png"}
        }}
    }
    pcall(function()
        local jsonData = HttpService:JSONEncode(data)
        local success, response = pcall(function()
            if syn then
                return syn.request({Url = url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
            else
                return request({Url = url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
            end
        end)
        if success then
            print("✅ Sent kill webhook: " .. targetName)
        else
            print("❌ Webhook error: " .. tostring(response))
        end
    end)
end

local lastBounty = 0
task.spawn(function()
    task.wait(3)
    if lp and lp:FindFirstChild("leaderstats") then
        lastBounty = lp.leaderstats["Bounty/Honor"] and lp.leaderstats["Bounty/Honor"].Value or 0
    end
end)

local lastKilledPlayer = nil
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            if getgenv().targ and getgenv().targ.Character then
                local targetPlayer = getgenv().targ
                local char = targetPlayer.Character
                if char:FindFirstChild("Humanoid") and char.Humanoid.Health <= 0 then
                    if lastKilledPlayer ~= targetPlayer.Name then
                        task.wait(2)
                        local currentBounty = lp.leaderstats["Bounty/Honor"] and lp.leaderstats["Bounty/Honor"].Value or 0
                        local bountyEarned = currentBounty - lastBounty

                        if bountyEarned < 0 then bountyEarned = 0 end
                        sendKillWebhook(targetPlayer.Name, bountyEarned, currentBounty)
                        lastKilledPlayer = targetPlayer.Name
                        print("🎯 ELIMINATED: " .. targetPlayer.Name)
                        print("💰 Bounty earned: " .. bountyEarned)
                        lastBounty = currentBounty
                        task.wait(3)
                        SkipPlayer()
                    end
                end
            end
        end)
    end
end)

task.wait(8)
pcall(function()
    if CFG.Webhook and CFG.Webhook.Enabled and CFG.Webhook.Url ~= "" then
        local currentBounty = lp.leaderstats["Bounty/Honor"] and lp.leaderstats["Bounty/Honor"].Value or 0
        local data = {
            ["embeds"] = {{
                ["title"] = "notify",
                ["description"] = "Bounty Ez",
                ["color"] = 16753920,
                ["fields"] = {
                    {["name"] = "User Name", ["value"] = "```" .. lp.Name .. "```", ["inline"] = true},
                    {["name"] = "Level", ["value"] = "```" .. tostring(lp.Data and lp.Data.Level and lp.Data.Level.Value or "?") .. "```", ["inline"] = true},
                    {["name"] = "Current Bounty", ["value"] = "```" .. tostring(currentBounty) .. "```", ["inline"] = true},
                    {["name"] = "Check Team", ["value"] = "```" .. (CFG.Team or "Unknown") .. "```", ["inline"] = true}
                },
                ["footer"] = {["text"] = "Auto Bounty By Lo Hub " .. os.date("%H:%M %d/%m/%Y")}
            }}
        }
        pcall(function()
            local jsonData = HttpService:JSONEncode(data)
            if syn then
                syn.request({Url = CFG.Webhook.Url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
            else
                request({Url = CFG.Webhook.Url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
            end
            print("✅ Sent startup webhook")
        end)
    end
end)

-- Kiểm tra thông báo skip
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            for _, v in pairs(lp.PlayerGui.Notifications:GetChildren()) do
                if v:IsA("TextLabel") then
                    local text = string.lower(v.Text)
                    local skipKeywords = {
                        "nguoi choi vua tu tran",
                        "người chơi vừa tử trận",
                        "player died recently",
                        "you can't attack them yet",
                        "died recently",
                        "can't attack them",
                        "cannot attack this player",
                        "cannot attack",
                        "unable to attack",
                    }
                    for _, keyword in pairs(skipKeywords) do
                        if string.find(text, keyword) then
                            print("🔄 AUTO-SKIP: Phát hiện '" .. keyword .. "' - " .. string.sub(v.Text, 1, 40))
                            SkipPlayer()
                            pcall(function() v:Destroy() end)
                            break
                        end
                    end
                end
            end
        end)
    end
end)
