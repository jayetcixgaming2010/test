-- =============================================
-- FIX ALL: AUTO BOUNTY HUNTER - DARKNESS X STYLE
-- =============================================

-- Kiểm tra executor có hỗ trợ không
if not getgenv then
    return warn("Executor không hỗ trợ getgenv!")
end

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

-- Đợi character load (an toàn hơn)
repeat task.wait() until player.Character and player.Character:FindFirstChild("HumanoidRootPart")

-- =============================================
-- TẢI VÀ CẤU HÌNH FASTATTACK MODULE
-- =============================================
local FastAttack = nil
pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/jayetcixgaming2010/UI/refs/heads/main/UI.lua"))()
    FastAttack = getgenv().rz_FastAttack
    if FastAttack then
        FastAttack.GetClosestEnemy = function(self, ...)
            local targ = getgenv().targ
            if targ and targ.Character and targ.Character:FindFirstChild("HumanoidRootPart") then
                return targ.Character.HumanoidRootPart
            end
            return nil
        end
        print("✅ FastAttack loaded and configured")
    else
        print("⚠️ FastAttack not loaded, using fallback M1")
    end
end)

-- =============================================
-- BIẾN TOÀN CỤC (đảm bảo khởi tạo)
-- =============================================
getgenv().weapon = nil
getgenv().targ = nil
getgenv().checked = getgenv().checked or {}
getgenv().killed = nil
getgenv().hopserver = false
getgenv().dangerCount = getgenv().dangerCount or {}
getgenv().dangerBlacklist = getgenv().dangerBlacklist or {}
getgenv().ServerBlacklist = getgenv().ServerBlacklist or {}

-- =============================================
-- KIỂM TRA WORLD
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

-- =============================================
-- GUI THÔNG BÁO M1 NO SUPPORT
-- =============================================
local NO_M1_FRUITS = {
    ["Smoke"]=true, ["Sand"]=true, ["Dark"]=true, ["Light"]=true,
    ["Magma"]=true, ["Ice"]=true, ["Diamond"]=true, ["Rumble"]=true,
    ["Gravity"]=true, ["Flame"]=true, ["Quake"]=true, ["Blizzard"]=true,
    ["Spider"]=true,
}
local m1NotifGui = Instance.new("ScreenGui")
m1NotifGui.Name = "M1FruitNotif"
m1NotifGui.ResetOnSpawn = false
m1NotifGui.Parent = CoreGui

-- GUI thông báo fruit không hỗ trợ M1 — góc phải bên dưới màn hình
local m1NotifFrame = Instance.new("Frame", m1NotifGui)
m1NotifFrame.Size = UDim2.new(0, 340, 0, 70)
m1NotifFrame.Position = UDim2.new(1, -360, 1, -90) -- góc phải bên dưới
m1NotifFrame.AnchorPoint = Vector2.new(0, 0)
m1NotifFrame.BackgroundColor3 = Color3.fromRGB(15,10,10)
m1NotifFrame.BackgroundTransparency = 0.1
m1NotifFrame.BorderSizePixel = 0
m1NotifFrame.Visible = false
Instance.new("UICorner", m1NotifFrame).CornerRadius = UDim.new(0,10)
local m1NotifStroke = Instance.new("UIStroke", m1NotifFrame)
m1NotifStroke.Color = Color3.fromRGB(255,60,60)
m1NotifStroke.Thickness = 2

local m1NotifIcon = Instance.new("TextLabel", m1NotifFrame)
m1NotifIcon.Size = UDim2.new(0,45,1,0)
m1NotifIcon.Position = UDim2.new(0,8,0,0)
m1NotifIcon.BackgroundTransparency = 1
m1NotifIcon.Text = "🚫"
m1NotifIcon.TextSize = 28
m1NotifIcon.Font = Enum.Font.RobotoMono
m1NotifIcon.TextColor3 = Color3.fromRGB(255,255,255)

local m1NotifTitle = Instance.new("TextLabel", m1NotifFrame)
m1NotifTitle.Size = UDim2.new(1,-65,0,30)
m1NotifTitle.Position = UDim2.new(0,58,0,8)
m1NotifTitle.BackgroundTransparency = 1
m1NotifTitle.Text = "⛔ Fruit Không Hỗ Trợ M1"
m1NotifTitle.TextSize = 15
m1NotifTitle.Font = Enum.Font.RobotoMono
m1NotifTitle.TextColor3 = Color3.fromRGB(255,80,80)
m1NotifTitle.TextXAlignment = Enum.TextXAlignment.Left

local m1NotifSub = Instance.new("TextLabel", m1NotifFrame)
m1NotifSub.Size = UDim2.new(1,-65,0,22)
m1NotifSub.Position = UDim2.new(0,58,0,38)
m1NotifSub.BackgroundTransparency = 1
m1NotifSub.Text = "Auto Bounty đã bị dừng lại"
m1NotifSub.TextSize = 12
m1NotifSub.Font = Enum.Font.RobotoMono
m1NotifSub.TextColor3 = Color3.fromRGB(220,180,180)
m1NotifSub.TextXAlignment = Enum.TextXAlignment.Left

-- Biến kiểm soát bounty bị chặn do fruit
getgenv().fruitBlocked = false
local lastNoM1Fruit = ""

local function showM1Notif(fruitName)
    if lastNoM1Fruit == fruitName and m1NotifFrame.Visible then return end
    lastNoM1Fruit = fruitName
    m1NotifSub.Text = "[ " .. fruitName .. " ] là loại Elemental — Dừng săn bounty"
    m1NotifFrame.Visible = true
    -- Không tự ẩn: thông báo giữ nguyên cho đến khi fruit thay đổi
end

local function hideM1Notif()
    m1NotifFrame.Visible = false
    lastNoM1Fruit = ""
    getgenv().fruitBlocked = false
end

-- =============================================
-- HÀM TIỆN ÍCH
-- =============================================
local function hasValue(tbl, val)
    if not tbl then return false end
    for _, v in ipairs(tbl) do if v == val then return true end end
    return false
end

local function isAlive(character)
    return character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0
end

local function getRoot(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

-- =============================================
-- AUTO CONFIRM TELEPORT POPUP
-- =============================================
task.spawn(function()
    local function autoConfirm(gui)
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

    local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
    if promptGui then
        local overlay = promptGui:FindFirstChild("promptOverlay")
        if overlay then
            overlay.ChildAdded:Connect(function(child)
                task.wait(0.1)
                autoConfirm(overlay)
            end)
            autoConfirm(overlay)
        end
    end

    CoreGui.ChildAdded:Connect(function(child)
        task.wait(0.2)
        autoConfirm(child)
    end)

    player.PlayerGui.ChildAdded:Connect(function(child)
        task.wait(0.2)
        autoConfirm(child)
    end)

    while task.wait(0.5) do
        pcall(function() autoConfirm(CoreGui) end)
        pcall(function() autoConfirm(player.PlayerGui) end)
    end
end)

-- =============================================
-- DANGER BLACKLIST
-- =============================================
local dangerCooldown = {}
local function checkDangerAndBlacklist()
    local cfg = CFG.Another and CFG.Another.DangerBlacklist
    if not cfg or not cfg.Enable then return end
    local targ = getgenv().targ
    if not targ then return end

    local myChar = player.Character
    if not myChar then return end
    local myHum = myChar:FindFirstChild("Humanoid")
    if not myHum or myHum.Health <= 0 then return end

    local healthPct = myHum.Health / myHum.MaxHealth
    if healthPct <= cfg.DangerHealthPct then
        if not dangerCooldown[targ.Name] then
            dangerCooldown[targ.Name] = true
            getgenv().dangerCount[targ.Name] = (getgenv().dangerCount[targ.Name] or 0) + 1
            if getgenv().dangerCount[targ.Name] >= cfg.MaxAttempts then
                getgenv().dangerBlacklist[targ.Name] = true
                if getgenv().SkipPlayer then getgenv().SkipPlayer() end
            end
        end
    else
        dangerCooldown[targ.Name] = nil
    end
end

-- =============================================
-- GUI (DARKNESS X STYLE)
-- =============================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DarknessX_AutoBounty"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

-- Nút Toggle
local ToggleBtn = Instance.new("ImageButton")
ToggleBtn.Parent = ScreenGui
ToggleBtn.BackgroundColor3 = Color3.fromRGB(10,10,10)
ToggleBtn.BackgroundTransparency = 0.2
ToggleBtn.Position = UDim2.new(0,30,0,30)
ToggleBtn.Size = UDim2.new(0,45,0,45)
ToggleBtn.Image = "rbxassetid://101138166721164"
ToggleBtn.Draggable = true
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0,4)
local ToggleStroke = Instance.new("UIStroke", ToggleBtn)
ToggleStroke.Color = Color3.fromRGB(255,255,255)
ToggleStroke.Thickness = 2

-- Khung chính
local MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(0,0,0)
MainFrame.BackgroundTransparency = 0.3
MainFrame.Position = UDim2.new(0.5,-200,0.5,-150)
MainFrame.Size = UDim2.new(0,400,0,300)
MainFrame.Visible = true
MainFrame.ClipsDescendants = true

local BgImage = Instance.new("ImageLabel", MainFrame)
BgImage.Size = UDim2.new(1,0,1,0)
BgImage.BackgroundTransparency = 1
BgImage.Image = "rbxassetid://101138166721164"
BgImage.ImageTransparency = 0.6
BgImage.ScaleType = Enum.ScaleType.Slice

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = Color3.fromRGB(255,255,255)
MainStroke.Thickness = 2
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0,6)

-- Kéo thả MainFrame
do
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
end

-- Kéo thả ToggleBtn
do
    local dragging, dragInput, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        ToggleBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    ToggleBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = ToggleBtn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    ToggleBtn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then update(input) end
    end)
end

-- TextLabels
local function CreateText(text, yPos)
    local lbl = Instance.new("TextLabel", MainFrame)
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0,25,0,yPos)
    lbl.Size = UDim2.new(1,-50,0,30)
    lbl.Font = Enum.Font.RobotoMono
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(255,255,255)
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
    btn.BackgroundColor3 = Color3.fromRGB(255,255,255)
    btn.BackgroundTransparency = 0.9
    btn.Position = UDim2.new(xPos,0,0.83,0)
    btn.Size = UDim2.new(0.4,0,0,40)
    btn.Font = Enum.Font.RobotoMono
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.TextSize = 16
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Color3.fromRGB(255,255,255)
    stroke.Thickness = 1.5
    return btn
end

local SkipBtn = CreateBtn("SKIP PLAYER", 0.07)
local HopBtn = CreateBtn("HOP SERVER", 0.53)

-- M1 luôn bật, không có nút toggle nữa
local m1Enabled = true

-- Sự kiện nút Hop
local autoHopActive = false
HopBtn.MouseButton1Click:Connect(function()
    if autoHopActive then
        autoHopActive = false
        HopBtn.Text = "HOP SERVER"
        getgenv().hopserver = false
    else
        autoHopActive = true
        HopBtn.Text = "STOP HOP"
        getgenv().hopserver = true
        task.spawn(function()
            while autoHopActive do
                if getgenv().HopServer then
                    pcall(getgenv().HopServer)
                end
                task.wait(5) -- hop mỗi 5s nếu vẫn active
            end
        end)
    end
end)

-- Nút Skip
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

-- Update UI
local uiStartTime = os.time()
local initialBounty = nil
task.spawn(function()
    task.wait(3)
    pcall(function()
        if player and player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Bounty/Honor") then
            initialBounty = player.leaderstats["Bounty/Honor"].Value
        end
    end)
    ExecLbl.Text = "Executor: " .. ((identifyexecutor and identifyexecutor()) or "Unknown")
end)

RunService.RenderStepped:Connect(function()
    pcall(function()
        if player and player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Bounty/Honor") and initialBounty then
            local earned = player.leaderstats["Bounty/Honor"].Value - initialBounty
            BountyLbl.Text = "Bounty Earn: " .. tostring(earned)
        end
        local diff = os.time() - uiStartTime
        TimeLbl.Text = string.format("Time Player: %02d:%02d:%02d", math.floor(diff/3600), math.floor((diff%3600)/60), diff%60)
        local targ = getgenv().targ
        if targ and targ.Character and getRoot(targ.Character) then
            TargetLbl.Text = "Target: " .. targ.Name
            local myRoot = getRoot(player.Character)
            if myRoot then
                local dist = (myRoot.Position - getRoot(targ.Character).Position).Magnitude
                DistLbl.Text = "Distance: " .. math.floor(dist) .. " m"
                DistLbl.TextColor3 = dist < 50 and Color3.fromRGB(255,50,50) or Color3.fromRGB(255,255,255)
            end
        else
            TargetLbl.Text = "Target: Searching..."
            DistLbl.Text = "Distance: 0 m"
            DistLbl.TextColor3 = Color3.fromRGB(255,255,255)
        end
    end)
end)

-- =============================================
-- CHECK FRUIT KHI JOIN TEAM (Hải tặc / Hải quân)
-- =============================================
local function checkFruitOnTeam()
    task.spawn(function()
        task.wait(2) -- đợi data load
        local char = player.Character
        if not char then return end

        -- Lấy fruit từ Data hoặc từ tool đang cầm
        local fruitName = nil

        -- Ưu tiên kiểm tra Data.DevilFruit
        pcall(function()
            if player:FindFirstChild("Data") and player.Data:FindFirstChild("DevilFruit") then
                fruitName = player.Data.DevilFruit.Value
            end
        end)

        -- Nếu không có trong Data thì check tool trong character
        if not fruitName or fruitName == "" then
            for _, tool in pairs(char:GetChildren()) do
                if tool:IsA("Tool") and tool.ToolTip == "Blox Fruit" then
                    fruitName = tool.Name
                    break
                end
            end
        end
        -- Cũng check Backpack
        if not fruitName or fruitName == "" then
            for _, tool in pairs(player.Backpack:GetChildren()) do
                if tool:IsA("Tool") and tool.ToolTip == "Blox Fruit" then
                    fruitName = tool.Name
                    break
                end
            end
        end

        if fruitName and fruitName ~= "" and NO_M1_FRUITS[fruitName] then
            getgenv().fruitBlocked = true
            showM1Notif(fruitName)
            print("⛔ Fruit [" .. fruitName .. "] không hỗ trợ M1 — Auto Bounty dừng lại")
        else
            hideM1Notif()
            print("✅ Fruit hợp lệ — Auto Bounty chạy bình thường" .. (fruitName and (" [" .. fruitName .. "]") or ""))
        end
    end)
end

-- Hook khi team thay đổi
player:GetPropertyChangedSignal("Team"):Connect(function()
    local team = player.Team
    if team then
        local teamName = team.Name
        -- Chỉ kích hoạt khi vào Hải tặc hoặc Hải quân
        if string.find(string.lower(teamName), "pirate") or string.find(string.lower(teamName), "marine")
        or string.find(string.lower(teamName), "hai tac") or string.find(string.lower(teamName), "hai quan")
        or string.find(string.lower(teamName), "hải tặc") or string.find(string.lower(teamName), "hải quân") then
            print("⚓ Vừa join team: " .. teamName .. " — Đang kiểm tra fruit...")
            checkFruitOnTeam()
        end
    end
end)

-- Cũng check ngay khi script load (nếu đã có team rồi)
task.spawn(function()
    task.wait(3)
    checkFruitOnTeam()
end)
if CFG.Another and CFG.Another.FPSBoost then
    pcall(function()
        local terrain = Workspace.Terrain
        terrain.WaterWaveSize = 0
        terrain.WaterWaveSpeed = 0
        terrain.WaterReflectance = 0
        terrain.WaterTransparency = 0
        game.Lighting.GlobalShadows = false
        game.Lighting.FogEnd = 9e9
        game.Lighting.Brightness = 0.8
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level10
    end)
end
RunService:Set3dRenderingEnabled(true)

-- Vô hiệu hóa va chạm
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            if player.Character then
                for _, v in pairs(player.Character:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.CanCollide = false
                    end
                end
            end
        end)
    end
end)

-- =============================================
-- COMBAT FRAMEWORK HACK
-- =============================================
local combatController = nil
pcall(function()
    if player:FindFirstChild("PlayerScripts") then
        local module = require(player.PlayerScripts:FindFirstChild("CombatFramework"))
        if module then
            local upvalues = debug.getupvalues(module)
            combatController = upvalues[2]  -- activeController
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if combatController and typeof(combatController) == "table" and combatController.activeController then
        pcall(function()
            local c = combatController.activeController
            c.hitboxMagnitude = 80
            c.active = false
            c.timeToNextBlock = 0
            c.blocking = false
            c.attacking = false
            if c.humanoid then
                c.humanoid.AutoRotate = true
            end
        end)
    end
end)

-- =============================================
-- HÀM DI CHUYỂN
-- =============================================
local currentTween = nil
function to(Pos)
    pcall(function()
        local char = player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then return end

        -- Tạo LinearVelocity nếu chưa có
        if not hrp:FindFirstChild("Hold") then
            local Hold = Instance.new("LinearVelocity", hrp)
            Hold.Name = "Hold"
            Hold.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            Hold.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
            Hold.VectorVelocity = Vector3.new(0,0,0)
            Hold.RelativeTo = Enum.ActuatorRelativeTo.World
            local att = Instance.new("Attachment", hrp)
            att.Name = "HoldAtt"
            Hold.Attachment0 = att
        end

        if hum.Sit then hum.Sit = false end

        local distance = (Pos.Position - hrp.Position).Magnitude
        if distance <= 250 then
            if currentTween then currentTween:Cancel() end
            hrp.CFrame = Pos
            return
        end

        local speed = distance < 1000 and 340 or 320
        if currentTween then currentTween:Cancel() end
        currentTween = TweenService:Create(hrp, TweenInfo.new(distance / speed, Enum.EasingStyle.Linear), {CFrame = Pos})
        currentTween:Play()
    end)
end

function down(key, duration)
    pcall(function()
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            VirtualInputManager:SendKeyEvent(true, key, false, nil)
            task.wait(duration or 0.1)
            VirtualInputManager:SendKeyEvent(false, key, false, nil)
        end
    end)
end

-- =============================================
-- CHECK SAFE ZONE
-- =============================================
function CheckSafeZone(pos)
    local safeZones = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("SafeZones")
    if safeZones then
        for _, zone in pairs(safeZones:GetChildren()) do
            if zone:IsA("Part") and (zone.Position - pos).Magnitude <= 400 then
                return true
            end
        end
    end
    -- Kiểm tra GUI safe zone (nếu có)
    if player.PlayerGui:FindFirstChild("Main") and player.PlayerGui.Main:FindFirstChild("[OLD]SafeZone") and player.PlayerGui.Main["[OLD]SafeZone"].Visible then
        return true
    end
    return false
end

-- =============================================
-- KIỂM TRA TARGET HỢP LỆ
-- =============================================
local function isValidTarget(v)
    if not v or v == player then return false end
    if not isAlive(v.Character) then return false end
    local vRoot = getRoot(v.Character)
    if not vRoot then return false end

    -- Data & leaderstats
    if not v:FindFirstChild("Data") or not v:FindFirstChild("leaderstats") then return false end
    local bountyStat = v.leaderstats:FindFirstChild("Bounty/Honor")
    if not bountyStat then return false end

    -- Bounty range
    local bounty = bountyStat.Value
    local minB = CFG.Hunt and CFG.Hunt.Min or 0
    local maxB = CFG.Hunt and CFG.Hunt.Max or math.huge
    if bounty < minB or bounty > maxB then return false end

    -- Level check (chỉ filter nếu cả hai đều có level)
    local myLevel = player.Data and player.Data:FindFirstChild("Level") and tonumber(player.Data.Level.Value)
    local targetLevel = v.Data and v.Data:FindFirstChild("Level") and tonumber(v.Data.Level.Value)
    if myLevel and targetLevel and (myLevel - 250) >= targetLevel then return false end

    -- Team check (khác team) — so sánh tên team để tránh nil
    local myTeam = player.Team and player.Team.Name or ""
    local vTeam = v.Team and v.Team.Name or ""
    -- Nếu cùng team thì bỏ qua (nhưng nếu 1 trong 2 chưa có team thì vẫn cho qua)
    if myTeam ~= "" and vTeam ~= "" and myTeam == vTeam then return false end

    -- Skip config
    if CFG.Skip then
        if CFG.Skip.RaceV4 and v.Character:FindFirstChild("RaceTransformed") then return false end
        if CFG["Skip Race V4"] and v.Character:FindFirstChild("RaceTransformed") then return false end
        if CFG.Skip.Fruit and v.Data:FindFirstChild("DevilFruit") then
            local fruit = v.Data.DevilFruit.Value
            if hasValue(CFG.Skip.FruitList or {}, fruit) then return false end
        end
        if CFG.Skip.SafeZone then
            local inSafe = pcall(function() return CheckSafeZone(vRoot.Position) end) or false
            if inSafe then return false end
        end
    end

    -- Blacklist / checked
    if getgenv().dangerBlacklist[v.Name] then
        print("⛔ Skip (dangerBlacklist): " .. v.Name)
        return false
    end
    if hasValue(getgenv().checked, v) then
        print("⛔ Skip (checked): " .. v.Name)
        return false
    end

    -- Quá cao (thoát)
    if vRoot.Position.Y > 12000 then return false end

    return true
end

-- =============================================
-- HÀM TÌM TARGET
-- =============================================
function target()
    pcall(function()
        if not isAlive(player.Character) then return end
        local myRoot = getRoot(player.Character)
        if not myRoot then return end

        local closestDist = math.huge
        local bestTarget = nil
        getgenv().targ = nil

        for _, v in pairs(Players:GetPlayers()) do
            if v ~= player and isValidTarget(v) then
                local vRoot = getRoot(v.Character)
                if vRoot then
                    local dist = (vRoot.Position - myRoot.Position).Magnitude
                    if dist < closestDist and not getgenv().hopserver then
                        closestDist = dist
                        bestTarget = v
                    end
                end
            end
        end

        -- Chat nếu có target
        if bestTarget then
            pcall(function()
                local chatCfg = CFG.Chat
                if not chatCfg then return end
                local enabled = chatCfg.Enabled
                local msgs = chatCfg.Messages
                -- Hỗ trợ cả 2 dạng: array thẳng hoặc {Enabled, Messages}
                if type(chatCfg) == "table" and enabled ~= false and msgs and #msgs > 0 then
                    local chatMsg = msgs[math.random(1, #msgs)]
                    if chatMsg then
                        ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents"):FindFirstChild("SayMessageRequest"):FireServer(chatMsg, "All")
                    end
                elseif type(chatCfg) == "table" and type(chatCfg[1]) == "string" and #chatCfg > 0 then
                    local chatMsg = chatCfg[math.random(1, #chatCfg)]
                    if chatMsg then
                        ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents"):FindFirstChild("SayMessageRequest"):FireServer(chatMsg, "All")
                    end
                end
            end)
        end

        if bestTarget then
            print("🎯 Target found: " .. bestTarget.Name)
            getgenv().targ = bestTarget
        else
            print("❌ No valid target")
            if CFG.Another and CFG.Another.HopAfterAllPlayers then
                -- Kiểm tra còn ai hợp lệ không
                local anyLeft = false
                for _, v in pairs(Players:GetPlayers()) do
                    if v ~= player and v.Character and getRoot(v.Character) then
                        if v:FindFirstChild("Data") and v:FindFirstChild("leaderstats") then
                            local bounty = v.leaderstats["Bounty/Honor"] and v.leaderstats["Bounty/Honor"].Value
                            if bounty and bounty >= (CFG.Hunt and CFG.Hunt.Min or 0) and bounty <= (CFG.Hunt and CFG.Hunt.Max or 1e9) then
                                if player.Data and player.Data.Level then
                                    if (tonumber(player.Data.Level.Value) - 250) < (v.Data.Level and v.Data.Level.Value or 0) then
                                        if not hasValue(getgenv().checked, v) and not getgenv().dangerBlacklist[v.Name] then
                                            anyLeft = true
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if not anyLeft then
                    print("✅ No players left, hopping...")
                    getgenv().checked = {}
                    getgenv().hopserver = true
                end
            else
                -- Reset checked list trước, thử lại 1 lần nữa rồi mới hop
                if #getgenv().checked > 0 then
                    print("🔄 Reset checked list, thử lại...")
                    getgenv().checked = {}
                else
                    getgenv().hopserver = true
                end
            end
        end
    end)
end
getgenv().target = target

-- =============================================
-- SKIP PLAYER
-- =============================================
local skipping = false
function SkipPlayer()
    if skipping then return end
    skipping = true
    local current = getgenv().targ
    if current then
        table.insert(getgenv().checked, current)
        getgenv().killed = current
    end
    getgenv().targ = nil
    print("⏭️ Skipping player")
    target() -- tìm target mới ngay
    task.delay(1, function() skipping = false end)
end
getgenv().SkipPlayer = SkipPlayer

-- =============================================
-- HOP SERVER
-- =============================================
local hopping = false
function HopServer()
    if hopping then return end
    hopping = true
    local currentJobId = game.JobId
    table.insert(getgenv().ServerBlacklist, currentJobId)

    local success, result = pcall(function()
        local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?limit=100", game.PlaceId)
        local data = HttpService:JSONDecode(game:HttpGet(url))
        local selected = nil
        for _, server in ipairs(data.data) do
            if server.playing and server.maxPlayers and server.playing > 5 and server.playing < server.maxPlayers - 2 then
                local jobId = server.id
                local blacklisted = false
                for _, b in ipairs(getgenv().ServerBlacklist) do
                    if b == jobId then blacklisted = true; break end
                end
                if not blacklisted then
                    selected = server
                    break
                end
            end
        end
        if not selected then
            for _, server in ipairs(data.data) do
                if server.playing and server.maxPlayers and server.playing > 10 and server.playing < server.maxPlayers then
                    local jobId = server.id
                    local blacklisted = false
                    for _, b in ipairs(getgenv().ServerBlacklist) do
                        if b == jobId then blacklisted = true; break end
                    end
                    if not blacklisted then
                        selected = server
                        break
                    end
                end
            end
        end
        if not selected and #data.data > 0 then
            for _, server in ipairs(data.data) do
                local jobId = server.id
                local blacklisted = false
                for _, b in ipairs(getgenv().ServerBlacklist) do
                    if b == jobId then blacklisted = true; break end
                end
                if not blacklisted then
                    selected = server
                    break
                end
            end
        end
        if not selected then selected = data.data[1] end
        if selected and selected.id then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, selected.id)
        else
            TeleportService:Teleport(game.PlaceId)
        end
    end)

    if not success then
        TeleportService:Teleport(game.PlaceId)
    end
    hopping = false
end
getgenv().HopServer = HopServer

-- =============================================
-- EQUIP FRUIT
-- =============================================
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            if not player.Character then return end
            local hasFruit = false
            for _, tool in pairs(player.Character:GetChildren()) do
                if tool:IsA("Tool") and tool.ToolTip == "Blox Fruit" then
                    hasFruit = true
                    break
                end
            end
            if not hasFruit then
                local hum = player.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    for _, item in pairs(player.Backpack:GetChildren()) do
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
-- FLY TO TARGET + BÁM SÁT (cải tiến)
-- =============================================
task.spawn(function()
    while task.wait(0) do
        pcall(function()
            if getgenv().hopserver or safehealth or getgenv().fruitBlocked then return end
            local targ = getgenv().targ
            if not targ or not targ.Character then return end
            local targRoot = getRoot(targ.Character)
            if not targRoot then return end
            local myRoot = getRoot(player.Character)
            if not myRoot then return end

            local dist = (targRoot.Position - myRoot.Position).Magnitude

            if dist > 5 then
                -- Tính điểm đứng sát target (offset 4 stud), cùng độ cao với target
                local dir = (targRoot.Position - myRoot.Position).Unit
                local goalPos = targRoot.Position - dir * 4
                goalPos = Vector3.new(goalPos.X, targRoot.Position.Y, goalPos.Z)

                if dist <= 500 then
                    -- Teleport thẳng không tween: bám sát tức thì từng frame
                    myRoot.CFrame = CFrame.new(goalPos, targRoot.Position)
                else
                    -- Xa hơn 500: tween tốc độ cao
                    if currentTween then currentTween:Cancel() end
                    currentTween = TweenService:Create(myRoot,
                        TweenInfo.new(dist / 600, Enum.EasingStyle.Linear),
                        {CFrame = CFrame.new(goalPos, targRoot.Position)}
                    )
                    currentTween:Play()
                end
            else
                -- Đã sát: luôn xoay nhìn thẳng vào target để M1 không trượt
                myRoot.CFrame = CFrame.lookAt(
                    myRoot.Position,
                    Vector3.new(targRoot.Position.X, myRoot.Position.Y, targRoot.Position.Z)
                )
            end
        end)
    end
end)

-- =============================================
-- AURA (Buso + Ken)
-- =============================================
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            if not getgenv().targ or not player.Character then return end
            -- Buso
            if not player.Character:FindFirstChild("HasBuso") then
                ReplicatedStorage.Remotes.CommF_:InvokeServer("Buso")
            end
            -- Ken (Observation)
            if not (player.PlayerGui:FindFirstChild("ScreenGui") and player.PlayerGui.ScreenGui:FindFirstChild("ImageLabel")) then
                VirtualUser:CaptureController()
                VirtualUser:SetKeyDown("0x65") -- E
                VirtualUser:SetKeyUp("0x65")
            end
        end)
    end
end)

-- =============================================
-- PV ENABLE + V3/V4
-- =============================================
task.spawn(function()
    while task.wait(3) do
        pcall(function()
            ReplicatedStorage.Remotes.CommF_:InvokeServer("EnablePvp")
            local targ = getgenv().targ
            if targ and targ.Character and player.Character then
                local myRoot = getRoot(player.Character)
                local targRoot = getRoot(targ.Character)
                if myRoot and targRoot and (targRoot.Position - myRoot.Position).Magnitude < 50 then
                    local transformed = player.Character:FindFirstChild("RaceTransformed")
                    if CFG.Another and CFG.Another.V3 and not transformed then
                        local shouldV3 = true
                        if CFG.Another.CustomHealth then
                            local hum = player.Character:FindFirstChild("Humanoid")
                            if hum and hum.Health <= (CFG.Another.Health or 4700) then
                                shouldV3 = true
                            else
                                shouldV3 = false
                            end
                        end
                        if shouldV3 then down("T", 0.1) end
                    end
                    if CFG.Another and CFG.Another.V4 and not transformed then
                        down("Y", 0.1)
                    end
                end
            end
        end)
    end
end)

-- =============================================
-- REMOTE HOOK (chỉ hook khi có target)
-- =============================================
local oldNamecall
pcall(function()
    local mt = getrawmetatable(game)
    if not mt then return end
    oldNamecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" and getgenv().targ and getgenv().targ.Character and getRoot(getgenv().targ.Character) then
            local args = {...}
            local remoteName = tostring(self)
            local targetPos = getRoot(getgenv().targ.Character).Position
            -- Chỉ hook các remote liên quan đến kỹ năng / vị trí
            if remoteName:find("UpdateMousePos") or remoteName:find("MousePos") or remoteName:find("Click") or
               remoteName:find("Skill") or remoteName:find("Activate") or remoteName:find("Ability") or
               remoteName:find("Z") or remoteName:find("X") or remoteName:find("C") or remoteName:find("V") then
                for i = 1, #args do
                    if type(args[i]) == "Vector3" then
                        args[i] = targetPos
                    elseif type(args[i]) == "CFrame" then
                        args[i] = CFrame.new(targetPos) * (args[i] - args[i].Position)
                    end
                end
                return oldNamecall(self, unpack(args))
            end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end)

-- =============================================
-- M1 AUTO ATTACK (aim cải tiến)
-- =============================================
-- Mở rộng hitbox M1 phía server bằng cách weld fake part vào HRP
local function expandHitbox(size)
    pcall(function()
        local char = player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if hrp:FindFirstChild("_HitboxExpand") then return end
        local fake = Instance.new("Part")
        fake.Name = "_HitboxExpand"
        fake.Size = Vector3.new(size, size, size)
        fake.Transparency = 1
        fake.CanCollide = false
        fake.Anchored = false
        fake.Parent = char
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = hrp
        weld.Part1 = fake
        weld.Parent = fake
        fake.CFrame = hrp.CFrame
    end)
end
expandHitbox(12) -- hitbox M1 rộng 12 stud xung quanh người chơi

task.spawn(function()
    while task.wait(0) do
        pcall(function()
            if not m1Enabled or getgenv().hopserver or safehealth or getgenv().fruitBlocked then return end

            local targ = getgenv().targ
            if not targ or not targ.Character then return end
            local targRoot = getRoot(targ.Character)
            if not targRoot then return end
            local char = player.Character
            if not char then return end
            local myRoot = getRoot(char)
            if not myRoot then return end
            local hum = char:FindFirstChild("Humanoid")
            if not hum or hum.Health <= 0 then return end
            local targHum = targ.Character:FindFirstChild("Humanoid")
            if not targHum or targHum.Health <= 0 then return end

            local dist = (targRoot.Position - myRoot.Position).Magnitude

            -- Aim: xoay chính xác về phía target (cùng độ cao)
            local aimTarget = Vector3.new(targRoot.Position.X, myRoot.Position.Y, targRoot.Position.Z)
            myRoot.CFrame = CFrame.lookAt(myRoot.Position, aimTarget)

            -- Chỉ M1 khi đã đủ gần
            if dist <= 12 then
                if FastAttack then
                    FastAttack:M1()
                else
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                    task.wait(0.04)
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                end
            end
        end)
    end
end)

-- =============================================
-- VÒNG LẶP CHÍNH
-- =============================================
local safehealth = false
task.spawn(function()
    while task.wait(0.1) do
        -- Dừng hoàn toàn nếu fruit không hỗ trợ
        if getgenv().fruitBlocked then
            -- Giữ targ = nil để không làm gì
            getgenv().targ = nil
        elseif safehealth then
            -- đang hồi máu, không làm gì
        else
            pcall(function()
                if not getgenv().targ or not getgenv().targ.Character then
                    target()
                end
                if not getgenv().targ and not getgenv().hopserver then
                    getgenv().hopserver = true
                end
            end)
            pcall(function()
                local targ = getgenv().targ
                if targ and targ.Character and player.Character then
                    local myRoot = getRoot(player.Character)
                    local targRoot = getRoot(targ.Character)
                    if myRoot and targRoot and (targRoot.Position - myRoot.Position).Magnitude < 40 then
                        -- Safe zone check
                        local inSafe = pcall(function() return CheckSafeZone(targRoot.Position) end) or false
                        if inSafe or (targ.Character.Humanoid and targ.Character.Humanoid.Sit) then
                            SkipPlayer()
                            return
                        end
                        -- Thông báo skip
                        for _, v in pairs(player.PlayerGui.Notifications:GetChildren()) do
                            if v:IsA("TextLabel") then
                                local text = string.lower(v.Text)
                                for _, kw in pairs({
                                    "player died recently", "you can't attack them yet", "cannot attack",
                                    "nguoi choi vua tu tran", "người chơi vừa tử trận",
                                    "died recently", "can't attack them", "cannot attack this player", "skill locked"
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
                end
            end)
        end
    end
end)

-- =============================================
-- SAFE HEALTH
-- =============================================
local function getHealthPct()
    local hum = player.Character and player.Character:FindFirstChild("Humanoid")
    if not hum or hum.MaxHealth <= 0 then return 1 end
    return hum.Health / hum.MaxHealth
end

local function getSafeHealthThreshold()
    local safeVal = CFG.SafeHealth and CFG.SafeHealth.Health or 0.3
    if safeVal <= 1 then return safeVal else return safeVal / 100 end -- nếu nhập số >1 thì coi như %
end

task.spawn(function()
    while task.wait(0.1) do
        local low = false
        pcall(function()
            low = getHealthPct() <= getSafeHealthThreshold()
        end)
        if low then
            safehealth = true
            checkDangerAndBlacklist()
            pcall(function()
                if player.Character and getRoot(player.Character) then
                    local hrp = getRoot(player.Character)
                    hrp.CFrame = hrp.CFrame * CFrame.new(0, math.random(8000,15000), 0)
                end
            end)
            repeat
                task.wait(0.5)
            until (pcall(function() return getHealthPct() > getSafeHealthThreshold() end) or not player.Character)
            safehealth = false
            print("💚 SafeHealth: Đã hồi máu")
        end
    end
end)

-- =============================================
-- WEBHOOK
-- =============================================
local function sendRequest(url, data)
    if not url or url == "" then return end
    local json = HttpService:JSONEncode(data)
    local success = pcall(function()
        if syn and syn.request then
            syn.request({Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=json})
        elseif request then
            request({Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=json})
        else
            warn("Executor không hỗ trợ request")
        end
    end)
    return success
end

function sendKillWebhook(targetName, bountyEarned, currentBounty)
    if not CFG.Webhook or not CFG.Webhook.Enable or CFG.Webhook.Url == "" then return end
    local url = CFG.Webhook.Url
    local function formatBounty(b)
        if b >= 1e6 then return string.format("%.1fM", b/1e6)
        elseif b >= 1e3 then return string.format("%.1fK", b/1e3)
        else return tostring(b) end
    end
    local data = {
        embeds = {{
            title = "BOUNTY HUNTER NOTIFICATION",
            description = "Kill Player",
            color = 0x67eb34,
            fields = {
                {name="Target", value="```"..targetName.."```", inline=true},
                {name="Bounty Earned", value="```"..formatBounty(bountyEarned).."```", inline=true},
                {name="Current Bounty", value="```"..formatBounty(currentBounty).."```", inline=true},
                {name="👤 Hunter", value="```"..player.Name.."```", inline=true},
                {name="Level", value="```"..tostring(player.Data and player.Data.Level and player.Data.Level.Value or "?").."```", inline=true},
                {name="Time", value="```"..os.date("%H:%M:%S %d/%m/%Y").."```", inline=true}
            },
            footer = {text="By Lo Hub Emorima"},
            thumbnail = {url="https://www.roblox.com/headshot-thumbnail/image?userId="..player.UserId.."&width=420&height=420&format=png"}
        }}
    }
    sendRequest(url, data)
    print("✅ Sent kill webhook for "..targetName)
end

local lastBounty = 0
task.spawn(function()
    task.wait(3)
    pcall(function()
        if player and player:FindFirstChild("leaderstats") then
            lastBounty = player.leaderstats["Bounty/Honor"] and player.leaderstats["Bounty/Honor"].Value or 0
        end
    end)
end)

local lastKilled = nil
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local targ = getgenv().targ
            if targ and targ.Character then
                local hum = targ.Character:FindFirstChild("Humanoid")
                if hum and hum.Health <= 0 and lastKilled ~= targ.Name then
                    task.wait(2)
                    local current = player.leaderstats and player.leaderstats["Bounty/Honor"] and player.leaderstats["Bounty/Honor"].Value or 0
                    local earned = current - lastBounty
                    if earned < 0 then earned = 0 end
                    sendKillWebhook(targ.Name, earned, current)
                    lastKilled = targ.Name
                    lastBounty = current
                    task.wait(3)
                    SkipPlayer()
                end
            end
        end)
    end
end)

-- Startup webhook
task.wait(8)
pcall(function()
    if CFG.Webhook and CFG.Webhook.Enable and CFG.Webhook.Url ~= "" then
        local current = player.leaderstats and player.leaderstats["Bounty/Honor"] and player.leaderstats["Bounty/Honor"].Value or 0
        local data = {
            embeds = {{
                title = "notify",
                description = "Bounty Ez",
                color = 16753920,
                fields = {
                    {name="User Name", value="```"..player.Name.."```", inline=true},
                    {name="Level", value="```"..tostring(player.Data and player.Data.Level and player.Data.Level.Value or "?").."```", inline=true},
                    {name="Current Bounty", value="```"..tostring(current).."```", inline=true},
                    {name="Check Team", value="```"..(CFG.Team or "Unknown").."```", inline=true}
                },
                footer = {text="Auto Bounty By Lo Hub "..os.date("%H:%M %d/%m/%Y")}
            }}
        }
        sendRequest(CFG.Webhook.Url, data)
        print("✅ Sent startup webhook")
    end
end)

-- Auto skip qua thông báo (bổ sung)
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            if not getgenv().targ then return end
            for _, v in pairs(player.PlayerGui.Notifications:GetChildren()) do
                if v:IsA("TextLabel") then
                    local text = string.lower(v.Text)
                    for _, kw in ipairs({
                        "nguoi choi vua tu tran", "người chơi vừa tử trận",
                        "player died recently", "you can't attack them yet",
                        "died recently", "can't attack them", "cannot attack this player",
                        "cannot attack", "unable to attack"
                    }) do
                        if string.find(text, kw) then
                            print("🔄 Auto-skip: " .. kw)
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

-- Xử lý lỗi prompt (an toàn)
pcall(function()
    CoreGui.RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
        if not getgenv().hopserver and child.Name == 'ErrorPrompt' and child:FindFirstChild('MessageArea') and child.MessageArea:FindFirstChild("ErrorFrame") then
            TeleportService:Teleport(game.PlaceId)
        end
    end)
end)

print("✅ Script đã được tối ưu và sẵn sàng chạy!")
