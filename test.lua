-- =============================================
-- AUTO BOUNTY HUNTER - DARKNESS X STYLE
-- =============================================

if not getgenv then return warn("Executor không hỗ trợ getgenv!") end

-- =============================================
-- SERVICES
-- =============================================
local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")
local TweenService    = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService     = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui         = game:GetService("CoreGui")
local Workspace       = game:GetService("Workspace")

local player = Players.LocalPlayer
local CFG    = getgenv().Setting or {}
local CommF_ = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

-- Đợi character
repeat task.wait() until player.Character and player.Character:FindFirstChild("HumanoidRootPart")

-- =============================================
-- KIỂM TRA WORLD
-- =============================================
local validPlaces = {
    [2753915549]=true,[85211729168715]=true,
    [4442272183]=true,[79091703265657]=true,
    [7449423635]=true,[100117331123089]=true,
}
if not validPlaces[game.PlaceId] then
    player:Kick("❌ Not Support Game ❌")
    return
end

-- =============================================
-- BIẾN TOÀN CỤC
-- =============================================
local safehealth   = false
local m1Enabled    = true
local fruitBlocked = false
local currentTween = nil

getgenv().targ         = nil
getgenv().checked      = {}
getgenv().hopserver    = false
getgenv().dangerCount  = {}
getgenv().dangerBlacklist = {}
getgenv().ServerBlacklist = {}
getgenv().fruitBlocked = false

-- Set team: retry cho đến khi join được
task.spawn(function()
    local targetTeam = CFG.Team or "Pirates"
    local joined = false
    for i = 1, 20 do -- thử tối đa 20 lần (10 giây)
        pcall(function()
            CommF_:InvokeServer("SetTeam", targetTeam)
        end)
        task.wait(0.5)
        -- Kiểm tra đã vào đúng team chưa
        pcall(function()
            if player.Team and string.lower(player.Team.Name):find(string.lower(targetTeam):sub(1,4)) then
                joined = true
                print("✅ Đã join team: " .. player.Team.Name)
            end
        end)
        if joined then break end
    end
    if not joined then
        -- Thử lần cuối
        pcall(function() CommF_:InvokeServer("SetTeam", targetTeam) end)
        print("⚠️ SetTeam xong (chưa verify)")
    end
end)

-- =============================================
-- LOAD FASTATTACK
-- =============================================
local FastAttack = nil
pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/jayetcixgaming2010/UI/refs/heads/main/UI.lua"))()
    FastAttack = getgenv().rz_FastAttack
    if FastAttack then
        FastAttack.GetClosestEnemy = function(self)
            local t = getgenv().targ
            if t and t.Character and t.Character:FindFirstChild("HumanoidRootPart") then
                return t.Character.HumanoidRootPart
            end
        end
    end
end)

-- =============================================
-- DANH SÁCH FRUIT KHÔNG CÓ M1
-- =============================================
local NO_M1_FRUITS = {
    Smoke=true, Sand=true, Dark=true, Light=true,
    Magma=true, Ice=true, Diamond=true, Rumble=true,
    Gravity=true, Flame=true, Quake=true, Blizzard=true,
    Spider=true,
}

-- =============================================
-- TIỆN ÍCH
-- =============================================
local function isAlive(char)
    return char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0
end

local function getRoot(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function hasValue(tbl, val)
    for _, v in ipairs(tbl) do if v == val then return true end end
    return false
end

-- =============================================
-- GUI THÔNG BÁO FRUIT BLOCKED (góc phải dưới)
-- =============================================
pcall(function()
    if CoreGui:FindFirstChild("M1FruitNotif") then
        CoreGui:FindFirstChild("M1FruitNotif"):Destroy()
    end
end)

local notifGui = Instance.new("ScreenGui")
notifGui.Name = "M1FruitNotif"
notifGui.ResetOnSpawn = false
notifGui.Parent = CoreGui

local notifFrame = Instance.new("Frame", notifGui)
notifFrame.Size = UDim2.new(0, 340, 0, 65)
notifFrame.Position = UDim2.new(1, -355, 1, -85)
notifFrame.BackgroundColor3 = Color3.fromRGB(15, 5, 5)
notifFrame.BackgroundTransparency = 0.05
notifFrame.BorderSizePixel = 0
notifFrame.Visible = false
Instance.new("UICorner", notifFrame).CornerRadius = UDim.new(0, 10)
local nStroke = Instance.new("UIStroke", notifFrame)
nStroke.Color = Color3.fromRGB(255, 50, 50)
nStroke.Thickness = 2

local nIcon = Instance.new("TextLabel", notifFrame)
nIcon.Size = UDim2.new(0, 45, 1, 0)
nIcon.Position = UDim2.new(0, 6, 0, 0)
nIcon.BackgroundTransparency = 1
nIcon.Text = "🚫"
nIcon.TextSize = 28
nIcon.Font = Enum.Font.RobotoMono
nIcon.TextColor3 = Color3.fromRGB(255, 255, 255)

local nTitle = Instance.new("TextLabel", notifFrame)
nTitle.Size = UDim2.new(1, -58, 0, 28)
nTitle.Position = UDim2.new(0, 55, 0, 6)
nTitle.BackgroundTransparency = 1
nTitle.Text = "⛔ Fruit Không Hỗ Trợ M1"
nTitle.TextSize = 14
nTitle.Font = Enum.Font.RobotoMono
nTitle.TextColor3 = Color3.fromRGB(255, 70, 70)
nTitle.TextXAlignment = Enum.TextXAlignment.Left

local nSub = Instance.new("TextLabel", notifFrame)
nSub.Size = UDim2.new(1, -58, 0, 22)
nSub.Position = UDim2.new(0, 55, 0, 36)
nSub.BackgroundTransparency = 1
nSub.Text = "Auto Bounty đã dừng"
nSub.TextSize = 12
nSub.Font = Enum.Font.RobotoMono
nSub.TextColor3 = Color3.fromRGB(200, 160, 160)
nSub.TextXAlignment = Enum.TextXAlignment.Left

local function showFruitNotif(name)
    nSub.Text = "[ " .. name .. " ] — Elemental, không dùng M1 được"
    notifFrame.Visible = true
end

local function hideFruitNotif()
    notifFrame.Visible = false
end

-- =============================================
-- CHECK FRUIT KHI JOIN TEAM
-- =============================================
local function checkFruit()
    task.spawn(function()
        task.wait(2)
        local fname = nil
        pcall(function()
            if player:FindFirstChild("Data") and player.Data:FindFirstChild("DevilFruit") then
                fname = player.Data.DevilFruit.Value
            end
        end)
        if not fname or fname == "" then
            for _, t in pairs(player.Character and player.Character:GetChildren() or {}) do
                if t:IsA("Tool") and t.ToolTip == "Blox Fruit" then fname = t.Name break end
            end
        end
        if not fname or fname == "" then
            for _, t in pairs(player.Backpack:GetChildren()) do
                if t:IsA("Tool") and t.ToolTip == "Blox Fruit" then fname = t.Name break end
            end
        end

        if fname and fname ~= "" and NO_M1_FRUITS[fname] then
            fruitBlocked = true
            getgenv().fruitBlocked = true
            showFruitNotif(fname)
        else
            fruitBlocked = false
            getgenv().fruitBlocked = false
            hideFruitNotif()
        end
    end)
end

player:GetPropertyChangedSignal("Team"):Connect(function()
    local t = player.Team
    if t then
        local n = string.lower(t.Name)
        if n:find("pirate") or n:find("marine") then
            checkFruit()
        end
    end
end)

task.delay(3, checkFruit)

-- Giữ team: tự join lại nếu bị kick ra khỏi team
task.spawn(function()
    local targetTeam = CFG.Team or "Pirates"
    while task.wait(10) do
        pcall(function()
            local currentTeam = player.Team and player.Team.Name or ""
            -- Nếu chưa có team hoặc team là Spectator/None thì join lại
            if currentTeam == "" or string.lower(currentTeam):find("spec") or string.lower(currentTeam):find("none") then
                CommF_:InvokeServer("SetTeam", targetTeam)
                print("🔄 Re-join team: " .. targetTeam)
            end
        end)
    end
end)

-- =============================================
-- GUI CHÍNH (DARKNESS X STYLE)
-- =============================================
pcall(function()
    if CoreGui:FindFirstChild("DarknessX_AutoBounty") then
        CoreGui:FindFirstChild("DarknessX_AutoBounty"):Destroy()
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DarknessX_AutoBounty"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui

local ToggleBtn = Instance.new("ImageButton", ScreenGui)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(10,10,10)
ToggleBtn.BackgroundTransparency = 0.2
ToggleBtn.Position = UDim2.new(0,30,0,30)
ToggleBtn.Size = UDim2.new(0,45,0,45)
ToggleBtn.Image = "rbxassetid://101138166721164"
ToggleBtn.Draggable = true
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0,4)
local tgStroke = Instance.new("UIStroke", ToggleBtn)
tgStroke.Color = Color3.fromRGB(255,255,255)
tgStroke.Thickness = 2

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.BackgroundColor3 = Color3.fromRGB(0,0,0)
MainFrame.BackgroundTransparency = 0.3
MainFrame.Position = UDim2.new(0.5,-200,0.5,-150)
MainFrame.Size = UDim2.new(0,400,0,300)
MainFrame.ClipsDescendants = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0,6)
local mfStroke = Instance.new("UIStroke", MainFrame)
mfStroke.Color = Color3.fromRGB(255,255,255)
mfStroke.Thickness = 2

local BgImg = Instance.new("ImageLabel", MainFrame)
BgImg.Size = UDim2.new(1,0,1,0)
BgImg.BackgroundTransparency = 1
BgImg.Image = "rbxassetid://101138166721164"
BgImg.ImageTransparency = 0.6
BgImg.ScaleType = Enum.ScaleType.Slice

-- Drag MainFrame
do
    local drag, dInput, dStart, sPos
    MainFrame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag=true dStart=i.Position sPos=MainFrame.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then drag=false end end)
        end
    end)
    MainFrame.InputChanged:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then dInput=i end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if i==dInput and drag then
            local d=i.Position-dStart
            MainFrame.Position=UDim2.new(sPos.X.Scale,sPos.X.Offset+d.X,sPos.Y.Scale,sPos.Y.Offset+d.Y)
        end
    end)
end

local function MkLabel(txt, y)
    local l = Instance.new("TextLabel", MainFrame)
    l.BackgroundTransparency=1
    l.Position=UDim2.new(0,25,0,y)
    l.Size=UDim2.new(1,-50,0,30)
    l.Font=Enum.Font.RobotoMono
    l.Text=txt
    l.TextColor3=Color3.fromRGB(255,255,255)
    l.TextSize=18
    l.TextXAlignment=Enum.TextXAlignment.Left
    return l
end

local Title     = MkLabel("DARKNESS X • AUTO BOUNTY", 15)
Title.TextSize  = 22
local BountyLbl = MkLabel("Bounty Earn: 0", 60)
local ExecLbl   = MkLabel("Executor: ...", 95)
local TimeLbl   = MkLabel("Time: 00:00:00", 130)
local TargetLbl = MkLabel("Target: Searching...", 175)
local DistLbl   = MkLabel("Distance: 0 m", 210)

local function MkBtn(txt, xScale)
    local b = Instance.new("TextButton", MainFrame)
    b.BackgroundColor3=Color3.fromRGB(255,255,255)
    b.BackgroundTransparency=0.9
    b.Position=UDim2.new(xScale,0,0.83,0)
    b.Size=UDim2.new(0.4,0,0,40)
    b.Font=Enum.Font.RobotoMono
    b.Text=txt
    b.TextColor3=Color3.fromRGB(255,255,255)
    b.TextSize=16
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    local s=Instance.new("UIStroke",b)
    s.Color=Color3.fromRGB(255,255,255) s.Thickness=1.5
    return b
end

local SkipBtn = MkBtn("SKIP PLAYER", 0.07)
local HopBtn  = MkBtn("HOP SERVER",  0.53)

ToggleBtn.MouseButton1Click:Connect(function() MainFrame.Visible = not MainFrame.Visible end)
SkipBtn.MouseButton1Click:Connect(function()
    SkipBtn.Text = "SKIPPING..."
    if getgenv().SkipPlayer then getgenv().SkipPlayer() end
    task.delay(0.5, function() SkipBtn.Text = "SKIP PLAYER" end)
end)

local autoHopActive = false
HopBtn.MouseButton1Click:Connect(function()
    autoHopActive = not autoHopActive
    if autoHopActive then
        HopBtn.Text = "STOP HOP"
        getgenv().hopserver = true
        task.spawn(function()
            while autoHopActive do
                pcall(function() if getgenv().HopServer then getgenv().HopServer() end end)
                task.wait(5)
            end
        end)
    else
        HopBtn.Text = "HOP SERVER"
        getgenv().hopserver = false
    end
end)

-- Update UI
local startTime = os.time()
local initBounty = nil
task.delay(3, function()
    pcall(function()
        local ls = player:FindFirstChild("leaderstats")
        if ls and ls:FindFirstChild("Bounty/Honor") then
            initBounty = ls["Bounty/Honor"].Value
        end
    end)
    pcall(function()
        ExecLbl.Text = "Executor: " .. ((identifyexecutor and identifyexecutor()) or "Unknown")
    end)
end)

RunService.RenderStepped:Connect(function()
    pcall(function()
        local d = os.time()-startTime
        TimeLbl.Text = string.format("Time: %02d:%02d:%02d", math.floor(d/3600), math.floor((d%3600)/60), d%60)
        local ls = player:FindFirstChild("leaderstats")
        if ls and ls:FindFirstChild("Bounty/Honor") and initBounty then
            BountyLbl.Text = "Bounty Earn: " .. tostring(ls["Bounty/Honor"].Value - initBounty)
        end
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
-- AUTO CONFIRM TELEPORT
-- =============================================
task.spawn(function()
    local function autoConfirm(gui)
        if not gui then return end
        for _, btn in pairs(gui:GetDescendants()) do
            if (btn:IsA("TextButton") or btn:IsA("ImageButton")) then
                local t = string.lower(btn.Text or "")
                if t=="ok" or t=="yes" or t=="teleport" or t=="confirm" or t=="leave" then
                    pcall(function() btn:activate() end)
                end
            end
        end
    end
    local prompt = CoreGui:FindFirstChild("RobloxPromptGui")
    if prompt then
        local overlay = prompt:FindFirstChild("promptOverlay")
        if overlay then
            overlay.ChildAdded:Connect(function() task.wait(0.1) autoConfirm(overlay) end)
        end
    end
    while task.wait(0.5) do
        pcall(function() autoConfirm(CoreGui) end)
        pcall(function() autoConfirm(player.PlayerGui) end)
    end
end)

-- =============================================
-- FPS BOOST
-- =============================================
if CFG.Another and CFG.Another.FPSBoost then
    pcall(function()
        Workspace.Terrain.WaterWaveSize = 0
        Workspace.Terrain.WaterWaveSpeed = 0
        Workspace.Terrain.WaterReflectance = 0
        game.Lighting.GlobalShadows = false
        game.Lighting.FogEnd = 9e9
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level10
    end)
end

-- Tắt collision
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            if player.Character then
                for _, v in pairs(player.Character:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
            end
        end)
    end
end)

-- =============================================
-- DANGER BLACKLIST
-- =============================================
local dangerCooldown = {}
local function checkDanger()
    local cfg = CFG.Another and CFG.Another.DangerBlacklist
    if not cfg or not cfg.Enable then return end
    local targ = getgenv().targ
    if not targ then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return end
    local pct = hum.Health / hum.MaxHealth
    if pct <= (cfg.DangerHealthPct or 0.2) then
        if not dangerCooldown[targ.Name] then
            dangerCooldown[targ.Name] = true
            getgenv().dangerCount[targ.Name] = (getgenv().dangerCount[targ.Name] or 0) + 1
            if getgenv().dangerCount[targ.Name] >= (cfg.MaxAttempts or 3) then
                getgenv().dangerBlacklist[targ.Name] = true
                if getgenv().SkipPlayer then getgenv().SkipPlayer() end
            end
        end
    else
        dangerCooldown[targ.Name] = nil
    end
end

-- =============================================
-- SAFE ZONE CHECK
-- =============================================
local function inSafeZone(pos)
    local ok, result = pcall(function()
        local zones = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("SafeZones")
        if zones then
            for _, z in pairs(zones:GetChildren()) do
                if z:IsA("Part") and (z.Position-pos).Magnitude <= 400 then return true end
            end
        end
        local main = player.PlayerGui:FindFirstChild("Main")
        if main and main:FindFirstChild("[OLD]SafeZone") and main["[OLD]SafeZone"].Visible then return true end
        return false
    end)
    return ok and result or false
end

-- =============================================
-- KIỂM TRA TARGET HỢP LỆ
-- =============================================
local function isValidTarget(v)
    if not v or v == player then return false end
    if not v.Character then return false end
    if not isAlive(v.Character) then return false end
    local vRoot = getRoot(v.Character)
    if not vRoot then return false end
    if not v:FindFirstChild("leaderstats") then return false end
    local bountyStat = v.leaderstats:FindFirstChild("Bounty/Honor")
    if not bountyStat then return false end

    local bounty = bountyStat.Value
    local minB = (CFG.Hunt and CFG.Hunt.Min) or 0
    local maxB = (CFG.Hunt and CFG.Hunt.Max) or math.huge
    if bounty < minB or bounty > maxB then return false end

    -- Team check: phải khác team, so sánh tên
    local myTeamName = player.Team and player.Team.Name or ""
    local vTeamName  = v.Team and v.Team.Name or ""
    if myTeamName ~= "" and vTeamName ~= "" and myTeamName == vTeamName then return false end

    -- Level check (safe)
    local myLv, vLv
    pcall(function()
        myLv = player.Data and player.Data:FindFirstChild("Level") and tonumber(player.Data.Level.Value)
        vLv  = v:FindFirstChild("Data") and v.Data:FindFirstChild("Level") and tonumber(v.Data.Level.Value)
    end)
    if myLv and vLv and (myLv - 250) >= vLv then return false end

    -- Skip config
    if CFG.Skip then
        if CFG.Skip.RaceV4 and v.Character:FindFirstChild("RaceTransformed") then return false end
        if CFG.Skip.Fruit and CFG.Skip.FruitList then
            local data = v:FindFirstChild("Data")
            local df = data and data:FindFirstChild("DevilFruit")
            if df and hasValue(CFG.Skip.FruitList, df.Value) then return false end
        end
        if CFG.Skip.SafeZone and inSafeZone(vRoot.Position) then return false end
    end

    if getgenv().dangerBlacklist[v.Name] then return false end
    if hasValue(getgenv().checked, v) then return false end
    if vRoot.Position.Y > 12000 then return false end

    return true
end

-- =============================================
-- TÌM TARGET
-- =============================================
local function findTarget()
    if not isAlive(player.Character) then return end
    local myRoot = getRoot(player.Character)
    if not myRoot then return end

    local bestDist = math.huge
    local best = nil

    for _, v in pairs(Players:GetPlayers()) do
        if isValidTarget(v) then
            local vRoot = getRoot(v.Character)
            if vRoot then
                local d = (vRoot.Position - myRoot.Position).Magnitude
                if d < bestDist then
                    bestDist = d
                    best = v
                end
            end
        end
    end

    if best then
        if getgenv().targ ~= best then
            getgenv().targ = best
            print("🎯 Target: " .. best.Name)
            -- Chat khi target mới
            pcall(function()
                local chat = CFG.Chat
                if chat and chat.Enabled and chat.Messages and #chat.Messages > 0 then
                    local msg = chat.Messages[math.random(1, #chat.Messages)]
                    ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents"):FindFirstChild("SayMessageRequest"):FireServer(msg, "All")
                end
            end)
        end
    else
        getgenv().targ = nil
        print("❌ No target found")
        -- Reset checked rồi mới hop
        if #getgenv().checked > 0 then
            getgenv().checked = {}
            getgenv().dangerBlacklist = {}  -- reset danger blacklist cùng lúc
            getgenv().dangerCount = {}
            print("🔄 Reset checked + blacklist")
        else
            -- Đợi 2s trước khi hop phòng server chưa load xong
            task.delay(2, function()
                if not getgenv().targ then
                    getgenv().hopserver = true
                end
            end)
        end
    end
end
getgenv().target = findTarget

-- =============================================
-- SKIP PLAYER
-- =============================================
local skipping = false
local function skipPlayer()
    if skipping then return end
    skipping = true
    local cur = getgenv().targ
    if cur then table.insert(getgenv().checked, cur) end
    getgenv().targ = nil
    findTarget()
    task.delay(1, function() skipping = false end)
end
getgenv().SkipPlayer = skipPlayer

-- =============================================
-- HOP SERVER
-- =============================================
local hopping = false
local function hopServer()
    if hopping then return end
    hopping = true
    table.insert(getgenv().ServerBlacklist, game.JobId)
    local ok, _ = pcall(function()
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?limit=100"):format(game.PlaceId)
        local data = HttpService:JSONDecode(game:HttpGet(url))
        local sel = nil
        for _, s in ipairs(data.data or {}) do
            if s.playing and s.maxPlayers and s.playing > 5 and s.playing < s.maxPlayers - 1 then
                local bl = false
                for _, b in ipairs(getgenv().ServerBlacklist) do if b==s.id then bl=true break end end
                if not bl then sel=s break end
            end
        end
        if sel then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, sel.id)
        else
            TeleportService:Teleport(game.PlaceId)
        end
    end)
    if not ok then TeleportService:Teleport(game.PlaceId) end
    task.wait(5) -- đợi teleport xử lý trước khi reset
    hopping = false
end
getgenv().HopServer = hopServer

-- =============================================
-- EQUIP FRUIT
-- =============================================
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            if not player.Character then return end
            local hasFruit = false
            for _, t in pairs(player.Character:GetChildren()) do
                if t:IsA("Tool") and t.ToolTip == "Blox Fruit" then hasFruit=true break end
            end
            if not hasFruit then
                local hum = player.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    for _, t in pairs(player.Backpack:GetChildren()) do
                        if t:IsA("Tool") and t.ToolTip == "Blox Fruit" then hum:EquipTool(t) break end
                    end
                end
            end
        end)
    end
end)

-- =============================================
-- FLY + BÁM SÁT TARGET (mỗi frame)
-- =============================================
task.spawn(function()
    while task.wait(0.016) do  -- ~60fps
        pcall(function()
            if getgenv().hopserver or safehealth or fruitBlocked then return end
            local targ = getgenv().targ
            if not targ or not targ.Character then return end
            local targRoot = getRoot(targ.Character)
            if not targRoot then return end
            local myRoot = getRoot(player.Character)
            if not myRoot then return end

            local dist = (targRoot.Position - myRoot.Position).Magnitude
            if dist > 5 then
                local dir = (targRoot.Position - myRoot.Position).Unit
                local goalPos = targRoot.Position - dir * 4
                goalPos = Vector3.new(goalPos.X, targRoot.Position.Y, goalPos.Z)
                if dist <= 500 then
                    myRoot.CFrame = CFrame.new(goalPos, targRoot.Position)
                else
                    if currentTween then currentTween:Cancel() end
                    currentTween = TweenService:Create(myRoot,
                        TweenInfo.new(dist/600, Enum.EasingStyle.Linear),
                        {CFrame = CFrame.new(goalPos, targRoot.Position)}
                    )
                    currentTween:Play()
                end
            else
                myRoot.CFrame = CFrame.lookAt(myRoot.Position,
                    Vector3.new(targRoot.Position.X, myRoot.Position.Y, targRoot.Position.Z))
            end
        end)
    end
end)

-- =============================================
-- BUSO + KEN
-- =============================================
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            if not getgenv().targ or not player.Character then return end
            if not player.Character:FindFirstChild("HasBuso") then
                CommF_:InvokeServer("Buso")
            end
        end)
    end
end)

-- =============================================
-- PVP + V3/V4
-- =============================================
task.spawn(function()
    while task.wait(3) do
        pcall(function()
            CommF_:InvokeServer("EnablePvp")
            local targ = getgenv().targ
            if not targ or not targ.Character or not player.Character then return end
            local myRoot  = getRoot(player.Character)
            local tRoot   = getRoot(targ.Character)
            if not myRoot or not tRoot then return end
            if (tRoot.Position - myRoot.Position).Magnitude > 50 then return end
            local transformed = player.Character:FindFirstChild("RaceTransformed")
            if CFG.Another then
                if CFG.Another.V3 and not transformed then
                    local shouldV3 = true
                    if CFG.Another.CustomHealth then
                        local hum = player.Character:FindFirstChild("Humanoid")
                        shouldV3 = hum and hum.Health <= (CFG.Another.Health or 4700)
                    end
                    if shouldV3 then
                        VirtualInputManager:SendKeyEvent(true,"T",false,nil)
                        task.wait(0.1)
                        VirtualInputManager:SendKeyEvent(false,"T",false,nil)
                    end
                end
                if CFG.Another.V4 and not transformed then
                    VirtualInputManager:SendKeyEvent(true,"Y",false,nil)
                    task.wait(0.1)
                    VirtualInputManager:SendKeyEvent(false,"Y",false,nil)
                end
            end
        end)
    end
end)

-- =============================================
-- REMOTE HOOK (aim skill về target)
-- =============================================
local oldNamecall
pcall(function()
    local mt = getrawmetatable(game)
    if not mt then return end
    oldNamecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" then
            local targ = getgenv().targ
            if targ and targ.Character and getRoot(targ.Character) then
                local args = {...}
                local name = tostring(self)
                local tPos = getRoot(targ.Character).Position
                if name:find("UpdateMousePos") or name:find("MousePos") or name:find("Click")
                or name:find("Skill") or name:find("Activate") or name:find("Ability") then
                    for i=1,#args do
                        if type(args[i])=="Vector3" then args[i]=tPos
                        elseif type(args[i])=="CFrame" then args[i]=CFrame.new(tPos)*(args[i]-args[i].Position) end
                    end
                    return oldNamecall(self, unpack(args))
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end)

-- =============================================
-- EXPAND HITBOX
-- =============================================
local function expandHitbox()
    pcall(function()
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if player.Character:FindFirstChild("_HB") then return end
        local p = Instance.new("Part")
        p.Name = "_HB"
        p.Size = Vector3.new(12,12,12)
        p.Transparency = 1
        p.CanCollide = false
        p.Anchored = false
        p.Parent = player.Character
        local w = Instance.new("WeldConstraint")
        w.Part0 = hrp w.Part1 = p w.Parent = p
        p.CFrame = hrp.CFrame
    end)
end
expandHitbox()
player.CharacterAdded:Connect(function() task.wait(1) expandHitbox() end)

-- =============================================
-- M1 AUTO ATTACK
-- =============================================
task.spawn(function()
    while task.wait(0.05) do  -- 0.05s = ~20 hits/s, đủ nhanh mà không spike CPU
        pcall(function()
            if not m1Enabled or getgenv().hopserver or safehealth or fruitBlocked then return end
            local targ = getgenv().targ
            if not targ or not targ.Character then return end
            local targRoot = getRoot(targ.Character)
            if not targRoot then return end
            local myRoot = getRoot(player.Character)
            if not myRoot then return end
            local hum = player.Character:FindFirstChild("Humanoid")
            if not hum or hum.Health <= 0 then return end
            local tHum = targ.Character:FindFirstChild("Humanoid")
            if not tHum or tHum.Health <= 0 then return end

            local dist = (targRoot.Position - myRoot.Position).Magnitude

            if dist <= 12 then
                -- Aim chính xác trước khi M1
                myRoot.CFrame = CFrame.lookAt(myRoot.Position,
                    Vector3.new(targRoot.Position.X, myRoot.Position.Y, targRoot.Position.Z))
                if FastAttack then
                    FastAttack:M1()
                else
                    VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,1)
                    task.wait(0.04)
                    VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,1)
                end
            end
        end)
    end
end)

-- =============================================
-- SAFE HEALTH
-- =============================================
local function getHPct()
    local hum = player.Character and player.Character:FindFirstChild("Humanoid")
    if not hum or hum.MaxHealth <= 0 then return 1 end
    return hum.Health / hum.MaxHealth
end
local function safeThreshold()
    local v = CFG.SafeHealth and CFG.SafeHealth.Health or 0.3
    return v <= 1 and v or v/100
end

task.spawn(function()
    while task.wait(0.1) do
        local ok, hpct = pcall(getHPct)
        if ok and hpct <= safeThreshold() and not safehealth then
            safehealth = true
            pcall(checkDanger)
            pcall(function()
                if currentTween then currentTween:Cancel() currentTween = nil end
                local hrp = getRoot(player.Character)
                if hrp then hrp.CFrame = hrp.CFrame * CFrame.new(0, math.random(8000,15000), 0) end
            end)
            -- Đợi hồi máu
            local timeout = 60 -- tối đa 60s
            while timeout > 0 do
                task.wait(0.5)
                timeout = timeout - 0.5
                local ok2, pct = pcall(getHPct)
                if (ok2 and pct > safeThreshold()) or not player.Character then break end
            end
            safehealth = false
        end
    end
end)

-- =============================================
-- VÒNG LẶP CHÍNH
-- =============================================
task.spawn(function()
    while task.wait(0.1) do
        if fruitBlocked or safehealth then
            getgenv().targ = nil
        else
            pcall(function()
                local curTarg = getgenv().targ
                if not curTarg or not curTarg.Character or not isAlive(curTarg.Character) then
                    getgenv().targ = nil
                    findTarget()
                end
                -- Skip nếu target trong safe zone hoặc ngồi
                local targ = getgenv().targ
                if targ and targ.Character and player.Character then
                    local myRoot = getRoot(player.Character)
                    local tRoot  = getRoot(targ.Character)
                    if myRoot and tRoot and (tRoot.Position-myRoot.Position).Magnitude < 40 then
                        if inSafeZone(tRoot.Position) then skipPlayer() return end
                        local th = targ.Character:FindFirstChild("Humanoid")
                        if th and th.Sit then skipPlayer() return end
                    end
                end
            end)
            -- Auto hop nếu cần (spawn riêng để không block main loop)
            if getgenv().hopserver then
                getgenv().hopserver = false
                task.spawn(hopServer)
            end
        end
    end
end)

-- =============================================
-- AUTO SKIP THÔNG BÁO "PLAYER DIED RECENTLY"
-- =============================================
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            if not getgenv().targ then return end
            local notifs = player.PlayerGui:FindFirstChild("Notifications")
            if not notifs then return end
            for _, v in pairs(notifs:GetChildren()) do
                if v:IsA("TextLabel") then
                    local txt = string.lower(v.Text)
                    for _, kw in ipairs({"player died recently","you can't attack them yet","cannot attack","died recently","can't attack them"}) do
                        if txt:find(kw) then
                            skipPlayer()
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
-- WEBHOOK
-- =============================================
local function sendWebhook(url, data)
    if not url or url=="" then return end
    pcall(function()
        local body = HttpService:JSONEncode(data)
        if syn and syn.request then
            syn.request({Url=url,Method="POST",Headers={["Content-Type"]="application/json"},Body=body})
        elseif request then
            request({Url=url,Method="POST",Headers={["Content-Type"]="application/json"},Body=body})
        end
    end)
end

local lastBounty = 0
local lastKilled = nil
task.delay(3, function()
    pcall(function()
        local ls = player:FindFirstChild("leaderstats")
        if ls and ls:FindFirstChild("Bounty/Honor") then lastBounty = ls["Bounty/Honor"].Value end
    end)
end)

task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local targ = getgenv().targ
            if not targ or not targ.Character then return end
            local h = targ.Character:FindFirstChild("Humanoid")
            if h and h.Health <= 0 and lastKilled ~= targ.Name then
                lastKilled = targ.Name
                task.wait(2)
                local cur = player.leaderstats and player.leaderstats["Bounty/Honor"] and player.leaderstats["Bounty/Honor"].Value or 0
                local earned = math.max(0, cur - lastBounty)
                lastBounty = cur
                -- Gửi webhook nếu bật
                pcall(function()
                    local wh = CFG.Webhook
                    if not wh or not wh.Enable or not wh.Url or wh.Url == "" then return end
                    local function fmt(b)
                        if b>=1e6 then return ("%.1fM"):format(b/1e6)
                        elseif b>=1e3 then return ("%.1fK"):format(b/1e3)
                        else return tostring(b) end
                    end
                    sendWebhook(wh.Url, {embeds={{
                        title="BOUNTY HUNTER",color=0x67eb34,
                        fields={
                            {name="Target",value="```"..targ.Name.."```",inline=true},
                            {name="Earned",value="```"..fmt(earned).."```",inline=true},
                            {name="Total",value="```"..fmt(cur).."```",inline=true},
                            {name="Hunter",value="```"..player.Name.."```",inline=true},
                        },
                        footer={text="Auto Bounty"},
                    }}})
                end)
                task.wait(2)
                skipPlayer()
            end
        end)
    end
end)

-- Startup webhook
task.delay(8, function()
    pcall(function()
        local wh = CFG.Webhook
        if not wh or not wh.Enable or not wh.Url or wh.Url=="" then return end
        local cur = player.leaderstats and player.leaderstats["Bounty/Honor"] and player.leaderstats["Bounty/Honor"].Value or 0
        sendWebhook(wh.Url, {embeds={{
            title="Auto Bounty Started",color=16753920,
            fields={
                {name="Player",value="```"..player.Name.."```",inline=true},
                {name="Team",value="```"..(CFG.Team or "?").."```",inline=true},
                {name="Bounty",value="```"..tostring(cur).."```",inline=true},
            },
            footer={text=os.date("%H:%M %d/%m/%Y")},
        }}})
    end)
end)

-- Error auto rejoin
pcall(function()
    CoreGui.RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
        if not getgenv().hopserver and child.Name=="ErrorPrompt" then
            TeleportService:Teleport(game.PlaceId)
        end
    end)
end)

print("✅ Auto Bounty đã sẵn sàng!")
