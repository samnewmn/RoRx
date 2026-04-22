# RoRx
 
A Reactive Extension Library for Roblox Studio — ReactiveX-style observables, operators, and state management built natively for Luau.
 
![Version](https://img.shields.io/badge/version-1.1.0-blue)
![Release](https://img.shields.io/badge/release-2026--04--22-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)
 
---
 
### Overview
 
RoRx brings the reactive programming model from [RxJS](https://rxjs.dev/) into Roblox Studio. It provides composable `Observable` streams, a suite of transformation operators, multicasting subjects, and an ergonomic `State`/`Atom` container — all built on top of Roblox's native task scheduler and event system.

This is more than just useless bloat, but provides a better architecture similar to what large corporations use, but inside of Roblox Studio. When working with large databases, this prevents a large number of unknown issues and bugs that are faced, and converts those into a chainable, clean library of functions.

### Usage
RoRx is provided as a singular module script, which can either be copied from the source or downloaded as an .rbxm file or .luau file.

You can place this module within any context or environment, but some functions may be disabled as they are client-only. The recommended storage location for this module is within ReplicatedStorage.

This is a simple usage example on how to chain your Observables to provide the most efficient programming techniques when using this module:
```lua
local RoRx = require(path.to.RoRx)
 
-- React to player joins, debounced
RoRx.fromPlayerAdded()
    :debounceTime(500)
    :filter(function(player) return player.Team ~= nil end)
    :subscribe(function(player)
        print(player.Name .. " joined a team")
    end)
```
