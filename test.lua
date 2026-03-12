--[[
    Tên Script: Khfresh Hub v23 - Fixed & Optimized
    Mô tả: Script hỗ trợ tự động câu cá và teleport trong game.
    Đã sửa lỗi: Auto Farm, Dropdown skill, Teleport dùng Tween với tốc độ 310 studs/s
              Thêm nút Auto Use VIP Skill, điểm Store, Auto Spin Skill Book (không teleport)
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetService = game:GetService("AssetService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local guiParent = gethui and gethui() or CoreGui

-- Tải và khởi tạo thư viện WindUI
local WindUI
local success, result = pcall(function()
    local windUIContent = game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua")
    WindUI = loadstring(windUIContent)()
end)

if not (success and WindUI) then
    warn("Không thể tải WindUI. Script sẽ không hoạt động.")
    return
end

-- Tạo cửa sổ chính
local Window = WindUI:CreateWindow({
    Author = "AwesomeKhfresh",
    Folder = "KhfreshHub_V23",
    Icon = "rbxassetid://97028818666741",
    Size = UDim2.fromOffset(560, 460),
    Theme = "Dark",
    Title = "Khfresh Hub v23 - Optimized"
})

-- Biến toàn cục
local autoFarmEnabled = false
local autoSkillEnabled = false
local selectedSkills = {}
local farmThread = nil
local skillThread = nil
local clickDelay = 0.5
local tweenSpeed = 310 -- tốc độ mặc định (studs/s)

-- Hàm tìm Fishing Button
local function findFishingButton()
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        for _, gui in ipairs(playerGui:GetDescendants()) do
            if gui:IsA("TextButton") or gui:IsA("ImageButton") then
                if gui.Name:lower():find("fish") or gui.Name:lower():find("cast") then
                    return gui
                end
            end
        end
    end
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Part") and obj:FindFirstChild("ClickDetector") then
            if obj.Name:lower():find("fish") or obj.Name:lower():find("water") then
                return obj
            end
        end
    end
    
    return nil
end

-- Hàm mô phỏng click (ưu tiên :Click() không di chuột)
local function simulateClick(target)
    if not target then return false end
    
    if target:IsA("GuiButton") then
        local success, err = pcall(function()
            target:Click()
        end)
        if success then 
            return true 
        else
            local pos = target.AbsolutePosition + (target.AbsoluteSize / 2)
            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 1)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 1)
            return true
        end
    elseif target:IsA("Part") and target:FindFirstChild("ClickDetector") then
        local detector = target:FindFirstChild("ClickDetector")
        if detector then
            fireclickdetector(detector)
            return true
        end
    end
    
    return false
end

-- Auto Farm Loop
local function autoFarmLoop()
    while autoFarmEnabled do
        local fishingButton = findFishingButton()
        if fishingButton then
            simulateClick(fishingButton)
        end
        task.wait(clickDelay)
    end
end

local function startAutoFarm()
    if farmThread then
        task.cancel(farmThread)
        farmThread = nil
    end
    farmThread = task.spawn(autoFarmLoop)
end

local function stopAutoFarm()
    autoFarmEnabled = false
    farmThread = nil
end

-- Auto Skill Loop
local function autoSkillLoop()
    while autoSkillEnabled do
        if #selectedSkills > 0 then
            for _, skill in ipairs(selectedSkills) do
                local keyCode = Enum.KeyCode[skill]
                if keyCode then
                    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
                    task.wait(0.1)
                    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
                    task.wait(0.2)
                end
            end
        end
        task.wait(1)
    end
end

local function startAutoSkill()
    if skillThread then
        task.cancel(skillThread)
        skillThread = nil
    end
    skillThread = task.spawn(autoSkillLoop)
end

local function stopAutoSkill()
    autoSkillEnabled = false
    skillThread = nil
end

-- Tab Fishing
local FishingTab = Window:Tab({Icon = "fish", Title = "Fishing"})

FishingTab:Toggle({
    Title = "Auto Farm",
    Description = "Tự động Click vào FishingButton",
    Value = false,
    Callback = function(value)
        autoFarmEnabled = value
        if autoFarmEnabled then
            startAutoFarm()
            Window:Notify({Title = "Khfresh Hub", Content = "Auto Farm đã được bật!", Duration = 3})
        else
            stopAutoFarm()
            Window:Notify({Title = "Khfresh Hub", Content = "Auto Farm đã tắt", Duration = 3})
        end
    end
})

FishingTab:Slider({
    Title = "Click Delay (seconds)",
    Description = "Thời gian chờ giữa các lần click",
    Min = 0.1,
    Max = 2,
    Default = 0.5,
    Callback = function(value)
        clickDelay = value
    end
})

local skillOptions = {"Z", "X", "C", "V"}
local skillDropdown = FishingTab:Dropdown({
    Title = "Select Skills",
    Description = "Chọn các phím kỹ năng sẽ tự động sử dụng",
    Multi = true,
    Options = skillOptions,
    Callback = function(values)
        selectedSkills = values
        print("Kỹ năng đã chọn:", table.concat(selectedSkills, ", "))
        if #selectedSkills > 0 then
            Window:Notify({Title = "Khfresh Hub", Content = "Đã chọn " .. #selectedSkills .. " kỹ năng: " .. table.concat(selectedSkills, ", "), Duration = 3})
        end
    end
})

task.spawn(function()
    task.wait(0.5)
    skillDropdown:Refresh(skillOptions, true)
    if skillDropdown and skillDropdown.Main then
        skillDropdown.Main.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    end
end)

FishingTab:Toggle({
    Title = "Auto Skill",
    Description = "Tự động sử dụng kỹ năng đã chọn",
    Value = false,
    Callback = function(value)
        autoSkillEnabled = value
        if autoSkillEnabled then
            if #selectedSkills == 0 then
                Window:Notify({Title = "Cảnh báo", Content = "Vui lòng chọn kỹ năng trước!", Duration = 3})
                autoSkillEnabled = false
                return
            end
            startAutoSkill()
            Window:Notify({Title = "Khfresh Hub", Content = "Auto Skill đã được bật!", Duration = 3})
        else
            stopAutoSkill()
            Window:Notify({Title = "Khfresh Hub", Content = "Auto Skill đã tắt", Duration = 3})
        end
    end
})

FishingTab:Button({
    Title = "Test Find Fishing Button",
    Description = "Kiểm tra tìm nút câu cá",
    Callback = function()
        local button = findFishingButton()
        if button then
            Window:Notify({Title = "Thành công", Content = "Đã tìm thấy Fishing Button: " .. button.ClassName .. " - " .. button.Name, Duration = 5})
        else
            Window:Notify({Title = "Thất bại", Content = "Không tìm thấy Fishing Button!", Duration = 3})
        end
    end
})

-- ==================== AUTO USE VIP SKILL ====================
FishingTab:Button({
    Title = "Auto Use VIP Skill",
    Description = "Tự động vào Inventory, chọn cần câu hiện tại và dùng skill VIP nhất",
    Callback = function()
        task.spawn(function()
            Window:Notify({Title = "VIP Skill", Content = "Đang xử lý...", Duration = 2})
            
            local function openInventory()
                local playerGui = player:FindFirstChild("PlayerGui")
                if not playerGui then return false end
                for _, gui in ipairs(playerGui:GetDescendants()) do
                    if gui:IsA("TextButton") or gui:IsA("ImageButton") then
                        local name = gui.Name:lower()
                        if name:find("inventory") or name:find("bag") or name:find("backpack") then
                            simulateClick(gui)
                            task.wait(0.5)
                            return true
                        end
                    end
                end
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.I, false, game)
                task.wait(0.1)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.I, false, game)
                task.wait(0.5)
                return true
            end
            
            local function findCurrentRod()
                local playerGui = player:FindFirstChild("PlayerGui")
                if not playerGui then return nil end
                for _, gui in ipairs(playerGui:GetDescendants()) do
                    if gui:IsA("ImageButton") or gui:IsA("TextButton") then
                        local itemName = gui.Name:lower()
                        if itemName:find("rod") or itemName:find("cần") or itemName:find("lean") or itemName:find("reel") then
                            return gui
                        end
                    end
                end
                for _, gui in ipairs(playerGui:GetDescendants()) do
                    if gui:IsA("ImageButton") then
                        for _, child in ipairs(gui:GetChildren()) do
                            if child:IsA("TextLabel") and child.Text:lower():find("equipped") then
                                return gui
                            end
                        end
                    end
                end
                return nil
            end
            
            local function selectVipSkill()
                task.wait(0.5)
                local playerGui = player:FindFirstChild("PlayerGui")
                if not playerGui then return false end
                local skillButtons = {}
                for _, gui in ipairs(playerGui:GetDescendants()) do
                    if gui:IsA("TextButton") or gui:IsA("ImageButton") then
                        local fullText = gui.Name:lower()
                        local textLabel = gui:FindFirstChild("TextLabel")
                        if textLabel then
                            fullText = fullText .. " " .. textLabel.Text:lower()
                        end
                        local priority = 0
                        if fullText:find("vip") or fullText:find("legend") then priority = 4
                        elseif fullText:find("epic") then priority = 3
                        elseif fullText:find("rare") then priority = 2
                        elseif fullText:find("common") then priority = 1
                        end
                        if priority > 0 then
                            table.insert(skillButtons, {button = gui, priority = priority})
                        end
                    end
                end
                table.sort(skillButtons, function(a, b) return a.priority > b.priority end)
                if #skillButtons > 0 then
                    simulateClick(skillButtons[1].button)
                    task.wait(0.2)
                    return true
                end
                return false
            end
            
            if not openInventory() then
                Window:Notify({Title = "VIP Skill", Content = "Không thể mở Inventory!", Duration = 3})
                return
            end
            local rod = findCurrentRod()
            if rod then
                simulateClick(rod)
                if selectVipSkill() then
                    Window:Notify({Title = "VIP Skill", Content = "Đã chọn skill VIP!", Duration = 3})
                else
                    Window:Notify({Title = "VIP Skill", Content = "Không tìm thấy skill VIP!", Duration = 3})
                end
            else
                Window:Notify({Title = "VIP Skill", Content = "Không tìm thấy cần câu hiện tại!", Duration = 3})
            end
        end)
    end
})
-- ==================== KẾT THÚC AUTO VIP SKILL ====================

-- ==================== TELEPORT TAB (TỐC ĐỘ 310) ====================
local TeleportTab = Window:Tab({Icon = "map-pinned", Title = "Teleport"})

local function teleportWithTween(target)
    local character = player.Character
    if not character then
        character = player.CharacterAdded:Wait()
    end
    
    local hrp = character:WaitForChild("HumanoidRootPart", 5)
    if hrp then
        local destCFrame
        if typeof(target) == "CFrame" then
            destCFrame = target
        else
            destCFrame = CFrame.new(target)
        end
        
        local distance = (hrp.Position - destCFrame.Position).Magnitude
        local duration = math.max(distance / tweenSpeed, 0.1)
        
        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
        local goal = {CFrame = destCFrame}
        local tween = TweenService:Create(hrp, tweenInfo, goal)
        tween:Play()
        
        tween.Completed:Wait()
        
        Window:Notify({
            Title = "Teleport",
            Content = string.format("Đã dịch chuyển! (%.1f studs)", distance),
            Duration = 2
        })
    else
        warn("Không thể teleport: Thiếu HumanoidRootPart.")
    end
end

-- Hàm tìm nút spin trong GUI
local function findSpinButton()
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    for _, gui in ipairs(playerGui:GetDescendants()) do
        if gui:IsA("TextButton") or gui:IsA("ImageButton") then
            local txt = gui.Name:lower() .. " " .. (gui:FindFirstChild("TextLabel") and gui:FindFirstChild("TextLabel").Text:lower() or "")
            if txt:find("spin") or txt:find("roll") or txt:find("gacha") or txt:find("mở") or txt:find("quay") then
                return gui
            end
        end
    end
    return nil
end

-- Thanh trượt điều chỉnh tốc độ
TeleportTab:Slider({
    Title = "Tween Speed (studs/s)",
    Description = "Tốc độ di chuyển (mặc định 310)",
    Min = 100,
    Max = 1000,
    Default = 310,
    Callback = function(value)
        tweenSpeed = value
    end
})

-- Danh sách điểm teleport (hỗn hợp Vector3 và CFrame)
local teleportPoints = {
    ["Island 1"] = CFrame.new(282, 29.8, 51.2),
    ["Island 2"] = CFrame.new(1491.4, 25.6, -451.1),
    ["Island 3"] = CFrame.new(990, 28.1, 1272),
    ["Island 4"] = CFrame.new(631.4, 28.1, -846.7),
    ["Island 5"] = CFrame.new(-337.1, 29.9, 829.6),
    -- Skill Book (NPC random skill)
    ["Skill Book"] = CFrame.new(
        120.66777, 67.662674, -41.885273,
        -0.0367827006, 1.6738765e-08, 0.999323308,
        8.67729284e-08, 1, -1.35561962e-08,
        -0.999323308, 8.62155716e-08, -0.0367827006
    ),
    -- Skill Shop
    ["Skill Shop"] = CFrame.new(
        208.996475, 22.4446487, 59.3335266,
        0.131857201, 7.43682804e-08, 0.991268694,
        -6.4368777e-08, 1, -6.64610837e-08,
        -0.991268694, -5.50433832e-08, 0.131857201
    ),
    -- Sell Fish
    ["Sell Fish"] = CFrame.new(
        208.996475, 22.4446487, 59.3335266,
        0.131857201, -8.01955267e-08, 0.991268694,
        6.94082871e-08, 1, 7.16693052e-08,
        -0.991268694, 5.93521499e-08, 0.131857201
    ),
    -- Store (mua cần câu, mồi câu)
    ["Store"] = CFrame.new(
        168.836685, 23.9898472, 73.5896072,
        0.199367687, -5.60842262e-10, 0.979924738,
        -2.40166269e-08, 1, 5.45856382e-09,
        -0.979924738, -2.46227501e-08, 0.199367687
    )
}

-- Tạo các nút teleport thông thường
for name, pos in pairs(teleportPoints) do
    TeleportTab:Button({
        Title = "Teleport to " .. name,
        Callback = function()
            teleportWithTween(pos)
        end
    })
end

-- Nút teleport nhanh đến đảo gần nhất
TeleportTab:Button({
    Title = "Quick Teleport",
    Description = "Teleport đến đảo gần nhất",
    Callback = function()
        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        local currentPos = hrp.Position
        local nearestPoint = nil
        local nearestDistance = math.huge
        
        for name, pos in pairs(teleportPoints) do
            local posVec = typeof(pos) == "CFrame" and pos.Position or pos
            -- Chỉ xét các đảo chính (Island), có thể bỏ qua các điểm khác nếu muốn
            if name:find("Island") then
                local dist = (currentPos - posVec).Magnitude
                if dist < nearestDistance then
                    nearestDistance = dist
                    nearestPoint = pos
                end
            end
        end
        
        if nearestPoint then
            teleportWithTween(nearestPoint)
        else
            Window:Notify({Title = "Quick Teleport", Content = "Không tìm thấy đảo nào!", Duration = 2})
        end
    end
})

-- Nút Auto Spin Skill Book (KHÔNG teleport, tìm và tương tác từ xa)
TeleportTab:Button({
    Title = "Auto Spin Skill Book",
    Description = "Tìm NPC Skill Book và tự động spin (từ xa nếu có thể)",
    Callback = function()
        task.spawn(function()
            Window:Notify({Title = "Auto Spin", Content = "Đang tìm NPC Skill Book...", Duration = 2})
            
            -- Tìm NPC Skill Book trong toàn bộ workspace
            local npcFound = false
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Part") and obj:FindFirstChild("ClickDetector") then
                    local name = obj.Name:lower()
                    -- Kết hợp thêm kiểm tra vị trí gần với tọa độ Skill Book để tăng độ chính xác
                    local distFromBook = (obj.Position - teleportPoints["Skill Book"].Position).Magnitude
                    if distFromBook < 20 and (name:find("skill") or name:find("book") or name:find("npc") or name:find("gacha")) then
                        fireclickdetector(obj:FindFirstChild("ClickDetector"))
                        npcFound = true
                        break
                    end
                end
            end
            
            if not npcFound then
                Window:Notify({Title = "Auto Spin", Content = "Không tìm thấy NPC Skill Book gần điểm đã định!", Duration = 3})
                return
            end
            
            task.wait(1) -- đợi menu mở
            
            -- Tìm nút spin
            local spinBtn = findSpinButton()
            if spinBtn then
                simulateClick(spinBtn)
                Window:Notify({Title = "Auto Spin", Content = "Đã nhấn nút Spin!", Duration = 3})
            else
                Window:Notify({Title = "Auto Spin", Content = "Không tìm thấy nút Spin!", Duration = 3})
            end
        end)
    end
})
-- ==================== KẾT THÚC TELEPORT TAB ====================

-- Tab Settings
local SettingsTab = Window:Tab({Icon = "settings", Title = "Settings"})

SettingsTab:Button({
    Title = "Performance Mode",
    Description = "Xóa bỏ vật liệu và chi tiết thừa để mượt hơn",
    Callback = function()
        local deleted = 0
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Part") or obj:IsA("MeshPart") then
                if obj.Material == Enum.Material.Grass or 
                   obj.Material == Enum.Material.Leaves or
                   obj.Name:lower():find("grass") or
                   obj.Name:lower():find("leaf") then
                    obj:Destroy()
                    deleted = deleted + 1
                end
            end
        end
        Window:Notify({Title = "Performance Mode", Content = "Đã xóa " .. deleted .. " vật thể", Duration = 3})
    end
})

SettingsTab:Button({
    Title = "FPS Boost",
    Description = "Mở khóa FPS và giảm chất lượng render",
    Callback = function()
        pcall(function()
            setfpscap(9999)
        end)
        Lighting.Brightness = 3
        Lighting.GlobalShadows = false
        Lighting.ClockTime = 12
        Lighting.FogEnd = 1000
        Window:Notify({Title = "FPS Boost", Content = "Đã kích hoạt FPS Boost", Duration = 3})
    end
})

SettingsTab:Toggle({
    Title = "Full Brightness",
    Description = "Giúp nhìn rõ hơn trong khu vực tối",
    Callback = function(value)
        if value then
            Lighting.Brightness = 3
            Lighting.GlobalShadows = false
            Lighting.ClockTime = 12
            Lighting.FogEnd = 1000
        else
            Lighting.Brightness = 1
            Lighting.GlobalShadows = true
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
        end
    end
})

-- Nút GUI phụ
local guiButton = Instance.new("ScreenGui")
guiButton.Parent = guiParent
guiButton.Name = "KhfreshHubButton"
guiButton.ResetOnSpawn = false
guiButton.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local button = Instance.new("ImageButton")
button.Parent = guiButton
button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
button.Position = UDim2.new(0, 25, 0.5, -27.5)
button.Size = UDim2.new(0, 55, 0, 55)
button.Image = "rbxassetid://80225033364855"
button.BackgroundTransparency = 0.3
button.Active = true
button.Draggable = true

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = button

button.MouseButton1Click:Connect(function()
    Window:Toggle()
end)

button.MouseEnter:Connect(function()
    button.BackgroundTransparency = 0.1
end)

button.MouseLeave:Connect(function()
    button.BackgroundTransparency = 0.3
end)

-- Dọn dẹp cache định kỳ
task.spawn(function()
    while true do
        task.wait(300)
        pcall(function()
            AssetService:ClearContentCache()
            collectgarbage("collect")
        end)
    end
end)

-- Thông báo khởi động
task.wait(1)
Window:Notify({
    Title = "Khfresh Hub",
    Content = "Tối ưu hoàn tất! Tốc độ teleport mặc định 310 studs/s",
    Duration = 5
})

print("=== Khfresh Hub Loaded ===")
print("Player:", player.Name)
print("Auto Farm:", autoFarmEnabled)
print("Selected Skills:", #selectedSkills)
print("==========================")
