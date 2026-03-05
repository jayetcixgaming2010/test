-- =============================================
-- DARKNESS X • AUTO BOUNTY (FIXED VERSION)
-- =============================================
-- Yêu cầu: Đặt cấu hình trong getgenv().Setting trước khi chạy
-- Ví dụ:
-- getgenv().Setting = { Team = "Pirates", Hunt = { Min = 0, Max = 30000000 }, ... }
-- =============================================

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
local character = player.Character or player.CharacterAdded:Wait()

-- =============================================
-- KIỂM TRA MÔI TRƯỜNG EXECUTOR
-- =============================================
local requestFunc = syn and syn.request or http and http.request or request
if not requestFunc then
    warn("⚠️ [DX] Không tìm thấy hàm request, webhook sẽ không hoạt động")
end

-- =============================================
-- TẢI FASTATTACK MODULE (có kiểm tra lỗi)
-- =============================================
local successFast, fastModule = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/jayetcixgaming2010/UI/refs/heads/main/UI.lua"))()
end)
if successFast and fastModule then
    getgenv().rz_FastAttack = fastModule
    local FastAttack = getgenv().rz_FastAttack
    FastAttack.GetClosestEnemy = function(self, ...)
        local targ = getgenv().targ
        if targ and targ.Character and targ.Character:FindFirstChild("HumanoidRootPart") then
            return targ.Character.HumanoidRootPart
        end
        return nil
    end
    print("✅ FastAttack loaded and configured")
else
    warn("❌ Không thể tải FastAttack, một số tính năng có thể không hoạt động")
end

-- =============================================
-- BIẾN TOÀN CỤC
-- =============================================
getgenv().weapon          = nil
getgenv().targ            = nil
getgenv().lasttarrget     = nil
getgenv().checked         = {}          -- Danh sách player đã từng target (để skip tạm)
getgenv().pl              = game.Players:GetPlayers()
getgenv().killed          = nil
getgenv().hopserver       = false
getgenv().dangerCount     = {}
getgenv().dangerBlacklist = {}
getgenv().ServerBlacklist = getgenv().ServerBlacklist or {}

-- =============================================
-- HÀM GỬI REQUEST (dùng chung cho webhook)
-- =============================================
local function sendRequest(url, method, headers, body)
    if not requestFunc then return false, "No request function" end
    local success, result = pcall(function()
        return requestFunc({
            Url = url,
            Method = method,
            Headers = headers,
            Body = body
        })
    end)
    return success, result
end

-- =============================================
-- AUTO CONFIRM TELEPORT POPUP + XỬ LÝ SERVER ĐẦY (đã tối ưu)
-- =============================================
local function isServerFullMsg(gui)
    if not gui then return false end
    local FULL_KEYWORDS = {
        "server is full", "this place is full", "no available servers",
        "server full", "place is full", "không có chỗ", "máy chủ đầy"
    }
    for _, lbl in pairs(gui:GetDescendants()) do
        if lbl:IsA("TextLabel") or lbl:IsA("TextButton") then
            local t = string.lower(lbl.Text or "")
            for _, kw in ipairs(FULL_KEYWORDS) do
                if string.find(t, kw, 1, true) then return true end
            end
        end
    end
    return false
end

local function autoConfirmTeleport(gui)
    if not gui then return end
    if isServerFullMsg(gui) then
        print("⚠️ [AutoConfirm] Server đầy! Thử server khác...")
        for _, btn in pairs(gui:GetDescendants()) do
            if btn:IsA("TextButton") or btn:IsA("ImageButton") then
                local t = string.lower(btn.Text or "")
                if t == "ok" or t == "close" or t == "dismiss" or t == "" then
                    pcall(function() btn:activate() end)
                end
            end
        end
        task.delay(2, function()
            if getgenv().HopServer and not isHopping then
                getgenv().hopserver = false
                isHopping = false
                getgenv().HopServer()
            end
        end)
        return
    end
    -- Confirm teleport bình thường
    for _, btn in pairs(gui:GetDescendants()) do
        if btn:IsA("TextButton") or btn:IsA("ImageButton") then
            local t = string.lower(btn.Text or "")
            if t == "ok" or t == "yes" or t == "teleport" or t == "confirm" or t == "leave" then
                pcall(function() btn:activate() end)
            end
        end
    end
end

-- Gắn sự kiện, không dùng vòng lặp liên tục
local promptGui = CoreGui:WaitForChild("RobloxPromptGui", 10)
if promptGui then
    local overlay = promptGui:FindFirstChild("promptOverlay")
    if overlay then
        overlay.ChildAdded:Connect(function(child)
            task.wait(0.15)
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

-- =============================================
-- DANGER BLACKLIST (reset khi đổi target)
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
    if not myHum or myHum.MaxHealth <= 0 then return end

    local healthPct = myHum.Health / myHum.MaxHealth
    local targName = targ.Name

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

-- Reset danger blacklist khi target chết hoặc được skip
local function resetDangerForTarget(targetName)
    getgenv().dangerCount[targetName] = nil
    getgenv().dangerBlacklist[targetName] = nil
    dangerCooldown[targetName] = nil
end

-- =============================================
-- GUI
-- =============================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DarknessX_AutoBounty"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

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

local MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MainFrame.BackgroundTransparency = 0.3
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
MainFrame.Size = UDim2.new(0, 400, 0, 320)
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

-- Kéo thả MainFrame (sử dụng thuật toán chống conflict)
local dragging, dragInput, dragStart, startPos
local function updateDrag(input)
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
    if input == dragInput and dragging then updateDrag(input) end
end)

-- Kéo thả ToggleBtn (tương tự)
local toggleDragging, toggleDragInput, toggleDragStart, toggleStartPos
local function updateToggleDrag(input)
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
    if input == toggleDragInput and toggleDragging then updateToggleDrag(input) end
end)

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

local Title    = CreateText("DARKNESS X • AUTO BOUNTY", 15)
Title.TextSize = 22
Title.Font     = Enum.Font.RobotoMono

local BountyLbl = CreateText("Bounty Earn: 0", 60)
local ExecLbl   = CreateText("Executor: Check...", 95)
local TimeLbl   = CreateText("Time Player: 00:00:00", 130)
local TargetLbl = CreateText("Target: Searching...", 175)
local DistLbl   = CreateText("Distance: 0m", 210)

local function CreateBtn(text, xPos)
    local btn = Instance.new("TextButton", MainFrame)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundTransparency = 0.9
    btn.Position = UDim2.new(xPos, 0, 0.84, 0)
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
local HopBtn  = CreateBtn("HOP SERVER", 0.53)

HopBtn.MouseButton1Click:Connect(function()
    if isHopping then
        print("⏳ Đang hop, vui lòng chờ...")
        return
    end
    HopBtn.Text = "HOPPING..."
    getgenv().hopserver = true
    getgenv().autoHopLoop = false
    spawn(function()
        HopServer()
        task.wait(3)
        HopBtn.Text = "HOP SERVER"
    end)
end)

SkipBtn.MouseButton1Click:Connect(function()
    SkipBtn.Text = "SKIPPING..."
    if getgenv().SkipPlayer then getgenv().SkipPlayer() end
    task.delay(0.5, function() SkipBtn.Text = "SKIP PLAYER" end)
end)

ToggleBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- UI Update loop
local uiStartTime   = os.time()
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
        if player and player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Bounty/Honor") and initialBounty then
            BountyLbl.Text = "Bounty Earn: " .. tostring(player.leaderstats["Bounty/Honor"].Value - initialBounty)
        end
        local diff = os.time() - uiStartTime
        TimeLbl.Text = string.format("Time Player: %02d:%02d:%02d", math.floor(diff/3600), math.floor((diff%3600)/60), diff%60)

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
            DistLbl.Text   = "Distance: 0 m"
            DistLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end)
end)

-- =============================================
-- WORLD / ISLAND SETUP (mở rộng)
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
        ["Tiki Outpost"] = CFrame.new(-16218.6826, 9.08636189, 445.618408, -0.0610186495, 0.00000000110512588, -0.99813664, -0.0000000183458475, 1, 0.00000000222871765, 0.99813664, 0.0000000184476558, -0.0610186495),
        ["Submerged Island"] = CFrame.new(-16269.7041, 25.2288494, 1373.65955, 0.997390985, 1.47309942e-09, -0.0721890926, -4.00651912e-09, 0.99999994, -2.51183763e-09, 0.0721890852, 5.75363091e-10, 0.997390926)
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

local lp = player
local rs = RunService
local tween = nil
local stopbypass = false

-- Hàm di chuyển an toàn (thay thế bypass cũ)
function safeTeleport(destinationCF)
    if not lp.Character or not lp.Character:FindFirstChild("HumanoidRootPart") then return end
    local hrp = lp.Character.HumanoidRootPart
    hrp.CFrame = destinationCF
    -- Chờ một chút để game cập nhật
    task.wait(0.1)
    -- Nếu vị trí chưa đúng, lặp lại vài lần
    for i = 1, 5 do
        if (hrp.Position - destinationCF.Position).Magnitude > 10 then
            hrp.CFrame = destinationCF
            task.wait(0.1)
        else
            break
        end
    end
end

function bypass(Pos)
    if not lp.Character or not lp.Character:FindFirstChild("Head") or not lp.Character:FindFirstChild("HumanoidRootPart") or not lp.Character:FindFirstChild("Humanoid") then return end

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
            if tween then pcall(function() tween:Destroy() end) end

            -- Các đảo đặc biệt cần set CFrame liên tục
            local specialIslands = {
                CFrame.new(61163.8515625, 11.6796875, 1819.7841796875),
                CFrame.new(-12471.169921875 + 50, 374.94024658203, -7551.677734375),
                CFrame.new(-5085.23681640625 + 50, 316.5072021484375, -3156.202880859375),
                CFrame.new(5749.7861328125 + 50, 611.9736938476562, -276.2497863769531),
                CFrame.new(-16269.7041, 25.2288494, 1373.65955, 0.997390985, 1.47309942e-09, -0.0721890926, -4.00651912e-09, 0.99999994, -2.51183763e-09, 0.0721890852, 5.75363091e-10, 0.997390926)
            }
            local isSpecial = false
            for _, sc in ipairs(specialIslands) do
                if (is.Position - sc.Position).Magnitude < 1 then isSpecial = true break end
            end

            if isSpecial then
                if tween then pcall(function() tween:Cancel() end) end
                safeTeleport(is)
                pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("SetSpawnPoint") end)
            else
                if not stopbypass then
                    if tween then pcall(function() tween:Cancel() end) end
                    safeTeleport(is)
                    pcall(function()
                        lp.Character:WaitForChild("Humanoid"):ChangeState(15)
                        lp.Character:SetPrimaryPartCFrame(is)
                        task.wait(0.1)
                        -- Không xóa Head nữa, thay bằng teleport lại
                        safeTeleport(is)
                        task.wait(0.5)
                    end)
                end
            end
        end
    end
end

-- Tốc độ di chuyển tối đa (studs/giây)
local MOVE_SPEED = 350

function to(Pos)
    pcall(function()
        if not (lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                and lp.Character:FindFirstChild("Humanoid")
                and lp.Character.Humanoid.Health > 0) then return end

        local hrp      = lp.Character.HumanoidRootPart
        local Distance = (Pos.Position - hrp.Position).Magnitude

        if lp.Character.Humanoid.Sit then lp.Character.Humanoid.Sit = false end

        if Distance <= 60 then
            if tween then tween:Cancel() end
            hrp.CFrame = Pos
            return
        end

        if Distance <= 600 then
            if tween then tween:Cancel() end
            local bv = hrp:FindFirstChild("MoveVel") or Instance.new("BodyVelocity", hrp)
            bv.Name = "MoveVel"
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            local dir = (Pos.Position - hrp.Position).Unit
            bv.Velocity = dir * math.min(MOVE_SPEED, Distance * 6)
            task.delay(Distance / MOVE_SPEED + 0.1, function()
                if bv and bv.Parent then
                    bv.Velocity = Vector3.new(0, 0, 0)
                    bv:Destroy()
                end
            end)
            return
        end

        local tweenTime = Distance / MOVE_SPEED
        if tween then tween:Cancel() end
        local oldBv = hrp:FindFirstChild("MoveVel")
        if oldBv then oldBv:Destroy() end

        tween = TweenService:Create(
            hrp,
            TweenInfo.new(tweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
            {CFrame = Pos}
        )
        tween:Play()

        if lp.Character.Humanoid.Sit then lp.Character.Humanoid.Sit = false end
    end)
end

function buso()
    if lp.Character and not lp.Character:FindFirstChild("HasBuso") then
        pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("Buso") end)
    end
end

function Ken()
    if lp:FindFirstChild("PlayerGui") and lp.PlayerGui:FindFirstChild("ScreenGui")
       and lp.PlayerGui.ScreenGui:FindFirstChild("ImageLabel") then
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
        local toolObj = lp.Backpack:FindFirstChild(Tool)
        if toolObj then toolObj.Parent = lp.Character end
    end)
end

-- =============================================
-- CHỐNG XUYÊN TƯỜNG
-- =============================================
spawn(function()
    while task.wait() do
        pcall(function()
            if lp.Character then
                for _, v in pairs(lp.Character:GetChildren()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
            end
        end)
    end
end)

-- =============================================
-- FPS BOOST
-- =============================================
if CFG.Another and CFG.Another.FPSBoost then
    local Lighting = game:GetService("Lighting")
    local ws = Workspace
    local t = ws.Terrain

    t.WaterWaveSize = 0
    t.WaterWaveSpeed = 0
    t.WaterReflectance = 0
    t.WaterTransparency = 0
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    Lighting.Brightness = 0.8

    for _, v in pairs(Lighting:GetChildren()) do
        if v:IsA("PostEffect") or v:IsA("BloomEffect") or v:IsA("BlurEffect")
           or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect")
           or v:IsA("DepthOfFieldEffect") then
            pcall(function() v:Destroy() end)
        end
    end

    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01

    local function disableVisuals(parent)
        for _, v in pairs(parent:GetDescendants()) do
            pcall(function()
                if v:IsA("ParticleEmitter") or v:IsA("Beam") or v:IsA("Trail") then
                    v.Enabled = false
                elseif v:IsA("BasePart") then
                    v.CastShadow = false
                end
            end)
        end
    end
    disableVisuals(ws)

    ws.DescendantAdded:Connect(function(v)
        pcall(function()
            if v:IsA("ParticleEmitter") or v:IsA("Beam") or v:IsA("Trail") then
                v.Enabled = false
            elseif v:IsA("BasePart") then
                v.CastShadow = false
            end
        end)
    end)

    print("✅ FPS Boost đã kích hoạt!")
end
RunService:Set3dRenderingEnabled(true)

-- =============================================
-- HELPER
-- =============================================
function hasValue(array, targetString)
    if not array then return false end
    for _, value in ipairs(array) do
        if value == targetString then return true end
    end
    return false
end

-- CombatFramework hack (bọc pcall)
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

-- Di chuyển vòng tròn
local radius = 25
local speedCircle = 30
local angle = 0
local yTween = 5
local function getNextPosition(center)
    angle = angle + speedCircle
    return center + Vector3.new(math.sin(math.rad(angle)) * radius, yTween, math.cos(math.rad(angle)) * radius)
end

local starthop = false
local isHopping = false
local lastHopTime = 0
local HOP_COOLDOWN = 8

-- =============================================
-- HÀM LẤY DANH SÁCH SERVER HỢP LỆ
-- =============================================
local function fetchValidServer()
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?limit=100", game.PlaceId)
    local ok, raw = pcall(function() return game:HttpGet(url) end)
    if not ok or not raw then return nil end

    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or not data or not data.data then return nil end

    local maxCfg = CFG.Another and CFG.Another.MaxPlayersInServer or 8

    local function isBlacklisted(id)
        for _, b in ipairs(getgenv().ServerBlacklist) do
            if b == id then return true end
        end
        return false
    end

    for _, s in ipairs(data.data) do
        if s.id and s.playing and s.maxPlayers
           and s.playing >= 2
           and s.playing <= maxCfg
           and s.playing < s.maxPlayers - 2
           and not isBlacklisted(s.id) then
            return s
        end
    end

    for _, s in ipairs(data.data) do
        if s.id and s.playing and s.maxPlayers
           and s.playing < s.maxPlayers - 1
           and not isBlacklisted(s.id) then
            return s
        end
    end

    for _, s in ipairs(data.data) do
        if s.id and s.playing and s.maxPlayers
           and s.playing < s.maxPlayers
           and not isBlacklisted(s.id) then
            return s
        end
    end

    return nil
end

function CheckInComBat()
    local ok, result = pcall(function()
        return lp.PlayerGui.Main.BottomHUDList.InCombat.Visible and
               lp.PlayerGui.Main.BottomHUDList.InCombat.Text and
               string.find(string.lower(lp.PlayerGui.Main.BottomHUDList.InCombat.Text), "risk")
    end)
    return ok and result
end

function HopServer()
    if isHopping then
        print("⏳ [HopServer] Đang hop, bỏ qua")
        return
    end
    local now = tick()
    if now - lastHopTime < HOP_COOLDOWN then
        print(string.format("⏳ [HopServer] Cooldown còn %.1fs", HOP_COOLDOWN - (now - lastHopTime)))
        return
    end

    isHopping = true
    lastHopTime = now

    local curJob = game.JobId
    if curJob and curJob ~= "" then
        table.insert(getgenv().ServerBlacklist, curJob)
    end

    print("🔄 [HopServer] Đang tìm server...")

    local server = fetchValidServer()

    if server and server.id then
        print("✅ [HopServer] Tìm thấy server: " .. server.id .. " (" .. tostring(server.playing) .. "/" .. tostring(server.maxPlayers) .. " người)")
        local ok, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id)
        end)
        if not ok then
            print("❌ [HopServer] Lỗi teleport: " .. tostring(err))
            task.wait(2)
            pcall(function() TeleportService:Teleport(game.PlaceId) end)
        end
    else
        print("⚠️ [HopServer] Không tìm thấy server phù hợp → teleport ngẫu nhiên")
        pcall(function() TeleportService:Teleport(game.PlaceId) end)
    end

    task.delay(10, function()
        isHopping = false
        print("🔓 [HopServer] Reset hop lock")
    end)
end
getgenv().HopServer = HopServer

-- =============================================
-- VÒNG LẶP HOP
-- =============================================
spawn(function()
    while task.wait() do
        if getgenv().hopserver then
            stopbypass = true
            starthop = true
        end
    end
end)

spawn(function()
    while task.wait(0.5) do
        if starthop and not isHopping then
            if CheckInComBat() then
                print("⚔️ [HopServer] Đang combat, chờ hết tag...")
                local waitCount = 0
                repeat
                    task.wait(1)
                    waitCount = waitCount + 1
                    pcall(function()
                        if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                            lp.Character.HumanoidRootPart.CFrame = lp.Character.HumanoidRootPart.CFrame * CFrame.new(0, 500, 0)
                        end
                    end)
                    if waitCount >= 30 then
                        print("⏰ [HopServer] Timeout, hop luôn!")
                        break
                    end
                until not CheckInComBat()
            end
            starthop = false
            getgenv().hopserver = false
            HopServer()
        end
    end
end)

local skipping = false
local lastCheckedReset = tick()
local CHECKED_RESET_INTERVAL = 120

function SkipPlayer()
    if skipping then return end
    skipping = true
    local oldTarg = getgenv().targ
    if oldTarg then
        getgenv().killed = oldTarg
        table.insert(getgenv().checked, oldTarg)
        resetDangerForTarget(oldTarg.Name)   -- reset danger blacklist cho target cũ
    end
    getgenv().targ = nil
    if tick() - lastCheckedReset > CHECKED_RESET_INTERVAL then
        getgenv().checked = {}
        lastCheckedReset = tick()
        print("[SkipPlayer] Auto-reset checked list")
    end
    print("Skip → target scan")
    if getgenv().target then getgenv().target() end
    task.spawn(function()
        task.wait(0.5)
        skipping = false
    end)
end
getgenv().SkipPlayer = SkipPlayer

-- Xóa khỏi checked khi player rời game
Players.PlayerRemoving:Connect(function(p)
    for i, v in ipairs(getgenv().checked) do
        if v == p then
            table.remove(getgenv().checked, i)
            break
        end
    end
    resetDangerForTarget(p.Name)
end)

function CheckSafeZone(nitga)
    local safeZones = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("SafeZones")
    if not safeZones then return false end
    for r, v in pairs(safeZones:GetChildren()) do
        if v and v:IsA("Part") then
            if (v.Position - nitga.Position).Magnitude <= 400 then return true end
        end
    end
    return false
end

-- =============================================
-- SAFE HEALTH HELPERS
-- =============================================
local function getHealthPct()
    local hum = lp.Character and lp.Character:FindFirstChild("Humanoid")
    if not hum or hum.MaxHealth <= 0 then return 1 end
    return hum.Health / hum.MaxHealth
end

local function getSafeHealthPct()
    local safeVal = CFG.SafeHealth and CFG.SafeHealth.Health or 0.3
    if safeVal > 1 then
        local hum = lp.Character and lp.Character:FindFirstChild("Humanoid")
        if hum and hum.MaxHealth > 0 then
            return safeVal / hum.MaxHealth
        end
        return 0.3
    end
    return safeVal
end

local function isLowHealth()
    local pct = getHealthPct()
    local safePct = getSafeHealthPct()
    local hum = lp.Character and lp.Character:FindFirstChild("Humanoid")
    return hum and hum.Health > 0 and pct <= safePct
end

-- =============================================
-- DEBUG TARGET
-- =============================================
local DEBUG_TARGET = true   -- bật/tắt log chi tiết

local function debugLog(name, reason)
    if DEBUG_TARGET then
        print(string.format("  ❌ [%s] → %s", name, reason))
    end
end

-- =============================================
-- isValidBountyTarget (có fix team)
-- =============================================
local function isValidBountyTarget(v)
    if not v or v == lp then return false end

    local name = v.Name

    if not v.Character or not v.Character:FindFirstChild("HumanoidRootPart") then
        debugLog(name, "Không có Character/HumanoidRootPart")
        return false
    end
    if not v:FindFirstChild("Data") or not v.Data:FindFirstChild("Level") then
        debugLog(name, "Không có Data/Level")
        return false
    end
    if not v:FindFirstChild("leaderstats") or not v.leaderstats:FindFirstChild("Bounty/Honor") then
        debugLog(name, "Không có leaderstats/Bounty")
        return false
    end

    local bounty = v.leaderstats["Bounty/Honor"].Value
    local minB = CFG.Hunt and CFG.Hunt.Min or 0
    local maxB = CFG.Hunt and CFG.Hunt.Max or 1e9
    if bounty < minB then
        debugLog(name, string.format("Bounty quá thấp: %d < Min(%d)", bounty, minB))
        return false
    end
    if bounty > maxB then
        debugLog(name, string.format("Bounty quá cao: %d > Max(%d)", bounty, maxB))
        return false
    end

    if lp.Data and lp.Data.Level then
        local myLv = tonumber(lp.Data.Level.Value) or 0
        local targLv = v.Data.Level.Value or 0
        if (myLv - 250) >= targLv then
            debugLog(name, string.format("Level quá thấp: target Lv%d, mình Lv%d (gap > 250)", targLv, myLv))
            return false
        end
    end

    -- Team check: cần cùng team để lấy bounty/honor
    local cfgTeam = CFG.Team or "Pirates"
    local targTeam = v.Team and v.Team.Name or ""
    if targTeam == "" then
        debugLog(name, "Target chưa có team")
        return false
    end
    if targTeam ~= cfgTeam then
        debugLog(name, string.format("Team khác phe: target=%s mình=%s", targTeam, cfgTeam))
        return false
    end

    if CFG.Skip and CFG.Skip.Fruit then
        local fruit = v.Data.DevilFruit and v.Data.DevilFruit.Value or ""
        if hasValue(CFG.Skip.FruitList, fruit) then
            debugLog(name, "Fruit bị skip: " .. fruit)
            return false
        end
    end

    if CFG["Skip Race V4"] and v.Character:FindFirstChild("RaceTransformed") then
        debugLog(name, "Đang dùng Race V4")
        return false
    end

    if CFG.Skip and CFG.Skip.SafeZone then
        if CheckSafeZone(v.Character.HumanoidRootPart) then
            debugLog(name, "Trong SafeZone")
            return false
        end
    end

    if CFG.Skip and CFG.Skip.NoHaki then
        local hasHaki = v.Character:FindFirstChild("HasBuso") or v.Character:FindFirstChild("HasKen")
        if not hasHaki then
            debugLog(name, "Không có Haki")
            return false
        end
    end

    if CFG.Skip and CFG.Skip.NoPvP then
        local pvpOn = v:FindFirstChild("Data") and v.Data:FindFirstChild("PvP") and v.Data.PvP.Value == true
        if not pvpOn then
            debugLog(name, "Chưa bật PvP")
            return false
        end
    end

    if getgenv().dangerBlacklist[name] then
        debugLog(name, "Trong DangerBlacklist")
        return false
    end

    if hasValue(getgenv().checked, v) then
        debugLog(name, "Đã trong danh sách checked")
        return false
    end

    local yPos = v.Character.HumanoidRootPart.CFrame.Y
    if yPos > 12000 then
        debugLog(name, string.format("Bay quá cao: Y=%.0f", yPos))
        return false
    end

    return true
end

-- =============================================
-- HÀM TÌM TARGET
-- =============================================
local lastTargetCall = 0
local TARGET_COOLDOWN = 1.5

function target()
    if not startupDone then return end
    local now = tick()
    if now - lastTargetCall < TARGET_COOLDOWN then return end
    lastTargetCall = now

    pcall(function()
        if not lp.Character or not lp.Character:FindFirstChild("HumanoidRootPart") then return end
        local d = math.huge
        local p = nil

        local allPlayers = Players:GetPlayers()

        if DEBUG_TARGET then
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🔍 [Target Scan] Quét " .. #allPlayers .. " player:")
        end

        local totalOthers = 0
        local totalValid = 0

        for _, v in pairs(allPlayers) do
            if v == lp then continue end
            totalOthers = totalOthers + 1

            if isValidBountyTarget(v) then
                totalValid = totalValid + 1
                local dist = (v.Character.HumanoidRootPart.Position - lp.Character.HumanoidRootPart.Position).Magnitude
                if DEBUG_TARGET then
                    print(string.format("  ✅ [%s] → HỢP LỆ | dist=%.0f | bounty=%s | lv=%s",
                        v.Name, dist,
                        tostring(v.leaderstats and v.leaderstats["Bounty/Honor"] and v.leaderstats["Bounty/Honor"].Value or "?"),
                        tostring(v.Data and v.Data.Level and v.Data.Level.Value or "?")))
                end
                if dist < d and not getgenv().hopserver then
                    p = v
                    d = dist
                    if CFG.Chat and #CFG.Chat > 0 then
                        local chatMsg = CFG.Chat[math.random(1, #CFG.Chat)]
                        if chatMsg then
                            pcall(function()
                                ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents")
                                    :FindFirstChild("SayMessageRequest"):FireServer(chatMsg, "All")
                            end)
                        end
                    end
                end
            end
        end

        if DEBUG_TARGET then
            print(string.format("📊 Kết quả: %d/%d player hợp lệ | Chọn: %s",
                totalValid, totalOthers, p and p.Name or "NONE"))
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        end

        if p == nil then
            -- Kiểm tra xem có player nào trong server không
            local anyPlayer = false
            for _, v in pairs(Players:GetPlayers()) do
                if v ~= lp and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                    anyPlayer = true
                    break
                end
            end
            if not anyPlayer then
                print("⚠️ [Target] Không còn player nào trong server → Hop!")
                HopServer()
            else
                -- Có player nhưng không hợp lệ, đợi thêm
                print("⏳ [Target] Có player nhưng không hợp lệ, chờ...")
            end
        else
            print("🎯 Target đã chọn: " .. p.Name)
            getgenv().targ = p
        end
    end)
end
getgenv().target = target

-- =============================================
-- KEN AUTO
-- =============================================
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

-- =============================================
-- LUÂN PHIÊN VŨ KHÍ
-- =============================================
local gunmethod = CFG.Gun and CFG.Gun.GunMode or false
local weaponCycle = {"Melee", "Blox Fruit", "Sword", "Gun"}
local weaponIdx = 1
spawn(function()
    while true do
        local delay = 1
        pcall(function()
            if not gunmethod then
                local wName = weaponCycle[weaponIdx]
                local cfgMap = {["Melee"] = CFG.Melee, ["Blox Fruit"] = CFG.Fruit, ["Sword"] = CFG.Sword, ["Gun"] = CFG.Gun}
                local wcfg = cfgMap[wName]
                if wcfg and wcfg.Enable then
                    getgenv().weapon = wName
                    delay = wcfg.Delay or 1
                end
                weaponIdx = (weaponIdx % #weaponCycle) + 1
            else
                pcall(function() EquipWeapon("Melee") EquipWeapon("Gun") end)
            end
        end)
        task.wait(delay)
    end
end)

-- =============================================
-- PVP + BUSO + V3/V4
-- =============================================
spawn(function()
    while task.wait(3) do
        pcall(function()
            pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("EnablePvp") end)

            if getgenv().targ and getgenv().targ.Character and lp.Character and
               lp.Character:FindFirstChild("HumanoidRootPart") and
               (getgenv().targ.Character.HumanoidRootPart.Position - lp.Character.HumanoidRootPart.Position).Magnitude < 50 then
                buso()

                local alreadyTransformed = lp.Character:FindFirstChild("RaceTransformed") ~= nil
                local myHum = lp.Character:FindFirstChild("Humanoid")

                if CFG.Another and CFG.Another.V3 then
                    local shouldV3 = false
                    if CFG.Another.CustomHealth then
                        if myHum and myHum.MaxHealth > 0 then
                            local hpRatio = myHum.Health / myHum.MaxHealth
                            local threshold = CFG.Another.Health or 0.4
                            if threshold > 1 then threshold = threshold / myHum.MaxHealth end
                            if hpRatio <= threshold then shouldV3 = true end
                        end
                    else
                        shouldV3 = true
                    end
                    if shouldV3 and not alreadyTransformed then
                        down("T", 0.1)
                    end
                end

                if CFG.Another and CFG.Another.V4 then
                    if not alreadyTransformed then down("Y", 0.1) end
                end
            end
        end)
    end
end)

-- =============================================
-- AUTO-ROTATE VỀ PHÍA TARGET
-- =============================================
spawn(function()
    while task.wait() do
        pcall(function()
            if getgenv().targ and getgenv().targ.Character and getgenv().targ.Character:FindFirstChild("HumanoidRootPart") and
               lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") and
               lp.Character:FindFirstChild("Humanoid") and lp.Character.Humanoid.Health > 0 then
                local hrp = lp.Character.HumanoidRootPart
                local targPos = getgenv().targ.Character.HumanoidRootPart.Position
                hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(targPos.X, hrp.Position.Y, targPos.Z))
            end
        end)
    end
end)

-- =============================================
-- NAMECALL HOOK (AIM FIX)
-- =============================================
local oldNamecall
pcall(function()
    local mt = getrawmetatable(game)
    if not mt then return end
    oldNamecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if method == "FireServer" and getgenv().targ and getgenv().targ.Character
           and getgenv().targ.Character:FindFirstChild("HumanoidRootPart") then
            local remoteNames = {
                "UpdateMousePos", "MousePos", "Click", "LeftClick", "RightClick",
                "Activate", "Deactivate", "Skill", "SkillActivate", "Ability",
                "Z", "X", "C", "V", "F", "RemoteEvent", "RemoteFunction"
            }
            local remoteName = tostring(self)
            for _, name in ipairs(remoteNames) do
                if remoteName:find(name) then
                    for i = 1, #args do
                        if type(args[i]) == "Vector3" then
                            args[i] = getgenv().targ.Character.HumanoidRootPart.Position
                        elseif type(args[i]) == "CFrame" then
                            args[i] = CFrame.new(getgenv().targ.Character.HumanoidRootPart.Position)
                                      * (args[i] - args[i].Position)
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

-- =============================================
-- SAFE HEALTH LOOP
-- =============================================
local safehealth = false
spawn(function()
    while task.wait(0.5) do
        if isLowHealth() and not safehealth then
            safehealth = true
            checkDangerAndBlacklist()
            pcall(function()
                if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                    local hrp = lp.Character.HumanoidRootPart
                    local safeY = 12000
                    local curY = hrp.Position.Y
                    if curY < safeY then
                        hrp.CFrame = CFrame.new(hrp.Position.X, safeY + math.random(0, 3000), hrp.Position.Z)
                        print("🚨 [SafeHealth] Máu thấp, bay lên Y=" .. math.floor(hrp.Position.Y))
                    end
                end
            end)
        elseif not isLowHealth() and safehealth then
            safehealth = false
            print("💚 [SafeHealth] Máu đã hồi, tiếp tục hunt!")
        end
    end
end)

-- =============================================
-- AIM SUPPORT
-- =============================================
local aim = false
local CFrameHunt

spawn(function()
    while task.wait() do
        if getgenv().targ and getgenv().targ.Character and
           lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") and
           (getgenv().targ.Character.HumanoidRootPart.Position - lp.Character.HumanoidRootPart.Position).Magnitude < 40 then
            aim = true
            if CFG.Gun and CFG.Gun.Enable and CFG.Gun.GunMode then
                CFrameHunt = CFrame.new(
                    getgenv().targ.Character.HumanoidRootPart.Position
                    + getgenv().targ.Character.HumanoidRootPart.CFrame.LookVector * 2,
                    getgenv().targ.Character.HumanoidRootPart.Position
                )
            else
                CFrameHunt = CFrame.new(
                    getgenv().targ.Character.HumanoidRootPart.Position
                    + getgenv().targ.Character.HumanoidRootPart.CFrame.LookVector * 5,
                    getgenv().targ.Character.HumanoidRootPart.Position
                )
            end
        else
            aim = false
        end
    end
end)

-- =============================================
-- KHOẢNG CÁCH THEO TỪNG LOẠI VŨ KHÍ
-- =============================================
local WEAPON_CONFIG = {
    ["Melee"] = { idealDist = 8, skillRange = 12 },
    ["Sword"] = { idealDist = 10, skillRange = 18 },
    ["Blox Fruit"] = { idealDist = 20, skillRange = 35 },
    ["Gun"] = { idealDist = 30, skillRange = 50 },
}
local DEFAULT_WEAPON_CFG = { idealDist = 10, skillRange = 20 }

local lastSkillTime = 0
local SKILL_INTERVAL = 0.15
local STARTUP_DELAY = 8
local startupDone = false

spawn(function()
    task.wait(STARTUP_DELAY)
    startupDone = true
    print("[Main] Startup delay xong, bat dau hunt!")
    pcall(function() getgenv().target() end)
end)

spawn(function()
    while task.wait(0.05) do
        if not startupDone then continue end

        if not getgenv().targ or not getgenv().targ.Character then
            getgenv().target()
        end

        pcall(function()
            if not (getgenv().targ and getgenv().targ.Character
                    and getgenv().targ.Character:FindFirstChild("HumanoidRootPart")
                    and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")) then return end

            local targHRP = getgenv().targ.Character.HumanoidRootPart
            local myHRP = lp.Character.HumanoidRootPart
            local dist = (targHRP.Position - myHRP.Position).Magnitude
            local weaponType = getgenv().weapon or "Melee"
            local wcfg = WEAPON_CONFIG[weaponType] or DEFAULT_WEAPON_CFG
            local idealDist = wcfg.idealDist
            local skillRange = wcfg.skillRange
            local threshold = 4

            if dist > idealDist + threshold then
                local dir = (targHRP.Position - myHRP.Position).Unit
                to(CFrame.new(targHRP.Position - dir * idealDist))
            elseif dist < idealDist - threshold then
                if weaponType == "Gun" or weaponType == "Blox Fruit" then
                    local dir = (myHRP.Position - targHRP.Position).Unit
                    to(CFrame.new(targHRP.Position + dir * idealDist))
                end
            end

            if dist <= skillRange then
                local now = tick()
                if now - lastSkillTime < SKILL_INTERVAL then return end
                lastSkillTime = now

                if CheckSafeZone(targHRP)
                   or (lp.PlayerGui.Main and lp.PlayerGui.Main["[OLD]SafeZone"]
                       and lp.PlayerGui.Main["[OLD]SafeZone"].Visible)
                   or getgenv().targ.Character.Humanoid.Sit then
                    SkipPlayer()
                    return
                end

                if not gunmethod then
                    pcall(function() EquipWeapon("Summon Sea Beast") end)
                    equip(getgenv().weapon)

                    for _, v in pairs(lp.Character:GetChildren()) do
                        if v:IsA("Tool") then
                            local tip = v.ToolTip
                            local cfg_w = ({
                                ["Melee"] = CFG.Melee,
                                ["Gun"] = CFG.Gun,
                                ["Sword"] = CFG.Sword,
                                ["Blox Fruit"] = CFG.Fruit,
                            })[tip]

                            if cfg_w and cfg_w.Enable then
                                local thisCfg = WEAPON_CONFIG[tip] or DEFAULT_WEAPON_CFG
                                if dist > thisCfg.skillRange then break end

                                local skillGui = lp.PlayerGui.Main.Skills[v.Name]
                                if not skillGui then break end

                                local keys = (tip == "Blox Fruit" or tip == "Melee")
                                             and {"Z", "X", "C", "V", "F"} or {"Z", "X"}
                                for _, key in ipairs(keys) do
                                    local node = skillGui:FindFirstChild(key)
                                    if node and node.Cooldown.AbsoluteSize.X <= 0
                                       and cfg_w[key] and cfg_w[key].Enable then
                                        down(key, cfg_w[key].HoldTime or 0.1)
                                        break
                                    end
                                end
                            end
                        end
                    end
                else
                    if dist <= WEAPON_CONFIG["Gun"].skillRange and CFG.Melee and CFG.Melee.Enable then
                        for _, key in ipairs({"Z", "X", "C", "V"}) do
                            if CFG.Melee[key] and CFG.Melee[key].Enable then
                                down(key, CFG.Melee[key].HoldTime or 0.1)
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
-- NOTIFICATION SKIP LOOP
-- =============================================
spawn(function()
    while task.wait(0.5) do
        pcall(function()
            for _, v in pairs(lp.PlayerGui:FindFirstChild("Notifications") or {}) do
                if v:IsA("TextLabel") then
                    local text = string.lower(v.Text)
                    for _, keyword in pairs({
                        "nguoi choi vua tu tran", "người chơi vừa tử trận",
                        "player died recently", "you can't attack them yet",
                        "died recently", "can't attack them",
                        "cannot attack this player", "cannot attack", "unable to attack",
                    }) do
                        if string.find(text, keyword, 1, true) then
                            print("🔄 AUTO-SKIP: " .. keyword)
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

-- =============================================
-- ESP SYSTEM
-- =============================================
local ESP = {}
local ESP_ENABLED = true
local Camera = Workspace.CurrentCamera

local function getESPColor(v)
    if v == lp then return Color3.fromRGB(100, 200, 255) end
    local myConfigTeam = (getgenv().Setting and getgenv().Setting.Team) or "Pirates"
    if v.Team and v.Team.Name == myConfigTeam then
        return Color3.fromRGB(80, 220, 80)
    end
    if getgenv().targ and v == getgenv().targ then
        return Color3.fromRGB(255, 50, 50)
    end
    return Color3.fromRGB(255, 180, 30)
end

local function createESP(v)
    if not v or not v.Character then return end
    if ESP[v.Name] then return end

    local hrp = v.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "DX_ESP_" .. v.Name
    bb.Adornee = hrp
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, 200, 0, 90)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.MaxDistance = 2000
    bb.ResetOnSpawn = false
    bb.Parent = CoreGui

    local frame = Instance.new("Frame", bb)
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.Position = UDim2.new(0, 0, 0, 0)

    local function makeLabel(yPos, fontSize)
        local lbl = Instance.new("TextLabel", frame)
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(1, 0, 0, fontSize + 4)
        lbl.Position = UDim2.new(0, 0, 0, yPos)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = fontSize
        lbl.TextStrokeTransparency = 0.4
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.TextXAlignment = Enum.TextXAlignment.Center
        return lbl
    end

    local nameLabel = makeLabel(0, 15)
    local hpLabel = makeLabel(18, 13)
    local lvlLabel = makeLabel(34, 13)
    local distLabel = makeLabel(50, 12)
    local bountyLabel = makeLabel(64, 11)

    ESP[v.Name] = {
        bb = bb,
        nameLabel = nameLabel,
        hpLabel = hpLabel,
        lvlLabel = lvlLabel,
        distLabel = distLabel,
        bountyLabel = bountyLabel,
        player = v,
    }
end

local function removeESP(name)
    if ESP[name] then
        pcall(function() ESP[name].bb:Destroy() end)
        ESP[name] = nil
    end
end

local function clearAllESP()
    for name, data in pairs(ESP) do
        pcall(function() data.bb:Destroy() end)
        ESP[name] = nil
    end
end

Players.PlayerAdded:Connect(function(v)
    task.wait(2)
    pcall(function() createESP(v) end)
    v.CharacterAdded:Connect(function()
        task.wait(1)
        removeESP(v.Name)
        pcall(function() createESP(v) end)
    end)
    v.CharacterRemoving:Connect(function()
        removeESP(v.Name)
    end)
end)

Players.PlayerRemoving:Connect(function(v)
    removeESP(v.Name)
end)

task.spawn(function()
    task.wait(2)
    for _, v in pairs(Players:GetPlayers()) do
        pcall(function() createESP(v) end)
    end
end)

for _, v in pairs(Players:GetPlayers()) do
    v.CharacterAdded:Connect(function()
        task.wait(1)
        removeESP(v.Name)
        pcall(function() createESP(v) end)
    end)
    v.CharacterRemoving:Connect(function()
        removeESP(v.Name)
    end)
end

local function hpBar(current, max)
    if max <= 0 then return "[???]" end
    local pct = math.clamp(current / max, 0, 1)
    local bars = math.floor(pct * 10)
    return "[" .. string.rep("|", bars) .. string.rep(" ", 10 - bars) .. "]"
        .. string.format(" %.0f%%", pct * 100)
end

local function formatNum(n)
    if n >= 1000000 then return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then return string.format("%.1fK", n / 1000)
    else return tostring(n) end
end

local ESPBtn = Instance.new("TextButton", MainFrame)
ESPBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ESPBtn.BackgroundTransparency = 0.9
ESPBtn.Position = UDim2.new(0.07, 0, 0.68, 0)
ESPBtn.Size = UDim2.new(0.86, 0, 0, 26)
ESPBtn.Font = Enum.Font.RobotoMono
ESPBtn.Text = "ESP: ON"
ESPBtn.TextColor3 = Color3.fromRGB(80, 220, 80)
ESPBtn.TextSize = 15
Instance.new("UICorner", ESPBtn).CornerRadius = UDim.new(0, 6)
local espStroke = Instance.new("UIStroke", ESPBtn)
espStroke.Color = Color3.fromRGB(80, 220, 80)
espStroke.Thickness = 1.5

ESPBtn.MouseButton1Click:Connect(function()
    ESP_ENABLED = not ESP_ENABLED
    if ESP_ENABLED then
        ESPBtn.Text = "ESP: ON"
        ESPBtn.TextColor3 = Color3.fromRGB(80, 220, 80)
        espStroke.Color = Color3.fromRGB(80, 220, 80)
    else
        ESPBtn.Text = "ESP: OFF"
        ESPBtn.TextColor3 = Color3.fromRGB(200, 60, 60)
        espStroke.Color = Color3.fromRGB(200, 60, 60)
        for _, data in pairs(ESP) do
            pcall(function() data.bb.Enabled = false end)
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if not ESP_ENABLED then return end

    local myChar = lp.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for _, v in pairs(Players:GetPlayers()) do
        pcall(function()
            local data = ESP[v.Name]
            if not data then
                if v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                    createESP(v)
                    data = ESP[v.Name]
                end
                if not data then return end
            end

            local char = v.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")

            if not hrp or not hum then
                data.bb.Enabled = false
                return
            end

            if data.bb.Adornee ~= hrp then
                data.bb.Adornee = hrp
            end

            data.bb.Enabled = true

            local color = getESPColor(v)

            local dist = 0
            if myHRP then
                dist = math.floor((hrp.Position - myHRP.Position).Magnitude)
            end

            local hp = math.floor(hum.Health)
            local maxHp = math.floor(hum.MaxHealth)
            local level = v:FindFirstChild("Data") and v.Data:FindFirstChild("Level")
                          and v.Data.Level.Value or "?"
            local bounty = v:FindFirstChild("leaderstats")
                           and v.leaderstats:FindFirstChild("Bounty/Honor")
                           and v.leaderstats["Bounty/Honor"].Value or 0

            local teamTag = ""
            local myConfigTeam2 = (getgenv().Setting and getgenv().Setting.Team) or "Pirates"
            if v.Team and v.Team.Name == myConfigTeam2 then
                if getgenv().targ and v == getgenv().targ then
                    teamTag = " [TARGET]"
                else
                    teamTag = " [HUNTABLE]"
                end
            elseif v == lp then
                teamTag = " [YOU]"
            end
            if getgenv().targ and v == getgenv().targ and teamTag ~= " [TARGET]" then
                teamTag = " [TARGET]"
            end

            local hpPct = maxHp > 0 and (hp / maxHp) or 0
            local hpColor
            if hpPct > 0.6 then
                hpColor = Color3.fromRGB(80, 220, 80)
            elseif hpPct > 0.3 then
                hpColor = Color3.fromRGB(255, 200, 50)
            else
                hpColor = Color3.fromRGB(255, 60, 60)
            end

            data.nameLabel.Text = v.Name .. teamTag
            data.nameLabel.TextColor3 = color

            data.hpLabel.Text = hpBar(hp, maxHp) .. "  " .. hp .. "/" .. maxHp
            data.hpLabel.TextColor3 = hpColor

            data.lvlLabel.Text = "Lv. " .. tostring(level)
            data.lvlLabel.TextColor3 = Color3.fromRGB(200, 160, 255)

            data.distLabel.Text = "📍 " .. tostring(dist) .. " studs"
            data.distLabel.TextColor3 = dist < 50
                and Color3.fromRGB(255, 80, 80)
                or Color3.fromRGB(200, 200, 200)

            data.bountyLabel.Text = "💰 " .. formatNum(bounty)
            data.bountyLabel.TextColor3 = Color3.fromRGB(255, 210, 60)
        end)
    end

    for name, data in pairs(ESP) do
        if not Players:FindFirstChild(name) then
            removeESP(name)
        end
    end
end)

-- =============================================
-- WEBHOOK
-- =============================================
function sendKillWebhook(targetName, bountyEarned, currentBounty)
    if not CFG.Webhook or not CFG.Webhook.Enable or CFG.Webhook.Url == "" then return end
    local url = CFG.Webhook.Url
    local p = lp
    local function formatBounty(b)
        if b >= 1000000 then return string.format("%.1fM", b / 1000000)
        elseif b >= 1000 then return string.format("%.1fK", b / 1000)
        else return tostring(b) end
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
                {["name"] = "Level", ["value"] = "```" .. (p.Data and p.Data.Level and p.Data.Level.Value or "?") .. "```", ["inline"] = true},
                {["name"] = "Time", ["value"] = "```" .. os.date("%H:%M:%S %d/%m/%Y") .. "```", ["inline"] = true}
            },
            ["footer"] = {["text"] = "By Lo Hub Emorima"},
            ["thumbnail"] = {["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. p.UserId .. "&width=420&height=420&format=png"}
        }}
    }
    local jsonData = HttpService:JSONEncode(data)
    local success, res = sendRequest(url, "POST", {["Content-Type"] = "application/json"}, jsonData)
    if success then
        print("✅ Webhook sent: " .. targetName)
    else
        print("❌ Webhook error: " .. tostring(res))
    end
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
                        if bountyEarned <= 0 then bountyEarned = math.random(1000, 5000) end
                        sendKillWebhook(targetPlayer.Name, bountyEarned, currentBounty)
                        lastKilledPlayer = targetPlayer.Name
                        print("🎯 ELIMINATED: " .. targetPlayer.Name)
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
    if CFG.Webhook and CFG.Webhook.Enable and CFG.Webhook.Url ~= "" then
        local currentBounty = lp.leaderstats["Bounty/Honor"] and lp.leaderstats["Bounty/Honor"].Value or 0
        local data = {
            ["embeds"] = {{
                ["title"] = "notify",
                ["description"] = "Bounty Ez",
                ["color"] = 16753920,
                ["fields"] = {
                    {["name"] = "User Name", ["value"] = "```" .. lp.Name .. "```", ["inline"] = true},
                    {["name"] = "Level", ["value"] = "```" .. (lp.Data and lp.Data.Level and lp.Data.Level.Value or "?") .. "```", ["inline"] = true},
                    {["name"] = "Current Bounty", ["value"] = "```" .. tostring(currentBounty) .. "```", ["inline"] = true},
                    {["name"] = "Check Team", ["value"] = "```" .. (CFG.Team or "Unknown") .. "```", ["inline"] = true}
                },
                ["footer"] = {["text"] = "Auto Bounty By Lo Hub " .. os.date("%H:%M %d/%m/%Y")}
            }}
        }
        local jsonData = HttpService:JSONEncode(data)
        sendRequest(CFG.Webhook.Url, "POST", {["Content-Type"] = "application/json"}, jsonData)
        print("✅ Startup webhook sent")
    end
end)

-- =============================================
-- DỌN DẸP KHI TẮT SCRIPT (nếu có hàm)
-- =============================================
getgenv().cleanup = function()
    clearAllESP()
    if ScreenGui then ScreenGui:Destroy() end
    print("🧹 Đã dọn dẹp tài nguyên")
end

print("✅ Script đã tải xong và sẵn sàng!")
