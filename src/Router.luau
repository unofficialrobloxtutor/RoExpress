------------------------------------------------------------------------
--  <> Title:       RoExpress.Router
--  <> Version:     1.0
--  <> Date:        30/05/2026
--  <> Author:      DeathToTheStadium
--  <> Description: Advanced route matching engine for RoExpress.
--
--  Supports typed params, wildcards, globs, and inline pattern constraints.
--
--  SEGMENT SYNTAX
--  ─────────────────────────────────────────────────────────────────
--  Literal          player/coins            exact match
--  Typed param      :id=number              coerce & validate type
--  Constrained      :id(\d+)                raw string must match pattern
--  Typed+constrain  :id(\d+)=number         pattern match then coerce
--  Wildcard *       player/*/coins          one segment, any value
--  Glob     **      player/**/data          zero-or-more segments
--
--  SUPPORTED TYPES
--  ─────────────────────────────────────────────────────────────────
--  string   boolean   number
--  vector2  vector3   color3   cframe
--
--  PRIORITY ORDER (highest → lowest)
--  ─────────────────────────────────────────────────────────────────
--  1. Exact literal segments
--  2. Constrained params  :id(\d+)
--  3. Typed params        :id=number
--  4. Plain params        :id
--  5. Single wildcard     *
--  6. Glob                **
------------------------------------------------------------------------

local TypeCoercer = require(script.Parent.TypeCoercer)

local Router = {}
Router.__index = Router

-- ─────────────────────────────────────────────────────────────────
-- TYPES
-- ─────────────────────────────────────────────────────────────────

export type ParamType =
	"string"  | "boolean" | "number"  | "int"     |
	"vector2" | "vector3" | "color3"  | "cframe"  |
	"Instance"| string    -- also accepts "Enum.TypeName"

export type SegmentKind =
	"literal"      -- exact text
	| "param"      -- :name  (plain, no type, no constraint)
	| "typed"      -- :name=type
	| "constrained"-- :name(\d+)  or  :name(\d+)=type
	| "wildcard"   -- *
	| "glob"       -- **

export type Segment = {
	kind        : SegmentKind,
	literal     : string?,         -- kind == "literal"
	name        : string?,         -- param / typed / constrained
	paramType   : ParamType?,      -- typed / constrained
	pattern     : string?,         -- constrained — raw lua pattern
}

export type Route = {
	method   : string,
	raw      : string,
	segments : { Segment },
	priority : number,
	compress : boolean,
	handler  : (...any) -> (),
}

export type MatchResult = {
	route    : Route,
	params   : { [string]: any },   -- coerced values keyed by name
	captures : { any },             -- wildcard/glob positional captures
}

export type Type = typeof(setmetatable({}, Router)) & {
	_routes      : { Route },
	_paramError  : ((...any) -> ())?,
}

-- ─────────────────────────────────────────────────────────────────
-- COERCERS — delegated to TypeCoercer
-- ─────────────────────────────────────────────────────────────────

type Coercer = (raw: string) -> (boolean, any)

-- delegate all coercion to TypeCoercer
local function _coerce(typeName: string, raw: string): (boolean, any)
	return TypeCoercer.FromString(raw, typeName)
end

-- ─────────────────────────────────────────────────────────────────
-- SEGMENT PARSER
-- ─────────────────────────────────────────────────────────────────

-- Returns a priority score for a segment (lower = higher priority in sort)
local function _segmentPriority(seg: Segment): number
	if seg.kind == "literal"       then return 0 end
	if seg.kind == "constrained"   then return 1 end
	if seg.kind == "typed"         then return 2 end
	if seg.kind == "param"         then return 3 end
	if seg.kind == "wildcard"      then return 4 end
	if seg.kind == "glob"          then return 5 end
	return 9
end

--[[
	Parses a single path segment token into a Segment descriptor.

	Token forms:
	  literal text        →  { kind = "literal", literal = "text" }
	  *                   →  { kind = "wildcard" }
	  **                  →  { kind = "glob" }
	  :name               →  { kind = "param",       name = "name" }
	  :name=type          →  { kind = "typed",        name, paramType }
	  :name(\d+)          →  { kind = "constrained",  name, pattern }
	  :name(\d+)=type     →  { kind = "constrained",  name, pattern, paramType }
]]
local function _parseSegment(token: string): Segment
	if token == "**" then return { kind = "glob" } end
	if token == "*"  then return { kind = "wildcard" } end

	if token:sub(1,1) ~= ":" then
		return { kind = "literal", literal = token }
	end

	-- strip leading colon
	local rest = token:sub(2)

	-- extract optional =type suffix
	local paramType: ParamType? = nil
	-- support "=Enum.TypeName", "=Instance", and base types
	local typeMatch = rest:match("=(Enum%.[%a%.]+)$") or rest:match("=(Instance)$") or rest:match("=(%a+)$")
	if typeMatch then
		assert(
			TypeCoercer.Supports(typeMatch),
			"RoExpress.Router: Unknown param type '" .. typeMatch .. "' in segment '" .. token .. "'"
		)
		paramType = typeMatch :: ParamType
		rest = rest:sub(1, -(#typeMatch + 2)) -- strip "=type"
	end

	-- extract optional (pattern) constraint
	local pattern: string? = nil
	local nameWithPattern = rest:match("^([^%(]+)%((.-)%)$")
	local name: string

	if nameWithPattern then
		local n, p = rest:match("^([^%(]+)%((.-)%)$")
		name    = n
		pattern = p
	else
		name = rest
	end

	assert(name and #name > 0, "RoExpress.Router: Empty param name in segment '" .. token .. "'")

	if pattern and paramType then
		return { kind = "constrained", name = name, pattern = pattern, paramType = paramType }
	elseif pattern then
		return { kind = "constrained", name = name, pattern = pattern }
	elseif paramType then
		return { kind = "typed", name = name, paramType = paramType }
	else
		return { kind = "param", name = name }
	end
end

local function _parseRoute(raw: string): { Segment }
	local segments = {}
	for token in raw:gmatch("[^/]+") do
		table.insert(segments, _parseSegment(token))
	end
	return segments
end

-- Route-level priority: sum of segment priorities (lower = matched first)
local function _routePriority(segments: { Segment }): number
	local score = 0
	for _, seg in ipairs(segments) do
		score += _segmentPriority(seg)
	end
	return score
end

-- ─────────────────────────────────────────────────────────────────
-- MATCHING ENGINE
-- ─────────────────────────────────────────────────────────────────

local function _splitPath(path: string): { string }
	local parts = {}
	for token in path:gmatch("[^/]+") do
		table.insert(parts, token)
	end
	return parts
end

--[[
	Attempts to match incoming path segments against a route's segment
	descriptors. Returns (params, captures) on success, nil on failure.

	params    — named param values (coerced)
	captures  — positional wildcard/glob captures
]]
local function _match(
	incomingParts : { string },
	segments      : { Segment }
): ({ [string]: any }, { any })

	local params   : { [string]: any } = {}
	local captures : { any }           = {}

	local si = 1  -- segment index
	local pi = 1  -- incoming part index

	while si <= #segments do
		local seg = segments[si]

		if seg.kind == "glob" then
			-- ** consumes all remaining parts
			local consumed = {}
			while pi <= #incomingParts do
				table.insert(consumed, incomingParts[pi])
				pi += 1
			end
			table.insert(captures, consumed)
			si += 1
			-- after a glob there must be no more segments
			if si <= #segments then return nil end
			break
		end

		-- all non-glob segments need a corresponding incoming part
		if pi > #incomingParts then return nil end

		local raw = incomingParts[pi]

		if seg.kind == "literal" then
			if raw ~= seg.literal then return nil end

		elseif seg.kind == "wildcard" then
			table.insert(captures, raw)

		elseif seg.kind == "param" then
			params[seg.name] = raw

		elseif seg.kind == "typed" then
			local ok, value = _coerce(seg.paramType, raw)
			if ok then
				params[seg.name] = value
			else
				params[seg.name] = raw
				params["__typeFail_" .. seg.name] = seg.paramType
			end

		elseif seg.kind == "constrained" then
			-- pattern check first
			if not raw:match("^" .. seg.pattern .. "$") then
				return nil  -- constraint failed
			end
			if seg.paramType then
				local ok, value = _coerce(seg.paramType, raw)
				if ok then
					params[seg.name] = value
				else
					params[seg.name] = raw
					params["__typeFail_" .. seg.name] = seg.paramType
				end
			else
				params[seg.name] = raw
			end
		end

		si += 1
		pi += 1
	end

	-- all incoming parts must be consumed (unless glob was last)
	if pi <= #incomingParts then return nil end

	return params, captures
end

-- ─────────────────────────────────────────────────────────────────
-- CONSTRUCTOR
-- ─────────────────────────────────────────────────────────────────

function Router.New(): Type
	local self       = setmetatable({}, Router) :: Type
	self._routes     = {}
	self._paramError = nil
	return self
end

-- ─────────────────────────────────────────────────────────────────
-- PUBLIC API
-- ─────────────────────────────────────────────────────────────────

--[[
	Register a route.

	method  — "GET" | "POST"
	raw     — route pattern string e.g. "player/:id=number/coins"
	handler — function called on match
]]
function Router:Add(method: string, raw: string, handler: (...any) -> (), options: { compress: boolean? }?)
	local segments = _parseRoute(raw)
	local priority = _routePriority(segments)

	local route: Route = {
		method   = method,
		raw      = raw,
		segments = segments,
		priority = priority,
		handler  = handler,
		compress = options and options.compress == true or false,
	}

	table.insert(self._routes, route)

	table.sort(self._routes, function(a, b)
		return a.priority < b.priority
	end)
end

--[[
	Register a param validation error handler.
	Called when a typed param fails coercion.

	fn(player, payload, paramName, expectedType)
]]
function Router:OnParamError(fn: (player: any, payload: any, paramName: string, expectedType: string) -> ())
	self._paramError = fn
end

--[[
	Attempt to match an incoming path + method against registered routes.

	Returns MatchResult on success, nil on no match.
	Surfaces type failures to the paramError handler (or returns a 400 signal).
]]
function Router:Match(method: string, path: string): MatchResult?
	local incomingParts = _splitPath(path)

	for _, route in ipairs(self._routes) do
		if route.method ~= method then continue end

		local result = _match(incomingParts, route.segments)
		if not result then continue end

		local params, captures = result[1] or result, result[2] or {}

		-- surface type failures
		local typeFailName: string? = nil
		local typeFailType: string? = nil
		for key, val in pairs(params) do
			local failName = key:match("^__typeFail_(.+)$")
			if failName then
				typeFailName = failName
				typeFailType = val
				params[key]  = nil  -- clean sentinel out of params
			end
		end

		if typeFailName then
			return {
				route       = route,
				params      = params,
				captures    = captures,
				_typeFail   = { name = typeFailName, expectedType = typeFailType },
			} :: any
		end

		return {
			route    = route,
			params   = params,
			captures = captures,
		}
	end

	return nil
end

function Router:Destroy()
	table.clear(self._routes)
	self._paramError = nil
end

return Router
