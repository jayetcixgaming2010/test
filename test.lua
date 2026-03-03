local CFG = getgenv().Setting or {}  -- Kiểm tra Setting đã tồn tại
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CommF_Remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
pcall(function() CommF_Remote:InvokeServer("SetTeam", CFG["Team"]) end)

local LocalPlayer = game:GetService("Players").LocalPlayer
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local player = LocalPlayer
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Đợi character
local character = player.Character or player.CharacterAdded:Wait()

-- =============================================
-- TẢI VÀ CẤU HÌNH FASTATTACK MODULE
-- =============================================
loadstring(game:HttpGet("https://pastefy.app/0vZrrYO0/raw"))()
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
    -- Đảm bảo AutoClick được bật (mặc định đã true)
    print("✅ FastAttack loaded and configured")
end

-- =============================================
-- BIẾN TOÀN CỤC
-- =============================================
getgenv().weapon = nil
getgenv().targ = nil 
getgenv().lasttarrget = nil
getgenv().checked = {}
getgenv().pl = game.Players:GetPlayers()
getgenv().killed = nil
getgenv().hopserver = false
getgenv().dangerCount = {}
getgenv().dangerBlacklist = {}
getgenv().ServerBlacklist = getgenv().ServerBlacklist or {}

-- =============================================
-- AUTO CONFIRM TELEPORT POPUP
-- =============================================
spawn(function()
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
local lastMyHealth = nil
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

-- Sự kiện nút
HopBtn.MouseButton1Click:Connect(function()
    HopBtn.Text = "HOPPING..."
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
spawn(function()
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
-- WORLD / ISLAND SETUP
-- =============================================
local placeId = game.PlaceId
local worldMap = {
    [2753915549] = "World1",
    [85211729168715] = "World1",
    [4442272183] = "World2",
    [79091703265657] = "World2",
    [7449423635] = "World3",
    [100117331123089] = "World3"
}
local World1, World2, World3 = false, false, false
if worldMap[placeId] then
    local world = worldMap[placeId]
    if world == "World1" then World1 = true
    elseif world == "World2" then World2 = true
    elseif world == "World3" then World3 = true end
else
    player:Kick("❌ Not Support Game ❌")
    return
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
        ["Tiki Outpost"] = CFrame.new(-16218.6826, 9.08636189, 445.618408, -0.0610186495, 0.00000000110512588, -0.99813664, -0.0000000183458475, 1, 0.00000000222871765, 0.99813664, 0.0000000184476558, -0.0610186495)
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

local p2 = Players
local lp = player
local rs = RunService
local hb = rs.Heartbeat
local rends = rs.RenderStepped

local tween = nil
local stopbypass = false

function bypass(Pos)
    if not lp.Character or not lp.Character:FindFirstChild("Head") or not lp.Character:FindFirstChild("HumanoidRootPart") or not lp.Character:FindFirstChild("Humanoid") then
        return
    end
    local dist = math.huge
    local is = nil
    for i, v in pairs(island) do
        if (Pos.Position - v.Position).magnitude < dist then
            is = v
            dist = (Pos.Position - v.Position).magnitude
        end
    end
    if is == nil then return end
    if lp:DistanceFromCharacter(Pos.Position) > distbyp then
        if (lp.Character.Head.Position - Pos.Position).magnitude > (is.Position - Pos.Position).magnitude then
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
                repeat
                    task.wait()
                    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                        lp.Character.HumanoidRootPart.CFrame = is
                    else
                        break
                    end
                until lp.Character and lp.Character.PrimaryPart and lp.Character.PrimaryPart.CFrame == is
                task.wait(0.1)
                pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("SetSpawnPoint") end)
            else
                if not stopbypass then
                    if tween then
                        pcall(function() tween:Cancel() end)
                    end
                    repeat
                        task.wait()
                        if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                            lp.Character.HumanoidRootPart.CFrame = is
                        else
                            break
                        end
                    until lp.Character and lp.Character.PrimaryPart and lp.Character.PrimaryPart.CFrame == is
                    pcall(function()
                        lp.Character:WaitForChild("Humanoid"):ChangeState(15)
                        lp.Character:SetPrimaryPartCFrame(is)
                        wait(0.1)
                        if lp.Character and lp.Character:FindFirstChild("Head") then
                            lp.Character.Head:Destroy()
                        end
                        wait(0.5)
                        repeat
                            task.wait()
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
            local hrp = lp.Character.HumanoidRootPart
            local Distance = (Pos.Position - hrp.Position).Magnitude

            if not hrp:FindFirstChild("Hold") then
                local Hold = Instance.new("BodyVelocity", hrp)
                Hold.Name = "Hold"
                Hold.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                Hold.Velocity = Vector3.new(0, 0, 0)
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

function buso()
    if lp.Character and not lp.Character:FindFirstChild("HasBuso") then
        pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("Buso") end)
    end
end

function Ken()
    if lp:FindFirstChild("PlayerGui") and lp.PlayerGui:FindFirstChild("ScreenGui") and lp.PlayerGui.ScreenGui:FindFirstChild("ImageLabel") then
        return true
    else
        VirtualUser:CaptureController()
        VirtualUser:SetKeyDown("0x65")
        VirtualUser:SetKeyUp("0x65")
        return false
    end
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

function equip(tooltip)
    local char = lp.Character or lp.CharacterAdded:Wait()
    for _, item in pairs(lp.Backpack:GetChildren()) do
        if item:IsA("Tool") and item.ToolTip == tooltip then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid and not humanoid:IsDescendantOf(item) then
                humanoid:EquipTool(item)
                return true
            end
        end
    end
    return false
end

function EquipWeapon(Tool)
    pcall(function()
        if lp.Backpack:FindFirstChild(Tool) then
            local ToolHumanoid = lp.Backpack:FindFirstChild(Tool)
            if ToolHumanoid then
                ToolHumanoid.Parent = lp.Character
            end
        end
    end)
end

-- =============================================
-- FASTATTACK ĐÃ ĐẢM NHIỆM ĐÒN ĐÁNH THƯỜNG
-- KHÔNG CẦN FIREHIT
-- =============================================

-- Vòng lặp chống xuyên tường (giữ nguyên)
spawn(function()
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
if CFG.Another and CFG.Another.FPSBoots then
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

-- Hack CombatFramework (giữ nguyên)
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

spawn(function()
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
end)

-- =============================================
-- ĐÃ LOẠI BỎ HOÀN TOÀN CÁC ĐOẠN MỞ RỘNG HITBOX
-- (không còn phình to nhân vật)
-- =============================================

-- Các biến hỗ trợ di chuyển vòng tròn (giữ nguyên)
local radius = 25
local speedCircle = 30
local angle = 0
local yTween = 5
local function getNextPosition(center)
    angle = angle + speedCircle
    return center + Vector3.new(math.sin(math.rad(angle)) * radius, yTween, math.cos(math.rad(angle)) * radius)
end

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
                repeat
                    task.wait()
                    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                        to(lp.Character.HumanoidRootPart.CFrame * CFrame.new(0, math.random(500, 2000), 0))
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
    return lp.PlayerGui.Main.BottomHUDList.InCombat.Visible and
           lp.PlayerGui.Main.BottomHUDList.InCombat.Text and
           (string.find(string.lower(lp.PlayerGui.Main.BottomHUDList.InCombat.Text), "risk"))
end

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
    if not v or v == lp then return false end
    if not v.Character or not v.Character:FindFirstChild("HumanoidRootPart") then return false end
    if not v:FindFirstChild("Data") or not v.Data:FindFirstChild("Level") then return false end
    if not v:FindFirstChild("leaderstats") or not v.leaderstats:FindFirstChild("Bounty/Honor") then return false end

    local bounty = v.leaderstats["Bounty/Honor"].Value
    if bounty < (CFG.Hunt and CFG.Hunt.Min or 0) or bounty > (CFG.Hunt and CFG.Hunt.Max or 1e9) then return false end

    if lp.Data and lp.Data.Level then
        if (tonumber(lp.Data.Level.Value) - 250) >= v.Data.Level.Value then return false end
    end

    if v.Team == nil then return false end
    if not (tostring(lp.Team) == (CFG.Team or "") or (tostring(v.Team) == (CFG.Team or "") and tostring(lp.Team) ~= (CFG.Team or ""))) then return false end

    if CFG.Skip and CFG.Skip.Fruit and hasValue(CFG.Skip.FruitList, v.Data.DevilFruit and v.Data.DevilFruit.Value or "") then return false end
    if CFG.Skip and CFG.Skip.RaceV4 and v.Character:FindFirstChild("RaceTransformed") then return false end
    if CFG.Skip and CFG.Skip["Skip Race V4"] and v.Character:FindFirstChild("RaceTransformed") then return false end

    if CFG.Skip and CFG.Skip.SafeZone then
        local safeOk = pcall(function()
            return not CheckSafeZone(v.Character.HumanoidRootPart)
        end)
        if not safeOk then return false end
    end

    if getgenv().dangerBlacklist[v.Name] then return false end
    if hasValue(getgenv().checked, v) then return false end
    if v.Character.HumanoidRootPart.CFrame.Y > 12000 then return false end

    return true
end

-- Hàm tìm target
function target()
    pcall(function()
        if not lp.Character or not lp.Character:FindFirstChild("HumanoidRootPart") then return end
        local d = math.huge
        local p = nil
        getgenv().targ = nil

        for _, v in pairs(Players:GetPlayers()) do
            if isValidBountyTarget(v) then
                local dist = (v.Character.HumanoidRootPart.Position - lp.Character.HumanoidRootPart.Position).Magnitude
                if dist < d and not getgenv().hopserver then
                    p = v
                    d = dist
                    if CFG.Chat and #CFG.Chat > 0 then
                        local chatMsg = CFG.Chat[math.random(1, #CFG.Chat)]
                        if chatMsg then
                            pcall(function()
                                ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents"):FindFirstChild("SayMessageRequest"):FireServer(chatMsg, "All")
                            end)
                        end
                    end
                end
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

-- Kích hoạt Ken (giữ nguyên)
spawn(function()
    while task.wait() do
        pcall(function()
            if getgenv().targ and getgenv().targ.Character and lp.Character and
               (getgenv().targ.Character.HumanoidRootPart.Position - lp.Character.HumanoidRootPart.Position).Magnitude < 40 then
                Ken()
            end
        end)
    end
end)

-- Luân phiên vũ khí (giữ nguyên)
local gunmethod = CFG.Gun and CFG.Gun.GunMode or false

spawn(function()
    while task.wait() do
        pcall(function()
            if getgenv().targ and getgenv().targ.Character and getgenv().targ.Character:FindFirstChild("HumanoidRootPart") and
               lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                if (getgenv().targ.Character.HumanoidRootPart.Position - lp.Character.HumanoidRootPart.Position).Magnitude < 40 then
                    if not gunmethod then
                        if CFG.Melee and CFG.Melee.Enable then
                            getgenv().weapon = "Melee"
                            task.wait(CFG.Melee.Delay or 0.1)
                        end
                        if CFG.Fruit and CFG.Fruit.Enable then
                            getgenv().weapon = "Blox Fruit"
                            task.wait(CFG.Fruit.Delay or 0.1)
                        end
                        if CFG.Sword and CFG.Sword.Enable then
                            getgenv().weapon = "Sword"
                            task.wait(CFG.Sword.Delay or 0.1)
                        end
                        if CFG.Gun and CFG.Gun.Enable then
                            getgenv().weapon = "Gun"
                            task.wait(CFG.Gun.Delay or 0.1)
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

-- Bật PVP và buso (giữ nguyên)
spawn(function()
    while task.wait(3) do
        pcall(function()
            pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("EnablePvp") end)

            if getgenv().targ and getgenv().targ.Character and lp.Character and
               (getgenv().targ.Character.HumanoidRootPart.Position - lp.Character.HumanoidRootPart.Position).Magnitude < 50 then
                buso()
                if CFG.Another and CFG.Another.V3 then
                    if CFG.Another.CustomHealth and lp.Character.Humanoid.Health <= (CFG.Another.Health or 0) then
                        down("T", 0.1)
                    end
                end
                if CFG.Another and CFG.Another.V4 then
                    down("Y", 0.1)
                end
            end
        end)
    end
end)

-- Vòng lặp chính: di chuyển và sử dụng kỹ năng
spawn(function()
    while task.wait() do
        if not getgenv().targ or not getgenv().targ.Character then
            getgenv().target()
        end
        if not getgenv().targ then
            getgenv().hopserver = true
        end
        pcall(function()
            if getgenv().targ and getgenv().targ.Character and getgenv().targ.Character:FindFirstChild("HumanoidRootPart") and
               lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                if (getgenv().targ.Character.HumanoidRootPart.Position - lp.Character.HumanoidRootPart.Position).Magnitude < 40 then
                    spawn(function()
                        if not gunmethod then
                            pcall(function() EquipWeapon("Summon Sea Beast") end)
                            equip(getgenv().weapon)
                            for _, v in pairs(lp.Character:GetChildren()) do
                                if v:IsA("Tool") then
                                    if v.ToolTip == "Melee" then
                                        if CFG.Melee and CFG.Melee.Enable then
                                            if lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("Z") and lp.PlayerGui.Main.Skills[v.Name].Z.Cooldown.AbsoluteSize.X <= 0 and CFG.Melee.Z and CFG.Melee.Z.Enable then
                                                down("Z", CFG.Melee.Z.HoldTime or 0.1)
                                            elseif lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("X") and lp.PlayerGui.Main.Skills[v.Name].X.Cooldown.AbsoluteSize.X <= 0 and CFG.Melee.X and CFG.Melee.X.Enable then
                                                down("X", CFG.Melee.X.HoldTime or 0.1)
                                            elseif lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("C") and lp.PlayerGui.Main.Skills[v.Name].C.Cooldown.AbsoluteSize.X <= 0 and CFG.Melee.C and CFG.Melee.C.Enable then
                                                down("C", CFG.Melee.C.HoldTime or 0.1)
                                            elseif CFG.Melee.V and CFG.Melee.V.Enable and lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("V") and lp.PlayerGui.Main.Skills[v.Name].V.Cooldown.AbsoluteSize.X <= 0 then
                                                down("V", CFG.Melee.V.HoldTime or 0.1)
                                            end
                                        end
                                    elseif v.ToolTip == "Gun" then
                                        if CFG.Gun and CFG.Gun.Enable then
                                            if lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("Z") and lp.PlayerGui.Main.Skills[v.Name].Z.Cooldown.AbsoluteSize.X <= 0 and CFG.Gun.Z and CFG.Gun.Z.Enable then
                                                down("Z", CFG.Gun.Z.HoldTime or 0.1)
                                            elseif lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("X") and lp.PlayerGui.Main.Skills[v.Name].X.Cooldown.AbsoluteSize.X <= 0 and CFG.Gun.X and CFG.Gun.X.Enable then
                                                down("X", CFG.Gun.X.HoldTime or 0.1)
                                            end
                                        end
                                    elseif v.ToolTip == "Sword" then
                                        if CFG.Sword and CFG.Sword.Enable then
                                            if lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("Z") and lp.PlayerGui.Main.Skills[v.Name].Z.Cooldown.AbsoluteSize.X <= 0 and CFG.Sword.Z and CFG.Sword.Z.Enable then
                                                down("Z", CFG.Sword.Z.HoldTime or 0.1)
                                            elseif lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("X") and lp.PlayerGui.Main.Skills[v.Name].X.Cooldown.AbsoluteSize.X <= 0 and CFG.Sword.X and CFG.Sword.X.Enable then
                                                down("X", CFG.Sword.X.HoldTime or 0.1)
                                            end
                                        end
                                    elseif v.ToolTip == "Blox Fruit" then
                                        if CFG.Fruit and CFG.Fruit.Enable then
                                            if lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("Z") and lp.PlayerGui.Main.Skills[v.Name].Z.Cooldown.AbsoluteSize.X <= 0 and CFG.Fruit.Z and CFG.Fruit.Z.Enable then
                                                down("Z", CFG.Fruit.Z.HoldTime or 0.1)
                                            elseif lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("X") and lp.PlayerGui.Main.Skills[v.Name].X.Cooldown.AbsoluteSize.X <= 0 and CFG.Fruit.X and CFG.Fruit.X.Enable then
                                                down("X", CFG.Fruit.X.HoldTime or 0.1)
                                            elseif lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("C") and lp.PlayerGui.Main.Skills[v.Name].C.Cooldown.AbsoluteSize.X <= 0 and CFG.Fruit.C and CFG.Fruit.C.Enable then
                                                down("C", CFG.Fruit.C.HoldTime or 0.1)
                                            elseif lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("V") and lp.PlayerGui.Main.Skills[v.Name].V.Cooldown.AbsoluteSize.X <= 0 and CFG.Fruit.V and CFG.Fruit.V.Enable then
                                                down("V", CFG.Fruit.V.HoldTime or 0.1)
                                            elseif CFG.Fruit.F and CFG.Fruit.F.Enable and lp.PlayerGui.Main.Skills[v.Name]:FindFirstChild("F") and lp.PlayerGui.Main.Skills[v.Name].F.Cooldown.AbsoluteSize.X <= 0 then
                                                down("F", CFG.Fruit.F.HoldTime or 0.1)
                                            end
                                        end
                                    end
                                end
                            end
                        else
                            if CFG.Melee and CFG.Melee.Enable then
                                if CFG.Melee.Z and CFG.Melee.Z.Enable then
                                    down("Z", CFG.Melee.Z.HoldTime or 0.1)
                                elseif CFG.Melee.X and CFG.Melee.X.Enable then
                                    down("X", CFG.Melee.X.HoldTime or 0.1)
                                elseif CFG.Melee.C and CFG.Melee.C.Enable then
                                    down("C", CFG.Melee.C.HoldTime or 0.1)
                                elseif CFG.Melee.V and CFG.Melee.V.Enable then
                                    down("V", CFG.Melee.V.HoldTime or 0.1)
                                end
                            end
                        end

                        -- Kiểm tra safezone
                        if CheckSafeZone(getgenv().targ.Character.HumanoidRootPart) or (lp.PlayerGui.Main and lp.PlayerGui.Main["[OLD]SafeZone"] and lp.PlayerGui.Main["[OLD]SafeZone"].Visible) or getgenv().targ.Character.Humanoid.Sit == true then
                            SkipPlayer()
                        end

                        -- Kiểm tra thông báo notifications
                        for _, v in pairs(lp.PlayerGui.Notifications:GetChildren()) do
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
-- SAFE HEALTH (tự động bay lên cao khi máu thấp)
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

spawn(function()
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
            if not getgenv().targ then getgenv().target() end
            if not getgenv().targ then getgenv().hopserver = true end
            pcall(function()
                if getgenv().targ and getgenv().targ.Character and getgenv().targ.Character:FindFirstChild("HumanoidRootPart") and
                   lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") and lp.Character:FindFirstChild("Humanoid") then
                    pcall(function()
                        local locations = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("Locations")
                        if not (locations and locations:FindFirstChild("Island 1") and getgenv().targ:DistanceFromCharacter(locations["Island 1"].Position) < 10000) then
                            if (getgenv().targ.Character.HumanoidRootPart.Position - lp.Character.HumanoidRootPart.Position).Magnitude < 40 then
                                if lp.PlayerGui.Main and lp.PlayerGui.Main.SafeZone and lp.PlayerGui.Main.SafeZone.Visible then
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
                        if (CFG.Gun and CFG.Gun.Enable and CFG.Gun.GunMode) then
                            Nguvc = 14
                        else
                            Nguvc = 15
                        end
                    else
                        yTween = 5
                        if (CFG.Gun and CFG.Gun.Enable and CFG.Gun.GunMode) then
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
        end
    end
end)

local aim = false
local CFrameHunt

spawn(function()
    while task.wait() do
        if getgenv().targ and getgenv().targ.Character and
           lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") and
           (getgenv().targ.Character.HumanoidRootPart.Position - lp.Character.HumanoidRootPart.Position).Magnitude < 40 then
            aim = true
            if (CFG.Gun and CFG.Gun.Enable and CFG.Gun.GunMode) then
                CFrameHunt = CFrame.new(getgenv().targ.Character.HumanoidRootPart.Position + getgenv().targ.Character.HumanoidRootPart.CFrame.LookVector * 2, getgenv().targ.Character.HumanoidRootPart.Position)
            else
                CFrameHunt = CFrame.new(getgenv().targ.Character.HumanoidRootPart.Position + getgenv().targ.Character.HumanoidRootPart.CFrame.LookVector * 5, getgenv().targ.Character.HumanoidRootPart.Position)
            end
        else
            aim = false
        end
    end
end)

-- Hook namecall (giữ nguyên, nhưng bọc pcall)
pcall(function()
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
    setreadonly(gg, true)
end)

-- Xử lý lỗi prompt
CoreGui.RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
    if not getgenv().hopserver and child.Name == 'ErrorPrompt' and child:FindFirstChild('MessageArea') and child.MessageArea:FindFirstChild("ErrorFrame") then
        TeleportService:Teleport(game.PlaceId)
    end
end)

-- Webhook kill (giữ nguyên)
function sendKillWebhook(targetName, bountyEarned, currentBounty)
    if not CFG.Webhook or not CFG.Webhook.Enabled or CFG.Webhook.Url == "" then return end
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
spawn(function()
    task.wait(3)
    if lp and lp:FindFirstChild("leaderstats") then
        lastBounty = lp.leaderstats["Bounty/Honor"] and lp.leaderstats["Bounty/Honor"].Value or 0
    end
end)

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
                        local currentBounty = lp.leaderstats["Bounty/Honor"] and lp.leaderstats["Bounty/Honor"].Value or 0
                        local bountyEarned = currentBounty - lastBounty
                        if bountyEarned <= 0 then
                            bountyEarned = math.random(1000, 5000)
                        end
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

-- Kiểm tra thông báo skip (giữ nguyên)
spawn(function()
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
