# Contributing

Thanks for your interest in contributing to RoRx.

## Reporting bugs

Open an issue and include a minimal reproduction — the smallest possible code snippet that demonstrates the problem. Include what you expected to happen and what actually happened.

## Suggesting changes

Open an issue before writing code. A quick discussion upfront avoids wasted effort if the change isn't a good fit for the library.

## Pull requests

1. Fork the repository and create a branch from `main`.
2. Make your changes to `RoRx.luau`.
3. Make sure existing behaviour isn't broken — test against a place if you can.
4. Open a pull request with a clear description of what changed and why.

## Style

- Follow the existing code style — consistent indentation, local functions before use, no globals.
- Keep operator implementations self-contained where possible; shared internal helpers (`buildObserver`, `createObservable`, etc.) are intentional and should stay minimal.
- New operators should match the behaviour of their RxJS equivalents unless there's a specific Roblox-related reason to diverge. Document any divergence in a comment.

## Versioning

RoRx follows [Semantic Versioning](https://semver.org/). Breaking changes require a major version bump. New operators or creation functions are minor bumps. Bug fixes are patches.
