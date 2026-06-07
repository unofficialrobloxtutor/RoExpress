-- BasicServer.server.luau
-- Place this in ServerScriptService

local RoExpress = require(game.ReplicatedStorage.Packages.RoExpress)

local app       = RoExpress("App")
local broadcast = RoExpress("Broadcast")

-- ─── Middleware ────────────────────────────────────────────────────────────────
-- Runs before every request. Return false to reject (403), throw to crash (500).
app:Use("logger", function(player, payload)
    print(("[RoExpress] %s  %s %s"):format(player.Name, payload.method, payload.route))
end)

-- ─── Routes ────────────────────────────────────────────────────────────────────

-- GET /ping  →  basic health check
app:Get("ping", function(player, payload, req, res)
    res:Send({ ok = true, time = os.time() })
end)

-- GET /player/:userId=number  →  fetch player data by numeric id
app:Get("player/:userId=number", function(player, payload, req, res)
    local userId = req.params.userId  -- already a Lua number thanks to :userId=number

    -- Replace with your real data lookup
    local data = {
        userId  = userId,
        name    = player.Name,
        coins   = 500,
        level   = 3,
    }

    res:Send(data)
end)

-- POST /player/:userId=number/coins/add  →  add coins
app:Post("player/:userId=number/coins/add", function(player, payload, req, res)
    local amount = req.data and req.data.amount

    if type(amount) ~= "number" or amount <= 0 then
        res:Status(400):Error("amount must be a positive number")
        return
    end

    -- Replace with your real ledger logic
    local newBalance = 500 + amount
    res:Send({ balance = newBalance })
end)

-- ─── Server Push ───────────────────────────────────────────────────────────────
-- Tell every client when a new player joins (unreliable broadcast is fine here)
game.Players.PlayerAdded:Connect(function(player)
    broadcast:EmitAll("playerJoined", { name = player.Name })
end)

-- Reliable server-push for round lifecycle events
local function startRound()
    app:PushAll("roundStarted", { duration = 120 })

    task.delay(120, function()
        app:PushAll("roundEnded", { winner = "somePlayer" })
    end)
end

-- Kick off the first round once the server is ready
task.delay(5, startRound)
