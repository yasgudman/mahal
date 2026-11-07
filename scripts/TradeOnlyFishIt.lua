-- ============================================================
-- Fish It! Trade-Only (Delta-friendly, dengan notifikasi)
--
-- Pakai lewat Delta:
--   local Http = game:GetService("HttpService")
--   local src  = Http:GetHttpAsset("https://raw.githubusercontent.com/yasgudman/mahal/main/scripts/TradeOnlyFishIt.lua")
--   loadstring(src)()
--
-- Catatan:
--   - Http:GetHttpAsset = HttpService (Roblox-native, bisa di-cache client)
--   - Kalau GetHttpAsset error (game tanpa HTTP permission),
--     pakai game:HttpGet:
--     loadstring(game:HttpGet("https://raw.githubusercontent.com/yasgudman/mahal/main/scripts/TradeOnlyFishIt.lua"))()
--
-- Setelah di-loadstring:
--   - Notif "trade-only ON/OFF" muncul di layar tiap toggle
--   - Hook remote trade (auto-detect nama yang dipakai server)
--   - Kalau remote belum ada (trade area belum load), notif jelas
-- ============================================================

local KONFIG = {
    KeyToggle = "T",
    PlayerOnly = true,
    AutoAcceptWhitelist = true,
    AutoDeclineNPC = true,
    Log = true,
    -- Jarak maksimum (studs) untuk dianggap "sedang trade"
    TradeDistance = 40,
    -- Interval cek loop (detik)
    LoopInterval = 0.4,
}

------------------------------------------------------------
-- Services
------------------------------------------------------------
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

local function log(msg)
    if KONFIG.Log then
        print("[FishIt-TradeOnly] " .. tostring(msg))
    end
end

local function warn(msg)
    print("[FishIt-TradeOnly][WARN] " .. tostring(msg))
end

------------------------------------------------------------
-- Notif GUI (screen-space, di atas PlayerGui, selalu terlihat)
------------------------------------------------------------
local function notify(msg, kind)
    kind = kind or "info"
    local pg = localPlayer:WaitForChild("PlayerGui")

    local colors = {
        success = Color3.fromRGB(22, 84, 54),
        error   = Color3.fromRGB(46, 24, 30),
        info    = Color3.fromRGB(24, 24, 36),
    }

    local frame = Instance.new("Frame")
    frame.Name = "FishItNotify_" .. tostring(os.clock())
    frame.Size = UDim2.new(0, 340, 0, 48)
    frame.BackgroundColor3 = colors[kind] or colors.info
    frame.BorderSizePixel = 0
    frame.Position = UDim2.new(0.5, -170, 0, 44)
    frame.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = msg
    label.TextSize = 14
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextWrapped = true
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Padding = Dimension.new(12, 2)
    label.Parent = frame

    frame.Parent = pg

    -- Fade out + destroy
    task.delay(3.2, function()
        if not frame or not frame.Parent then return end
        task.spawn(function()
            local t = 0
            local duration = 0.4
            while t < duration and frame.Parent do
                t += 0.02
                frame.BackgroundTransparency = math.min(1, t / duration)
                task.wait()
            end
            if frame then frame:Destroy() end
        end)
    end)
end

------------------------------------------------------------
-- Remote scan
------------------------------------------------------------
local REMOTE_NAMES = {
    "Trade", "TradeOnly", "TradeRequest",
    "TradeAccept", "TradeDecline",
    "OpenTrade", "RequestTrade", "StartTrade",
}

local remoteCache = {}

local function findRemote(root, name)
    local function rec(node, depth)
        if depth > 5 then return nil end
        for _, child in ipairs(node:GetChildren()) do
            if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                if child.Name == name then
                    return child
                end
            end
            local r = rec(child, depth + 1)
            if r then return r end
        end
        return nil
    end
    return rec(root, 0)
end

local function scanTradeRemotes()
    local found = {}
    for _, name in ipairs(REMOTE_NAMES) do
        local r = findRemote(ReplicatedStorage, name)
        if r then
            found[name] = r
            remoteCache[name] = r
        end
    end
    return found
end

------------------------------------------------------------
-- Hook remote: capture payload asli (bikin replikasi sama)
------------------------------------------------------------
local callLog = {}

local function hookRemote(remote, tag)
    if not remote then return end
    if remote:IsA("RemoteFunction") then
        local originalCall = remote.Call
        remote.Call = function(self, ...)
            local args = table.pack(...)
            table.insert(callLog, { tag = tag, args = args, time = os.clock() })
            log(string.format("%s -> %s", tag, table.concat({ args }, " ")))
            return originalCall(self, ...)
        end
    elseif remote:IsA("RemoteEvent") then
        local originalFire = remote.FireServer
        remote.FireServer = function(self, ...)
            local args = table.pack(...)
            table.insert(callLog, { tag = tag, args = args, time = os.clock() })
            log(string.format("%s -> %s", tag, table.concat({ args }, " ")))
            return originalFire(self, ...)
        end
        -- Observe incoming calls (server -> client)
        local originalOnClient = remote.OnClientEvent
        if not originalOnClient then
            remote.OnClientEvent = function(...)
                local args = table.pack(...)
                table.insert(callLog, { tag = tag .. ":in", args = args, time = os.clock() })
            end
        end
    end
end

------------------------------------------------------------
-- Trade counterpart
------------------------------------------------------------
local function getTradeCounterpart()
    local localChar = localPlayer.Character
    if not localChar then return nil, nil end
    local closest, closestDist = nil, math.huge
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= localPlayer then
            local oc = other.Character
            if oc and oc:FindFirstChild("Humanoid") then
                local d = (oc:GetPivot().Position - localChar:GetPivot().Position).Magnitude
                if d < closestDist then
                    closest, closestDist = other, d
                end
            end
        end
    end
    return closest, closestDist
end

------------------------------------------------------------
-- Klik GUI (mirror klik asli pemain — lebih aman dari
-- re-fire remote kalau validasi server-side ada)
------------------------------------------------------------
local function clickGuiButton(guiRoot, buttonName)
    local btn = guiRoot:FindFirstChild(buttonName)
    if not btn then
        for _, d in ipairs(guiRoot:GetDescendants()) do
            if d.Name:lower() == buttonName:lower() and d:IsA("TextButton") then
                btn = d
                break
            end
        end
    end
    if btn and btn:IsA("TextButton") then
        btn.MouseButton1Click:Fire()
        log("Clicked GUI button: " .. buttonName)
        return true
    end
    warn("GUI button not found: " .. buttonName)
    return false
end

------------------------------------------------------------
-- Mode
------------------------------------------------------------
local tradeModeActive = false
local inWhitelist = {}

local function markWhitelisted(playerName)
    if not inWhitelist[playerName] then
        inWhitelist[playerName] = true
        log("Whitelisted: " .. playerName)
    end
end

local function toggleTradeMode()
    tradeModeActive = not tradeModeActive
    log(string.format("Trade-only mode: %s", tradeModeActive and "ON" or "OFF"))
    notify(
        string.format("Fish It! trade-only: %s", tradeModeActive and "ON" or "OFF"),
        tradeModeActive and "success" or "info"
    )
end

local function autoTradeLoop()
    while true do
        task.wait(KONFIG.LoopInterval)
        if not tradeModeActive then continue end

        local counterpart, dist = getTradeCounterpart()
        if not counterpart or dist > KONFIG.TradeDistance then continue end

        -- Target bukan player (NPC/robot)
        if not counterpart.Character or not counterpart.Character:FindFirstChild("Humanoid") then
            if KONFIG.AutoDeclineNPC then
                warn("Declining non-player target: " .. counterpart.Name)
                clickGuiButton(localPlayer:FindFirstChild("PlayerGui"), "Decline")
            end
            continue
        end

        if not KONFIG.PlayerOnly then continue end

        -- Kalau counterparty ada di whitelist (riwayat accept), auto-accept
        if KONFIG.AutoAcceptWhitelist and inWhitelist[counterpart.Name] then
            log("Auto-accepting trade with: " .. counterpart.Name)
            -- 1) Coba klik GUI button "Accept" (paling aman, mirror klik asli)
            local pg = localPlayer:FindFirstChild("PlayerGui")
            if pg then
                local ok = clickGuiButton(pg, "Accept")
                if ok then
                    log("GUI Accept clicked for " .. counterpart.Name)
                end
            end
            -- 2) Fallback: fire remote TradeAccept langsung
            local acceptRemote = remoteCache["TradeAccept"] or remoteCache["Trade"]
            if acceptRemote then
                pcall(function()
                    if acceptRemote:IsA("RemoteFunction") then
                        acceptRemote:InvokeServer()
                    else
                        acceptRemote:FireServer()
                    end
                end)
            end
        else
            log(string.format("Near player: %s (%.1f studs)", counterpart.Name, dist))
        end
    end
end

------------------------------------------------------------
-- Startup
------------------------------------------------------------
local function setup()
    log("Scanning for trade remotes...")
    local found = scanTradeRemotes()
    local count = 0
    for _ in pairs(found) do count += 1 end

    if count == 0 then
        notify(
            "Fish It! trade-only: NO trade remotes found. Script is idle — make sure you're in the trade area, then remount / re-loadstring.",
            "error"
        )
        warn("No trade remotes found yet.")

        -- Watch for late-loaded remotes
        ReplicatedStorage.DescendantAdded:Connect(function(inst)
            if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
                for _, name in ipairs(REMOTE_NAMES) do
                    if inst.Name == name then
                        log("Late-bound remote: " .. name)
                        remoteCache[name] = inst
                        hookRemote(inst, name)
                        notify("Late-bound trade remote found: " .. name, "info")
                    end
                end
            end
        end)
    else
        for name, remote in pairs(found) do
            hookRemote(remote, name)
        end
        notify(
            string.format("Fish It! trade-only: %d remotes found. Press '%s' to toggle mode.", count, KONFIG.KeyToggle),
            "success"
        )
        log(string.format("%d trade remotes found.", count))
    end

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard
            and input.KeyCode.Name:upper():sub(1, 1) == KONFIG.KeyToggle:upper()
        then
            toggleTradeMode()
        end
    end)

    task.spawn(autoTradeLoop)
end

-- Run
task.spawn(setup)
