local module = {}
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
--  ◄► Title:       RoExpress.Codec
--  ◄► Version:     1.0
--  ◄► Date:        30/05/2026
--  ◄► Author:      DeathToTheStadium
--  ◄► Description: Buffer-based payload compression for RoExpress.
--
--  ALGORITHM — LZ77 sliding window
--  ────────────────────────────────────────────────────────────────
--  Compression encodes JSON as a byte stream then emits either:
--    • Literal token  [0x00][byte]        — a single raw byte
--    • Match token    [0x01][dist_hi][dist_lo][len] — back-reference
--
--  The sliding window is 4096 bytes (12-bit distance).
--  Match length is encoded in one byte, so max match = 255 bytes.
--  Minimum match length = 4 bytes (below that a literal is cheaper).
--
--  OUTPUT FORMAT
--  ────────────────────────────────────────────────────────────────
--  The compressed buffer is base64-encoded for transmission (same
--  path as existing POST responses). A 2-byte magic header is
--  prepended so the decoder can detect and reject uncompressed data
--  gracefully.
--
--    [0xC0][0xDE] magic
--    [token stream...]
--
--  WHEN TO USE
--  ────────────────────────────────────────────────────────────────
--  Codec is opt-in per route. App exposes:
--    app:Get("route", handler, { compress = true })
--    app:Post("route", handler, { compress = true })
--
--  Compression is not applied to Broadcast (already size-capped at
--  900 bytes — the overhead would be counterproductive).
--
--  PERFORMANCE NOTES
--  ────────────────────────────────────────────────────────────────
--  LZ77 is O(n*w) where w is window size. At w=4096 and typical
--  Roblox payload sizes (<50kb) this is fast enough to run server-
--  side per request without frame budget concerns. If you're pushing
--  very large tables (leaderboards, maps) measure before enabling.
--■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■

local HttpService = game:GetService("HttpService")
local Base64      = require(script.Parent.Base64)

local Codec = {}

-- ─────────────────────────────────────────────────────────────────
-- CONSTANTS
-- ─────────────────────────────────────────────────────────────────
local MAGIC_0       = 0xC0
local MAGIC_1       = 0xDE
local TOKEN_LITERAL = 0x00
local TOKEN_MATCH   = 0x01
local WINDOW_SIZE   = 4096   -- 12-bit distance
local MIN_MATCH     = 4      -- below this a literal sequence is cheaper
local MAX_MATCH     = 255    -- single byte length field

-- ─────────────────────────────────────────────────────────────────
-- COMPRESS
-- ─────────────────────────────────────────────────────────────────

--[[
	_findMatch(bytes, pos, windowStart)

	Searches the sliding window for the longest match starting at pos.
	Returns (matchDist, matchLen) or (0, 0) if no match >= MIN_MATCH.

	bytes      — the full byte array (1-indexed)
	pos        — current position (1-indexed)
	windowStart — first byte of the window
]]
local function _findMatch(bytes: { number }, pos: number, windowStart: number): (number, number)
	local bestDist = 0
	local bestLen  = 0
	local n        = #bytes

	-- search backwards from pos-1 to windowStart
	for i = pos - 1, windowStart, -1 do
		-- quick first-byte check before inner loop
		if bytes[i] ~= bytes[pos] then continue end

		local len = 0
		while	len < MAX_MATCH
			and pos + len <= n
			and bytes[i + len] == bytes[pos + len]
		do
			len += 1
		end

		if len > bestLen then
			bestLen  = len
			bestDist = pos - i
			if bestLen == MAX_MATCH then break end -- can't do better
		end
	end

	if bestLen >= MIN_MATCH then
		return bestDist, bestLen
	end
	return 0, 0
end

--[[
	Compress(data: any) -> string

	JSON-encodes data, compresses with LZ77, base64-encodes the result.
	Returns the compressed base64 string.
]]
function Codec.Compress(data: any): string
	local json  = HttpService:JSONEncode(data)
	local bytes = table.create(#json)
	for i = 1, #json do
		bytes[i] = string.byte(json, i)
	end

	local n       = #bytes
	-- worst case: every byte is a literal (2 bytes each) + 2 magic bytes
	local out     = buffer.create(2 + n * 2)
	local outPos  = 0

	-- write magic header
	buffer.writeu8(out, outPos,     MAGIC_0) outPos += 1
	buffer.writeu8(out, outPos,     MAGIC_1) outPos += 1

	local pos = 1
	while pos <= n do
		local windowStart = math.max(1, pos - WINDOW_SIZE)
		local dist, len   = _findMatch(bytes, pos, windowStart)

		if len >= MIN_MATCH then
			-- match token: [0x01][dist_hi][dist_lo][len]
			buffer.writeu8(out, outPos, TOKEN_MATCH)      outPos += 1
			buffer.writeu8(out, outPos, math.floor(dist / 256)) outPos += 1
			buffer.writeu8(out, outPos, dist % 256)       outPos += 1
			buffer.writeu8(out, outPos, len)              outPos += 1
			pos += len
		else
			-- literal token: [0x00][byte]
			buffer.writeu8(out, outPos, TOKEN_LITERAL) outPos += 1
			buffer.writeu8(out, outPos, bytes[pos])    outPos += 1
			pos += 1
		end
	end

	-- slice to actual written size and base64-encode
	local packed = buffer.tostring(buffer.create(outPos))
	-- copy only the written bytes
	local result = buffer.create(outPos)
	buffer.copy(result, 0, out, 0, outPos)

	return Base64.Encode(buffer.tostring(result))
end

-- ─────────────────────────────────────────────────────────────────
-- DECOMPRESS
-- ─────────────────────────────────────────────────────────────────

--[[
	Decompress(encoded: string) -> any

	Base64-decodes, validates magic header, decompresses LZ77 stream,
	JSON-decodes the result and returns the original Lua value.

	Returns nil and logs a warning if the data is malformed.
]]
function Codec.Decompress(encoded: string): any
	local raw = Base64.Decode(encoded)
	if not raw or #raw < 2 then
		warn("RoExpress.Codec: Decompress received empty or too-short data")
		return nil
	end

	local src = buffer.fromstring(raw)
	local len = buffer.len(src)

	-- validate magic
	if buffer.readu8(src, 0) ~= MAGIC_0 or buffer.readu8(src, 1) ~= MAGIC_1 then
		warn("RoExpress.Codec: Missing magic header — data may be uncompressed")
		return nil
	end

	local outBytes = {}
	local pos      = 2  -- skip magic (0-indexed)

	while pos < len do
		local token = buffer.readu8(src, pos)
		pos += 1

		if token == TOKEN_LITERAL then
			if pos >= len then
				warn("RoExpress.Codec: Truncated literal token")
				break
			end
			table.insert(outBytes, buffer.readu8(src, pos))
			pos += 1

		elseif token == TOKEN_MATCH then
			if pos + 2 >= len then
				warn("RoExpress.Codec: Truncated match token")
				break
			end
			local distHi = buffer.readu8(src, pos)     pos += 1
			local distLo = buffer.readu8(src, pos)     pos += 1
			local mlen   = buffer.readu8(src, pos)     pos += 1
			local dist   = distHi * 256 + distLo

			local startIdx = #outBytes - dist + 1
			if startIdx < 1 then
				warn("RoExpress.Codec: Invalid back-reference distance " .. dist)
				break
			end

			-- copy byte by byte (handles overlapping matches correctly)
			for i = 0, mlen - 1 do
				table.insert(outBytes, outBytes[startIdx + i])
			end
		else
			warn("RoExpress.Codec: Unknown token 0x" .. string.format("%02X", token))
			break
		end
	end

	local jsonStr = string.char(table.unpack(outBytes))
	local ok, result = pcall(HttpService.JSONDecode, HttpService, jsonStr)
	if not ok then
		warn("RoExpress.Codec: JSON decode failed after decompression:", result)
		return nil
	end

	return result
end

-- ─────────────────────────────────────────────────────────────────
-- HELPERS — used by App and Network
-- ─────────────────────────────────────────────────────────────────

--[[
	IsCompressed(encoded: string) -> boolean

	Checks whether a base64 string was produced by Codec.Compress.
	Used by Network to decide whether to decompress or plain-decode.
]]
function Codec.IsCompressed(encoded: string): boolean
	if not encoded or #encoded < 4 then return false end
	local ok, raw = pcall(Base64.Decode, encoded)
	if not ok or #raw < 2 then return false end
	local src = buffer.fromstring(raw)
	return buffer.readu8(src, 0) == MAGIC_0 and buffer.readu8(src, 1) == MAGIC_1
end

return Codec
