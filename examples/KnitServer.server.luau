-- KnitServer.server.luau
-- Place this in ServerScriptService
--
-- Knit-style Services built on RoExpress.
-- Each service gets its own Port: an isolated RemoteEvent, Router,
-- and TokenBucket. The pattern mirrors Knit's Service.Client table
-- and KnitSignal, but uses RoExpress primitives directly.
--
--   Knit                          RoExpress
--   ─────────────────────────     ───────────────────────────────────
--   Service.Client.Method(p,…)  → port:Get / port:Post route
--   KnitSignal (server→client)  → port:Push / port:PushAll
--   Service isolation           → app:Listen(name, …) port per service

local RoExpress = require(game.ReplicatedStorage.Packages.RoExpress)

local app       = RoExpress("App")
local broadcast = RoExpress("Broadcast")

-- ─── Global middleware ────────────────────────────────────────────────────────
app:Use("logger", function(player, payload)
    print(("[RoExpress] %s  %s /%s"):format(player.Name, payload.method, payload.route))
end)

------------------------------------------------------------------------
-- CurrencyService
-- Routes:  GET  balance
--          POST add     { amount: number }
--          POST spend   { amount: number }
-- Signals: BalanceChanged { balance: number }
------------------------------------------------------------------------
app:Listen("CurrencyService", function(port)
    local balances: { [number]: number } = {}

    local function getBalance(userId: number): number
        return balances[userId] or 100
    end

    port:Get("balance", function(player, _payload, _req, res)
        res:Send({ balance = getBalance(player.UserId) })
    end)

    port:Post("add", function(player, _payload, req, res)
        local amount = req.data and req.data.amount
        if type(amount) ~= "number" or amount <= 0 then
            res:Status(400):Error("amount must be a positive number")
            return
        end
        balances[player.UserId] = getBalance(player.UserId) + amount
        local newBalance = balances[player.UserId]
        res:Send({ balance = newBalance })
        port:Push(player, "BalanceChanged", { balance = newBalance })
    end)

    port:Post("spend", function(player, _payload, req, res)
        local amount = req.data and req.data.amount
        if type(amount) ~= "number" or amount <= 0 then
            res:Status(400):Error("amount must be a positive number")
            return
        end
        local current = getBalance(player.UserId)
        if current < amount then
            res:Status(402):Error("Insufficient funds")
            return
        end
        balances[player.UserId] = current - amount
        local newBalance = balances[player.UserId]
        res:Send({ balance = newBalance })
        port:Push(player, "BalanceChanged", { balance = newBalance })
    end)
end)

------------------------------------------------------------------------
-- InventoryService
-- Routes:  GET  items
--          POST add   { item: string, qty: number? }
--          POST use   { item: string }
-- Signals: InventoryUpdated { userId, item, qty }
------------------------------------------------------------------------
app:Listen("InventoryService", function(port)
    local inventories: { [number]: { [string]: number } } = {}

    local function getInventory(userId: number): { [string]: number }
        if not inventories[userId] then
            inventories[userId] = { sword = 1, potion = 5 }
        end
        return inventories[userId]
    end

    port:Get("items", function(player, _payload, _req, res)
        res:Send({ items = getInventory(player.UserId) })
    end)

    port:Post("add", function(player, _payload, req, res)
        local item = req.data and req.data.item
        local qty  = req.data and req.data.qty or 1
        if type(item) ~= "string" or #item == 0 then
            res:Status(400):Error("item must be a non-empty string")
            return
        end
        if type(qty) ~= "number" or qty < 1 then
            res:Status(400):Error("qty must be a positive number")
            return
        end
        local inv = getInventory(player.UserId)
        inv[item] = (inv[item] or 0) + qty
        res:Send({ items = inv })
        port:PushAll("InventoryUpdated", { userId = player.UserId, item = item, qty = inv[item] })
    end)

    port:Post("use", function(player, _payload, req, res)
        local item = req.data and req.data.item
        if type(item) ~= "string" or #item == 0 then
            res:Status(400):Error("item must be a non-empty string")
            return
        end
        local inv = getInventory(player.UserId)
        if not inv[item] or inv[item] < 1 then
            res:Status(404):Error("Item not in inventory")
            return
        end
        inv[item] -= 1
        if inv[item] == 0 then
            inv[item] = nil
        end
        res:Send({ items = inv })
        port:Push(player, "InventoryUpdated", { userId = player.UserId, item = item, qty = inv[item] or 0 })
    end)
end)

-- ─── Global server-push events ────────────────────────────────────────────────
game.Players.PlayerAdded:Connect(function(player)
    broadcast:EmitAll("PlayerJoined", { name = player.Name })
end)

game.Players.PlayerRemoving:Connect(function(player)
    broadcast:EmitAll("PlayerLeft", { name = player.Name })
end)