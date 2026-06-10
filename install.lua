------------------------------------------------------------------------
--  RoExpress — GitHub installer
--  Run via the Studio command bar bootstrap:
--
--    local H=game:GetService"HttpService"
--    loadstring(H:GetAsync"https://raw.githubusercontent.com/unofficialrobloxtutor/RoExpress/main/install.lua")()
--
--  Fetches every module from GitHub raw, builds the full ModuleScript
--  hierarchy, and parents the root to ReplicatedStorage.
------------------------------------------------------------------------

local HttpService       = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REPO   = "unofficialrobloxtutor/RoExpress"
local BRANCH = "main"
local BASE   = "https://raw.githubusercontent.com/" .. REPO .. "/" .. BRANCH .. "/src/"

------------------------------------------------------------------------
--  Helpers
------------------------------------------------------------------------
local function fetch(path)
    local ok, result = pcall(HttpService.GetAsync, HttpService, BASE .. path)
    if not ok then
        error("[RoExpress] Failed to fetch " .. path .. ": " .. tostring(result), 2)
    end
    return result
end

local function ms(name, source, parent)
    local m      = Instance.new("ModuleScript")
    m.Name       = name
    m.Source     = source
    m.Parent     = parent
    return m
end

------------------------------------------------------------------------
--  Remove any existing install so re-runs are clean
------------------------------------------------------------------------
local existing = ReplicatedStorage:FindFirstChild("RoExpress")
if existing then
    existing:Destroy()
    print("[RoExpress] Removed previous install")
end

------------------------------------------------------------------------
--  Build hierarchy
------------------------------------------------------------------------
print("[RoExpress] Downloading from GitHub (" .. BRANCH .. ")...")

-- Root (src/init.luau becomes the RoExpress ModuleScript)
local root = ms("RoExpress", fetch("init.luau"), ReplicatedStorage)

-- Flat modules
local flat = {
    "App", "Base64", "Benchmark", "Bridge", "Broadcast",
    "Harpy", "Listener", "Network", "Port", "Promise",
    "Router", "Tamper", "TokenBucket", "TypeCoercer", "Version",
}
for _, name in ipairs(flat) do
    ms(name, fetch(name .. ".luau"), root)
end

-- Codec (folder with init + two sub-modules)
local codec = ms("Codec", fetch("Codec/init.luau"), root)
ms("LZ77", fetch("Codec/LZ77.luau"), codec)
ms("LZH",  fetch("Codec/LZH.luau"),  codec)

-- Stream (folder with init + three sub-modules)
local stream = ms("Stream", fetch("Stream/init.luau"), root)
ms("Channel", fetch("Stream/Channel.luau"), stream)
ms("Schema",  fetch("Stream/Schema.luau"),  stream)
ms("Types",   fetch("Stream/Types.luau"),   stream)

------------------------------------------------------------------------
--  Done
------------------------------------------------------------------------
local total = #flat + 1 + 2 + 1 + 3  -- flat + Codec tree + Stream tree
print("[RoExpress] Done -> ReplicatedStorage/RoExpress (" .. total .. " modules)")
print("[RoExpress] require: local RoExpress = require(game.ReplicatedStorage.RoExpress)")
