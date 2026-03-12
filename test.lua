--[[
    Khfresh Hub v31 - Titan Fishing Ultimate
    Cập nhật v31:
      - Fix riêng cho Delta X (mobile) + Velocity (PC)
      - Delta X: hookmetamethod/getnamecallmethod KHÔNG có → bỏ hẳn hook, dùng scan remote
      - Delta X: VirtualInputManager không work mobile → dùng tap() fallback
      - Velocity: gethui guard thêm
      - Auto-detect executor, tự chọn click method phù hợp
      - Log rõ executor + method đang dùng vào console
--]]

-- ==================== SERVICES ====================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService   = game:GetService("TeleportService")
local CoreGui           = game:GetService("CoreGui")
local AssetService      = game:GetService("AssetService")

local player = Players.LocalPlayer

-- ==================== EXECUTOR COMPAT LAYER ====================
-- Tự detect executor để chọn đúng method

local IS_DELTA_X  = false
local IS_VELOCITY = false
local EXEC_NAME   = "Unknown"

pcall(function()
    if identifyexecutor then
        EXEC_NAME = identifyexecutor() or "Unknown"
        local low = EXEC_NAME:lower()
        if low:find("delta") then IS_DELTA_X = true end
        if low:find("velocity") then IS_VELOCITY = true end
    end
end)
-- Fallback detect Delta X qua thiếu hookmetamethod (mobile executor thường không có)
if not IS_DELTA_X and not IS_VELOCITY then
    pcall(function()
        if not hookmetamethod and not getnamecallmethod then
            IS_DELTA_X = true -- assume mobile executor
        end
    end)
end

print("[KhfreshHub] Executor: " .. EXEC_NAME)
print("[KhfreshHub] Delta X mode: " .. tostring(IS_DELTA_X))
print("[KhfreshHub] Velocity mode: " .. tostring(IS_VELOCITY))

-- gethui (Velocity có, Delta X thường có, nhưng guard cẩn thận)
local _gethui = nil
pcall(function()
    if typeof(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and result then _gethui = gethui end
    end
end)

-- hookmetamethod + getnamecallmethod
-- Delta X KHÔNG có → skip hoàn toàn, không gây error
local _hookmetamethod    = nil
local _getnamecallmethod = nil
if not IS_DELTA_X then
    pcall(function()
        if typeof(hookmetamethod) == "function" then
            _hookmetamethod = hookmetamethod
        end
        if typeof(getnamecallmethod) == "function" then
            _getnamecallmethod = getnamecallmethod
        end
    end)
end

-- fireclickdetector
local _fireclickdetector = nil
pcall(function()
    if typeof(fireclickdetector) == "function" then
        _fireclickdetector = fireclickdetector
    end
end)

-- setclipboard
local _setclipboard = nil
pcall(function()
    if typeof(setclipboard) == "function" then _setclipboard = setclipboard
    elseif typeof(toclipboard) == "function" then _setclipboard = toclipboard
    elseif typeof(Clipboard) == "table" and typeof(Clipboard.set) == "function" then
        _setclipboard = function(s) Clipboard.set(s) end
    end
end)

-- tap() — Delta X mobile click method
local _tap = nil
pcall(function()
    if typeof(tap) == "function" then _tap = tap end
end)

-- VirtualInputManager
local _vim = nil
pcall(function()
    _vim = game:GetService("VirtualInputManager")
end)

-- guiParent
local guiParent = CoreGui
pcall(function()
    if _gethui then
        local ok, h = pcall(_gethui)
        if ok and h then guiParent = h end
    end
end)

-- ── HELPER FUNCTIONS ──
local function safeFireCD(cd)
    if _fireclickdetector then
        pcall(_fireclickdetector, cd)
    else
        pcall(function() cd:Activate() end)
    end
end

local function safeCopyClipboard(str)
    if _setclipboard then pcall(_setclipboard, str) end
end

-- ── CLICK FUNCTION (tự chọn method theo executor) ──
-- Delta X mobile → dùng tap() nếu có, không thì remote-only
-- Velocity / PC   → dùng VirtualInputManager
local function sendClick()
    if IS_DELTA_X then
        -- Mobile: tap vào center màn hình
        if _tap then
            pcall(function()
                local vp = workspace.CurrentCamera.ViewportSize
                _tap(vp.X / 2, vp.Y / 2)
            end)
        end
        -- Nếu không có tap → reel sẽ fallback dùng remote (xem doReel)
    else
        -- PC executor (Velocity, KRNL, Synapse...)
        if _vim then
            pcall(function()
                _vim:SendMouseButtonEvent(0, 0, 0, true,  game, 1)
            end)
            task.wait(0.01)
            pcall(function()
                _vim:SendMouseButtonEvent(0, 0, 0, false, game, 1)
            end)
        end
    end
end

-- ==================== WINDUI ====================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
if not WindUI then warn("[KhfreshHub] Không thể tải WindUI.") return end

local Window = WindUI:CreateWindow({
    Author = "Khfresh",
    Folder = "KhfreshHub_TitanFishing",
    Icon   = "rbxassetid://97028818666741",
    Size   = UDim2.fromOffset(660, 600),
    Theme  = "Dark",
    Title  = "Khfresh Hub - Titan Fishing Ultimate"
})

-- ==================== ISLAND CONFIG ====================
local ISLANDS = {
    {
        name     = "Island 1",
        minLevel = 0,
        cf       = CFrame.new(250.169052, 22.0446796, 41.1053085,
                              -0.207915217, -4.50629534e-09, -0.978146851,
                              -8.3387242e-08, 1, 1.31178464e-08,
                              0.978146851, 8.42923669e-08, -0.207915217),
    },
    {
        name     = "Island 2",
        minLevel = 10,
        cf       = CFrame.new(0, 0, 0), -- << FILL
    },
    {
        name     = "Island 3",
        minLevel = 20,
        cf       = CFrame.new(0, 0, 0), -- << FILL
    },
    {
        name     = "Island 4",
        minLevel = 40,
        cf       = CFrame.new(0, 0, 0), -- << FILL
    },
    {
        name     = "Island 5",
        minLevel = 60,
        cf       = CFrame.new(0, 0, 0), -- << FILL
    },
}

-- ==================== REMOTE PATH ====================
local Communication = ReplicatedStorage:WaitForChild("Communication", 10)
local Events        = Communication and Communication:WaitForChild("Events", 10)
local Functions     = Communication and Communication:WaitForChild("Functions", 10)

local Remote = {}
local function refreshRemotes()
    Remote = {}
    local function cacheFolder(folder)
        if not folder then return end
        for _, v in ipairs(folder:GetDescendants()) do
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                Remote[v.Name] = v
            end
        end
    end
    cacheFolder(Events)
    cacheFolder(Functions)
end
refreshRemotes()

print("=== [KhfreshHub] Remotes found ===")
for name in pairs(Remote) do print(" -", name) end
print("==================================")

-- ==================== BIẾN ====================
local autoFarmEnabled     = false
local autoProgressEnabled = false
local autoSellEnabled     = false
local autoRollEnabled     = false
local antiAdminEnabled    = false
local antiAfkEnabled      = false
local fpsBoostEnabled     = false
local whitescreenEnabled  = false
local blackscreenEnabled  = false

local targetRarity  = "Legendary"
local tweenSpeed    = 310
local reelDelay     = 0.05
local sellInterval  = 10
local autoSellDelay = 30
local catchCount    = 0

local syncedStart   = nil
local syncedRelease = nil
local syncedDamage  = nil
local syncedSkill   = nil
local syncedSellOne = nil
local syncedSellAll = nil

local customX, customY, customZ = 0, 0, 0
local currentIslandIndex = 1

local farmThread      = nil
local rollThread      = nil
local antiAfkThread   = nil
local antiAdminThread = nil
local autoSellThread  = nil

-- ==================== TIỆN ÍCH ====================
local function getHRP()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function snapTo(cf)
    local hrp = getHRP()
    if hrp then
        pcall(function() hrp.CFrame = cf end)
    end
end

local function teleportTo(cf)
    local hrp = getHRP()
    if not hrp then return end
    local ok, dist = pcall(function()
        return (hrp.Position - cf.Position).Magnitude
    end)
    if not ok then return end
    local dur = math.max(dist / tweenSpeed, 0.05)
    local ok2, tw = pcall(function()
        return TweenService:Create(hrp, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = cf})
    end)
    if ok2 and tw then
        tw:Play()
        tw.Completed:Wait()
    end
end

local function findGui(keywords, class)
    class = class or "TextButton"
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, obj in ipairs(pg:GetDescendants()) do
        if obj:IsA(class) and obj.Visible then
            local text = ""
            pcall(function() text = obj.Text or "" end)
            local src = (obj.Name .. " " .. text):lower()
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

local function fireRemote(name, ...)
    local r = Remote[name]
    if not r then return false end
    local args = {...}
    if r:IsA("RemoteEvent") then
        pcall(function() r:FireServer(table.unpack(args)) end)
        return true
    elseif r:IsA("RemoteFunction") then
        local ok, res = pcall(function() return r:InvokeServer(table.unpack(args)) end)
        return ok and res
    end
    return false
end

-- sendClick() defined in compat layer above

-- ==================== ĐỌC LEVEL ====================
-- Format game: "Level: 1 [0/40]"
local function getPlayerLevel()
    -- Cách 1: Leaderstats
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        for _, name in ipairs({"Level", "Lvl", "LVL", "level", "Rank"}) do
            local stat = ls:FindFirstChild(name)
            if stat then
                local val = tonumber(stat.Value)
                if val then return val end
            end
        end
    end

    -- Cách 2: PlayerData
    for _, folder in ipairs({"PlayerData", "Data", "Stats"}) do
        local data = player:FindFirstChild(folder)
        if data then
            for _, name in ipairs({"Level", "Lvl", "level", "Rank"}) do
                local stat = data:FindFirstChild(name)
                if stat then
                    local val = tonumber(stat.Value)
                    if val then return val end
                end
            end
        end
    end

    -- Cách 3: Scan PlayerGui — "Level: 1 [0/40]"
    local pg = player:FindFirstChild("PlayerGui")
    if pg then
        for _, obj in ipairs(pg:GetDescendants()) do
            if obj:IsA("TextLabel") then
                local t = obj.Text or ""
                local num = t:match("[Ll]evel[%s:]*(%d+)")
                         or t:match("[Ll]vl[%s:]*(%d+)")
                         or t:match("[Rr]ank[%s:]*(%d+)")
                if num then return tonumber(num) end
            end
        end
    end

    -- Cách 4: CoreGui ScreenGui
    for _, sg in ipairs(CoreGui:GetChildren()) do
        if sg:IsA("ScreenGui") then
            for _, obj in ipairs(sg:GetDescendants()) do
                if obj:IsA("TextLabel") then
                    local t = obj.Text or ""
                    local num = t:match("[Ll]evel[%s:]*(%d+)")
                    if num then return tonumber(num) end
                end
            end
        end
    end

    return nil
end

-- ==================== ISLAND PROGRESSION ====================
local function getBestIslandIndex(level)
    local best = 1
    for i, island in ipairs(ISLANDS) do
        if level >= island.minLevel then best = i end
    end
    return best
end

local function canAdvanceIsland(level)
    local nxt = currentIslandIndex + 1
    if nxt > #ISLANDS then return false end
    return level >= ISLANDS[nxt].minLevel
end

local function getCurrentIsland()
    return ISLANDS[currentIslandIndex]
end

local function islandCFValid(island)
    local ok, mag = pcall(function() return island.cf.Position.Magnitude end)
    return ok and mag > 1
end

local function flyToCurrentIsland()
    local island = getCurrentIsland()
    if not islandCFValid(island) then
        Window:Notify({
            Title   = "CFrame Chua Co",
            Content = island.name .. " chua fill CFrame!",
            Duration = 4
        })
        return false
    end
    teleportTo(island.cf)
    Window:Notify({
        Title   = island.name,
        Content = "Lv yeu cau: " .. island.minLevel,
        Duration = 3
    })
    return true
end

-- ==================== HOOK __namecall (optional) ====================
-- Chỉ chạy nếu executor hỗ trợ, không crash nếu không có
local hookedNamecall = nil
if _hookmetamethod and _getnamecallmethod then
    pcall(function()
        hookedNamecall = _hookmetamethod(game, "__namecall", function(self, ...)
            local method = _getnamecallmethod()
            local args   = {...}
            if method == "InvokeServer" or method == "FireServer" then
                local ok, fullName = pcall(function() return self:GetFullName() end)
                if ok and fullName and fullName:find("Communication") then
                    local lname = self.Name:lower()
                    if lname:find("fish") or lname:find("cast") or lname:find("reel") or lname:find("start") then
                        for i, v in ipairs(args) do
                            if type(v) == "number" then
                                if i == 1 then syncedStart   = v end
                                if i == 2 then syncedRelease = v end
                                if i == 3 then syncedDamage  = v end
                                if i == 4 then syncedSkill   = v end
                            end
                        end
                    end
                    if lname:find("sell") then
                        for i, v in ipairs(args) do
                            if type(v) == "number" then
                                if i == 1 then syncedSellOne = v end
                                if i == 2 then syncedSellAll = v end
                            end
                        end
                    end
                end
            end
            return hookedNamecall(self, ...)
        end)
    end)
end

-- ==================== SYNC ====================
local function doSync()
    local syncNames = {"Sync", "Init", "Initialize", "SyncFishing", "GetData", "Connect"}
    for _, name in ipairs(syncNames) do
        local r = Remote[name]
        if r then
            pcall(function()
                if r:IsA("RemoteFunction") then
                    local res = r:InvokeServer()
                    if type(res) == "table" then
                        for k, v in pairs(res) do
                            local kl = tostring(k):lower()
                            if kl:find("start")   then syncedStart   = v end
                            if kl:find("release") then syncedRelease = v end
                            if kl:find("damage")  then syncedDamage  = v end
                            if kl:find("skill")   then syncedSkill   = v end
                        end
                    end
                else r:FireServer() end
            end)
        end
    end
    Window:Notify({Title = "Sync", Content = "Sync fishing xong!", Duration = 2})
end

local function doSyncShop()
    local syncNames = {"SyncShop", "InitShop", "ShopSync", "Sync", "Init"}
    for _, name in ipairs(syncNames) do
        local r = Remote[name]
        if r then
            pcall(function()
                if r:IsA("RemoteFunction") then r:InvokeServer()
                else r:FireServer() end
            end)
        end
    end
    Window:Notify({Title = "Sync Shop", Content = "Sync shop xong!", Duration = 2})
end

-- ==================== FISHING ====================
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
        sendClick()
        task.wait(reelDelay)
    end
end

local function doCast()
    local castNames = {"Cast", "CastLine", "StartFishing", "Throw", "Fish", "StartCast"}
    for _, name in ipairs(castNames) do
        if fireRemote(name) then return true end
    end
    local castBtn = findGui({"cast", "fish", "throw", "bait", "start"})
    if castBtn then clickGui(castBtn); return true end
    return false
end

local function doReel()
    local reelNames = {"Reel", "Pull", "ReelFish", "StartReel", "Damage", "Attack"}
    for _, name in ipairs(reelNames) do
        local fired
        if syncedStart then
            fired = fireRemote(name, syncedStart, syncedRelease, syncedDamage, syncedSkill)
        else
            fired = fireRemote(name)
        end
        if fired then return true end
    end
    spamClick(12)
    return true
end

-- ==================== SELL ====================
local function doSellOne()
    local sellNames = {"SellFish", "SellOne", "Sell", "SellOneFish"}
    for _, name in ipairs(sellNames) do
        local fired
        if syncedSellOne then fired = fireRemote(name, syncedSellOne)
        else fired = fireRemote(name) end
        if fired then
            Window:Notify({Title = "Sell", Content = "Da ban 1 ca!", Duration = 2})
            return
        end
    end
end

local function doSellAll()
    local sellNames = {"SellAllFish", "SellAll", "Sell", "SellFish"}
    local sold = false
    for _, name in ipairs(sellNames) do
        local fired
        if syncedSellAll then fired = fireRemote(name, syncedSellAll)
        else fired = fireRemote(name) end
        if fired then sold = true; break end
    end
    if not sold then
        local savedCF = getHRP() and getHRP().CFrame
        snapTo(CFrame.new(208.996, 22.445, 59.334))
        task.wait(0.5)
        local sellBtn = findGui({"sell all", "sell", "jual", "confirm"})
        if sellBtn then clickGui(sellBtn) end
        task.wait(0.3)
        if savedCF then snapTo(savedCF) end
    end
    catchCount = 0
    Window:Notify({Title = "Sell All", Content = "Da ban tat ca ca!", Duration = 2})
end

-- ==================== AUTO SELL LOOP ====================
local function autoSellLoop()
    while autoSellEnabled do
        task.wait(autoSellDelay)
        if autoSellEnabled then doSellAll() end
    end
end

-- ==================== AUTO FARM LOOP ====================
local function autoFarmLoop()
    if autoProgressEnabled then
        local lv = getPlayerLevel()
        if lv then
            currentIslandIndex = getBestIslandIndex(lv)
            Window:Notify({
                Title   = "Progression",
                Content = "Lv " .. lv .. " -> " .. ISLANDS[currentIslandIndex].name,
                Duration = 4
            })
        end
        flyToCurrentIsland()
        task.wait(1)
    end

    while autoFarmEnabled do
        -- Progression check
        if autoProgressEnabled then
            local lv = getPlayerLevel()
            if lv and canAdvanceIsland(lv) then
                currentIslandIndex = currentIslandIndex + 1
                Window:Notify({
                    Title   = "Next Island!",
                    Content = "Lv " .. lv .. " -> " .. getCurrentIsland().name,
                    Duration = 5
                })
                flyToCurrentIsland()
                task.wait(1)
            end
            -- Re-snap nếu drift quá xa
            local hrp    = getHRP()
            local island = getCurrentIsland()
            if hrp and islandCFValid(island) then
                local ok, dist = pcall(function()
                    return (hrp.Position - island.cf.Position).Magnitude
                end)
                if ok and dist > 50 then
                    teleportTo(island.cf)
                    task.wait(0.5)
                end
            end
        end

        -- Cast
        doCast()

        -- Chờ bite (timeout 15s)
        local biteTimer = 0
        local bitten    = false
        while biteTimer < 15 and autoFarmEnabled do
            if isInReelPhase() then bitten = true; break end
            task.wait(0.25)
            biteTimer = biteTimer + 0.25
        end

        -- Reel
        if bitten then
            doReel()
            local endT = 0
            while isInReelPhase() and endT < 8 and autoFarmEnabled do
                task.wait(0.2)
                endT = endT + 0.2
            end
            catchCount = catchCount + 1
        end

        -- Sell theo interval
        if not autoSellEnabled and catchCount >= sellInterval then
            doSellAll()
        end

        task.wait(0.3)
    end
end

-- ==================== ANTI ADMIN ====================
local adminKeywords      = {"admin", "mod", "moderator", "staff", "owner", "dev", "developer"}
local blacklistedServers = {}

local function isAdmin(p)
    local name    = p.Name:lower()
    local display = p.DisplayName:lower()
    for _, kw in ipairs(adminKeywords) do
        if name:find(kw) or display:find(kw) then return true end
    end
    return false
end

local function hopServer()
    local currentJobId = game.JobId
    table.insert(blacklistedServers, currentJobId)
    pcall(function()
        local ok, servers = pcall(function()
            return TeleportService:GetServersByPlaceId(game.PlaceId)
        end)
        if ok and servers then
            for _, server in ipairs(servers) do
                local blacklisted = false
                for _, id in ipairs(blacklistedServers) do
                    if id == server.Id then blacklisted = true; break end
                end
                if not blacklisted and server.Playing < server.MaxPlayers then
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, server.Id, player)
                    end)
                    return
                end
            end
        end
        pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
    end)
end

local function antiAdminLoop()
    while antiAdminEnabled do
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and isAdmin(p) then
                Window:Notify({
                    Title   = "Admin Detected!",
                    Content = p.Name .. " - Hop server...",
                    Duration = 3
                })
                task.wait(1)
                hopServer()
                return
            end
        end
        task.wait(5)
    end
end

-- ==================== ANTI AFK ====================
local function antiAfkLoop()
    local VirtualUser = nil
    pcall(function() VirtualUser = game:GetService("VirtualUser") end)
    while antiAfkEnabled do
        task.wait(60)
        if antiAfkEnabled and VirtualUser then
            pcall(function() VirtualUser:CaptureController() end)
            pcall(function() VirtualUser:ClickButton2(Vector2.new()) end)
        end
    end
end

-- ==================== SCREEN SAVER ====================
local screenGui = nil

local function removeScreenGui()
    if screenGui then
        pcall(function() screenGui:Destroy() end)
        screenGui = nil
    end
    whitescreenEnabled = false
    blackscreenEnabled = false
end

local function applyScreen(color)
    removeScreenGui()
    local ok, sg = pcall(function()
        local g = Instance.new("ScreenGui")
        g.Name           = "KhfreshScreen"
        g.ResetOnSpawn   = false
        g.DisplayOrder   = 9998
        g.IgnoreGuiInset = true
        g.Parent         = guiParent
        local f = Instance.new("Frame", g)
        f.Size                  = UDim2.new(1, 0, 1, 0)
        f.BackgroundColor3      = color
        f.BackgroundTransparency = 0
        f.BorderSizePixel       = 0
        f.ZIndex                = 9998
        return g
    end)
    if ok then screenGui = sg end
end

-- ==================== FPS BOOST ====================
local defaultFX = {}
local function applyFpsBoost()
    local L = game:GetService("Lighting")
    defaultFX.GlobalShadows  = L.GlobalShadows
    defaultFX.FogEnd         = L.FogEnd
    defaultFX.ShadowSoftness = L.ShadowSoftness
    pcall(function() L.GlobalShadows  = false end)
    pcall(function() L.FogEnd         = 9e9   end)
    pcall(function() L.ShadowSoftness = 0     end)
    for _, fx in ipairs(L:GetChildren()) do
        if fx:IsA("PostEffect") or fx:IsA("Atmosphere") then
            pcall(function() fx:Destroy() end)
        end
    end
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    Window:Notify({Title = "FPS Boost", Content = "Da bat!", Duration = 2})
end

local function removeFpsBoost()
    local L = game:GetService("Lighting")
    pcall(function() L.GlobalShadows  = defaultFX.GlobalShadows  or true  end)
    pcall(function() L.FogEnd         = defaultFX.FogEnd         or 100000 end)
    pcall(function() L.ShadowSoftness = defaultFX.ShadowSoftness or 0.5   end)
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
    end)
    Window:Notify({Title = "FPS Boost", Content = "Da tat.", Duration = 2})
end

-- ==================== AUTO ROLL ====================
local rarityRank = {Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythical = 5}

local function getRarityFromText(text)
    if not text then return nil end
    text = text:lower()
    if text:find("mythic")  then return "Mythical"
    elseif text:find("legend") then return "Legendary"
    elseif text:find("epic")   then return "Epic"
    elseif text:find("rare")   then return "Rare"
    elseif text:find("common") then return "Common" end
    return nil
end

local function tryRollRemote()
    local rollNames = {
        "SpinSkill","RollSkill","Spin","Roll","Gacha",
        "DrawSkill","GetSkill","RerollSkill","SkillSpin",
        "SpinBook","RollBook","Innate","InnateRoll"
    }
    for _, name in ipairs(rollNames) do
        local r = Remote[name]
        if r then
            local ok, res = pcall(function()
                if r:IsA("RemoteFunction") then return r:InvokeServer()
                else r:FireServer(); return true end
            end)
            if ok then
                if type(res) == "string" then return getRarityFromText(res) end
                return true
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
        local hrp = getHRP()
        if not hrp then task.wait(1); continue end
        local savedCF = hrp.CFrame

        local remoteResult = tryRollRemote()
        local gotRarity    = nil

        if remoteResult then
            if type(remoteResult) == "string" then gotRarity = remoteResult end
            task.wait(2)
            gotRarity = gotRarity or readRarityFromGui()
        else
            snapTo(SKILLBOOK_CF)
            task.wait(0.2)
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ClickDetector") then
                    local n = (obj.Parent and obj.Parent.Name or ""):lower()
                    if n:find("skill") or n:find("book") or n:find("spin") then
                        safeFireCD(obj); break
                    end
                end
            end
            task.wait(0.5)
            local spinBtn = findGui({"spin","roll","draw","gacha","quay","reroll","summon"})
            if spinBtn then
                clickGui(spinBtn)
                task.wait(2.5)
                gotRarity = readRarityFromGui()
            end
            local closeBtn = findGui({"close","ok","back","cancel","tiep","continue","exit"})
            if closeBtn then clickGui(closeBtn) end
            task.wait(0.2)
            snapTo(savedCF)
        end

        if gotRarity then
            local rank   = rarityRank[gotRarity] or 0
            local target = rarityRank[targetRarity] or 4
            Window:Notify({Title = "Auto Roll", Content = "Roll: " .. gotRarity, Duration = 2})
            if rank >= target then
                Window:Notify({Title = "Auto Roll OK", Content = "Dat " .. gotRarity .. "! Dung.", Duration = 6})
                autoRollEnabled = false
                break
            end
        end
        task.wait(0.5)
    end
end

-- ==================== GUI ====================

-- ─── FISHING TAB ───
local FishingTab = Window:Tab({Icon = "fish", Title = "Fishing"})

FishingTab:Label({Title = "--- Main Fishing ---"})

FishingTab:Button({
    Title = "Step 1: Sync Server",
    Description = "Sync truoc khi dung Auto Fish",
    Callback = function() doSync() end
})

FishingTab:Toggle({
    Title = "Auto Fish",
    Description = "Tu dong cast → reel",
    Value = false,
    Callback = function(v)
        autoFarmEnabled = v
        if v then
            farmThread = task.spawn(autoFarmLoop)
        else
            if farmThread then pcall(task.cancel, farmThread) end
        end
    end
})

FishingTab:Toggle({
    Title = "Island Progression",
    Description = "Tu bay dao phu hop level, du lv → sang dao tiep",
    Value = false,
    Callback = function(v) autoProgressEnabled = v end
})

FishingTab:Slider({
    Title = "Reel Speed",
    Description = "Delay spam click (nho = nhanh hon)",
    Min = 0.01, Max = 0.3, Default = 0.05,
    Callback = function(v) reelDelay = v end
})

FishingTab:Label({Title = "--- Island Config ---"})

FishingTab:Button({
    Title = "Xem Level Hien Tai",
    Callback = function()
        local lv = getPlayerLevel()
        if lv then
            Window:Notify({
                Title   = "Level: " .. lv,
                Content = "Island tot nhat: " .. ISLANDS[getBestIslandIndex(lv)].name,
                Duration = 4
            })
        else
            Window:Notify({Title = "Khong doc duoc level", Content = "Check console.", Duration = 3})
        end
    end
})

FishingTab:Dropdown({
    Title = "Farm Island (Manual)",
    Options = {"Island 1","Island 2","Island 3","Island 4","Island 5"},
    Default = "Island 1",
    Callback = function(v)
        for i, island in ipairs(ISLANDS) do
            if island.name == v then
                currentIslandIndex = i
                Window:Notify({Title = "Island Override", Content = v, Duration = 2})
                break
            end
        end
    end
})

FishingTab:Button({
    Title = "Fly to Current Island",
    Callback = function() flyToCurrentIsland() end
})

FishingTab:Label({Title = "--- Manual Override ---"})
FishingTab:Input({Title = "Number START",   Default = "", Callback = function(v) syncedStart   = tonumber(v) end})
FishingTab:Input({Title = "Number RELEASE", Default = "", Callback = function(v) syncedRelease = tonumber(v) end})
FishingTab:Input({Title = "Number DAMAGE",  Default = "", Callback = function(v) syncedDamage  = tonumber(v) end})
FishingTab:Input({Title = "Number SKILL",   Default = "", Callback = function(v) syncedSkill   = tonumber(v) end})

-- ─── SHOP TAB ───
local ShopTab = Window:Tab({Icon = "shopping-cart", Title = "Shop"})

ShopTab:Label({Title = "--- Safe Selling ---"})

ShopTab:Button({
    Title = "Step One: Sync Shop",
    Callback = function() doSyncShop() end
})

ShopTab:Button({
    Title = "Sell One Fish",
    Callback = function() doSellOne() end
})

ShopTab:Button({
    Title = "Sell All Fish",
    Callback = function() doSellAll() end
})

ShopTab:Label({Title = "--- Auto Selling ---"})

ShopTab:Toggle({
    Title = "Auto Sell All Fish",
    Description = "Tu dong ban all fish theo delay",
    Value = false,
    Callback = function(v)
        autoSellEnabled = v
        if v then
            autoSellThread = task.spawn(autoSellLoop)
        else
            if autoSellThread then pcall(task.cancel, autoSellThread) end
        end
    end
})

ShopTab:Slider({
    Title = "Delay Auto Sell (Detik)",
    Min = 5, Max = 300, Default = 30,
    Callback = function(v) autoSellDelay = v end
})

ShopTab:Label({Title = "--- Manual Override ---"})
ShopTab:Input({Title = "Number Sell One Fish", Default = "", Callback = function(v) syncedSellOne = tonumber(v) end})
ShopTab:Input({Title = "Number Sell All Fish", Default = "", Callback = function(v) syncedSellAll = tonumber(v) end})

-- ─── SKILL TAB ───
local SkillTab = Window:Tab({Icon = "zap", Title = "Skill"})

SkillTab:Toggle({
    Title = "Auto Roll Skill Book",
    Description = "Roll khong can den NPC",
    Value = false,
    Callback = function(v)
        autoRollEnabled = v
        if v then
            rollThread = task.spawn(autoRollLoop)
        else
            if rollThread then pcall(task.cancel, rollThread) end
        end
    end
})

SkillTab:Dropdown({
    Title = "Target Rarity",
    Options = {"Common","Rare","Epic","Legendary","Mythical"},
    Default = "Legendary",
    Callback = function(v) targetRarity = v end
})

SkillTab:Button({
    Title = "Roll 1x (Manual)",
    Callback = function()
        local r = tryRollRemote()
        task.wait(2)
        local got = (type(r) == "string" and r) or readRarityFromGui() or "?"
        Window:Notify({Title = "Roll", Content = "Ket qua: " .. got, Duration = 4})
    end
})

-- ─── SECURITY TAB ───
local SecurityTab = Window:Tab({Icon = "shield", Title = "Security"})

SecurityTab:Label({Title = "--- Server Protection ---"})

SecurityTab:Toggle({
    Title = "Anti Admin (Hop Server)",
    Description = "Tu hop khi detect admin trong server",
    Value = false,
    Callback = function(v)
        antiAdminEnabled = v
        if v then
            antiAdminThread = task.spawn(antiAdminLoop)
            Window:Notify({Title = "Anti Admin", Content = "Da bat! Scan moi 5 giay.", Duration = 3})
        else
            if antiAdminThread then pcall(task.cancel, antiAdminThread) end
        end
    end
})

SecurityTab:Label({Title = "--- Utility ---"})

SecurityTab:Toggle({
    Title = "Anti AFK",
    Description = "Ngan game kick do AFK",
    Value = false,
    Callback = function(v)
        antiAfkEnabled = v
        if v then
            antiAfkThread = task.spawn(antiAfkLoop)
        else
            if antiAfkThread then pcall(task.cancel, antiAfkThread) end
        end
    end
})

SecurityTab:Toggle({
    Title = "White Screen (CPU Saver)",
    Description = "Man trang de giam GPU load",
    Value = false,
    Callback = function(v)
        whitescreenEnabled = v
        blackscreenEnabled = false
        if v then applyScreen(Color3.new(1, 1, 1))
        else removeScreenGui() end
    end
})

SecurityTab:Toggle({
    Title = "Black Screen (Battery Saver)",
    Description = "Man den de tiet kiem pin",
    Value = false,
    Callback = function(v)
        blackscreenEnabled = v
        whitescreenEnabled = false
        if v then applyScreen(Color3.new(0, 0, 0))
        else removeScreenGui() end
    end
})

-- ─── SETTINGS TAB ───
local SettingsTab = Window:Tab({Icon = "settings", Title = "Settings"})

SettingsTab:Toggle({
    Title = "FPS Boost",
    Description = "Tat shadow/fog/PostEffect",
    Value = false,
    Callback = function(v)
        fpsBoostEnabled = v
        if v then applyFpsBoost() else removeFpsBoost() end
    end
})

SettingsTab:Slider({
    Title = "Tween Speed (studs/s)",
    Min = 50, Max = 2000, Default = 310,
    Callback = function(v) tweenSpeed = v end
})

SettingsTab:Button({
    Title = "In Remote List (Debug)",
    Callback = function()
        refreshRemotes()
        print("=== Remote List ===")
        for name, r in pairs(Remote) do
            print(r.ClassName, name, r:GetFullName())
        end
        Window:Notify({Title = "Debug", Content = "Check console!", Duration = 3})
    end
})

SettingsTab:Button({
    Title = "Copy Current CFrame",
    Description = "Dung dung cho → bam → copy CFrame",
    Callback = function()
        local hrp = getHRP()
        if hrp then
            local cf  = hrp.CFrame
            local str = string.format(
                "CFrame.new(%.6f, %.6f, %.6f, %.9f, %.9f, %.9f, %.9f, %.9f, %.9f, %.9f, %.9f, %.9f)",
                cf.X, cf.Y, cf.Z,
                cf.XVector.X, cf.XVector.Y, cf.XVector.Z,
                cf.YVector.X, cf.YVector.Y, cf.YVector.Z,
                cf.ZVector.X, cf.ZVector.Y, cf.ZVector.Z
            )
            safeCopyClipboard(str)
            Window:Notify({Title = "CFrame Copied!", Content = str:sub(1, 55) .. "...", Duration = 5})
            print("[CFrame]", str)
        end
    end
})

SettingsTab:Button({
    Title = "Rejoin Server",
    Callback = function()
        pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
    end
})

-- ─── TELEPORT TAB ───
local TeleportTab = Window:Tab({Icon = "map-pinned", Title = "Teleport"})

TeleportTab:Label({Title = "--- Islands ---"})
for _, island in ipairs(ISLANDS) do
    local isl = island
    TeleportTab:Button({
        Title = isl.name .. " (Lv " .. isl.minLevel .. "+)",
        Callback = function()
            if not islandCFValid(isl) then
                Window:Notify({Title = "Chua co CFrame", Content = isl.name, Duration = 3})
                return
            end
            teleportTo(isl.cf)
            Window:Notify({Title = "Teleport", Content = isl.name, Duration = 2})
        end
    })
end

TeleportTab:Label({Title = "--- Locations ---"})
local locations = {
    ["Skill Book"] = CFrame.new(120.668, 67.663, -41.885),
    ["Skill Shop"] = CFrame.new(208.996, 22.445,  59.334),
    ["Sell Fish"]  = CFrame.new(208.996, 22.445,  59.334),
}
for name, cf in pairs(locations) do
    local n, c = name, cf
    TeleportTab:Button({
        Title = n,
        Callback = function()
            teleportTo(c)
            Window:Notify({Title = "Teleport", Content = n, Duration = 2})
        end
    })
end

TeleportTab:Label({Title = "--- Custom XYZ ---"})
TeleportTab:Input({Title = "X", Default = "0", Callback = function(v) customX = tonumber(v) or 0 end})
TeleportTab:Input({Title = "Y", Default = "0", Callback = function(v) customY = tonumber(v) or 0 end})
TeleportTab:Input({Title = "Z", Default = "0", Callback = function(v) customZ = tonumber(v) or 0 end})
TeleportTab:Button({
    Title = "Go to XYZ",
    Callback = function()
        teleportTo(CFrame.new(customX, customY, customZ))
        Window:Notify({
            Title = "Teleport",
            Content = string.format("(%.1f, %.1f, %.1f)", customX, customY, customZ),
            Duration = 2
        })
    end
})

-- ==================== DRAG BUTTON ====================
local ok_gui = pcall(function()
    local guiButton = Instance.new("ScreenGui")
    guiButton.Name          = "KhfreshHubButton"
    guiButton.ResetOnSpawn  = false
    guiButton.Parent        = guiParent
    local dragBtn = Instance.new("ImageButton")
    dragBtn.Parent                 = guiButton
    dragBtn.BackgroundColor3       = Color3.fromRGB(25, 25, 25)
    dragBtn.Position               = UDim2.new(0, 25, 0.5, -27)
    dragBtn.Size                   = UDim2.new(0, 55, 0, 55)
    dragBtn.Image                  = "rbxassetid://80225033364855"
    dragBtn.BackgroundTransparency = 0.3
    dragBtn.Draggable              = true
    dragBtn.MouseButton1Click:Connect(function() Window:Toggle() end)
    Instance.new("UICorner", dragBtn).CornerRadius = UDim.new(0, 12)
end)

-- ==================== GC ====================
task.spawn(function()
    while true do
        task.wait(300)
        pcall(function() AssetService:ClearContentCache() end)
        pcall(collectgarbage, "collect")
    end
end)

-- ==================== STARTUP ====================
task.wait(1)

print("[KhfreshHub] hookmetamethod : " .. (_hookmetamethod ~= nil and "YES" or "NO"))
print("[KhfreshHub] fireclickdetector: " .. (_fireclickdetector ~= nil and "YES" or "NO"))
print("[KhfreshHub] setclipboard     : " .. (_setclipboard ~= nil and "YES" or "NO"))
print("[KhfreshHub] tap()            : " .. (_tap ~= nil and "YES" or "NO"))
print("[KhfreshHub] VIM              : " .. (_vim ~= nil and "YES" or "NO"))

local clickMode = IS_DELTA_X and (_tap and "tap()" or "remote-only") or (_vim and "VirtualInputManager" or "none")
print("[KhfreshHub] Click mode       : " .. clickMode)

Window:Notify({
    Title   = "Khfresh Hub v31",
    Content = "Loaded! Executor: " .. EXEC_NAME,
    Duration = 5
})
print("Khfresh Hub v31 - Titan Fishing loaded.")
