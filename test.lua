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
local player = LocalPlayer
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

-- Đợi character
local character = player.Character or player.CharacterAdded:Wait()

-- =============================================
-- BIẾN TOÀN CỤC
-- =============================================
getgenv().targ = nil 
getgenv().checked = {}
getgenv().killed = nil
getgenv().hopserver = false
getgenv().dangerCount = {}
getgenv().dangerBlacklist = {}
getgenv().ServerBlacklist = getgenv().ServerBlacklist or {}

-- =============================================
-- GUI ĐƠN GIẢN (DARKNESS X STYLE)
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

-- Khung chính
local MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MainFrame.BackgroundTransparency = 0.3
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
MainFrame.Size = UDim2.new(0, 400, 0, 250)
MainFrame.Visible = true
MainFrame.ClipsDescendants = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 6)

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

local Title = CreateText("DARKNESS X • AUTO BOUNTY (M1 ONLY)", 15)
Title.TextSize = 20
local TargetLbl = CreateText("Target: Searching...", 70)
local DistLbl = CreateText("Distance: 0m", 110)
local StatusLbl = CreateText("Status: Idle", 150)

-- Buttons
local function CreateBtn(text, xPos)
    local btn = Instance.new("TextButton", MainFrame)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundTransparency = 0.9
    btn.Position = UDim2.new(xPos, 0, 0.8, 0)
    btn.Size = UDim2.new(0.4, 0, 0, 40)
    btn.Font = Enum.Font.RobotoMono
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 16
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local SkipBtn = CreateBtn("SKIP PLAYER", 0.07)
local HopBtn = CreateBtn("HOP SERVER", 0.53)

-- Sự kiện nút
HopBtn.MouseButton1Click:Connect(function()
    HopBtn.Text = "HOPPING..."
    getgenv().hopserver = true
    HopServer()
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

-- Update loop
RunService.RenderStepped:Connect(function()
    pcall(function()
        local targ = getgenv().targ
        if targ and targ.Character and targ.Character:FindFirstChild("HumanoidRootPart") then
            TargetLbl.Text = "Target: " .. targ.Name
            local myChar = player.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local dist = (myRoot.Position - targ.Character.HumanoidRootPart.Position).Magnitude
                DistLbl.Text = "Distance: " .. math.floor(dist) .. " m"
                StatusLbl.Text = "Status: Attacking with M1"
            end
        else
            TargetLbl.Text = "Target: Searching..."
            DistLbl.Text = "Distance: 0 m"
            StatusLbl.Text = "Status: Idle"
        end
    end)
end)

-- =============================================
-- WORLD / ISLAND SETUP
-- =============================================
local placeId = game.PlaceId
local worldMap = {
    [2753915549] = "World1",
    [4442272183] = "World2",
    [7449423635] = "World3",
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
        ["Castle On The Sea"] = CFrame.new(-5085.23681640625 + 50, 316.5072021484375, -3156.202880859375),
        ["Great Tree"] = CFrame.new(2681.2736816406, 1682.8092041016, -7190.9853515625),
    }
elseif World2 then
    distbyp = 3500
    island = {
        a = CFrame.new(753.14288330078, 408.23559570313, -5274.6147460938),
        b = CFrame.new(-5622.033203125, 492.19604492188, -781.78552246094),
    }
elseif World1 then
    distbyp = 1500
    island = {
        a = CFrame.new(979.79895019531, 16.516613006592, 1429.0466308594),
        b = CFrame.new(-2566.4296875, 6.8556680679321, 2045.2561035156),
    }
end

-- =============================================
-- HÀM HỖ TRỢ
-- =============================================
function bypass(Pos)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local dist = math.huge
    local is = nil
    for i, v in pairs(island) do
        if (Pos.Position - v.Position).magnitude < dist then
            is = v
            dist = (Pos.Position - v.Position).magnitude
        end
    end
    if is == nil then return end
    
    if player:DistanceFromCharacter(Pos.Position) > distbyp then
        repeat
            task.wait()
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                player.Character.HumanoidRootPart.CFrame = is
            else
                break
            end
        until player.Character and player.Character.PrimaryPart and player.Character.PrimaryPart.CFrame == is
        task.wait(0.1)
    end
end

function to(Pos)
    pcall(function()
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and 
           player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            local hrp = player.Character.HumanoidRootPart
            local Distance = (Pos.Position - hrp.Position).Magnitude

            if Distance > 3000 then
                bypass(Pos)
            else
                hrp.CFrame = Pos
            end
        end
    end)
end

function equipFruit()
    -- Tự động trang bị trái Blox Fruit
    pcall(function()
        for _, item in pairs(player.Backpack:GetChildren()) do
            if item:IsA("Tool") and item.ToolTip == "Blox Fruit" then
                item.Parent = player.Character
                return true
            end
        end
    end)
end

-- M1 Attack với trái Blox Fruit
local attacking = false
function startM1Attack()
    if attacking then return end
    attacking = true
    
    spawn(function()
        while attacking and getgenv().targ and getgenv().targ.Character do
            pcall(function()
                -- Đảm bảo đang cầm trái Blox Fruit
                equipFruit()
                
                -- Click M1 để đánh thường
                VirtualUser:CaptureController()
                VirtualUser:ClickButton1(Vector2.new())
                
                -- Delay giữa các đòn đánh (tránh spam)
                task.wait(0.2)
            end)
        end
        attacking = false
    end)
end

function stopM1Attack()
    attacking = false
end

function buso()
    if player.Character and not player.Character:FindFirstChild("HasBuso") then
        pcall(function() ReplicatedStorage.Remotes.CommF_:InvokeServer("Buso") end)
    end
end

-- =============================================
-- TÌM TARGET
-- =============================================
local function isValidBountyTarget(v)
    if not v or v == player then return false end
    if not v.Character or not v.Character:FindFirstChild("HumanoidRootPart") then return false end
    if not v:FindFirstChild("leaderstats") or not v.leaderstats:FindFirstChild("Bounty/Honor") then return false end

    local bounty = v.leaderstats["Bounty/Honor"].Value
    if bounty < (CFG.Hunt and CFG.Hunt.Min or 0) or bounty > (CFG.Hunt and CFG.Hunt.Max or 1e9) then return false end

    if getgenv().dangerBlacklist[v.Name] then return false end
    if table.find(getgenv().checked, v) then return false end

    return true
end

function target()
    pcall(function()
        if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
        
        local d = math.huge
        local p = nil
        getgenv().targ = nil

        for _, v in pairs(Players:GetPlayers()) do
            if isValidBountyTarget(v) then
                local dist = (v.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
                if dist < d and not getgenv().hopserver then
                    p = v
                    d = dist
                end
            end
        end

        if p == nil then
            HopServer()
        else
            print("🎯 Target: " .. p.Name)
        end
        getgenv().targ = p
    end)
end
getgenv().target = target

-- =============================================
-- HOP SERVER
-- =============================================
function HopServer()
    local S = game.JobId
    table.insert(getgenv().ServerBlacklist, S)
    local success = pcall(function()
        local response = HttpService:JSONDecode(game:HttpGet(string.format("https://games.roblox.com/v1/games/%d/servers/Public?limit=100", game.PlaceId)))
        local server = nil
        for _, data in ipairs(response.data) do
            if data.playing and data.maxPlayers and data.playing < data.maxPlayers and data.playing > 5 then
                local blacklisted = false
                for _, id in ipairs(getgenv().ServerBlacklist) do
                    if id == data.id then blacklisted = true break end
                end
                if not blacklisted then
                    server = data
                    break
                end
            end
        end
        if server and server.id then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id)
        else
            TeleportService:Teleport(game.PlaceId)
        end
    end)
    if not success then
        TeleportService:Teleport(game.PlaceId)
    end
end
getgenv().HopServer = HopServer

-- =============================================
-- SKIP PLAYER
-- =============================================
local skipping = false
function SkipPlayer()
    if skipping then return end
    skipping = true
    stopM1Attack()
    if getgenv().targ then
        table.insert(getgenv().checked, getgenv().targ)
    end
    getgenv().targ = nil
    task.spawn(function()
        task.wait(0.5)
        skipping = false
    end)
end
getgenv().SkipPlayer = SkipPlayer

-- =============================================
-- MAIN LOOP - CHỈ DÙNG M1 CỦA TRÁI BLOX
-- =============================================
spawn(function()
    while task.wait() do
        if not getgenv().targ or not getgenv().targ.Character then
            getgenv().target()
        end
        
        pcall(function()
            if getgenv().targ and getgenv().targ.Character and getgenv().targ.Character:FindFirstChild("HumanoidRootPart") and
               player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                
                local dist = (getgenv().targ.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
                
                -- Bật buso khi gần target
                if dist < 30 then
                    buso()
                end
                
                -- Di chuyển đến gần target
                if dist > 8 then
                    local targetPos = getgenv().targ.Character.HumanoidRootPart.Position
                    to(CFrame.new(targetPos))
                    stopM1Attack()
                else
                    -- Khi đã rất gần, bắt đầu M1 attack
                    startM1Attack()
                end
                
                -- Tự động xoay mặt về target
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local hrp = player.Character.HumanoidRootPart
                    local targPos = getgenv().targ.Character.HumanoidRootPart.Position
                    hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(targPos.X, hrp.Position.Y, targPos.Z))
                end
            else
                stopM1Attack()
            end
        end)
    end
end)

-- Vòng lặp chống xuyên tường
spawn(function()
    while task.wait() do
        pcall(function()
            if player.Character then
                for _, v in pairs(player.Character:GetChildren()) do
                    if v:IsA("BasePart") then
                        v.CanCollide = false
                    end
                end
            end
        end)
    end
end)

print("✅ Auto Bounty M1 Only loaded successfully!")
