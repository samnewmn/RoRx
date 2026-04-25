# RoRx
 
A Reactive Extension Library for Roblox Studio — ReactiveX-style observables, operators, and state management built natively for Luau.
 
![Version](https://img.shields.io/badge/version-1.1.0-blue)
![Release](https://img.shields.io/badge/release-2026--04--22-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)
 
---
 
RoRx brings the reactive programming model from [RxJS](https://rxjs.dev/) into Roblox Studio. Instead of scattering callbacks, flags, and connection variables across your codebase, you describe data flows as composable chains that are readable, cancellable, and easy to reason about. This is the same architectural pattern used at scale in large engineering organisations — RoRx makes it available inside Roblox Studio.
 
## Installation
 
RoRx is a single `ModuleScript`. A .rbxm file and a .luau can both be found in the GitHub [releases](https://github.com/samnewmn/RoRx/releases/latest) section
 
## Core Concepts
 
An **Observable** is a lazy stream that produces values over time — after a delay, on every frame, on a Roblox event, or never. It does nothing until subscribed to.
 
An **Observer** consumes those values through three handlers: `next` (a value arrived), `error` (something went wrong), and `complete` (the stream is finished). After `error` or `complete`, no further `next` calls occur.
 
Calling `:subscribe()` returns a **Subscription**. Hold onto it if you need to cancel the stream early — for example, when a part is destroyed or a player leaves.
 
An **Operator** is a function that takes an Observable and returns a new one. Operators never modify the source; they always produce a fresh stream. Chain them with `:pipe()` or directly as methods.
 
```lua
-- These are equivalent
source:pipe(RoRx.filter(pred), RoRx.map(fn))
source:filter(pred):map(fn)
```
 
## Usage
 
```lua
-- React to players joining, debounced, only if they're on a team
RoRx.fromPlayerAdded()
    :debounceTime(500)
    :filter(function(player) return player.Team ~= nil end)
    :subscribe(function(player)
        print(player.Name .. " joined a team")
    end)
```
 
```lua
-- Fetch data for each player who joins, cancelling the previous request if a new one arrives
RoRx.fromPlayerAdded()
    :switchMap(function(player)
        return RoRx.http("https://api.example.com/player/" .. player.UserId)
    end)
    :subscribe(function(response)
        print("Got data:", response.body)
    end, function(err)
        warn("Request failed:", err.status)
    end)
```
 
```lua
-- Track a stat reactively
local score = RoRx.State.new(0)
 
score.update(function(n) return n + 10 end)
 
score.select(function(n) return n >= 100 end)
    :subscribe(function(won)
        if won then print("You win!") end
    end)
```
 
## Cleanup
 
Every subscription should be cleaned up when it is no longer needed.
 
```lua
-- Manual
local sub = RoRx.fromHeartbeat():subscribe(handler)
sub:unsubscribe()
 
-- Reactive — automatically stops when the part is removed
RoRx.fromHeartbeat()
    :takeUntil(RoRx.fromInstanceRemoved(workspace.SomePart))
    :subscribe(handler)
 
-- Registry — tear down many subscriptions at once
local registry = RoRx.createCleanupRegistry()
registry.add(RoRx.fromPlayerAdded():subscribe(...))
registry.add(someState.observe():subscribe(...))
registry.unsubscribeAll()
```
 
## What's Included
 
**Creation** — `of`, `fromArray`, `from`, `timer`, `interval`, `EMPTY`, `NEVER`, `throwError`
 
**Roblox sources** — `fromSignal`, `fromHeartbeat`, `fromRenderStep`, `fromPlayerAdded`, `fromPlayerRemoved`, `fromCharacterAdded`, `fromChildAdded`, `fromChildRemoved`, `fromDescendantAdded`, `fromDescendantRemoving`, `fromAncestryChanged`, `fromInstanceRemoved`, `fromPropertyChanged`, `fromAttributeChanged`, `fromTag`, `http`
 
**Combination** — `merge`, `concat`, `combineLatest`
 
**Filtering** — `filter`, `take`, `skip`, `first`, `last`, `takeUntil`, `takeWhile`, `distinctUntilChanged`, `find`, `findIndex`, `ignoreElements`
 
**Transformation** — `map`, `scan`, `reduce`, `toArray`, `pairwise`, `startWith`, `endWith`, `bufferCount`, `bufferTime`, `window`, `zipWith`
 
**Flattening** — `mergeMap`, `switchMap`, `concatMap`, and their `*To` shorthands
 
**Utility** — `tap`, `debounceTime`, `throttleTime`, `withLatestFrom`, `catchError`, `retry`, `share`, `shareReplay`, `multicast`
 
**Aggregation** — `every`, `count`, `min`, `max`, `isEmpty`, `defaultIfEmpty`
 
**Subjects** — `Subject`, `BehaviorSubject`, `ReplaySubject`
 
**State** — `State` / `Atom` — a reactive container with `get`, `set`, `update`, `observe`, `select`, and `destroy`
 
## Extending RoRx
 
Register custom operators with the `EXTENSION:` prefix. Once registered they are available as both `RoRx.myOp(...)` and as a chainable method on every Observable.
 
```lua
RoRx["EXTENSION:mapToString"] = function()
    return RoRx.map(function(value) return tostring(value) end)
end
 
RoRx.of(1, 2, 3):mapToString():subscribe(print) -- "1"  "2"  "3"
```
