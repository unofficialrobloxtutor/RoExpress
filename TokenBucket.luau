--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--  ◄► Title:       TokenBucket_Utility
--  ◄► Version:     1.0
--  ◄► Date:        18/05/2026
--  ◄► Author:      DeathToTheStadium
--  ◄► Description: Token bucket rate limiter for the remote pipeline.
--                  Each player is assigned a bucket on join that refills
--                  at a fixed rate. Requests cost tokens — if the bucket
--                  is empty the request is denied. Exposes grant utilities
--                  for rewarding burst capacity after round events.
--                  Buckets are automatically created and cleared via
--                  PlayerAdded and PlayerRemoving.
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--► Services     ◄--
local PlayerService = game:GetService("Players")

--► Tables       ◄--
local TokenBucket = {}
local Buckets = {}
local Settings = {
	Max    = 10,
	Refill = 2,
}
--► Variables    ◄--
--► Types        ◄--
export type Type = typeof(TokenBucket) & {
	Consume: (Player: Player, Cost: number)->(),
	HasTokens: (Player: Player)->boolean,
	HasEnoughTokens: (Player: Player, Cost: number)->boolean,
	Refill: (Player: Player)->(),
	Reset: (Player: Player)->(),
	Grant: (Player: Player, Amount: number)->(),
	GrantAll: (Amount: number)->(),
	GrantExact: (Player: Player, Amount: number)->(),
	GrantAllExact: (Amount: number)->(),
}


--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--	FUNCTIONS
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■


--► LOCAL ◄--
local function _newbucket()
	return {
		Tokens     = Settings.Max,
		Max        = Settings.Max,
		Refill     = Settings.Refill,
		LastRefill = tick()
	}
end

local function _refill(Bucket: {})
	local now     = tick()
	local elapsed = now - Bucket.LastRefill
	Bucket.Tokens     = math.min(Bucket.Max, Bucket.Tokens + elapsed * Bucket.Refill)
	Bucket.LastRefill = now
end

local function NewPlayerBucket(Player: Player)
	Buckets[Player.UserId] = _newbucket()
end

local function ClearPlayerBucket (Player: Player)
	Buckets[Player.UserId] = nil
end

--► GLOBAL ◄--

function TokenBucket.Consume(Player: Player, Cost: number)
	if not Buckets[Player.UserId] then
		Buckets[Player.UserId] = _newbucket()
	end

	local Bucket = Buckets[Player.UserId]
	
	_refill(Bucket)
	
	if Bucket.Tokens < Cost then
		warn(`{Player.Name} is being rate limited`)
		return false
	end
	Bucket.Tokens -= Cost
	return true
end

function TokenBucket.HasTokens(Player: Player)
	local Bucket = Buckets[Player.UserId]
	if not Bucket then return false end
	_refill(Bucket)
	return Bucket.Tokens > 0
end

function TokenBucket.HasEnoughTokens(Player: Player, Cost: number)
	local Bucket = Buckets[Player.UserId]
	if not Bucket then return false end
	_refill(Bucket)
	return Bucket.Tokens >= Cost
end

function TokenBucket.Refill(Player: Player)
	local Bucket = Buckets[Player.UserId]
	if not Bucket then return end
	_refill(Bucket)
end

function TokenBucket.Reset(Player: Player)
	local Bucket = Buckets[Player.UserId]
	if not Bucket then return end
	Bucket.Tokens     = Bucket.Max
	Bucket.LastRefill = tick()
end

-- Adds tokens up to Max
function TokenBucket.Grant(Player: Player, Amount: number)
	local Bucket = Buckets[Player.UserId]
	if not Bucket then return end
	Bucket.Tokens = math.min(Bucket.Max, Bucket.Tokens + Amount)
end

-- Adds tokens up to Max for all players
function TokenBucket.GrantAll(Amount: number)
	for _, Bucket in Buckets do
		Bucket.Tokens = math.min(Bucket.Max, Bucket.Tokens + Amount)
	end
end

-- Adds tokens ignoring Max
function TokenBucket.GrantExact(Player: Player, Amount: number)
	local Bucket = Buckets[Player.UserId]
	if not Bucket then return end
	Bucket.Tokens += Amount
end

-- Adds tokens ignoring Max for all players
function TokenBucket.GrantAllExact(Amount: number)
	for _, Bucket in Buckets do
		Bucket.Tokens += Amount
	end
end

function TokenBucket.Destroy()
	table.clear(Buckets)
end

--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--	EVENTS
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
PlayerService.PlayerAdded:Connect(NewPlayerBucket)
PlayerService.PlayerRemoving:Connect(ClearPlayerBucket)

return TokenBucket
