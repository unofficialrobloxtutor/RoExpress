-- BasicClient.client.luau
-- Place this in StarterPlayerScripts

local RoExpress = require(game.ReplicatedStorage.Packages.RoExpress)

local network  = RoExpress("Network")
local listener = RoExpress("Listener")

local localPlayer = game.Players.LocalPlayer

-- ─── Callback-based request ────────────────────────────────────────────────────
-- Simple GET — callback fires when the response arrives
network:Get("ping", nil, function(res)
    if res.type == "error" then
        warn("[ping] error:", res.message)
        return
    end
    print("[ping] server time:", res.data.time)
end)

-- ─── Promise-based request ─────────────────────────────────────────────────────
-- PostAsync returns a Promise — useful when you need to chain logic
local function addCoins(amount: number)
    return network:PostAsync(
        ("player/%d/coins/add"):format(localPlayer.UserId),
        { amount = amount }
    )
        :Then(function(res)
            print(("[coins] new balance: %d"):format(res.data.balance))
            return res.data.balance
        end)
        :Catch(function(err)
            warn(("[coins] failed: %s (status %d)"):format(err.message, err.status))
        end)
end

-- Fetch player data then add 50 coins
network:GetAsync(("player/%d"):format(localPlayer.UserId))
    :Then(function(res)
        print(("[player] level %d | coins %d"):format(res.data.level, res.data.coins))
        return addCoins(50)
    end)
    :Catch(function(err)
        warn("[player] fetch failed:", err.message)
    end)

-- ─── Broadcasts & Server Push ──────────────────────────────────────────────────
-- Persistent subscription — fires every time the event is received
listener:On("playerJoined", function(data)
    print(("[server] %s joined the game"):format(data.name))
end)

-- One-shot subscription — unsubscribes automatically after the first fire
listener:Once("roundStarted", function(data)
    print(("[round] started — %d seconds remaining"):format(data.duration))
end)

listener:On("roundEnded", function(data)
    print(("[round] over — winner: %s"):format(data.winner))
end)