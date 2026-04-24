# Changelog

All notable changes to RoRx will be documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-04-22

### Added
- `window` operator — splits the source into nested Subject streams on each boundary emission
- `zipWith` operator — combines source values with corresponding values from other observables by index
- `every`, `find`, `findIndex`, `count`, `min`, `max`, `isEmpty`, `defaultIfEmpty`, `ignoreElements` operators
- `mergeMapTo`, `concatMapTo` shorthands
- `RoRx.createCleanupRegistry()` — manages a collection of subscriptions with a single `unsubscribeAll` call
- `RoRx.asyncScheduler` — lightweight scheduler for deferred and delayed work
- `RoRx.isObservable`, `RoRx.isSubject`, `RoRx.isBehaviorSubject`, `RoRx.isSubscription` type guards
- `RoRx.Atom` as a public alias for `RoRx.State`
- Extension registration via `RoRx["EXTENSION:name"]`

### Changed
- `retry` now always defers resubscription through `task.delay` (even at 0ms) to prevent synchronous spin-loops on immediate errors

## [1.0.0] - 2026-04-01

### Added
- Initial release
- Core Observable, Observer, Subscriber, and Subscription primitives
- `Subject`, `BehaviorSubject`, `ReplaySubject`
- `State` reactive container
- Roblox-native creation functions: `fromSignal`, `fromHeartbeat`, `fromRenderStep`, `fromPlayerAdded`, `fromPlayerRemoved`, `fromCharacterAdded`, `fromChildAdded`, `fromChildRemoved`, `fromDescendantAdded`, `fromDescendantRemoving`, `fromAncestryChanged`, `fromInstanceRemoved`, `fromPropertyChanged`, `fromAttributeChanged`, `fromTag`
- `http` observable with automatic JSON decoding
- `merge`, `concat`, `combineLatest` combination operators
- `map`, `filter`, `tap`, `take`, `skip`, `first`, `last`, `reduce`, `scan`, `toArray`, `pairwise`, `distinctUntilChanged`, `debounceTime`, `throttleTime`, `startWith`, `endWith`, `takeUntil`, `takeWhile`, `mergeMap`, `switchMap`, `concatMap`, `switchMapTo`, `withLatestFrom`, `bufferCount`, `bufferTime`, `catchError`, `retry`, `share`, `shareReplay`, `multicast` operators
- `RoRx.pipe()` for composing operators into reusable pipelines
- `RoRx.EMPTY` and `RoRx.NEVER` constants
