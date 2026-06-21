-- Seller Tools | Run this on your ALTS
-- Set these before executing:
--   getgenv().Seller = "YourMainAccountName"
--   getgenv().prefix = "."        (optional, default ".")
--   getgenv().altMsg = "..."      (optional)

local SELLER  = getgenv().Seller or "luvizyv"
local PREFIX  = getgenv().prefix or "."
local ALT_MSG = getgenv().altMsg or "Thanks for using Seller Tools"

local Players   = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS        = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Character   = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP         = Character:WaitForChild("HumanoidRootPart")

-- ── Teleport alt beside the seller ──────────────────────────────────────────

local function getSellerHRP()
    local seller = Players:FindFirstChild(SELLER)
    if not seller then return nil end
    local char = seller.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function spawnBesideSeller()
    -- wait until seller is in the server
    local attempts = 0
    local sellerHRP
    repeat
        sellerHRP = getSellerHRP()
        if not sellerHRP then task.wait(1) end
        attempts += 1
    until sellerHRP or attempts >= 30

    if not sellerHRP then
        warn("[SellerTools] Seller '" .. SELLER .. "' not found in server after 30s")
        return
    end

    -- small random offset so alts don't stack exactly
    local offset = Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
    HRP.CFrame = sellerHRP.CFrame + offset
    print("[SellerTools] Spawned beside " .. SELLER)
end

-- Re-grab HRP after respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HRP = char:WaitForChild("HumanoidRootPart")
    task.wait(1) -- let character load fully
    spawnBesideSeller()
end)

spawnBesideSeller()

-- ── Da Hood cash drop ────────────────────────────────────────────────────────

local mainEvent = RS:WaitForChild("MainEvent")

local function dropAllCash()
    local dataFolder = LocalPlayer:FindFirstChild("DataFolder")
    local currency   = dataFolder and dataFolder:FindFirstChild("Currency")
    local cash       = currency and currency.Value or 0

    if cash <= 0 then
        print("[SellerTools] No cash to drop")
        return
    end

    mainEvent:FireServer("DropMoney", cash)
    print("[SellerTools] Dropped $" .. cash)
end

-- ── Chat command listener ────────────────────────────────────────────────────

local COMMANDS = {
    drop = function()
        dropAllCash()
    end,

    spawn = function()
        spawnBesideSeller()
    end,

    msg = function()
        -- make the alt say the configured message
        local chatRemote = RS:FindFirstChild("SayMessageRequest", true)
            or RS:FindFirstChild("DefaultChatSystemChatEvents", true)
        if chatRemote and chatRemote:IsA("RemoteEvent") then
            chatRemote:FireServer(ALT_MSG, "All")
        end
        print("[SellerTools] Said alt message")
    end,

    cmds = function()
        print("[SellerTools] Commands (said by " .. SELLER .. " in chat):")
        print("  " .. PREFIX .. "drop   — drop all cash")
        print("  " .. PREFIX .. "spawn  — teleport beside seller")
        print("  " .. PREFIX .. "msg    — say alt message")
    end,
}

local function onChat(player, message)
    if player.Name ~= SELLER then return end
    if message:sub(1, #PREFIX) ~= PREFIX then return end

    local body = message:sub(#PREFIX + 1):lower():match("^%s*(.-)%s*$")
    local cmd  = body:match("^(%S+)")
    if not cmd then return end

    local handler = COMMANDS[cmd]
    if handler then
        local ok, err = pcall(handler)
        if not ok then
            warn("[SellerTools] Command error: " .. tostring(err))
        end
    end
end

local function hookPlayer(player)
    player.Chatted:Connect(function(msg)
        onChat(player, msg)
    end)
end

for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
Players.PlayerAdded:Connect(hookPlayer)

-- ── Ready ────────────────────────────────────────────────────────────────────
print(string.format("[SellerTools] Ready | Seller: %s | Prefix: '%s'", SELLER, PREFIX))
