------------------------------------------------------------------------
--  <> Title:       RoExpress.Version
--  <> Version:     1.0
--  <> Date:        30/05/2026
--  <> Author:      DeathToTheStadium
--  <> Description: Single source of truth for the RoExpress version.
--
--  This is the ONLY module that writes shared.ROEXPRESS_VERSION.
--  All other modules read from shared — never write to it.
--
--  To bump the version:
--    1. Change VERSION below
--    2. Bump wally.toml to match
--    3. Done — App and Network stay in sync automatically
--
--  HISTORY
--  ---------------------------------------------------------------
--  2.2.0   TypeCoercer, Promise, new Router types
--  2.1.0   Stream, Port, optional Network callbacks
--  2.0.0   Router, Push, Codec, Bridge, Tamper, TokenBucket rewrite
--  1.6.0   Initial release
------------------------------------------------------------------------

local VERSION = "2.2.0"

-- Write once to shared — any other module writing here is a bug
assert(
    shared.ROEXPRESS_VERSION == nil or shared.ROEXPRESS_VERSION == VERSION,
    "RoExpress.Version: shared.ROEXPRESS_VERSION was already set to '"
        .. tostring(shared.ROEXPRESS_VERSION)
        .. "' — only Version.luau should write this value"
)

shared.ROEXPRESS_VERSION = VERSION

-- Also return the version directly for any module that wants
-- to require it explicitly rather than read shared
return VERSION
