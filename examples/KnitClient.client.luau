-- KnitClient.client.luau
-- Place this in StarterPlayerScripts
--
-- Knit-style Controllers built on RoExpress.
-- Each controller binds to its service's Port via a named Network and
-- Listener instance. The pattern mirrors Knit's Controller.Server proxy
-- and signal subscriptions.
--
--   Knit                             RoExpress
--   ──────────────────────────────   ─────────────────────────────────────
--   Controller.Server:Method(…)    → network:GetAsync / PostAsync
--   Signal:Connect(handler)        → listener:On(event, handler)
--   Controller.KnitInit            → bootstrap block at the bottom

local RoExpress   = require(game.ReplicatedStorage.Packages.RoExpress)
local localPlayer = game.Players.LocalPlayer

------------------------------------------------------------------------
-- CurrencyController
------------------------------------------------------------------------
local CurrencyController = {}

local _currencyNet = RoExpress("Network",  "CurrencyService")
local _currencyLis = RoExpress("Listener", "CurrencyService")

function CurrencyController.GetBalance()
    return _currencyNet:GetAsync("balance")
        :Then(function(res)
            return res.data.balance
        end)
end

function CurrencyController.AddCoins(amount: number)
    return _currencyNet:PostAsync("add", { amount = amount })
        :Then(function(res)
            return res.data.balance
        end)
        :Catch(function(err)
            warn(("[CurrencyController] AddCoins failed: %s (status %d)"):format(err.message, err.status))
        end)
end

function CurrencyController.SpendCoins(amount: number)
    return _currencyNet:PostAsync("spend", { amount = amount })
        :Then(function(res)
            return res.data.balance
        end)
        :Catch(function(err)
            warn(("[CurrencyController] SpendCoins failed: %s (status %d)"):format(err.message, err.status))
        end)
end

-- mirrors KnitSignal subscription
_currencyLis:On("BalanceChanged", function(data)
    print(("[CurrencyController] Balance updated → %d"):format(data.balance))
end)

------------------------------------------------------------------------
-- InventoryController
------------------------------------------------------------------------
local InventoryController = {}

local _inventoryNet = RoExpress("Network",  "InventoryService")
local _inventoryLis = RoExpress("Listener", "InventoryService")

function InventoryController.GetItems()
    return _inventoryNet:GetAsync("items")
        :Then(function(res)
            return res.data.items
        end)
end

function InventoryController.AddItem(item: string, qty: number?)
    return _inventoryNet:PostAsync("add", { item = item, qty = qty or 1 })
        :Then(function(res)
            return res.data.items
        end)
        :Catch(function(err)
            warn(("[InventoryController] AddItem failed: %s (status %d)"):format(err.message, err.status))
        end)
end

function InventoryController.UseItem(item: string)
    return _inventoryNet:PostAsync("use", { item = item })
        :Then(function(res)
            return res.data.items
        end)
        :Catch(function(err)
            warn(("[InventoryController] UseItem failed: %s (status %d)"):format(err.message, err.status))
        end)
end

_inventoryLis:On("InventoryUpdated", function(data)
    if data.userId == localPlayer.UserId then
        print(("[InventoryController] %s updated → x%d"):format(data.item, data.qty))
    end
end)

-- ─── Global broadcast events (unreliable) ────────────────────────────────────
local listener = RoExpress("Listener")

listener:On("PlayerJoined", function(data)
    print(("[Server] %s joined the game"):format(data.name))
end)

listener:On("PlayerLeft", function(data)
    print(("[Server] %s left the game"):format(data.name))
end)

-- ─── KnitInit equivalent — fetch initial state ───────────────────────────────
CurrencyController.GetBalance():Then(function(balance)
    print(("[CurrencyController] Starting balance: %d"):format(balance))
end)

InventoryController.GetItems():Then(function(items)
    print("[InventoryController] Starting inventory:")
    for item, qty in pairs(items) do
        print(("  %s x%d"):format(item, qty))
    end
end)