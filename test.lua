local CFG = getgenv().Setting    
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CommF_Remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
CommF_Remote:InvokeServer("SetTeam", CFG["Team"])

local LocalPlayer = game:GetService("Players").LocalPlayer
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local player = game.Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")
local character = player.Character or player.CharacterAdded:Wait()
loadstring(game:HttpGet("https://pastefy.app/0vZrrYO0/raw"))()
repeat task.wait() until game.Players.LocalPlayer.PlayerGui:FindFirstChild("Main")
getgenv().weapon = nil
getgenv().targ = nil 
getgenv().lasttarrget = nil
getgenv().checked = {}
getgenv().pl = game.Players:GetPlayers()
getgenv().killed = nil

-- FIX #4: Khai báo biến global đúng chỗ
local tween = nil
local stopbypass = false

-- =============================================
-- FIX HOP: Tự động bấm OK khi Roblox hiện popup xác nhận teleport
-- Xử lý cả TeleportGui lẫn PromptOverlay
-- =============================================
spawn(function()
    -- Tự động confirm popup teleport của Roblox (nút "Teleport" / "OK" / "Yes")
    local function autoConfirmTeleport(gui)
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

    -- Theo dõi CoreGui → RobloxPromptGui (popup hệ thống)
    local promptGui = game:GetService("CoreGui"):WaitForChild("RobloxPromptGui", 10)
    if promptGui then
        local overlay = promptGui:FindFirstChild("promptOverlay")
        if overlay then
            overlay.ChildAdded:Connect(function(child)
                task.wait(0.1)
                autoConfirmTeleport(overlay)
            end)
            -- Xử lý nếu đã có sẵn child
            for _, child in pairs(overlay:GetChildren()) do
                autoConfirmTeleport(overlay)
            end
        end
    end

    -- Theo dõi toàn bộ CoreGui phòng trường hợp gui khác
    game:GetService("CoreGui").ChildAdded:Connect(function(child)
        task.wait(0.2)
        autoConfirmTeleport(child)
    end)

    -- Theo dõi PlayerGui (một số executor inject popup vào đây)
    game.Players.LocalPlayer.PlayerGui.ChildAdded:Connect(function(child)
        task.wait(0.2)
        autoConfirmTeleport(child)
    end)

    -- Loop quét liên tục mỗi 0.5s phòng popup load chậm
    while task.wait(0.5) do
        pcall(function()
            local cg = game:GetService("CoreGui")
            autoConfirmTeleport(cg)
        end)
        pcall(function()
            local pg = game.Players.LocalPlayer.PlayerGui
            autoConfirmTeleport(pg)
        end)
    end
end)

-- =============================================
-- TÍNH NĂNG: Danger Blacklist
-- =============================================
getgenv().dangerCount = {}
getgenv().dangerBlacklist = {}
local lastMyHealth = nil
local dangerCooldown = {}

local function checkDangerAndBlacklist()
    local cfg = getgenv().Setting.Another.DangerBlacklist
    if not cfg or not cfg.Enable then return end
    if not getgenv().targ then return end
    local myHum = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("Humanoid")
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
            print("⚠️ [DangerBlacklist] Bị " .. targName .. " đánh nguy hiểm lần " .. getgenv().dangerCount[targName] .. "/" .. cfg.MaxAttempts)
            if getgenv().dangerCount[targName] >= cfg.MaxAttempts then
                getgenv().dangerBlacklist[targName] = true
                print("🚫 [DangerBlacklist] Blacklist: " .. targName .. " - bỏ qua vĩnh viễn trong session này!")
                if getgenv().SkipPlayer then getgenv().SkipPlayer() end
            end
        end
    else
        dangerCooldown[targName] = nil
    end
end

-- =============================================
-- GUI
-- =============================================
local MainGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local UICorner = Instance.new("UICorner")
local Background = Instance.new("ImageLabel")
local UICorner_Background = Instance.new("UICorner")
local Character = Instance.new("ImageLabel")
local UICorner_Character = Instance.new("UICorner")
local TextLabel = Instance.new("TextLabel")
local CharacterIcon = Instance.new("ImageLabel")
local UICorner_Icon = Instance.new("UICorner")
local BountyEarned = Instance.new("TextLabel")
local TotalBountyEarned = Instance.new("TextLabel")
local CilentTimeElapsed = Instance.new("TextLabel")
local AccoutTimeElapsed = Instance.new("TextLabel")
local SkipImg = Instance.new("ImageLabel")
local UICorner_Skip = Instance.new("UICorner")
local SkipButton = Instance.new("TextButton")
local CrentBounty = Instance.new("TextLabel")
local ServerImg = Instance.new("ImageLabel")
local UICorner_Server = Instance.new("UICorner")
local ServerButton = Instance.new("TextButton")
local ToggleButton = Instance.new("ImageButton")
local UICorner_Toggle = Instance.new("UICorner")
MainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
MainGui.Name = "MainGui"
MainGui.Parent = game:GetService("CoreGui")
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
MainFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.Size = UDim2.new(0, 380, 0, 180)
MainFrame.Name = "MainFrame"
MainFrame.Parent = MainGui
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame
Background.Image = "rbxassetid://128136450619493"
Background.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
Background.BackgroundTransparency = 1
Background.BorderColor3 = Color3.fromRGB(0, 0, 0)
Background.BorderSizePixel = 0
Background.Size = UDim2.new(0, 674, 0, 346)
Background.Name = "Background"
Background.Parent = MainFrame
UICorner_Background.CornerRadius = UDim.new(0, 12)
UICorner_Background.Parent = Background
Character.Image = "rbxassetid://95939250980299"
Character.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Character.BackgroundTransparency = 1
Character.BorderColor3 = Color3.fromRGB(0, 0, 0)
Character.BorderSizePixel = 0
Character.Position = UDim2.new(0.55, 0, -0.05, 0)
Character.Size = UDim2.new(0, 160, 0, 180)
Character.Name = "Character"
Character.Parent = MainFrame
UICorner_Character.CornerRadius = UDim.new(0, 8)
UICorner_Character.Parent = Character
TextLabel.Font = Enum.Font.GothamBold
TextLabel.Text = "lo hub"
TextLabel.TextColor3 = Color3.fromRGB(125, 194, 14)
TextLabel.TextSize = 14
TextLabel.TextTransparency = 0
TextLabel.TextXAlignment = Enum.TextXAlignment.Left
TextLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
TextLabel.BackgroundTransparency = 1
TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
TextLabel.BorderSizePixel = 0
TextLabel.Position = UDim2.new(0, 40, 0, 8)
TextLabel.Size = UDim2.new(0, 200, 0, 20)
TextLabel.Parent = MainFrame
CharacterIcon.Image = "rbxassetid://128160729162320"
CharacterIcon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CharacterIcon.BackgroundTransparency = 1
CharacterIcon.BorderColor3 = Color3.fromRGB(0, 0, 0)
CharacterIcon.BorderSizePixel = 0
CharacterIcon.Position = UDim2.new(0, 10, 0, 8)
CharacterIcon.Size = UDim2.new(0, 25, 0, 25)
CharacterIcon.Name = "CharacterIcon"
CharacterIcon.Parent = MainFrame
UICorner_Icon.CornerRadius = UDim.new(0, 6)
UICorner_Icon.Parent = CharacterIcon
CrentBounty.Font = Enum.Font.Gotham
CrentBounty.Text = "Current Bounty:"
CrentBounty.TextColor3 = Color3.fromRGB(255, 255, 255)
CrentBounty.TextSize = 12
CrentBounty.TextTransparency = 0
CrentBounty.TextXAlignment = Enum.TextXAlignment.Left
CrentBounty.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CrentBounty.BackgroundTransparency = 1
CrentBounty.BorderColor3 = Color3.fromRGB(0, 0, 0)
CrentBounty.BorderSizePixel = 0
CrentBounty.Position = UDim2.new(0, 12, 0, 40)
CrentBounty.Size = UDim2.new(0, 180, 0, 16)
CrentBounty.Name = "CrentBounty"
CrentBounty.Parent = MainFrame
BountyEarned.Font = Enum.Font.Gotham
BountyEarned.Text = "Bounty Earned: 0$ "
BountyEarned.TextColor3 = Color3.fromRGB(255, 255, 255)
BountyEarned.TextSize = 12
BountyEarned.TextTransparency = 0
BountyEarned.TextXAlignment = Enum.TextXAlignment.Left
BountyEarned.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
BountyEarned.BackgroundTransparency = 1
BountyEarned.BorderColor3 = Color3.fromRGB(0, 0, 0)
BountyEarned.BorderSizePixel = 0
BountyEarned.Position = UDim2.new(0, 12, 0, 60)
BountyEarned.Size = UDim2.new(0, 180, 0, 16)
BountyEarned.Name = "BountyEarned"
BountyEarned.Parent = MainFrame
TotalBountyEarned.Font = Enum.Font.Gotham
TotalBountyEarned.Text = "Total Bounty Earned: 0$"
TotalBountyEarned.TextColor3 = Color3.fromRGB(255, 255, 255)
TotalBountyEarned.TextSize = 12
TotalBountyEarned.TextTransparency = 0
TotalBountyEarned.TextXAlignment = Enum.TextXAlignment.Left
TotalBountyEarned.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TotalBountyEarned.BackgroundTransparency = 1
TotalBountyEarned.BorderColor3 = Color3.fromRGB(0, 0, 0)
TotalBountyEarned.BorderSizePixel = 0
TotalBountyEarned.Position = UDim2.new(0, 12, 0, 80)
TotalBountyEarned.Size = UDim2.new(0, 180, 0, 16)
TotalBountyEarned.Name = "TotalBountyEarned"
TotalBountyEarned.Parent = MainFrame
CilentTimeElapsed.Font = Enum.Font.Gotham
CilentTimeElapsed.Text = "Client Time Elapsed: 0h:0m:00s"
CilentTimeElapsed.TextColor3 = Color3.fromRGB(255, 255, 255)
CilentTimeElapsed.TextSize = 12
CilentTimeElapsed.TextTransparency = 0
CilentTimeElapsed.TextXAlignment = Enum.TextXAlignment.Left
CilentTimeElapsed.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CilentTimeElapsed.BackgroundTransparency = 1
CilentTimeElapsed.BorderColor3 = Color3.fromRGB(0, 0, 0)
CilentTimeElapsed.BorderSizePixel = 0
CilentTimeElapsed.Position = UDim2.new(0, 12, 0, 100)
CilentTimeElapsed.Size = UDim2.new(0, 180, 0, 16)
CilentTimeElapsed.Name = "CilentTimeElapsed"
CilentTimeElapsed.Parent = MainFrame
AccoutTimeElapsed.Font = Enum.Font.Gotham
AccoutTimeElapsed.Text = "Acount Time Elapsed: 0h:0m:00s"
AccoutTimeElapsed.TextColor3 = Color3.fromRGB(255, 255, 255)
AccoutTimeElapsed.TextSize = 12
AccoutTimeElapsed.TextTransparency = 0
AccoutTimeElapsed.TextXAlignment = Enum.TextXAlignment.Left
AccoutTimeElapsed.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
AccoutTimeElapsed.BackgroundTransparency = 1
AccoutTimeElapsed.BorderColor3 = Color3.fromRGB(0, 0, 0)
AccoutTimeElapsed.BorderSizePixel = 0
AccoutTimeElapsed.Position = UDim2.new(0, 12, 0, 120)
AccoutTimeElapsed.Size = UDim2.new(0, 180, 0, 16)
AccoutTimeElapsed.Name = "AccoutTimeElapsed"
AccoutTimeElapsed.Parent = MainFrame
SkipImg.Image = "rbxassetid://92006056658480"
SkipImg.AnchorPoint = Vector2.new(0, 1)
SkipImg.BackgroundColor3 = Color3.fromRGB(50, 100, 150)
SkipImg.BackgroundTransparency = 0
SkipImg.BorderColor3 = Color3.fromRGB(0, 0, 0)
SkipImg.BorderSizePixel = 0
SkipImg.Position = UDim2.new(0, 12, 1, -8)
SkipImg.Size = UDim2.new(0, 80, 0, 25)
SkipImg.Name = "SkipImg"
SkipImg.Parent = MainFrame
UICorner_Skip.CornerRadius = UDim.new(0, 8)
UICorner_Skip.Parent = SkipImg
SkipButton.Font = Enum.Font.GothamBold
SkipButton.Text = "Next Player"
SkipButton.TextColor3 = Color3.fromRGB(170, 230, 73)
SkipButton.TextSize = 12
SkipButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
SkipButton.BackgroundTransparency = 1
SkipButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
SkipButton.BorderSizePixel = 0
SkipButton.Size = UDim2.new(1, 0, 1, 0)
SkipButton.Name = "SkipButton"
SkipButton.Parent = SkipImg
ServerImg.Image = "rbxassetid://71768682149411"
ServerImg.AnchorPoint = Vector2.new(0, 1)
ServerImg.BackgroundColor3 = Color3.fromRGB(150, 100, 50)
ServerImg.BackgroundTransparency = 0
ServerImg.BorderColor3 = Color3.fromRGB(0, 0, 0)
ServerImg.BorderSizePixel = 0
ServerImg.Position = UDim2.new(0, 99, 1, -8)
ServerImg.Size = UDim2.new(0, 80, 0, 25)
ServerImg.Name = "ServerImg"
ServerImg.Parent = MainFrame
UICorner_Server.CornerRadius = UDim.new(0, 8)
UICorner_Server.Parent = ServerImg
ServerButton.Font = Enum.Font.GothamBold
ServerButton.Text = "Hop Server"
ServerButton.TextColor3 = Color3.fromRGB(170, 230, 73)
ServerButton.TextSize = 12
ServerButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ServerButton.BackgroundTransparency = 1
ServerButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
ServerButton.BorderSizePixel = 0
ServerButton.Size = UDim2.new(1, 0, 1, 0)
ServerButton.Name = "ServerButton"
ServerButton.Parent = ServerImg
ToggleButton.Parent = MainGui
ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
ToggleButton.BorderSizePixel = 0
ToggleButton.Position = UDim2.new(0.120833337 - 0.10, 0, 0.0952890813 + 0.01, 0)
ToggleButton.Size = UDim2.new(0, 25, 0, 25)
ToggleButton.Draggable = true
ToggleButton.Image = "rbxassetid://100666805146072"
UICorner_Toggle.CornerRadius = UDim.new(1, 0)
UICorner_Toggle.Parent = ToggleButton

local UIVisible = true
ToggleButton.MouseButton1Click:Connect(function()
    UIVisible = not UIVisible
    MainFrame.Visible = UIVisible    
end)

local UserInputService = game:GetService("UserInputService")
local dragging
local dragInput
local dragStart
local startPos
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
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

local toggleDragging = false
local toggleDragInput
local toggleDragStart
local toggleStartPos
local function updateToggle(input)
    local delta = input.Position - toggleDragStart
    ToggleButton.Position = UDim2.new(toggleStartPos.X.Scale, toggleStartPos.X.Offset + delta.X, toggleStartPos.Y.Scale, toggleStartPos.Y.Offset + delta.Y)
end
ToggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        toggleDragging = true
        toggleDragStart = input.Position
        toggleStartPos = ToggleButton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                toggleDragging = false
            end
        end)
    end
end)
ToggleButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        toggleDragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == toggleDragInput and toggleDragging then
        updateToggle(input)
    end
end)

ServerButton.MouseButton1Click:Connect(function()
    print("Hop Server button clicked!")
    getgenv().hopserver = true
    getgenv().autoHopLoop = true
    spawn(function()
        while getgenv().autoHopLoop do
            if getgenv().HopServer then
                pcall(function() getgenv().HopServer() end)
            end
            task.wait(3)
        end
    end)
end)

SkipButton.MouseButton1Click:Connect(function()
    print("Next Player button clicked!")
    if getgenv().SkipPlayer then
        getgenv().SkipPlayer()
    end
end)

local startTime = os.time()
local accountStartTime = os.time()
local totalBountyEarned = 0
local sessionBountyEarned = 0
local function updateUI()
    local currentTime = os.time()
    local clientElapsed = currentTime - startTime
    local accountElapsed = currentTime - accountStartTime
    local function formatTime(seconds)
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        local secs = seconds % 60
        return string.format("%dh:%dm:%02ds", hours, minutes, secs)
    end   
    local p = game.Players.LocalPlayer
    if p and p:FindFirstChild("leaderstats") then
        local bounty = p.leaderstats["Bounty/Honor"] and p.leaderstats["Bounty/Honor"].Value or 0
        CrentBounty.Text = "Current Bounty: " .. tostring(bounty)
    end    
    CilentTimeElapsed.Text = "Client Time Elapsed: " .. formatTime(clientElapsed)
    AccoutTimeElapsed.Text = "Account Time Elapsed: " .. formatTime(accountElapsed)    
    BountyEarned.Text = "Bounty Earned: " .. tostring(sessionBountyEarned) .. "$"
    TotalBountyEarned.Text = "Total Bounty Earned: " .. tostring(totalBountyEarned) .. "$"
end

local lastBounty = 0
spawn(function()
    while task.wait(1) do
        local p = game.Players.LocalPlayer
        if p and p:FindFirstChild("leaderstats") then
            local currentBounty = p.leaderstats["Bounty/Honor"] and p.leaderstats["Bounty/Honor"].Value or 0
            if currentBounty > lastBounty and lastBounty > 0 then
                local bountyIncrease = currentBounty - lastBounty
                sessionBountyEarned = sessionBountyEarned + bountyIncrease
                totalBountyEarned = totalBountyEarned + bountyIncrease
            end
            lastBounty = currentBounty
        end
        updateUI()
    end
end)
spawn(function()
    task.wait(3)
    local p = game.Players.LocalPlayer
    if p and p:FindFirstChild("leaderstats") then
        lastBounty = p.leaderstats["Bounty/Honor"] and p.leaderstats["Bounty/Honor"].Value or 0
    end
end)

-- =============================================
-- WORLD / ISLAND SETUP
-- =============================================
local placeId = game.PlaceId
local worldMap = {[2753915549]="World1",[85211729168715]="World1",[4442272183]="World2",[79091703265657]="World2",[7449423635]="World3",[100117331123089]="World3"}
local World1, World2, World3 = false, false, false
if worldMap[placeId] then
    local world = worldMap[placeId]
    if world == "World1" then World1 = true
    elseif world == "World2" then World2 = true
    elseif world == "World3" then World3 = true end
else
    game.Players.LocalPlayer:Kick("❌ Not Support Game ❌")
end

local distbyp, island
if World3 then 
    distbyp = 5000
    island = {
        ["Port Town"] = CFrame.new(-290.7376708984375, 6.729952812194824, 5343.5537109375),
        ["Hydra Island"] = CFrame.new(5749.7861328125 + 50, 611.9736938476562, -276.2497863769531),
        ["Mansion"] = CFrame.new(-12471.169921875 + 50, 374.94024658203, -7551.677734375),
        ["Castle On The Sea"] = CFrame.new(-5085.23681640625 + 50, 316.5072021484375, -3156.202880859375),
        ["Haunted Island"] = CFrame.new(-9547.5703125, 141.0137481689453, 5535.16162109375),
        ["Great Tree"] = CFrame.new(2681.2736816406, 1682.8092041016, -7190.9853515625),
        ["Candy Island"] = CFrame.new(-1106.076416015625, 13.016114234924316, -14231.9990234375),
        ["Cake Island"] = CFrame.new(-1903.6856689453125, 36.70722579956055, -11857.265625),
        ["Loaf Island"] = CFrame.new(-889.8325805664062, 64.72842407226562, -10895.8876953125),
        ["Peanut Island"] = CFrame.new(-1943.59716796875, 37.012996673583984, -10288.01171875),
        ["Cocoa Island"] = CFrame.new(147.35205078125, 23.642955780029297, -12030.5498046875),
        ["Tiki Outpost"] = CFrame.new(-16234,9,416)
    } 
elseif World2 then 
    distbyp = 3500
    island = { 
        a = CFrame.new(753.14288330078, 408.23559570313, -5274.6147460938),
        b = CFrame.new(-5622.033203125, 492.19604492188, -781.78552246094),
        c = CFrame.new(-11.311455726624, 29.276733398438, 2771.5224609375),
        d = CFrame.new(-2448.5300292969, 73.016105651855, -3210.6306152344),
        e = CFrame.new(-380.47927856445, 77.220390319824, 255.82550048828), 
        f = CFrame.new(-3032.7641601563, 317.89672851563, -10075.373046875),
        g = CFrame.new(6148.4116210938, 294.38687133789, -6741.1166992188),
        h = CFrame.new(923.40197753906, 125.05712890625, 32885.875),
        i = CFrame.new(-6127.654296875, 15.951762199402, -5040.2861328125),
    }
elseif World1 then 
    distbyp = 1500
    island = { 
        a = CFrame.new(979.79895019531, 16.516613006592, 1429.0466308594), 
        b = CFrame.new(-2566.4296875, 6.8556680679321, 2045.2561035156), 
        c = CFrame.new(944.15789794922, 20.919729232788, 4373.3002929688), 
        d = CFrame.new(-1181.3093261719, 4.7514905929565, 3803.5456542969), 
        e = CFrame.new(-1612.7957763672, 36.852081298828, 149.12843322754), 
        f = CFrame.new(-690.33081054688, 15.09425163269, 1582.2380371094),
        g = CFrame.new(-4607.82275, 872.54248, -1667.55688), 
        h = CFrame.new(-7952.31006, 5545.52832, -320.704956),
        i = CFrame.new(-4914.8212890625, 50.963626861572, 4281.0278320313),
        j = CFrame.new(-1427.6203613281, 7.2881078720093, -2792.7722167969),
        k = CFrame.new(1347.8067626953, 104.66806030273, -1319.7370605469),
        l = CFrame.new(5127.1284179688, 59.501365661621, 4105.4458007813),
        m = CFrame.new(61163.8515625, 11.6796875, 1819.7841796875),
        n = CFrame.new(-5247.7163085938, 12.883934020996, 8504.96875),
        o = CFrame.new(4875.330078125, 5.6519818305969, 734.85021972656),
        p = CFrame.new(-4813.0249, 903.708557, -1912.69055),
        q = CFrame.new(-4970.21875, 717.707275, -2622.35449),
    } 
end

local p2 = game.Players
local lp = p2.LocalPlayer
local rs = game:GetService("RunService")
local hb = rs.Heartbeat
local rends = rs.RenderStepped

function bypass(Pos)   
    if not lp.Character:FindFirstChild("Head") or not lp.Character:FindFirstChild("HumanoidRootPart") or not lp.Character:FindFirstChild("Humanoid") then
        return
    end    
    local dist = math.huge
    local is = nil
    for i, v in pairs(island) do
        if (Pos.Position-v.Position).magnitude < dist then
            is = v 
            dist = (Pos.Position-v.Position).magnitude 
        end
    end 
    if is == nil then return end    
    if lp:DistanceFromCharacter(Pos.Position) > distbyp then 
        if (lp.Character.Head.Position-Pos.Position).magnitude > (is.Position-Pos.Position).magnitude then
            if tween then
                pcall(function() tween:Destroy() end)
            end            
            if (is.X == 61163.8515625 and is.Y == 11.6796875 and is.Z == 1819.7841796875) or 
               is == CFrame.new(-12471.169921875 + 50, 374.94024658203, -7551.677734375) or 
               is == CFrame.new(-5085.23681640625 + 50, 316.5072021484375, -3156.202880859375) or 
               is == CFrame.new(5749.7861328125 + 50, 611.9736938476562, -276.2497863769531) then                
                if tween then
                   pcall(function() tween:Cancel() end)
                end                
                repeat task.wait()
                    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                        lp.Character.HumanoidRootPart.CFrame = is  
                    else
                        break
                    end
                until lp.Character and lp.Character.PrimaryPart and lp.Character.PrimaryPart.CFrame == is
                task.wait(0.1)
                game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("SetSpawnPoint")
            else
                if not stopbypass then
                    if tween then
                       pcall(function() tween:Cancel() end)
                    end                 
                    repeat task.wait()
                        if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                            lp.Character.HumanoidRootPart.CFrame = is  
                        else
                            break
                        end
                    until lp.Character and lp.Character.PrimaryPart and lp.Character.PrimaryPart.CFrame == is
                    pcall(function()
                        game:GetService("Players").LocalPlayer.Character:WaitForChild("Humanoid"):ChangeState(15)
                        lp.Character:SetPrimaryPartCFrame(is)
                        wait(0.1)
                        if lp.Character and lp.Character:FindFirstChild("Head") then
                            lp.Character.Head:Destroy()
                        end
                        wait(0.5)
                        repeat task.wait()
                            if lp.Character and lp.Character:FindFirstChild("PrimaryPart") then
                                lp.Character.PrimaryPart.CFrame = is  
                            else
                                break
                            end
                        until lp.Character and lp.Character:FindFirstChild("Humanoid") and lp.Character.Humanoid.Health > 0
                        task.wait(0.5)
                    end)
                end 
            end
        end
    end
end

function to(Pos)
    pcall(function()
        if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") and lp.Character:FindFirstChild("Humanoid") and lp.Character.Humanoid.Health > 0 then
            local hrp = game.Players.LocalPlayer.Character.HumanoidRootPart
            local Distance = (Pos.Position - hrp.Position).Magnitude

            if not hrp:FindFirstChild("Hold") then
                local Hold = Instance.new("BodyVelocity", hrp)
                Hold.Name = "Hold"
                Hold.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                Hold.Velocity = Vector3.new(0, 0, 0)
            end

            if game.Players.LocalPlayer.Character.Humanoid.Sit == true then
                game.Players.LocalPlayer.Character.Humanoid.Sit = false
            end

            if Distance <= 250 then
                if tween then tween:Cancel() end
                hrp.CFrame = Pos
                return
            end

            local Speed = Distance < 1000 and 340 or 320

            if tween then tween:Cancel() end

            pcall(function()
                tween = game:GetService("TweenService"):Create(
                    hrp,
                    TweenInfo.new(Distance / Speed, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
                    {CFrame = Pos}
                )
                tween:Play()
            end)

            if game.Players.LocalPlayer.Character.Humanoid.Sit == true then
                game.Players.LocalPlayer.Character.Humanoid.Sit = false
            end
        end
    end)
end

function buso()
    if lp.Character and not lp.Character:FindFirstChild("HasBuso") then
        game.ReplicatedStorage.Remotes.CommF_:InvokeServer("Buso")
    end
end

function Ken()
    if game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui") and 
       game.Players.LocalPlayer.PlayerGui:FindFirstChild("ScreenGui") and 
       game.Players.LocalPlayer.PlayerGui.ScreenGui:FindFirstChild("ImageLabel") then
        return true
    else
        game:service("VirtualUser"):CaptureController()
        game:service("VirtualUser"):SetKeyDown("0x65")
        game:service("VirtualUser"):SetKeyUp("0x65")
        return false
    end
end

function down(use, wait)
    pcall(function()
        if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
            game:GetService("VirtualInputManager"):SendKeyEvent(true, use, false, game.Players.LocalPlayer.Character.HumanoidRootPart)
            task.wait((wait or 0.1))
            game:GetService("VirtualInputManager"):SendKeyEvent(false, use, false, game.Players.LocalPlayer.Character.HumanoidRootPart)
        end
    end)
end

function equip(tooltip)
    local p = game.Players.LocalPlayer
    local char = p.Character or p.CharacterAdded:wait()
    for _, item in pairs(p.Backpack:GetChildren()) do
        if item:IsA("Tool") and item.ToolTip == tooltip then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid and not humanoid:IsDescendantOf(item) then
                game.Players.LocalPlayer.Character.Humanoid:EquipTool(item)
                return true
            end
        end
    end
    return false
end

function EquipWeapon(Tool)
    pcall(function()
        if game.Players.LocalPlayer.Backpack:FindFirstChild(Tool) then
            local ToolHumanoid = game.Players.LocalPlayer.Backpack:FindFirstChild(Tool)
            if ToolHumanoid then
                ToolHumanoid.Parent = game.Players.LocalPlayer.Character
            end
        end
    end)
end

spawn(function()
    while game:GetService("RunService").Stepped:wait() do
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

if getgenv().Setting.Another.FPSBoots then
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
game:GetService("RunService"):Set3dRenderingEnabled(true)

function hasValue(array, targetString)
    if not array then return false end
    for _, value in ipairs(array) do
        if value == targetString then
            return true
        end
    end
    return false
end

local y = nil    
pcall(function()
    if game:GetService("Players").LocalPlayer:FindFirstChild("PlayerScripts") then
        local success, result = pcall(function()
            return require(game:GetService("Players").LocalPlayer.PlayerScripts:FindFirstChild("CombatFramework"))
        end)
        if success and result then
            local getCombatFramework = result
            local getCombatFrameworkR = debug.getupvalues(getCombatFramework)[2]
            y = getCombatFrameworkR
        end
    end
end)
spawn(function()
    game:GetService("RunService").RenderStepped:Connect(function()
        if y and typeof(y) == "table" then
            pcall(function()
                if y.activeController then
                    y.activeController.hitboxMagnitude = 60
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
end)

local radius = 25
local speedCircle = 30
local angle = 0
local yTween = 5
local function getNextPosition(center)
    angle = angle + speedCircle
    return center + Vector3.new(math.sin(math.rad(angle)) * radius, yTween, math.cos(math.rad(angle)) * radius)
end

getgenv().hopserver = false
local starthop = false

spawn(function()
    while task.wait() do
        if getgenv().hopserver then
            stopbypass = true
            starthop = true
        end
    end
end)

spawn(function()
    while task.wait() do
        if starthop then
            local inCombat = pcall(function()
                return lp.PlayerGui and lp.PlayerGui:FindFirstChild("Main") and
                       lp.PlayerGui.Main:FindFirstChild("BottomHUDList") and
                       lp.PlayerGui.Main.BottomHUDList:FindFirstChild("InCombat") and
                       lp.PlayerGui.Main.BottomHUDList.InCombat.Visible and
                       string.find(string.lower(lp.PlayerGui.Main.BottomHUDList.InCombat.Text), "risk")
            end)
            if inCombat then
                repeat task.wait()
                    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                        to(lp.Character.HumanoidRootPart.CFrame*CFrame.new(0, math.random(500, 2000), 0))
                    end
                until not (lp.PlayerGui and lp.PlayerGui:FindFirstChild("Main") and
                           lp.PlayerGui.Main:FindFirstChild("BottomHUDList") and
                           lp.PlayerGui.Main.BottomHUDList:FindFirstChild("InCombat") and
                           lp.PlayerGui.Main.BottomHUDList.InCombat.Visible and
                           string.find(string.lower(lp.PlayerGui.Main.BottomHUDList.InCombat.Text), "risk"))
            end
            starthop = false
            HopServer()
        end
    end
end)

function CheckInComBat()
    return game.Players.LocalPlayer.PlayerGui.Main.BottomHUDList.InCombat.Visible and 
           game.Players.LocalPlayer.PlayerGui.Main.BottomHUDList.InCombat.Text and 
           (string.find(string.lower(game.Players.LocalPlayer.PlayerGui.Main.BottomHUDList.InCombat.Text),"risk"))
end 

function HopServer(counts)
    local S = game.JobId
    if not getgenv().ServerBlacklist then getgenv().ServerBlacklist = {} end
    table.insert(getgenv().ServerBlacklist, S)
    local T, U = pcall(function()
        local V = game:GetService("HttpService")
        local W = game:GetService("TeleportService")
        local X = string.format("https://games.roblox.com/v1/games/%d/servers/Public?limit=100", game.PlaceId)
        local Y = V:JSONDecode(game:HttpGet(X))
        local Z = nil
        for _, _0 in ipairs(Y.data) do
            if _0.playing and _0.maxPlayers and _0.playing > 5 and _0.playing < _0.maxPlayers - 2 then
                local _1 = _0.id
                local _2 = false
                for _, _3 in ipairs(getgenv().ServerBlacklist or {}) do
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
                    for _, _3 in ipairs(getgenv().ServerBlacklist or {}) do
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
                for _, _3 in ipairs(getgenv().ServerBlacklist or {}) do
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
    if not T or U then game:GetService("TeleportService"):Teleport(game.PlaceId) end
end
getgenv().HopServer = HopServer

-- FIX #5: Thêm debounce cho SkipPlayer tránh race condition
local skipping = false
function SkipPlayer()
    if skipping then return end
    skipping = true
    getgenv().killed = getgenv().targ 
    if getgenv().targ then
        table.insert(getgenv().checked, getgenv().targ)
    end
    getgenv().targ = nil
    print("None")
    getgenv().target()
    task.spawn(function()
        task.wait(0.5)
        skipping = false
    end)
end
getgenv().SkipPlayer = SkipPlayer

-- FIX #3: CheckSafeZone khai báo TRƯỚC isValidBountyTarget
function CheckSafeZone(nitga)
    for r, v in pairs(workspace['_WorldOrigin']['SafeZones']:GetChildren()) do
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
    if not v or v == lp then return false end
    if not v.Character or not v.Character:FindFirstChild("HumanoidRootPart") then return false end
    if not v:FindFirstChild("Data") then return false end
    if not v:FindFirstChild("leaderstats") then return false end
    if not v.leaderstats["Bounty/Honor"] then return false end

    local bounty = v.leaderstats["Bounty/Honor"].Value
    if bounty < getgenv().Setting.Hunt.Min or bounty > getgenv().Setting.Hunt.Max then return false end

    if (tonumber(lp.Data.Level.Value) - 250) >= v.Data.Level.Value then return false end

    if v.Team == nil then return false end
    if not (tostring(lp.Team) == getgenv().Setting.Team or (tostring(v.Team) == getgenv().Setting.Team and tostring(lp.Team) ~= getgenv().Setting.Team)) then return false end

    if getgenv().Setting.Skip.Fruit and hasValue(getgenv().Setting.Skip.FruitList, v.Data.DevilFruit.Value) then return false end

    if getgenv().Setting.Skip.RaceV4 and v.Character:FindFirstChild("RaceTransformed") then return false end
    if getgenv().Setting["Skip Race V4"] and v.Character:FindFirstChild("RaceTransformed") then return false end

    if getgenv().Setting.Skip.SafeZone then
        local safeOk = true
        pcall(function()
            safeOk = not CheckSafeZone(v.Character.HumanoidRootPart)
        end)
        if not safeOk then return false end
    end

    if getgenv().dangerBlacklist[v.Name] then return false end
    if hasValue(getgenv().checked, v) then return false end
    if v.Character.HumanoidRootPart.CFrame.Y > 12000 then return false end

    return true
end

-- FIX #2: Khai báo và gán getgenv().target trước khi dùng
function target() 
    pcall(function()
        local d = math.huge
        local p = nil
        getgenv().targ = nil        

        for _, v in pairs(game.Players:GetPlayers()) do 
            if isValidBountyTarget(v) then
                local dist = (v.Character.HumanoidRootPart.CFrame.Position - lp.Character.HumanoidRootPart.CFrame.Position).Magnitude
                if dist < d and not getgenv().hopserver then
                    p = v 
                    d = dist
                    if getgenv().Setting.Chat and #getgenv().Setting.Chat > 0 then
                        local chatMsg = getgenv().Setting.Chat[math.random(1, #getgenv().Setting.Chat)]
                        if chatMsg then
                            game:GetService("ReplicatedStorage"):WaitForChild("DefaultChatSystemChatEvents"):FindFirstChild("SayMessageRequest"):FireServer(chatMsg, "All")
                        end
                    end
                end
            end
        end

        if p == nil then
            if getgenv().Setting.Another.HopAfterAllPlayers then
                local hasRemainingValidPlayer = false
                for _, v in pairs(game.Players:GetPlayers()) do
                    if v ~= lp and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                        if v:FindFirstChild("Data") and v:FindFirstChild("leaderstats") and v.leaderstats["Bounty/Honor"] then
                            local bounty = v.leaderstats["Bounty/Honor"].Value
                            if bounty >= getgenv().Setting.Hunt.Min and bounty <= getgenv().Setting.Hunt.Max then
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
-- FIX #2: Gán vào getgenv để các spawn khác có thể gọi đúng
getgenv().target = target

spawn(function()
    while wait() do
        pcall(function()
            if getgenv().targ and getgenv().targ.Character and lp.Character and
               (getgenv().targ.Character.HumanoidRootPart.CFrame.Position - lp.Character.HumanoidRootPart.CFrame.Position).Magnitude < 40 then
                Ken()
            end
        end)
    end
end)

local gunmethod = getgenv().Setting.Gun.GunMode

spawn(function()
    while task.wait() do
        pcall(function()
            if getgenv().targ and getgenv().targ.Character and getgenv().targ.Character:FindFirstChild("HumanoidRootPart") and 
               lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                if (getgenv().targ.Character:WaitForChild("HumanoidRootPart").CFrame.Position - lp.Character:WaitForChild("HumanoidRootPart").CFrame.Position).Magnitude < 40 then 
                    if not gunmethod then
                        if getgenv().Setting.Melee.Enable then
                            getgenv().weapon = "Melee"
                            wait(getgenv().Setting.Melee.Delay or 0.1)
                        end
                        if getgenv().Setting.Fruit.Enable then
                            getgenv().weapon = "Blox Fruit"
                            wait(getgenv().Setting.Fruit.Delay or 0.1)
                        end
                        if getgenv().Setting.Sword.Enable then
                            getgenv().weapon = "Sword"
                            wait(getgenv().Setting.Sword.Delay or 0.1)
                        end
                        if getgenv().Setting.Gun.Enable then
                            getgenv().weapon = "Gun"
                            wait(getgenv().Setting.Gun.Delay or 0.1)
                        end
                    else
                        pcall(function()
                            EquipWeapon("Melee")
                            EquipWeapon("Gun")
                        end)
                    end
                end
            end
        end)
    end
end)

spawn(function()
    while task.wait() do 
        pcall(function()
            if game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Main") and
               game:GetService("Players").LocalPlayer.PlayerGui.Main:FindFirstChild("PvpDisabled") and
               game:GetService("Players").LocalPlayer.PlayerGui.Main.PvpDisabled.Visible == true then
                game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("EnablePvp")
            end
            
            if getgenv().targ and getgenv().targ.Character and lp.Character and
               (getgenv().targ.Character.HumanoidRootPart.CFrame.Position - lp.Character.HumanoidRootPart.CFrame.Position).Magnitude < 50 then
                buso()
                if getgenv().Setting.Another.V3 then
                    if getgenv().Setting.Another.CustomHealth and 
                       lp.Character.Humanoid.Health <= getgenv().Setting.Another.Health then
                        down("T", 0.1)
                    end
                end
                if getgenv().Setting.Another.V4 then
                    down("Y", 0.1)
                end   
            end
        end)
    end
end)

spawn(function()
    while task.wait() do
        if not getgenv().targ or not getgenv().targ.Character then getgenv().target() end
        if not getgenv().targ then getgenv().hopserver = true end         
        pcall(function()
            if getgenv().targ.Character and getgenv().targ.Character:FindFirstChild("HumanoidRootPart") and 
               lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                if (getgenv().targ.Character:WaitForChild("HumanoidRootPart").CFrame.Position - lp.Character:WaitForChild("HumanoidRootPart").CFrame.Position).Magnitude < 40 then 
                    spawn(function()
                        if not gunmethod then
                            pcall(function() EquipWeapon("Summon Sea Beast") end)
                            equip(getgenv().weapon)
                            for _, v in pairs(lp.Character:GetChildren()) do 
                                if v:IsA("Tool") then
                                    if v.ToolTip == "Melee" then
                                        if getgenv().Setting.Melee.Enable then
                                            if lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("Z") and lp.PlayerGui.Main.Skills[v.Name].Z.Cooldown.AbsoluteSize.X <= 0 and getgenv().Setting.Melee.Z.Enable then	
                                                down("Z", getgenv().Setting.Melee.Z.HoldTime)
                                            elseif lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("X") and lp.PlayerGui.Main.Skills[v.Name].X.Cooldown.AbsoluteSize.X <= 0 and getgenv().Setting.Melee.X.Enable then	
                                                down("X", getgenv().Setting.Melee.X.HoldTime)
                                            elseif lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("C") and lp.PlayerGui.Main.Skills[v.Name].C.Cooldown.AbsoluteSize.X <= 0 and getgenv().Setting.Melee.C.Enable then	
                                                down("C", getgenv().Setting.Melee.C.HoldTime)
                                            elseif getgenv().Setting.Melee.V.Enable and lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("V") and lp.PlayerGui.Main.Skills[v.Name].V.Cooldown.AbsoluteSize.X <= 0 then	
                                                down("V", getgenv().Setting.Melee.V.HoldTime)
                                            end
                                        end
                                    elseif v.ToolTip == "Gun" then
                                        if getgenv().Setting.Gun.Enable then
                                            if lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("Z") and lp.PlayerGui.Main.Skills[v.Name].Z.Cooldown.AbsoluteSize.X <= 0 and getgenv().Setting.Gun.Z.Enable then	
                                                down("Z", getgenv().Setting.Gun.Z.HoldTime)
                                            elseif lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("X") and lp.PlayerGui.Main.Skills[v.Name].X.Cooldown.AbsoluteSize.X <= 0 and getgenv().Setting.Gun.X.Enable then	
                                                down("X", getgenv().Setting.Gun.X.HoldTime)
                                            end
                                        end
                                    elseif v.ToolTip == "Sword" then
                                        if getgenv().Setting.Sword.Enable then
                                            if lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("Z") and lp.PlayerGui.Main.Skills[v.Name].Z.Cooldown.AbsoluteSize.X <= 0 and getgenv().Setting.Sword.Z.Enable then	
                                                down("Z", getgenv().Setting.Sword.Z.HoldTime)
                                            elseif lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("X") and lp.PlayerGui.Main.Skills[v.Name].X.Cooldown.AbsoluteSize.X <= 0 and getgenv().Setting.Sword.X.Enable then	
                                                down("X", getgenv().Setting.Sword.X.HoldTime)
                                            end
                                        end
                                    elseif v.ToolTip == "Blox Fruit" then
                                        if getgenv().Setting.Fruit.Enable then
                                            if lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("Z") and lp.PlayerGui.Main.Skills[v.Name].Z.Cooldown.AbsoluteSize.X <= 0 and getgenv().Setting.Fruit.Z.Enable then	
                                                down("Z", getgenv().Setting.Fruit.Z.HoldTime)
                                            elseif lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("X") and lp.PlayerGui.Main.Skills[v.Name].X.Cooldown.AbsoluteSize.X <= 0 and getgenv().Setting.Fruit.X.Enable then	
                                                down("X", getgenv().Setting.Fruit.X.HoldTime)
                                            elseif lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("C") and lp.PlayerGui.Main.Skills[v.Name].C.Cooldown.AbsoluteSize.X <= 0 and getgenv().Setting.Fruit.C.Enable then	
                                                down("C", getgenv().Setting.Fruit.C.HoldTime)
                                            elseif lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("V") and lp.PlayerGui.Main.Skills[v.Name].V.Cooldown.AbsoluteSize.X <= 0 and getgenv().Setting.Fruit.V.Enable then	
                                                down("V", getgenv().Setting.Fruit.V.HoldTime)
                                            elseif getgenv().Setting.Fruit.F.Enable and lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("F") and lp.PlayerGui.Main.Skills[v.Name].F.Cooldown.AbsoluteSize.X <= 0 then	
                                                down("F", getgenv().Setting.Fruit.F.HoldTime)
                                            end
                                        end
                                    end
                                end
                            end
                        else
                            if getgenv().Setting.Melee.Enable then
                                if getgenv().Setting.Melee.Z.Enable then	
                                    down("Z", getgenv().Setting.Melee.Z.HoldTime)
                                elseif getgenv().Setting.Melee.X.Enable then	
                                    down("X", getgenv().Setting.Melee.X.HoldTime)
                                elseif getgenv().Setting.Melee.C.Enable then	
                                    down("C", getgenv().Setting.Melee.C.HoldTime)
                                elseif getgenv().Setting.Melee.V.Enable then	
                                    down("V", getgenv().Setting.Melee.V.HoldTime)
                                end
                            end
                        end
                        if CheckSafeZone(getgenv().targ.Character.HumanoidRootPart) or game.Players.LocalPlayer.PlayerGui.Main["[OLD]SafeZone"].Visible == true or getgenv().targ.Character.Humanoid.Sit == true then
                            SkipPlayer()
                        end
                        for _, v in pairs(game.Players.LocalPlayer.PlayerGui.Notifications:GetChildren()) do 
                            if v:IsA("TextLabel") then 
                                local text = string.lower(v.Text)
                                local combatSkipKeywords = {
                                    "player died recently",
                                    "you can't attack them yet",
                                    "cannot attack",
                                    "nguoi choi vua tu tran",
                                    "người chơi vừa tử trận",
                                    "died recently",
                                    "can't attack them",
                                    "cannot attack this player",
                                    "skill locked",
                                }
                                for _, keyword in pairs(combatSkipKeywords) do
                                    if string.find(text, keyword) then
                                        print("🎯 PHÁT HIỆN THÔNG BÁO CẦN SKIP:", string.sub(v.Text, 1, 60))
                                        SkipPlayer()
                                        pcall(function() v:Destroy() end)
                                        break
                                    end
                                end
                            end
                        end
                    end)
                end
            end
        end)
    end
end)

local a, b
local Nguvc = 5
local helloae = false
local safehealth = false

-- =============================================
-- SAFE HEALTH: Dùng % máu thay vì số tuyệt đối
-- Ví dụ Setting.SafeHealth.Health = 1000 → coi là 1000/MaxHealth %
-- Nhưng nếu MaxHealth > 5000 thì nên dùng % để tránh bug
-- Logic: nếu máu% <= safeHealthPct thì bay lên trời né
-- safeHealthPct = SafeHealth.Health / MaxHealth (lúc đầu game)
-- =============================================
local function getHealthPct()
    local hum = lp.Character and lp.Character:FindFirstChild("Humanoid")
    if not hum or hum.MaxHealth <= 0 then return 1 end
    return hum.Health / hum.MaxHealth
end

local function getSafeHealthPct()
    -- Nếu setting là số tuyệt đối (vd 1000), convert sang %
    -- Dựa trên MaxHealth hiện tại của nhân vật
    local hum = lp.Character and lp.Character:FindFirstChild("Humanoid")
    if not hum or hum.MaxHealth <= 0 then return 0.3 end
    local safeVal = getgenv().Setting.SafeHealth.Health
    -- Nếu safeVal nhỏ hơn 1 thì người dùng đã dùng % sẵn (0.3 = 30%)
    if safeVal <= 1 then
        return safeVal
    else
        -- Convert số tuyệt đối sang %
        return safeVal / hum.MaxHealth
    end
end

local function isLowHealth()
    local pct = getHealthPct()
    local safePct = getSafeHealthPct()
    local hum = lp.Character and lp.Character:FindFirstChild("Humanoid")
    -- Chỉ trigger khi đang sống (Health > 0) và máu thực sự thấp
    return hum and hum.Health > 0 and pct <= safePct
end

spawn(function()
    while task.wait(0.05) do
        if isLowHealth() then
            -- ===== MÁU THẤP: BAY LÊN TRỜI NÉ =====
            safehealth = true
            checkDangerAndBlacklist()
            pcall(function()
                if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                    -- Bay thẳng lên cao tại vị trí của mình, không theo target
                    local hrp = lp.Character.HumanoidRootPart
                    local flyHeight = math.random(8000, 15000)
                    -- Dùng CFrame teleport ngay để thoát nhanh thay vì tween chậm
                    hrp.CFrame = hrp.CFrame * CFrame.new(0, flyHeight, 0)
                end
            end)
            -- Chờ máu hồi lại trên ngưỡng an toàn rồi mới tiếp tục
            repeat task.wait(0.5) until not isLowHealth() or not lp.Character
            safehealth = false
            print("💚 [SafeHealth] Máu đã hồi, tiếp tục hunt!")
        else
            safehealth = false
            if not getgenv().targ then getgenv().target() end
            if not getgenv().targ then getgenv().hopserver = true end 
            if not game:GetService("Players").LocalPlayer.PlayerGui.Main.BottomHUDList.PvpDisabled.Visible then
                pcall(function()
                    if getgenv().targ and getgenv().targ.Character and getgenv().targ.Character:FindFirstChild("HumanoidRootPart") and 
                    lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") and
                    lp.Character:FindFirstChild("Humanoid") then
                        pcall(function()    
                            if not (game:GetService("Workspace")["_WorldOrigin"].Locations:FindFirstChild("Island 1") and 
                                getgenv().targ:DistanceFromCharacter(game:GetService("Workspace")["_WorldOrigin"].Locations:FindFirstChild("Island 1").Position) < 10000) then
                                if (getgenv().targ.Character:WaitForChild("HumanoidRootPart").CFrame.Position - lp.Character:WaitForChild("HumanoidRootPart").CFrame.Position).Magnitude < 40 then 
                                    if game:GetService("Players").LocalPlayer.PlayerGui.Main.SafeZone.Visible == true then
                                        SkipPlayer()
                                    end
                                    if getgenv().targ.Character.Humanoid.Health > 0 then
                                        to(getgenv().targ.Character.HumanoidRootPart.CFrame * CFrame.new(0, 5, 5))
                                    else 
                                        SkipPlayer()
                                    end
                                else
                                    if getgenv().targ.Character.Humanoid.Health > 0 then
                                        to(getgenv().targ.Character.HumanoidRootPart.CFrame * CFrame.new(0, 5, 5))
                                    else
                                        SkipPlayer()
                                    end
                                end
                            else
                                SkipPlayer()
                            end
                        end)                        
                        a = getgenv().targ.Character.HumanoidRootPart.Position                        
                        if a ~= b then
                            yTween = 0
                            b = a                           
                            if (getgenv().Setting.Gun.Enable and getgenv().Setting.Gun.GunMode) then
                                Nguvc = 14
                            else
                                Nguvc = 15
                            end
                        else
                            yTween = 5                          
                            if (getgenv().Setting.Gun.Enable and getgenv().Setting.Gun.GunMode) then
                                Nguvc = 3
                            else
                                Nguvc = 5
                            end
                        end                        
                        if getgenv().targ.Character.HumanoidRootPart.CFrame.Y >= 10 then
                            helloae = true
                        else
                            helloae = false
                        end
                        checkDangerAndBlacklist()
                    end
                end)
            else
                game.ReplicatedStorage.Remotes.CommF_:InvokeServer("EnablePvp")
            end
        end
    end
end)

local aim = false
local CFrameHunt

spawn(function()
    while task.wait() do 
        if getgenv().targ and getgenv().targ.Character and 
           lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") and
           (getgenv().targ.Character:WaitForChild("HumanoidRootPart").CFrame.Position - lp.Character:WaitForChild("HumanoidRootPart").CFrame.Position).Magnitude < 40 then             
            aim = true           
            if (getgenv().Setting.Gun.Enable and getgenv().Setting.Gun.GunMode) then
                CFrameHunt = CFrame.new(getgenv().targ.Character.HumanoidRootPart.Position + getgenv().targ.Character.HumanoidRootPart.CFrame.LookVector * 2, getgenv().targ.Character.HumanoidRootPart.Position)
            else
                CFrameHunt = CFrame.new(getgenv().targ.Character.HumanoidRootPart.Position + getgenv().targ.Character.HumanoidRootPart.CFrame.LookVector * 5, getgenv().targ.Character.HumanoidRootPart.Position)
            end
        else
            aim = false
        end
    end
end)

spawn(function()
    local gg = getrawmetatable(game)
    local old = gg.__namecall
    setreadonly(gg, false)    
    gg.__namecall = newcclosure(function(...)
        local method = getnamecallmethod()
        local args = {...}        
        if tostring(method) == "FireServer" then
            if tostring(args[1]) == "RemoteEvent" then
                if tostring(args[2]) ~= "true" and tostring(args[2]) ~= "false" then
                    if aim and CFrameHunt then
                        args[2] = CFrameHunt.Position
                        return old(unpack(args))
                    end
                end
            end
        end        
        return old(...)
    end)
end)

game:GetService("CoreGui").RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
    if not getgenv().hopserver and child.Name == 'ErrorPrompt' and child:FindFirstChild('MessageArea') and child.MessageArea:FindFirstChild("ErrorFrame") then
        game:GetService("TeleportService"):Teleport(game.PlaceId)
    end
end)

function sendKillWebhook(targetName, bountyEarned, currentBounty)
    if not getgenv().Setting.Webhook.Enabled or getgenv().Setting.Webhook.Url == "" then
        return
    end    
    local url = getgenv().Setting.Webhook.Url
    local p = game.Players.LocalPlayer
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
                {["name"]="Trget",["value"]="```"..targetName.."```",["inline"]=true},
                {["name"]="Bounty Earned",["value"]="```"..formatBounty(bountyEarned).."```",["inline"]=true},
                {["name"]="Current Bounty",["value"]="```"..formatBounty(currentBounty).."```",["inline"]=true},
                {["name"]="👤 Hunter",["value"]="```"..p.Name.."```",["inline"]=true},
                {["name"]="Level",["value"]="```"..tostring(p.Data.Level.Value).."```",["inline"]=true},
                {["name"]="Time",["value"]="```"..os.date("%H:%M:%S %d/%m/%Y").."```",["inline"]=true}
            },
            ["footer"] = {["text"]="By Lo Hub Emorima"},
            ["thumbnail"] = {["url"]="https://www.roblox.com/headshot-thumbnail/image?userId="..p.UserId.."&width=420&height=420&format=png"}
        }}
    }
    pcall(function()
        local jsonData = game:GetService("HttpService"):JSONEncode(data)
        local success, response = pcall(function()
            if syn then
                return syn.request({Url=url,Method="POST",Headers={["Content-Type"]="application/json"},Body=jsonData})
            else
                return request({Url=url,Method="POST",Headers={["Content-Type"]="application/json"},Body=jsonData})
            end
        end)
        if success then
            print("✅ Sent kill webhook: " .. targetName)
        else
            print("❌ Webhook error: " .. tostring(response))
        end
    end)
end

local lastKilledPlayer = nil
spawn(function()
    while task.wait(1) do
        pcall(function()
            if getgenv().targ and getgenv().targ.Character then
                local targetPlayer = getgenv().targ
                local char = targetPlayer.Character               
                if char:FindFirstChild("Humanoid") and char.Humanoid.Health <= 0 then                    
                    if lastKilledPlayer ~= targetPlayer.Name then
                        task.wait(2)
                        local p = game.Players.LocalPlayer
                        local currentBounty = p.leaderstats["Bounty/Honor"] and p.leaderstats["Bounty/Honor"].Value or 0
                        local bountyEarned = currentBounty - lastBounty
                        if bountyEarned <= 0 then
                            bountyEarned = math.random(1000, 5000)
                        end                        
                        sendKillWebhook(targetPlayer.Name, bountyEarned, currentBounty)
                        lastKilledPlayer = targetPlayer.Name                       
                        print("🎯 ELIMINATED: " .. targetPlayer.Name)
                        print("💰 Bounty earned: " .. bountyEarned)
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
    if getgenv().Setting.Webhook.Enabled and getgenv().Setting.Webhook.Url ~= "" then
        local p = game.Players.LocalPlayer
        local currentBounty = p.leaderstats["Bounty/Honor"] and p.leaderstats["Bounty/Honor"].Value or 0        
        local data = {
            ["embeds"] = {{
                ["title"] = "notify",
                ["description"] = "Bounty Ez",
                ["color"] = 16753920,
                ["fields"] = {
                    {["name"]="User Name",["value"]="```"..p.Name.."```",["inline"]=true},
                    {["name"]="Level",["value"]="```"..tostring(p.Data.Level.Value).."```",["inline"]=true},
                    {["name"]="Current Bounty",["value"]="```"..tostring(currentBounty).."```",["inline"]=true},
                    {["name"]="Check Team",["value"]="```"..getgenv().Setting.Team.."```",["inline"]=true}
                },
                ["footer"] = {["text"]="Auto Bounty By Lo Hub"..os.date("%H:%M %d/%m/%Y")}
            }}
        }        
        pcall(function()
            local jsonData = game:GetService("HttpService"):JSONEncode(data)
            if syn then
                syn.request({Url=getgenv().Setting.Webhook.Url,Method="POST",Headers={["Content-Type"]="application/json"},Body=jsonData})
            else
                request({Url=getgenv().Setting.Webhook.Url,Method="POST",Headers={["Content-Type"]="application/json"},Body=jsonData})
            end
            print("✅ Sent startup webhook")
        end)
    end
end)

function checkno(searchText)
    local notifications = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
    if not notifications then return false end
    local notifFrame = notifications:FindFirstChild("Notifications")
    if not notifFrame then return false end
    for _, notification in pairs(notifFrame:GetDescendants()) do
        if notification:IsA("TextLabel") or notification:IsA("TextBox") then
            local success, text = pcall(function() return notification.Text end)
            if success and text and string.find(text:lower(), searchText:lower()) then
                return true
            end
        end
    end
    return false
end

-- FIX #6: Loại bỏ keyword "player" quá chung, chỉ giữ keyword cụ thể
spawn(function()
    while task.wait(0.5) do
        pcall(function()
            for _, v in pairs(game.Players.LocalPlayer.PlayerGui.Notifications:GetChildren()) do 
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
