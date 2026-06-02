------------------------------------------------------------------------
--  <> Title:       RoExpress.Benchmark
--  <> Version:     1.0
--  <> Date:        01/06/2026
--  <> Author:      DeathToTheStadium
--  <> Description: Route benchmarking module for RoExpress
--
--  Fires real requests through Network and measures round-trip time.
--  All timing is wall-clock (os.clock) — includes serialisation,
--  network, server handler execution, and deserialisation.
--
--  QUICK START
--  ──────────────────────────────────────────────────────────────────
--  local bench = RoExpress("Benchmark")
--
--  bench:RunAndPrint("player/123", { method = "GET", iterations = 20 })
--
--  OUTPUT
--  ──────────────────────────────────────────────────────────────────
--  ── player/123   GET × 20  (warmup: 3) ────────────────────────────
--    min          4.21 ms
--    avg          6.83 ms
--    median       6.10 ms
--    p95         12.44 ms
--    p99         18.07 ms
--    max         18.71 ms
--  ──────────────────────────────────────────────────────────────────
--    errors       0 / 20
--    throughput   8.3 req/s
--  ──────────────────────────────────────────────────────────────────
------------------------------------------------------------------------
-->> Tables <<--
local Benchmark = {}
Benchmark.__index = Benchmark
-->> Variables <<--
local Network = require(script.Parent.Network)  -- for type only

------------------------------------------------------------------------
--  TYPES
------------------------------------------------------------------------
export type Config = {
    method     : ("GET" | "POST")?,
    data       : any?,
    iterations : number?,
    warmup     : number?,
    interval   : number?,
    timeout    : number?,
    label      : string?,
}

export type Results = {
    label      : string,
    route      : string,
    method     : "GET" | "POST",
    iterations : number,
    completed  : number,
    errors     : number,
    errorCodes : { [number]: number },
    warmup     : number,
    min        : number,
    max        : number,
    avg        : number,
    median     : number,
    p95        : number,
    p99        : number,
    total      : number,
    throughput : number,
}

export type Type = typeof(setmetatable({}, Benchmark)) & {
    _network: Network.Type,
}

------------------------------------------------------------------------
--  PRIVATE
------------------------------------------------------------------------
local function _pct(sorted: { number }, p: number): number
    if #sorted == 0 then return 0 end
    return sorted[math.clamp(math.ceil(#sorted * p), 1, #sorted)]
end

local function _fmt(n: number): string
    return string.format("%.2f ms", n)
end

local function _fire(self: Type, method: string, route: string, data: any, timeout: number?)
    if method == "POST" then
        return self._network:Post(route, data, nil, timeout)
    end
    return self._network:Get(route, data, nil, timeout)
end

------------------------------------------------------------------------
--  CONSTRUCTOR
------------------------------------------------------------------------
function Benchmark.New(network: Network.Type): Type
    local self    = setmetatable({}, Benchmark) :: Type
    self._network = network
    return self
end

------------------------------------------------------------------------
--  PUBLIC API
------------------------------------------------------------------------

--[[
    Run(route, config?) -> Results

    Fires `iterations` sequential requests to `route` and returns a
    full statistics table. A warmup pass runs first — those results
    are discarded so JIT and connection overhead don't skew the numbers.

    Config defaults:
        method     = "GET"
        iterations = 20
        warmup     = 3
        interval   = 0     -- seconds between requests
        timeout    = 10    -- per-request timeout (passed to Network)
]]
function Benchmark:Run(route: string, config: Config?): Results
    local cfg        = config or {}
    local method     = cfg.method     or "GET"
    local data       = cfg.data
    local iterations = cfg.iterations or 20
    local warmup     = cfg.warmup     or 3
    local interval   = cfg.interval   or 0
    local timeout    = cfg.timeout
    local label      = cfg.label      or route

    assert(iterations > 0, "Benchmark: iterations must be > 0")
    assert(warmup >= 0,    "Benchmark: warmup must be >= 0")

    local times:      { number }          = {}
    local errorCodes: { [number]: number } = {}
    local errors = 0

    -- warmup — results discarded
    for _ = 1, warmup do
        _fire(self, method, route, data, timeout)
        if interval > 0 then task.wait(interval) end
    end

    -- measured pass
    local wallStart = os.clock()

    for _ = 1, iterations do
        local t0         = os.clock()
        local _, response = _fire(self, method, route, data, timeout)
        local elapsed    = (os.clock() - t0) * 1000  -- ms

        table.insert(times, elapsed)

        if response and response.type == "error" then
            errors += 1
            local code = response.status or 0
            errorCodes[code] = (errorCodes[code] or 0) + 1
        end

        if interval > 0 then task.wait(interval) end
    end

    local wallMs = (os.clock() - wallStart) * 1000

    table.sort(times)

    local n   = #times
    local sum = 0
    for _, t in ipairs(times) do sum += t end

    return {
        label      = label,
        route      = route,
        method     = method,
        iterations = iterations,
        completed  = n,
        errors     = errors,
        errorCodes = errorCodes,
        warmup     = warmup,
        min        = n > 0 and times[1]   or 0,
        max        = n > 0 and times[n]   or 0,
        avg        = n > 0 and sum / n    or 0,
        median     = _pct(times, 0.50),
        p95        = _pct(times, 0.95),
        p99        = _pct(times, 0.99),
        total      = wallMs,
        throughput = wallMs > 0 and (n / (wallMs / 1000)) or 0,
    }
end

--[[
    Print(results)

    Prints a formatted summary of a Results table to the output window.
]]
function Benchmark:Print(results: Results): ()
    local bar  = "── " .. string.rep("─", 50)
    local thin = "   " .. string.rep("─", 50)

    local function row(k: string, v: string)
        print(string.format("   %-12s %s", k, v))
    end

    print("")
    print(string.format("%s  %s   %s × %d  (warmup: %d)",
        bar, results.label, results.method, results.iterations, results.warmup))
    print(thin)
    row("min",    _fmt(results.min))
    row("avg",    _fmt(results.avg))
    row("median", _fmt(results.median))
    row("p95",    _fmt(results.p95))
    row("p99",    _fmt(results.p99))
    row("max",    _fmt(results.max))
    print(thin)

    -- error summary line
    local errStr = results.errors .. " / " .. results.iterations
    if results.errors > 0 then
        local parts: { string } = {}
        for code, count in pairs(results.errorCodes) do
            table.insert(parts, count .. " × " .. code)
        end
        table.sort(parts)
        errStr = errStr .. "   (" .. table.concat(parts, ", ") .. ")"
    end

    row("errors",     errStr)
    row("throughput", string.format("%.1f req/s", results.throughput))
    print(bar .. "\n")
end

--[[
    RunAndPrint(route, config?) -> Results

    Convenience wrapper — runs the benchmark and immediately prints results.
]]
function Benchmark:RunAndPrint(route: string, config: Config?): Results
    local results = self:Run(route, config)
    self:Print(results)
    return results
end

--[[
    Compare(results) -> ()

    Prints multiple Results side-by-side for easy comparison.

    bench:Compare({
        bench:Run("player/:id", { label = "GET player" }),
        bench:Run("stats/save", { method = "POST", label = "POST stats" }),
    })
]]
function Benchmark:Compare(resultSet: { Results }): ()
    assert(#resultSet > 0, "Benchmark:Compare — resultSet is empty")

    local bar  = "── " .. string.rep("─", 66)
    local thin = "   " .. string.rep("─", 66)

    -- header
    print("")
    local header = string.format("   %-14s", "route")
    for _, r in ipairs(resultSet) do
        header = header .. string.format("  %-14s", r.label)
    end
    print(bar)
    print(header)
    print(thin)

    local metrics: { { label: string, key: string } } = {
        { label = "min",    key = "min"    },
        { label = "avg",    key = "avg"    },
        { label = "median", key = "median" },
        { label = "p95",    key = "p95"    },
        { label = "p99",    key = "p99"    },
        { label = "max",    key = "max"    },
    }

    for _, m in ipairs(metrics) do
        local line = string.format("   %-14s", m.label)
        for _, r in ipairs(resultSet) do
            line = line .. string.format("  %-14s", _fmt((r :: any)[m.key]))
        end
        print(line)
    end

    print(thin)

    -- errors row
    local errLine = string.format("   %-14s", "errors")
    for _, r in ipairs(resultSet) do
        errLine = errLine .. string.format("  %-14s", r.errors .. "/" .. r.iterations)
    end
    print(errLine)

    -- throughput row
    local tpLine = string.format("   %-14s", "throughput")
    for _, r in ipairs(resultSet) do
        tpLine = tpLine .. string.format("  %-14s", string.format("%.1f req/s", r.throughput))
    end
    print(tpLine)

    print(bar .. "\n")
end

--[[
    Destroy()

    Clears the benchmark reference. Does NOT destroy the Network
    instance — the caller owns it.
]]
function Benchmark:Destroy(): ()
    self._network = nil :: any
end

return Benchmark
