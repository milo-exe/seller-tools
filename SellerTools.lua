-- Seller Tools | Run on ALTS
-- getgenv().Seller = "luvizyv"
-- getgenv().prefix = "."
-- getgenv().altMsg = "Thanks for using Seller Tools"

local SELLER  = getgenv().Seller  or "luvizyv"
local PREFIX  = getgenv().prefix  or "."
local ALT_MSG = getgenv().altMsg  or "Thanks for using Seller Tools"

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TCS        = game:GetService("TextChatService")

local LocalPlayer = Players.LocalPlayer
local Character   = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP         = Character:WaitForChild("HumanoidRootPart")
local Humanoid    = Character:WaitForChild("Humanoid")

local mainEvent = RS:WaitForChild("MainEvent")

-- ── Respawn handling ─────────────────────────────────────────────────────────

LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HRP       = char:WaitForChild("HumanoidRootPart")
    Humanoid  = char:WaitForChild("Humanoid")
    task.wait(1)
    spawnBesideSeller()
end)

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function getSellerHRP()
    local seller = Players:FindFirstChild(SELLER)
    if not seller or not seller.Character then return nil end
    return seller.Character:FindFirstChild("HumanoidRootPart")
end

local function getCash()
    local df = LocalPlayer:FindFirstChild("DataFolder")
    local c  = df and df:FindFirstChild("Currency")
    return c and c.Value or 0
end

-- ── Spawn beside seller ──────────────────────────────────────────────────────

function spawnBesideSeller()
    local attempts = 0
    local sellerHRP
    repeat
        sellerHRP = getSellerHRP()
        if not sellerHRP then task.wait(1) end
        attempts += 1
    until sellerHRP or attempts >= 30

    if not sellerHRP then
        warn("[SellerTools] Seller not found after 30s")
        return
    end

    local offset = Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
    HRP.CFrame = sellerHRP.CFrame + offset
    print("[SellerTools] Spawned beside " .. SELLER)
end

spawnBesideSeller()

-- ── Drop cash (20k chunks, 20s cooldown) ─────────────────────────────────────

local DROP_MAX      = 20000
local DROP_COOLDOWN = 20
local isDropping    = false

local function dropAllCash()
    if isDropping then
        print("[SellerTools] Already dropping, please wait")
        return
    end

    local cash = getCash()
    if cash <= 0 then
        print("[SellerTools] No cash to drop")
        return
    end

    isDropping = true
    task.spawn(function()
        local remaining = cash
        while remaining > 0 do
            local amount = math.min(remaining, DROP_MAX)
            mainEvent:FireServer("DropMoney", amount)
            print("[SellerTools] Dropped $" .. amount .. " | Remaining: $" .. (remaining - amount))
            remaining -= amount
            if remaining > 0 then
                print("[SellerTools] Cooldown — dropping again in " .. DROP_COOLDOWN .. "s")
                task.wait(DROP_COOLDOWN)
            end
        end
        print("[SellerTools] Done dropping all cash")
        isDropping = false
    end)
end

-- ── Fly / Follow ─────────────────────────────────────────────────────────────

local flyConnection = nil
local isFlying      = false
local FLY_HEIGHT    = 12

local function startFly()
    if isFlying then return end
    isFlying = true
    Humanoid.PlatformStand = true

    -- Add BodyPosition + BodyGyro to hover above seller
    local bp = Instance.new("BodyPosition")
    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bp.P = 10000
    bp.Parent = HRP

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 10000
    bg.Parent = HRP

    flyConnection = RunService.Heartbeat:Connect(function()
        local sellerHRP = getSellerHRP()
        if sellerHRP then
            bp.Position = sellerHRP.Position + Vector3.new(0, FLY_HEIGHT, 0)
            bg.CFrame   = sellerHRP.CFrame
        end
    end)

    print("[SellerTools] Flying above " .. SELLER)
end

local function stopFly()
    if not isFlying then return end
    isFlying = false

    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end

    for _, obj in ipairs(HRP:GetChildren()) do
        if obj:IsA("BodyPosition") or obj:IsA("BodyGyro") then
            obj:Destroy()
        end
    end

    Humanoid.PlatformStand = false
    print("[SellerTools] Stopped flying")
end

-- ── Say message ──────────────────────────────────────────────────────────────

local function sayMessage(msg)
    -- Try TextChatService first (newer Roblox)
    local ok = pcall(function()
        local channel = TCS.TextChannels:FindFirstChild("RBXGeneral")
        if channel then channel:SendAsync(msg) end
    end)
    if not ok then
        -- Fallback: legacy chat remote
        local sayRemote = RS:FindFirstChild("SayMessageRequest", true)
        if sayRemote then
            sayRemote:FireServer(msg, "All")
        end
    end
end

-- ── UI ───────────────────────────────────────────────────────────────────────

local function buildUI()
    local pg = LocalPlayer:WaitForChild("PlayerGui")

    local gui = Instance.new("ScreenGui")
    gui.Name = "SellerToolsUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = pg

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 180, 0, 200)
    frame.Position = UDim2.new(0, 10, 0.5, -100)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "Seller Tools"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = frame
    Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

    -- Status label
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -10, 0, 20)
    status.Position = UDim2.new(0, 5, 0, 35)
    status.BackgroundTransparency = 1
    status.TextColor3 = Color3.fromRGB(180, 180, 180)
    status.Text = "Cash: $" .. getCash()
    status.Font = Enum.Font.Gotham
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = frame

    -- Update cash display
    task.spawn(function()
        while gui.Parent do
            status.Text = "Cash: $" .. getCash() .. (isFlying and "  ✈" or "") .. (isDropping and "  💸" or "")
            task.wait(1)
        end
    end)

    local buttons = {
        { label = "Drop All Cash",  cmd = function() dropAllCash() end,  color = Color3.fromRGB(220, 60, 60) },
        { label = "Fly / Unfly",    cmd = function() if isFlying then stopFly() else startFly() end end, color = Color3.fromRGB(60, 120, 220) },
        { label = "Spawn Beside",   cmd = function() spawnBesideSeller() end, color = Color3.fromRGB(60, 180, 80) },
        { label = "Say Alt Msg",    cmd = function() sayMessage(ALT_MSG) end,  color = Color3.fromRGB(140, 80, 200) },
    }

    for i, btn in ipairs(buttons) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -10, 0, 28)
        b.Position = UDim2.new(0, 5, 0, 60 + (i - 1) * 33)
        b.BackgroundColor3 = btn.color
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Text = btn.label
        b.Font = Enum.Font.GothamSemibold
        b.TextSize = 12
        b.BorderSizePixel = 0
        b.Parent = frame
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseButton1Click:Connect(btn.cmd)
    end
end

buildUI()

-- ── Chat commands ─────────────────────────────────────────────────────────────
-- Commands (prefix defaults to "."):
--   .drop          — drop all cash in 20k chunks
--   .fly           — toggle fly above seller
--   .spawn         — teleport beside seller
--   .say <msg>     — alt says message in chat
--   .cmds          — list commands

local COMMANDS = {
    drop = function(_)
        dropAllCash()
    end,

    fly = function(_)
        if isFlying then stopFly() else startFly() end
    end,

    spawn = function(_)
        spawnBesideSeller()
    end,

    say = function(args)
        local msg = table.concat(args, " ")
        if msg == "" then return end
        sayMessage(msg)
    end,

    cmds = function(_)
        print("[SellerTools] Commands:")
        print("  " .. PREFIX .. "drop       — drop all cash (20k/20s)")
        print("  " .. PREFIX .. "fly        — toggle fly above seller")
        print("  " .. PREFIX .. "spawn      — teleport beside seller")
        print("  " .. PREFIX .. "say <msg>  — alt says message in chat")
    end,
}

local function onChat(player, message)
    if player.Name ~= SELLER then return end
    if message:sub(1, #PREFIX) ~= PREFIX then return end

    local body  = message:sub(#PREFIX + 1):match("^%s*(.-)%s*$")
    local parts = {}
    for word in body:gmatch("%S+") do parts[#parts + 1] = word end
    if #parts == 0 then return end

    local cmd     = table.remove(parts, 1):lower()
    local handler = COMMANDS[cmd]
    if handler then
        local ok, err = pcall(handler, parts)
        if not ok then warn("[SellerTools] Error: " .. tostring(err)) end
    end
end

local function hookPlayer(p)
    p.Chatted:Connect(function(msg) onChat(p, msg) end)
end

for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
Players.PlayerAdded:Connect(hookPlayer)

print(string.format("[SellerTools] Ready | Seller: %s | Prefix: '%s'", SELLER, PREFIX))
