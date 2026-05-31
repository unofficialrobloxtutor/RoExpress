# Contributing to RoExpress

Thanks for your interest in contributing. RoExpress is a small, focused framework — contributions that fit its philosophy are welcome.

## Philosophy

RoExpress has a clear design intent: one disciplined networking pipeline for Roblox games. Before contributing, read the [Design Consensus](https://roexpress.dev) page to understand why decisions were made. A PR that contradicts a documented decision without addressing the tradeoff will not be merged.

## What we welcome

- Bug fixes with a clear reproduction case
- Performance improvements with measurable benchmarks
- New router param types (must go through TypeCoercer)
- Documentation improvements and example additions
- Test cases

## What we don't want

- New modules that duplicate existing functionality
- Dependencies on external packages — RoExpress has zero runtime dependencies by design
- Breaking changes to the public API without a major version discussion

## Getting started

```bash
git clone https://github.com/unofficialrobloxtutor/RoExpress
cd RoExpress
```

All source files are in `src/`. The entry point is `src/init.luau`.

## Code style

- Luau strict mode compatible
- Type annotations on all public functions
- Module-level comments explaining purpose and design decisions
- Banner comment at top of each file matching existing format
- No inline `shared` writes except in `Version.luau`

## Pull request process

1. Fork the repo and create a branch from `main`
2. Make your change
3. Update `CHANGELOG.md` under an `[Unreleased]` section
4. Open a PR with a clear description of what changed and why
5. Reference any related issues

## Reporting bugs

Open an issue on GitHub with:
- RoExpress version
- Roblox Studio version
- Minimal reproduction steps
- Expected vs actual behavior

Or drop it in `#bug-reports` on the [Discord server](https://discord.gg/TszEHgEyV5).

## Questions

- Discord: https://discord.gg/TszEHgEyV5
- DevForum: https://devforum.roblox.com/t/roexpress/4646082
