-- Da Hood | Auto Farm
-- Farms cashiers, collects drops, tracks stats

local Players    = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Character   = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP         = Character:WaitForChild("HumanoidRootPart")
local Humanoid    = Character:WaitForChild("Humanoid")

LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HRP       = char:WaitForChild("HumanoidRootPart")
    Humanoid  = char:WaitForChild("Humanoid")
end)

-- ── Stats ─────────────────────────────────────────────────────────────────────

local stats = {
    totalCash  = 0,
    profit     = 0,
    startCash  = 0,
    startTime  = tick(),
    running    = false,
}

local function getCash()
    local df = LocalPlayer:FindFirstChild("DataFolder")
    local c  = df and df:FindFirstChild("Currency")
    return c and c.Value or 0
end

local function formatTime(s)
    local m = math.floor(s / 60)
    local sec = math.floor(s % 60)
    return m .. "m" .. string.format("%02d", sec) .. "s"
end

-- ── Farm logic ────────────────────────────────────────────────────────────────

local function getTool()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return nil end
    for _, t in ipairs(backpack:GetChildren()) do
        if t:IsA("Tool") then return t end
    end
    -- also check if already equipped
    for _, t in ipairs(Character:GetChildren()) do
        if t:IsA("Tool") then return t end
    end
    return nil
end

local function collectDrops()
    task.wait(0.3)
    local drops = workspace:FindFirstChild("Ignored") and workspace.Ignored:FindFirstChild("Drop")
    if not drops then return end
    for _, money in ipairs(drops:GetChildren()) do
        if money.Name == "MoneyDrop" then
            local dist = (money.Position - HRP.Position).Magnitude
            if dist <= 25 then
                HRP.CFrame = money.CFrame
                local cd = money:FindFirstChildWhichIsA("ClickDetector")
                if cd then fireclickdetector(cd) end
                task.wait(0.2)
            end
        end
    end
end

local function farmCashiers()
    local tool = getTool()
    if not tool then
        warn("[Farm] No tool found in backpack")
        return
    end

    Humanoid:EquipTool(tool)
    task.wait(0.3)

    local cashiers = workspace:FindFirstChild("Cashiers")
    if not cashiers then
        warn("[Farm] Cashiers not found in workspace")
        return
    end

    for _, cashier in ipairs(cashiers:GetChildren()) do
        if not stats.running then break end

        local openPart = cashier:FindFirstChild("Open")
        if not openPart then continue end

        HRP.CFrame = openPart.CFrame * CFrame.new(0, 0, 2)
        task.wait(0.2)

        for i = 1, 15 do
            if not stats.running then break end
            task.wait(0.3)
            tool:Activate()
        end

        collectDrops()
    end
end

local farmThread = nil

local function startFarm()
    if stats.running then return end
    stats.running   = true
    stats.startCash = getCash()
    stats.startTime = tick()

    farmThread = task.spawn(function()
        while stats.running do
            farmCashiers()
            stats.totalCash = getCash()
            stats.profit    = stats.totalCash - stats.startCash
            task.wait(1)
        end
    end)
end

local function stopFarm()
    stats.running = false
    if farmThread then
        task.cancel(farmThread)
        farmThread = nil
    end
end

local function serverHop()
    stopFarm()
    local placeId = game.PlaceId
    local servers = {}
    local ok, result = pcall(function()
        return game:GetService("HttpService"):JSONDecode(
            game:HttpGet("https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100")
        )
    end)
    if ok and result and result.data then
        for _, s in ipairs(result.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                servers[#servers + 1] = s.id
            end
        end
    end
    if #servers > 0 then
        TeleportService:TeleportToPlaceInstance(placeId, servers[math.random(1, #servers)])
    else
        TeleportService:Teleport(placeId)
    end
end

-- ── UI ────────────────────────────────────────────────────────────────────────

local function buildUI()
    local pg = LocalPlayer:WaitForChild("PlayerGui")

    -- Remove old UI if re-executing
    local old = pg:FindFirstChild("VaultFarmUI")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "VaultFarmUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = pg

    -- Main frame
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 280)
    frame.Position = UDim2.new(0.5, -150, 0.5, -140)
    frame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(120, 60, 220)
    stroke.Thickness = 2
    stroke.Parent = frame

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 50)
    title.BackgroundTransparency = 1
    title.Text = "Da Hood | Auto Farm"
    title.TextColor3 = Color3.fromRGB(140, 80, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.Parent = frame

    -- Status label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 20)
    statusLabel.Position = UDim2.new(0, 0, 0, 50)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Idle"
    statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    statusLabel.Font = Enum.Font.GothamSemibold
    statusLabel.TextSize = 13
    statusLabel.Parent = frame

    -- Stats box
    local statsBox = Instance.new("Frame")
    statsBox.Size = UDim2.new(1, -30, 0, 90)
    statsBox.Position = UDim2.new(0, 15, 0, 80)
    statsBox.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    statsBox.BorderSizePixel = 0
    statsBox.Parent = frame

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 8)
    boxCorner.Parent = statsBox

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Color = Color3.fromRGB(80, 40, 160)
    boxStroke.Thickness = 1.5
    boxStroke.Parent = statsBox

    local function makeStatLabel(text, yPos)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -10, 0, 22)
        lbl.Position = UDim2.new(0, 10, 0, yPos)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = Color3.fromRGB(80, 255, 160)
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = statsBox
        return lbl
    end

    local cashLabel   = makeStatLabel("Total cash: $0",    5)
    local profitLabel = makeStatLabel("Profit: $0",        28)
    local timeLabel   = makeStatLabel("Time spent: 0m00s", 51)

    -- Buttons
    local function makeButton(text, xPos, color, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 120, 0, 36)
        btn.Position = UDim2.new(0, xPos, 0, 185)
        btn.BackgroundColor3 = color
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Text = text
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 13
        btn.BorderSizePixel = 0
        btn.Parent = frame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    local startBtn = makeButton("Start Farm", 15, Color3.fromRGB(100, 50, 200), function()
        if stats.running then
            stopFarm()
            startBtn.Text = "Start Farm"
            startBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
            statusLabel.Text = "Idle"
        else
            startFarm()
            startBtn.Text = "Stop Farm"
            startBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
            statusLabel.Text = "Farming..."
        end
    end)

    makeButton("Server Hop", 165, Color3.fromRGB(40, 40, 40), serverHop)

    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(1, -30, 0, 28)
    resetBtn.Position = UDim2.new(0, 15, 0, 235)
    resetBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    resetBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
    resetBtn.Text = "Reset Stats"
    resetBtn.Font = Enum.Font.Gotham
    resetBtn.TextSize = 12
    resetBtn.BorderSizePixel = 0
    resetBtn.Parent = frame
    Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 8)
    resetBtn.MouseButton1Click:Connect(function()
        stats.startCash = getCash()
        stats.startTime = tick()
        stats.profit    = 0
        stats.totalCash = getCash()
    end)

    -- Live stat updates
    task.spawn(function()
        while gui.Parent do
            stats.totalCash = getCash()
            if stats.running then
                stats.profit = stats.totalCash - stats.startCash
            end
            cashLabel.Text   = "Total cash: $" .. stats.totalCash
            profitLabel.Text = "Profit: $" .. stats.profit
            timeLabel.Text   = "Time spent: " .. formatTime(tick() - stats.startTime)
            task.wait(1)
        end
    end)
end

buildUI()
print("[Farm] UI loaded — press Start Farm to begin")
