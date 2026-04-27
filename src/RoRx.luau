RoRx
A Reactive Extension Library for Roblox Studio.

Version: 1.1.0
Release: 2026-04-22
Version: 1.1.1
Release: 2026-04-27
]]

local RoRx = {}
RoRx.VERSION = "1.1.0"
RoRx.VERSION = "1.1.1"

-- Default error handler used when a subscription does not provide one.
-- Errors are re-thrown asynchronously to avoid interrupting the current call stack,
local FALLBACK_ERROR_HANDLER = function(err)
	error(tostring(err), 2)
-- Errors are re-thrown asynchronously to avoid interrupting the current call stack
local FALLBACK_ERROR_HANDLER = function(err: any)
	task.defer(function()
		error(err)
	end)
end

-- The key used to identify each RoRx class
local KIND_KEY = "__T"

-- Services we need to create Observables from (Roblox-specific events and APIs).
-- Services we need to create Observables from.
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

-- Represents an Observer, which has next, error, and complete handlers.
export type Observer<T> = {
next: (value: T) -> (),
error: (err: any) -> (),
complete: () -> (),
}

-- Represents a partial observer object that users can pass to subscribe,
-- where all handlers are optional.
export type IncompleteObserver<T> = {
next: ((value: T) -> ())?,
error: ((err: any) -> ())?,
complete: (() -> ())?,
}

-- Represents a Subscription, which allows unsubscribing and managing teardown.
-- These are only related to Observables, when using the :subscribe method
export type Subscription = {
	__T: "Subscription",
unsubscribe: (self: Subscription) -> (),
closed: (self: Subscription) -> boolean,
add: (self: Subscription, teardown: TeardownLogic) -> (),
@@ -54,7 +55,6 @@
-- A Subscriber is both an Observer and a Subscription, allowing it to manage
-- its own subscription state and teardown logic.
export type Subscriber<T> = {
	__T: "Subscriber",
next: (self: Subscriber<T>, value: T) -> (),
error: (self: Subscriber<T>, err: any) -> (),
complete: (self: Subscriber<T>) -> (),
@@ -63,50 +63,66 @@
unsubscribe: (self: Subscriber<T>) -> (),
}

-- The trick: define a non-generic "raw" Observable that uses `any` for self-referential
-- returns, then create a generic alias that casts to it.
-- Luau allows ONE level of generic indirection before choking on recursion.
-- In v1.1.0, I removed the generic type parameter from ObservableStatic to make sure recursive functions/chainables
-- don't error-type, as it would lead to an infinite expansion of Observable<Observable<Observable<...>>> in some cases.
-- The Observable<T> alias is still generic, so users can annotate with a specific type if they want, but the core
-- implementation is now non-generic to avoid that issue.

-- I will consider adding back a generic parameter to ObservableStatic in a future major release if I can find a way to
-- avoid the infinite expansion problem, but for now this is the most practical solution to ensure type safety without
-- hitting Luau's recursion limits.
export type ObservableStatic = {
	__T: "Observable" | "Subject" | "BehaviorSubject" | "ReplaySubject",
subscribe: (
self: ObservableStatic,
observerOrNext: (IncompleteObserver<any> | ((value: any) -> ()))?,
errorHandler: ((err: any) -> ())?,
completeHandler: (() -> ())?
) -> Subscription,

	pipe:               (self: ObservableStatic, ...any) -> any,
	filter:             (self: ObservableStatic, predicate: (value: any, index: number) -> boolean) -> ObservableStatic,
	take:               (self: ObservableStatic, count: number) -> ObservableStatic,
	skip:               (self: ObservableStatic, count: number) -> ObservableStatic,
	distinctUntilChanged:(self: ObservableStatic, comparator: ((a: any, b: any) -> boolean)?) -> ObservableStatic,
	takeUntil:          (self: ObservableStatic, notifier: ObservableStatic) -> ObservableStatic,
	takeWhile:          (self: ObservableStatic, predicate: (value: any, index: number) -> boolean, inclusive: boolean?) -> ObservableStatic,
	first:              (self: ObservableStatic, predicate: ((value: any, index: number) -> boolean)?) -> ObservableStatic,
	last:               (self: ObservableStatic, predicate: ((value: any, index: number) -> boolean)?) -> ObservableStatic,
	debounceTime:       (self: ObservableStatic, dueMs: number) -> ObservableStatic,
	throttleTime:       (self: ObservableStatic, durationMs: number) -> ObservableStatic,
	tap:                (self: ObservableStatic, observerOrNext: (IncompleteObserver<any> | ((value: any) -> ()))?) -> ObservableStatic,
	startWith:          (self: ObservableStatic, values: { any }) -> ObservableStatic,
	endWith:            (self: ObservableStatic, values: { any }) -> ObservableStatic,
	catchError:         (self: ObservableStatic, selector: (err: any, caught: ObservableStatic) -> ObservableStatic) -> ObservableStatic,
	retry:              (self: ObservableStatic, count: number?, delayMs: number?) -> ObservableStatic,
	share:              (self: ObservableStatic) -> ObservableStatic,
	shareReplay:        (self: ObservableStatic, bufferSize: number?) -> ObservableStatic,
	multicast:          (self: ObservableStatic, subject: any) -> ObservableStatic,
	map:          (self: ObservableStatic, project: (value: any, index: number) -> any) -> ObservableStatic,
	reduce:       (self: ObservableStatic, accumulator: (acc: any, value: any, index: number) -> any, seed: any) -> ObservableStatic,
	scan:         (self: ObservableStatic, accumulator: (acc: any, value: any, index: number) -> any, seed: any) -> ObservableStatic,
	mergeMap:     (self: ObservableStatic, project: (value: any, index: number) -> ObservableStatic, concurrent: number?) -> ObservableStatic,
	switchMap:    (self: ObservableStatic, project: (value: any, index: number) -> ObservableStatic) -> ObservableStatic,
	concatMap:    (self: ObservableStatic, project: (value: any, index: number) -> ObservableStatic) -> ObservableStatic,
	switchMapTo:  (self: ObservableStatic, inner: ObservableStatic) -> ObservableStatic,
	withLatestFrom:(self: ObservableStatic, other: ObservableStatic) -> ObservableStatic,
	toArray:      (self: ObservableStatic) -> ObservableStatic,
	pairwise:     (self: ObservableStatic) -> ObservableStatic,
	bufferTime:   (self: ObservableStatic, ms: number, intervalMs: number?) -> ObservableStatic,
	bufferCount:  (self: ObservableStatic, n: number, skip: number?) -> ObservableStatic,
	pipe: (self: ObservableStatic, ...any) -> any,
	filter: (self: ObservableStatic, predicate: (value: any, index: number) -> boolean) -> ObservableStatic,
	take: (self: ObservableStatic, count: number) -> ObservableStatic,
	skip: (self: ObservableStatic, count: number) -> ObservableStatic,
	distinctUntilChanged: (self: ObservableStatic, comparator: ((a: any, b: any) -> boolean)?) -> ObservableStatic,
	takeUntil: (self: ObservableStatic, notifier: ObservableStatic) -> ObservableStatic,
	takeWhile: (self: ObservableStatic, predicate: (value: any, index: number) -> boolean, inclusive: boolean?) -> ObservableStatic,
	first: (self: ObservableStatic, predicate: ((value: any, index: number) -> boolean)?) -> ObservableStatic,
	last: (self: ObservableStatic, predicate: ((value: any, index: number) -> boolean)?) -> ObservableStatic,
	debounceTime: (self: ObservableStatic, dueMs: number) -> ObservableStatic,
	throttleTime: (self: ObservableStatic, durationMs: number) -> ObservableStatic,
	tap: (self: ObservableStatic, observerOrNext: (IncompleteObserver<any> | ((value: any) -> ()))?) -> ObservableStatic,
	startWith: (self: ObservableStatic, values: { any }) -> ObservableStatic,
	endWith: (self: ObservableStatic, values: { any }) -> ObservableStatic,
	catchError: (self: ObservableStatic, selector: (err: any, caught: ObservableStatic) -> ObservableStatic) -> ObservableStatic,
	retry: (self: ObservableStatic, count: number?, delayMs: number?) -> ObservableStatic,
	share: (self: ObservableStatic) -> ObservableStatic,
	shareReplay: (self: ObservableStatic, bufferSize: number?) -> ObservableStatic,
	multicast: (self: ObservableStatic, subject: any) -> ObservableStatic,
	map: (self: ObservableStatic, project: (value: any, index: number) -> any) -> ObservableStatic,
	reduce: (self: ObservableStatic, accumulator: (acc: any, value: any, index: number) -> any, seed: any) -> ObservableStatic,
	scan: (self: ObservableStatic, accumulator: (acc: any, value: any, index: number) -> any, seed: any) -> ObservableStatic,
	mergeMap: (self: ObservableStatic, project: (value: any, index: number) -> ObservableStatic, concurrent: number?) -> ObservableStatic,
	switchMap: (self: ObservableStatic, project: (value: any, index: number) -> ObservableStatic) -> ObservableStatic,
	concatMap: (self: ObservableStatic, project: (value: any, index: number) -> ObservableStatic) -> ObservableStatic,
	switchMapTo: (self: ObservableStatic, inner: ObservableStatic) -> ObservableStatic,
	mergeMapTo: (self: ObservableStatic, inner: ObservableStatic, concurrent: number?) -> ObservableStatic,
	concatMapTo: (self: ObservableStatic, inner: ObservableStatic) -> ObservableStatic,
	withLatestFrom: (self: ObservableStatic, other: ObservableStatic) -> ObservableStatic,
	toArray: (self: ObservableStatic) -> ObservableStatic,
	pairwise: (self: ObservableStatic) -> ObservableStatic,
	bufferTime: (self: ObservableStatic, ms: number, intervalMs: number?) -> ObservableStatic,
	bufferCount: (self: ObservableStatic, n: number, skip: number?) -> ObservableStatic,
	every: (self: ObservableStatic, predicate: (value: any, index: number) -> boolean) -> ObservableStatic,
	find: (self: ObservableStatic, predicate: (value: any, index: number) -> boolean) -> ObservableStatic,
	findIndex: (self: ObservableStatic, predicate: (value: any, index: number) -> boolean) -> ObservableStatic,
	count: (self: ObservableStatic, predicate: ((value: any, index: number) -> boolean)?) -> ObservableStatic,
	min: (self: ObservableStatic, comparer: ((a: any, b: any) -> boolean)?) -> ObservableStatic,
	max: (self: ObservableStatic, comparer: ((a: any, b: any) -> boolean)?) -> ObservableStatic,
	isEmpty: (self: ObservableStatic) -> ObservableStatic,
	defaultIfEmpty: (self: ObservableStatic, defaultValue: any) -> ObservableStatic,
	ignoreElements: (self: ObservableStatic) -> ObservableStatic,
	window: (self: ObservableStatic, windowBoundaries: ObservableStatic) -> ObservableStatic,
	zipWith: (self: ObservableStatic, ...ObservableStatic) -> ObservableStatic,
}

export type Observable<T> = ObservableStatic
@@ -116,7 +132,6 @@

-- A Subject is both an Observable and an Observer.
export type Subject<T> = Observable<T> & {
	__T: "Subject" | "BehaviorSubject" | "ReplaySubject",
next: (self: Subject<T>, value: T) -> (),
error: (self: Subject<T>, err: any) -> (),
complete: (self: Subject<T>) -> (),
@@ -125,7 +140,6 @@

-- A BehaviorSubject holds the current value and replays it to new subscribers.
export type BehaviorSubject<T> = Subject<T> & {
	__T: "BehaviorSubject",
getValue: (self: BehaviorSubject<T>) -> T,
value: T,
}
@@ -134,17 +148,15 @@
-- select is generic so the derived Observable type is inferred from the
-- selector's return type rather than widened to any.
export type State<T> = {
	__T: "State",
	get: () -> T,
	set: (value: T) -> (),
	update: (updater: (current: T) -> T) -> (),
	observe: () -> Observable<T>,
	select: (selector: (value: T) -> any) -> Observable<any>,
	destroy: () -> (),
	get: (self: State<T>) -> T,
	set: (self: State<T>, value: T) -> (),
	update: (self: State<T>, updater: (current: T) -> T) -> (),
	observe: (self: State<T>) -> Observable<T>,
	select: (self: State<T>, selector: (value: T) -> any) -> Observable<any>,
	destroy: (self: State<T>) -> (),
}

export type CleanupRegistry = {
	__T: "CleanupRegistry",
add: (subscription: Subscription) -> (),
remove: (subscription: Subscription) -> (),
unsubscribeAll: () -> (),
@@ -189,16 +201,32 @@
end
end

local function createClass(name: string, content: {[any]: any}, methods: {__index: any, [any]: any}): any
	local class = {
		[KIND_KEY] = name,
	}
	for index, value in content do
		class[index] = value
	end
	if methods ~= nil then
		class = setmetatable(class, methods)
	end
	return class
end

local function buildObserver(
nextHandler: ((value: any) -> ())?,
errorHandler: ((err: any) -> ())?,
completeHandler: (() -> ())?
): Observer<any>
	return {
		next = nextHandler or noop,
		error = errorHandler or FALLBACK_ERROR_HANDLER,
		complete = completeHandler or noop,
	}
	return createClass(
		"Observer",
		{
			next = nextHandler or noop,
			error = errorHandler or FALLBACK_ERROR_HANDLER,
			complete = completeHandler or noop,
		}
	)
end

local SubscriptionMethods = {}
@@ -248,24 +276,29 @@
end

local function createSubscription(initialTeardown: TeardownLogic?): Subscription
	local self = setmetatable({
		[KIND_KEY] = "Subscription",
		_closed = false,
		_teardowns = {} :: { TeardownLogic },
	}, SubscriptionMethods)
	local self = createClass(
		"Subscription",
		{
			_closed = false,
			_teardowns = {} :: { TeardownLogic },
		},
		SubscriptionMethods
	)
if initialTeardown ~= nil then
self:add(initialTeardown)
end
return self :: any
end

local function createSubscriber(observer: Observer<any>): Subscriber<any>
	local state = {
		[KIND_KEY] = "Subscriber",
		_observer = observer,
		_closed = false,
		_teardowns = {} :: { TeardownLogic },
	}
	local state = createClass(
		"Subscriber",
		{
			_observer = observer,
			_closed = false,
			_teardowns = {} :: { TeardownLogic },
		}
	)

local function cleanup()
local teardowns = state._teardowns
@@ -349,9 +382,6 @@
return buildObserver(nil, errorHandler, completeHandler)
end

-- Annotating ObservableMethods as Observable<any> lets Luau resolve all operator
-- method signatures through the structural type you declared, rather than falling
-- through the untyped dynamic __index path which collapses generics to error-type.
local ObservableMethods: Observable<any> = {} :: Observable<any>

local function pipeFrom(self: Observable<any>, ...)
@@ -389,12 +419,10 @@
}

local function createObservable(subscribeFn: (subscriber: Subscriber<any>) -> TeardownLogic): Observable<any>
	local self = {
		[KIND_KEY] = "Observable",
		_subscribe = subscribeFn,
	}
	setmetatable(self, ObservableMeta)
	return self :: any
	return setmetatable(
		{ _subscribe = subscribeFn },
		ObservableMeta
	) :: any
end

;(ObservableMethods :: any).subscribe = function(self, observerOrNext, errorHandler, completeHandler): Subscription
@@ -2109,8 +2137,10 @@
end

local function createBehaviorSubject(initialValue: any): BehaviorSubject<any>
	local base = (createSubject() :: Subject<any>) :: any
	base[KIND_KEY] = "BehaviorSubject"
	local base = createClass(
		"BehaviorSubject",
		createSubject()
	)
base.value = initialValue

local baseSubscribe = base._subscribe
@@ -2135,8 +2165,10 @@
end

local function createReplaySubject(bufferSize: number?): Subject<any>
	local base = (createSubject() :: Subject<any>) :: any
	base[KIND_KEY] = "ReplaySubject"
	local base = createClass(
		"ReplaySubject",
		createSubject()
	)
local maxSize = bufferSize or math.huge
local buffer = {} :: { any }

@@ -2249,35 +2281,48 @@
end
end

local StateMethods = {}
StateMethods.__index = StateMethods

function StateMethods:get()
	return self._subject:getValue()
end

function StateMethods:set(value: any)
	if not self._destroyed then self._subject:next(value) end
end

function StateMethods:update(updater: (current: any) -> any)
	if not self._destroyed then self._subject:next(updater(self._subject:getValue())) end
end

function StateMethods:observe(): Observable<any>
	return self._subject:asObservable()
end

function StateMethods:select(selector: (value: any) -> any): Observable<any>
	return self._subject:asObservable():map(selector):distinctUntilChanged()
end

function StateMethods:destroy()
	if not self._destroyed then
		self._destroyed = true
		self._subject:complete()
	end
end

-- State is a small wrapper around BehaviorSubject with ergonomic mutation APIs.
local function createState(initialValue: any): State<any>
	local subject = createBehaviorSubject(initialValue)
	local destroyed = false

	return {
		[KIND_KEY] = "State",
		get = function(): any
			return subject:getValue()
		end,
		set = function(value: any)
			if not destroyed then subject:next(value) end
		end,
		update = function(updater: (current: any) -> any)
			if not destroyed then subject:next(updater(subject:getValue())) end
		end,
		observe = function(): Observable<any>
			return subject:asObservable()
		end,
		select = function(selector: (value: any) -> any): Observable<any>
			return subject:asObservable():map(selector):distinctUntilChanged()
		end,
		destroy = function()
			if not destroyed then
				destroyed = true
				subject:complete()
			end
		end,
	}
	local self = createClass(
		"State",
		{
			_subject = createBehaviorSubject(initialValue),
			_destroyed = false
		},
		StateMethods
	)

	return self :: State<any>
end

RoRx.isObservable = isObservable
@@ -2309,29 +2354,52 @@
return isTable(value) and value.unsubscribeAll ~= nil
end

function RoRx.is(value: any, kind: string): boolean
	if not isTable(value) then return false end
	return (value :: any)[KIND_KEY] == kind
end

function RoRx.isRoRxObject(value: any)
	-- Not very reliable, as your own code may have the KIND_KEY in it, make sure that the KIND_KEY
	-- is unique to RoRx objects
	return (value :: any)[KIND_KEY] ~= nil
end

-- CleanupRegistry is a simple utility for tracking and unsubscribing from multiple
-- subscriptions at once.
local function createCleanupRegistry(): CleanupRegistry
	local subs: { Subscription } = {}
	return {
		[KIND_KEY] = "CleanupRegistry",
		add = function(sub: Subscription)
			table.insert(subs, sub)
		end,
		remove = function(sub: Subscription)
			arrRemove(subs, sub)
		end,
		unsubscribeAll = function()
			local snapshot = table.clone(subs)
			table.clear(subs)
			for _, sub in ipairs(snapshot) do
				pcall(function() sub:unsubscribe() end)
			end
		end,
		count = function(): number
			return #subs
		end,
	} :: CleanupRegistry
	local self = createClass(
		"CleanupRegistry",
		{
			_subscriptions = {} :: { Subscription },
		}
	)

	function self.add(sub: Subscription)
		table.insert(self._subscriptions, sub)
	end

	function self.remove(sub: Subscription)
		arrRemove(self._subscriptions, sub)
	end

	function self.unsubscribeAll()
		local snapshot = table.clone(self._subscriptions)
		table.clear(self._subscriptions)
		for _, sub in ipairs(snapshot) do
			pcall(function() sub:unsubscribe() end)
		end
	end
	
	function self.count()
		return #self._subscriptions
	end

	return self :: CleanupRegistry
end

-- Public constructors, all using the "new" convention.

RoRx.Observable = { new = createObservable }
RoRx.Subject = { new = createSubject }
RoRx.BehaviorSubject = { new = createBehaviorSubject }
@@ -2340,9 +2408,6 @@
RoRx.State = { new = createState }
RoRx.CleanupRegistry = { new = createCleanupRegistry }

-- Atom is a public alias for State for ergonomic naming.
RoRx.Atom = RoRx.State

RoRx.asyncScheduler = {
now = function(): number
return os.clock() * 1000
@@ -2365,14 +2430,6 @@
}

setmetatable(RoRx, {
	__newindex = function(tbl, key, value)
		-- Extension registration: assign to EXTENSION:<name> to expose a new API method.
		if type(key) == "string" and key:sub(1, 10) == "EXTENSION:" then
			rawset(tbl, key:sub(11), value)
			return
		end
		warn("[RoRx] Blocked write to readonly API. Use EXTENSION:<name> for extensions.")
	end,
__tostring = function()
return "RoRxLibrary " .. RoRx.VERSION
end,
