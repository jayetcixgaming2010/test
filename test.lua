--[[
    Tên Script: Khfresh Hub v27 - Titan Fishing Ultimate
    Cập nhật v27:
      - Dùng đúng remote path: ReplicatedStorage.Communication.Events / .Functions
      - Auto Farm hook __namecall để sync số START/RELEASE/DAMAGE/SKILL tự động
      - Auto Sell dùng remote trực tiếp (không cần đứng gần NPC)
      - Auto Roll Skill dùng remote trực tiếp (không cần teleport)
      - Giữ nguyên UI WindUI + tên Khfresh Hub
--]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui           = game:GetService("CoreGui")
local AssetService      = game:GetService("AssetService")

local player    = Players.LocalPlayer
local guiParent = gethui and gethui() or CoreGui

-- ==================== WINDUI ====================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
if not WindUI then warn("Không thể tải WindUI.") return end

local Window = WindUI:CreateWindow({
    Author = "Khfresh",
    Folder = "KhfreshHub_TitanFishing",
    Icon   = "rbxassetid://97028818666741",
    Size   = UDim2.fromOffset(640, 580),
    Theme  = "Dark",
    Title  = "Khfresh Hub - Titan Fishing Ultimate"
})

-- ==================== REMOTE PATH ====================
-- Game dùng: ReplicatedStorage.Communication.Events & .Functions
local Communication = ReplicatedStorage:WaitForChild("Communication", 10)
local Events        = Communication and Communication:WaitForChild("Events", 10)
local Functions     = Communication and Communication:WaitForChild("Functions", 10)

-- Cache tất cả remote để dùng nhanh
local Remote = {}
if Events then
    for _, v in ipairs(Events:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            Remote[v.Name] = v
        end
    end
end
if Functions then
    for _, v in ipairs(Functions:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            Remote[v.Name] = v
        end
    end
end

-- Debug: in ra danh sách remote tìm được
print("=== [KhfreshHub] Remotes found ===")
for name, _ in pairs(Remote) do print(" -", name) end
print("==================================")

-- ==================== BIẾN ====================
local autoFarmEnabled   = false
local autoSellEnabled   = false
local autoRollEnabled   = false
local autoBuyRodEnabled = false
local fpsBoostEnabled   = false
local targetRarity      = "Legendary"
local tweenSpeed        = 310
local reelDelay         = 0.05
local sellInterval      = 10
local catchCount        = 0
local customX, customY, customZ = 0, 0, 0

-- Giá trị sync từ hook (sẽ tự fill khi Sync)
local syncedStart   = nil
local syncedRelease = nil
local syncedDamage  = nil
local syncedSkill   = nil

local farmThread = nil
local rollThread = nil

-- ==================== TIỆN ÍCH ====================
local function getHRP()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function snapTo(cf)
    local hrp = getHRP()
    if hrp then hrp.CFrame = cf end
end

local function teleportTo(cf)
    local hrp = getHRP()
    if not hrp then return end
    local dist = (hrp.Position - cf.Position).Magnitude
    local dur  = math.max(dist / tweenSpeed, 0.05)
    local tw   = TweenService:Create(hrp, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = cf})
    tw:Play(); tw.Completed:Wait()
end

local function findGui(keywords, class)
    class = class or "TextButton"
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, obj in ipairs(pg:GetDescendants()) do
        if obj:IsA(class) and obj.Visible then
            local src = (obj.Name .. " " .. (pcall(function() return obj.Text end) and obj.Text or "")):lower()
            for _, kw in ipairs(keywords) do
                if src:find(kw:lower()) then return obj end
            end
        end
    end
    return nil
end

local function clickGui(btn)
    if not btn then return end
    pcall(function() btn:Click() end)
end

-- Fire RemoteEvent theo tên (tìm trong cache)
local function fireRemote(name, ...)
    local r = Remote[name]
    if r then
        if r:IsA("RemoteEvent") then
            pcall(function() r:FireServer(...) end)
            return true
        elseif r:IsA("RemoteFunction") then
            local ok, res = pcall(function() return r:InvokeServer(...) end)
            return ok and res
        end
    end
    return false
end

-- ==================== HOOK __namecall ĐỂ SYNC ====================
-- Khi player bấm Sync trong game gốc, hook sẽ bắt được args
-- và lưu lại để dùng cho auto farm
local hookedNamecall
if hookmetamethod then
    hookedNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args   = {...}

        -- Bắt InvokeServer / FireServer từ remote trong Communication
        if (method == "InvokeServer" or method == "FireServer") then
            local ok, fullName = pcall(function() return self:GetFullName() end)
            if ok and fullName and fullName:find("Communication") then
                -- In ra để debug
                -- print("[Hook]", fullName, method, table.unpack(args))

                -- Nếu remote liên quan fishing → lưu args
                local lname = self.Name:lower()
                if lname:find("fish") or lname:find("cast") or lname:find("reel") or lname:find("start") then
                    -- Lưu các số tự động phát hiện
                    for i, v in ipairs(args) do
                        if type(v) == "number" then
                            if i == 1 then syncedStart   = v end
                            if i == 2 then syncedRelease = v end
                            if i == 3 then syncedDamage  = v end
                            if i == 4 then syncedSkill   = v end
                        end
                    end
                end
            end
        end

        return hookedNamecall(self, ...)
    end)
end

-- ==================== SYNC SERVER ====================
-- Bắt chước nút "Sync" của LuvHub: gọi remote Sync/Init để lấy số
local function doSync()
    -- Thử các tên remote sync phổ biến trong game
    local syncNames = {"Sync", "Init", "Initialize", "SyncFishing", "SyncShop", "GetData", "Connect"}
    for _, name in ipairs(syncNames) do
        local r = Remote[name]
        if r then
            pcall(function()
                if r:IsA("RemoteFunction") then
                    local res = r:InvokeServer()
                    if type(res) == "table" then
                        -- Parse kết quả nếu có số
                        for k, v in pairs(res) do
                            local kl = tostring(k):lower()
                            if kl:find("start") then syncedStart = v end
                            if kl:find("release") then syncedRelease = v end
                            if kl:find("damage") then syncedDamage = v end
                            if kl:find("skill") then syncedSkill = v end
                        end
                    end
                elseif r:IsA("RemoteEvent") then
                    r:FireServer()
                end
            end)
        end
    end
    Window:Notify({Title = "Sync", Content = "Đã sync server!", Duration = 2})
end

-- ==================== AUTO FARM ====================
local function isInReelPhase()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return false end
    for _, obj in ipairs(pg:GetDescendants()) do
        if obj.Visible then
            local n = obj.Name:lower()
            if n:find("reel") or n:find("pull") or n:find("minigame") or n:find("progress") then
                return true
            end
        end
    end
    return false
end

local function spamClick(maxDur)
    local t = tick()
    while tick() - t < maxDur and autoFarmEnabled do
        if not isInReelPhase() then break end
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true,  game, 1)
        task.wait(reelDelay)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        task.wait(reelDelay)
    end
end

local function doCast()
    -- Thử remote Cast trực tiếp
    local castNames = {"Cast", "CastLine", "StartFishing", "Throw", "Fish", "StartCast"}
    for _, name in ipairs(castNames) do
        if fireRemote(name) then return true end
    end
    -- Fallback: click GUI button
    local castBtn = findGui({"cast", "fish", "throw", "bait", "start"})
    if castBtn then clickGui(castBtn); return true end
    return false
end

local function doReel()
    -- Thử remote Reel trực tiếp với synced values
    local reelNames = {"Reel", "Pull", "ReelFish", "StartReel", "Damage", "Attack"}
    for _, name in ipairs(reelNames) do
        if syncedStart then
            -- Kirim args yang di-sync
            if fireRemote(name, syncedStart, syncedRelease, syncedDamage, syncedSkill) then
                return true
            end
        else
            if fireRemote(name) then return true end
        end
    end
    -- Fallback: spam click
    spamClick(12)
    return true
end

local function doSell()
    -- Jual via remote langsung
    local sellNames = {"SellFish", "Sell", "SellAll", "SellOne", "SellAllFish"}
    local sold = false
    for _, name in ipairs(sellNames) do
        if fireRemote(name) then sold = true; break end
    end

    if not sold then
        -- Fallback: teleport ke NPC, click GUI
        local savedCF = getHRP() and getHRP().CFrame
        local sellCF  = CFrame.new(208.996, 22.445, 59.334)
        snapTo(sellCF)
        task.wait(0.5)
        local sellBtn = findGui({"sell all", "sell", "jual", "confirm"})
        if sellBtn then clickGui(sellBtn) end
        task.wait(0.3)
        if savedCF then snapTo(savedCF) end
    end

    catchCount = 0
    Window:Notify({Title = "Auto Sell", Content = "Đã bán cá!", Duration = 2})
end

local function autoFarmLoop()
    while autoFarmEnabled do
        -- 1. Cast
        doCast()

        -- 2. Chờ bite (GUI reel xuất hiện, timeout 15s)
        local biteTimer = 0
        local bitten    = false
        while biteTimer < 15 and autoFarmEnabled do
            if isInReelPhase() then bitten = true; break end
            task.wait(0.25); biteTimer = biteTimer + 0.25
        end

        -- 3. Reel
        if bitten then
            doReel()
            -- Chờ reel kết thúc
            local endT = 0
            while isInReelPhase() and endT < 8 and autoFarmEnabled do
                task.wait(0.2); endT = endT + 0.2
            end
            catchCount = catchCount + 1
        end

        -- 4. Auto Sell
        if autoSellEnabled and catchCount >= sellInterval then
            doSell()
        end

        task.wait(0.3)
    end
end

-- ==================== AUTO ROLL (REMOTE LANGSUNG) ====================
local rarityRank = {Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythical = 5}

local function getRarityFromText(text)
    text = text:lower()
    if text:find("mythic")  then return "Mythical"
    elseif text:find("legend") then return "Legendary"
    elseif text:find("epic")   then return "Epic"
    elseif text:find("rare")   then return "Rare"
    elseif text:find("common") then return "Common" end
    return nil
end

local function tryRollRemote()
    -- Thử tất cả tên remote liên quan spin/skill book
    local rollNames = {
        "SpinSkill", "RollSkill", "Spin", "Roll", "Gacha",
        "DrawSkill", "GetSkill", "RerollSkill", "SkillSpin",
        "SpinBook", "RollBook", "Innate", "InnateRoll"
    }
    for _, name in ipairs(rollNames) do
        local r = Remote[name]
        if r then
            local ok, res = pcall(function()
                if r:IsA("RemoteFunction") then
                    return r:InvokeServer()
                else
                    r:FireServer()
                    return true
                end
            end)
            if ok then
                -- Coba parse hasil rarity dari response
                if type(res) == "string" then
                    return getRarityFromText(res)
                elseif type(res) == "table" then
                    for k, v in pairs(res) do
                        if type(v) == "string" then
                            local r2 = getRarityFromText(v)
                            if r2 then return r2 end
                        end
                    end
                end
                return true -- fired tapi ga ada hasil rarity
            end
        end
    end
    return nil
end

local function readRarityFromGui()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, obj in ipairs(pg:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible then
            local r = getRarityFromText(obj.Text)
            if r then return r end
        end
    end
    return nil
end

local SKILLBOOK_CF = CFrame.new(120.668, 67.663, -41.885)

local function autoRollLoop()
    while autoRollEnabled do
        local hrp    = getHRP()
        if not hrp then task.wait(1); continue end
        local savedCF = hrp.CFrame

        -- 1. Coba remote langsung dulu (tidak perlu teleport)
        local remoteResult = tryRollRemote()

        local gotRarity = nil

        if remoteResult then
            -- Remote berhasil
            if type(remoteResult) == "string" then
                gotRarity = remoteResult
            end
            task.wait(2) -- tunggu animasi
            gotRarity = gotRarity or readRarityFromGui()
        else
            -- Remote gagal → snap ke NPC, click, balik
            snapTo(SKILLBOOK_CF)
            task.wait(0.2)

            -- Click ClickDetector NPC
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ClickDetector") then
                    local n = (obj.Parent and obj.Parent.Name or ""):lower()
                    if n:find("skill") or n:find("book") or n:find("spin") then
                        pcall(fireclickdetector, obj)
                        break
                    end
                end
            end
            task.wait(0.5)

            -- Click tombol spin di GUI
            local spinBtn = findGui({"spin", "roll", "draw", "gacha", "quay", "reroll", "summon"})
            if spinBtn then
                clickGui(spinBtn)
                task.wait(2.5)
                gotRarity = readRarityFromGui()
            end

            -- Tutup popup
            local closeBtn = findGui({"close", "ok", "back", "cancel", "tiếp", "continue", "exit"})
            if closeBtn then clickGui(closeBtn) end
            task.wait(0.2)

            -- Balik ke posisi semula
            snapTo(savedCF)
        end

        -- 2. Cek apakah sudah mencapai target
        if gotRarity then
            local rank   = rarityRank[gotRarity] or 0
            local target = rarityRank[targetRarity] or 4
            Window:Notify({
                Title   = "Auto Roll",
                Content = "Roll ra: " .. gotRarity,
                Duration = 2
            })
            if rank >= target then
                Window:Notify({
                    Title   = "Auto Roll ✅",
                    Content = "Đạt " .. gotRarity .. "! Dừng roll.",
                    Duration = 6
                })
                autoRollEnabled = false
                break
            end
        end

        task.wait(0.5)
    end
end

-- ==================== FPS BOOST ====================
local defaultFX = {}
local function applyFpsBoost()
    local L = game:GetService("Lighting")
    defaultFX = {GlobalShadows = L.GlobalShadows, FogEnd = L.FogEnd, ShadowSoftness = L.ShadowSoftness}
    L.GlobalShadows  = false
    L.FogEnd         = 9e9
    L.ShadowSoftness = 0
    for _, fx in ipairs(L:GetChildren()) do
        if fx:IsA("PostEffect") or fx:IsA("Atmosphere") then pcall(fx.Destroy, fx) end
    end
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    Window:Notify({Title = "FPS Boost", Content = "Đã bật!", Duration = 2})
end
local function removeFpsBoost()
    local L = game:GetService("Lighting")
    pcall(function()
        L.GlobalShadows  = defaultFX.GlobalShadows or true
        L.FogEnd         = defaultFX.FogEnd or 100000
        L.ShadowSoftness = defaultFX.ShadowSoftness or 0.5
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
    end)
    Window:Notify({Title = "FPS Boost", Content = "Đã tắt.", Duration = 2})
end

-- ==================== TELEPORT POINTS ====================
local teleportPoints = {
    ["Island 1"]   = CFrame.new(282,    29.8,   51.2),
    ["Island 2"]   = CFrame.new(1491.4, 25.6,  -451.1),
    ["Island 3"]   = CFrame.new(990,    28.1,   1272),
    ["Island 4"]   = CFrame.new(631.4,  28.1,  -846.7),
    ["Island 5"]   = CFrame.new(-337.1, 29.9,   829.6),
    ["Skill Book"] = CFrame.new(120.668, 67.663, -41.885),
    ["Skill Shop"] = CFrame.new(208.996, 22.445,  59.334),
    ["Sell Fish"]  = CFrame.new(208.996, 22.445,  59.334),
    ["Store"]      = CFrame.new(168.837, 23.990,  73.590),
}

-- ==================== GUI TABS ====================

-- TAB: FISHING
local FishingTab = Window:Tab({Icon = "fish", Title = "Fishing"})

FishingTab:Button({
    Title = "🔄 Sync Server",
    Description = "Sync remote trước khi dùng Auto Farm",
    Callback = function() doSync() end
})

FishingTab:Toggle({
    Title = "Auto Farm",
    Description = "Tự động cast → reel → sell",
    Value = false,
    Callback = function(v)
        autoFarmEnabled = v
        if v then farmThread = task.spawn(autoFarmLoop)
        else if farmThread then pcall(task.cancel, farmThread) end end
    end
})

FishingTab:Toggle({
    Title = "Auto Sell Fish",
    Description = "Tự động bán sau N lần câu",
    Value = false,
    Callback = function(v) autoSellEnabled = v end
})

FishingTab:Slider({
    Title = "Sell Interval (lần câu)",
    Min = 1, Max = 30, Default = 10,
    Callback = function(v) sellInterval = v end
})

FishingTab:Slider({
    Title = "Reel Speed (delay giây)",
    Description = "Nhỏ hơn = spam nhanh hơn",
    Min = 0.01, Max = 0.3, Default = 0.05,
    Callback = function(v) reelDelay = v end
})

-- Manual override: set số thủ công nếu cần
FishingTab:Label({Title = "─── Manual Override (nếu Sync thất bại) ───"})

FishingTab:Input({
    Title = "Number START",
    Default = "",
    Callback = function(v) syncedStart = tonumber(v) end
})
FishingTab:Input({
    Title = "Number RELEASE",
    Default = "",
    Callback = function(v) syncedRelease = tonumber(v) end
})
FishingTab:Input({
    Title = "Number DAMAGE",
    Default = "",
    Callback = function(v) syncedDamage = tonumber(v) end
})
FishingTab:Input({
    Title = "Number SKILL",
    Default = "",
    Callback = function(v) syncedSkill = tonumber(v) end
})

-- TAB: SKILL ROLL
local SkillTab = Window:Tab({Icon = "zap", Title = "Skill"})

SkillTab:Toggle({
    Title = "Auto Roll Skill Book",
    Description = "Roll remote langsung, TIDAK perlu ke NPC",
    Value = false,
    Callback = function(v)
        autoRollEnabled = v
        if v then rollThread = task.spawn(autoRollLoop)
        else if rollThread then pcall(task.cancel, rollThread) end end
    end
})

SkillTab:Dropdown({
    Title = "Target Rarity",
    Options = {"Common", "Rare", "Epic", "Legendary", "Mythical"},
    Default = "Legendary",
    Callback = function(v) targetRarity = v end
})

SkillTab:Button({
    Title = "Roll 1x (Manual)",
    Description = "Roll sekali dan lihat hasilnya",
    Callback = function()
        local r = tryRollRemote()
        task.wait(2)
        local got = (type(r) == "string" and r) or readRarityFromGui() or "?"
        Window:Notify({Title = "Roll", Content = "Hasil: " .. got, Duration = 4})
    end
})

-- TAB: TELEPORT
local TeleportTab = Window:Tab({Icon = "map-pinned", Title = "Teleport"})

TeleportTab:Slider({
    Title = "Tween Speed (studs/s)",
    Min = 50, Max = 2000, Default = 310,
    Callback = function(v) tweenSpeed = v end
})

for name, cf in pairs(teleportPoints) do
    local n = name
    TeleportTab:Button({
        Title = "Teleport → " .. n,
        Callback = function()
            teleportTo(cf)
            Window:Notify({Title = "Teleport", Content = "Đến " .. n, Duration = 2})
        end
    })
end

TeleportTab:Label({Title = "─── Custom Teleport ───"})
TeleportTab:Input({Title = "X", Default = "0", Callback = function(v) customX = tonumber(v) or 0 end})
TeleportTab:Input({Title = "Y", Default = "0", Callback = function(v) customY = tonumber(v) or 0 end})
TeleportTab:Input({Title = "Z", Default = "0", Callback = function(v) customZ = tonumber(v) or 0 end})
TeleportTab:Button({
    Title = "Teleport to Custom XYZ",
    Callback = function()
        teleportTo(CFrame.new(customX, customY, customZ))
        Window:Notify({
            Title = "Teleport",
            Content = string.format("Đến (%.1f, %.1f, %.1f)", customX, customY, customZ),
            Duration = 2
        })
    end
})

-- TAB: MISC
local MiscTab = Window:Tab({Icon = "settings", Title = "Misc"})

MiscTab:Toggle({
    Title = "FPS Boost",
    Description = "Tắt shadow/fog/PostEffect",
    Value = false,
    Callback = function(v)
        fpsBoostEnabled = v
        if v then applyFpsBoost() else removeFpsBoost() end
    end
})

MiscTab:Button({
    Title = "In Remote List (Console)",
    Description = "Debug: in tất cả remote tìm được",
    Callback = function()
        print("=== Remote List ===")
        for name, r in pairs(Remote) do
            print(r.ClassName, name, r:GetFullName())
        end
        Window:Notify({Title = "Debug", Content = "Đã in ra console!", Duration = 3})
    end
})

MiscTab:Button({
    Title = "Rejoin Server",
    Callback = function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, player)
    end
})

-- ==================== DRAG BUTTON ====================
local guiButton = Instance.new("ScreenGui")
guiButton.Name          = "KhfreshHubButton"
guiButton.Parent        = guiParent
guiButton.ResetOnSpawn  = false

local btn = Instance.new("ImageButton")
btn.Parent                 = guiButton
btn.BackgroundColor3       = Color3.fromRGB(25, 25, 25)
btn.Position               = UDim2.new(0, 25, 0.5, -27)
btn.Size                   = UDim2.new(0, 55, 0, 55)
btn.Image                  = "rbxassetid://80225033364855"
btn.BackgroundTransparency = 0.3
btn.Draggable              = true
btn.MouseButton1Click:Connect(function() Window:Toggle() end)
local btnCorner = Instance.new("UICorner", btn)
btnCorner.CornerRadius = UDim.new(0, 12)

-- ==================== GARBAGE COLLECT ====================
task.spawn(function()
    while true do
        task.wait(300)
        pcall(function() AssetService:ClearContentCache() end)
        collectgarbage("collect")
    end
end)

-- ==================== STARTUP ====================
task.wait(1)
Window:Notify({
    Title   = "Khfresh Hub v27",
    Content = "Loaded! Bấm 'Sync Server' trước khi dùng Auto Farm.",
    Duration = 6
})
print("✅ Khfresh Hub v27 - Titan Fishing loaded.")
print("💡 Tip: Bấm 'In Remote List' để xem remotes tìm được.")
