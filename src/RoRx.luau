--[[
RoRx
A Reactive Extension Library for Roblox Studio.

Version: 1.2.0
Release: 2026-04-27
]]

local RoRx = {}
RoRx.VERSION = "1.2.0"

-- Default error handler used when a subscription does not provide one.
-- Errors are re-thrown asynchronously to avoid interrupting the current call stack
local FALLBACK_ERROR_HANDLER = function(err: any)
	task.defer(function()
		error(err)
	end)
end

-- The key used to identify each RoRx class
local KIND_KEY = "__T"

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
export type Subscription = {
	unsubscribe: (self: Subscription) -> (),
	closed: (self: Subscription) -> boolean,
	add: (self: Subscription, teardown: TeardownLogic) -> (),
	remove: (self: Subscription, teardown: TeardownLogic) -> (),
}

-- TeardownLogic can be a cleanup function, another Subscription, or nil.
export type TeardownLogic = (() -> ()) | Subscription | nil

-- A Subscriber is both an Observer and a Subscription, allowing it to manage
-- its own subscription state and teardown logic.
export type Subscriber<T> = {
	next: (self: Subscriber<T>, value: T) -> (),
	error: (self: Subscriber<T>, err: any) -> (),
	complete: (self: Subscriber<T>) -> (),
	closed: (self: Subscriber<T>) -> boolean,
	add: (self: Subscriber<T>, teardown: TeardownLogic) -> (),
	unsubscribe: (self: Subscriber<T>) -> (),
}

-- In v1.1.0, I removed the generic type parameter from ObservableStatic to make sure recursive functions/chainables
-- don't error-type, as it would lead to an infinite expansion of Observable<Observable<Observable<...>>> in some cases.
-- The Observable<T> alias is still generic, so users can annotate with a specific type if they want, but the core
-- implementation is now non-generic to avoid that issue.

-- I will consider adding back a generic parameter to ObservableStatic in a future major release if I can find a way to
-- avoid the infinite expansion problem, but for now this is the most practical solution to ensure type safety without
-- hitting Luau's recursion limits.
export type ObservableStatic = {
	subscribe: (
		self: ObservableStatic,
		observerOrNext: (IncompleteObserver<any> | ((value: any) -> ()))?,
		errorHandler: ((err: any) -> ())?,
		completeHandler: (() -> ())?
	) -> Subscription,
	
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

export type OperatorFunction<T, R> = (source: Observable<T>) -> Observable<R>
export type MonoTypeOperatorFunction<T> = OperatorFunction<T, T>

-- A Subject is both an Observable and an Observer.
export type Subject<T> = Observable<T> & {
	next: (self: Subject<T>, value: T) -> (),
	error: (self: Subject<T>, err: any) -> (),
	complete: (self: Subject<T>) -> (),
	asObservable: (self: Subject<T>) -> Observable<T>,
}

-- A BehaviorSubject holds the current value and replays it to new subscribers.
export type BehaviorSubject<T> = Subject<T> & {
	getValue: (self: BehaviorSubject<T>) -> T,
	value: T,
}

-- State<T> is a reactive container wrapping a BehaviorSubject.
-- select is generic so the derived Observable type is inferred from the
-- selector's return type rather than widened to any.
export type State<T> = {
	get: (self: State<T>) -> T,
	set: (self: State<T>, value: T) -> (),
	update: (self: State<T>, updater: (current: T) -> T) -> (),
	observe: (self: State<T>) -> Observable<T>,
	select: (self: State<T>, selector: (value: T) -> any) -> Observable<any>,
	destroy: (self: State<T>) -> (),
}

export type CleanupRegistry = {
	add: (subscription: Subscription) -> (),
	remove: (subscription: Subscription) -> (),
	unsubscribeAll: () -> (),
	count: () -> number
}

local function noop() end

local function isFunction(value: any): boolean
	return type(value) == "function"
end

local function isTable(value: any): boolean
	return type(value) == "table"
end

local function hasKind(value: any, expected: string): boolean
	return isTable(value) and (value :: any)[KIND_KEY] == expected
end

local function isSubscription(value: any): boolean
	if not isTable(value) then return false end
	if hasKind(value, "Subscription") then return true end
	return isFunction(value.unsubscribe) and isFunction(value.closed)
end

local function isObservable(value: any): boolean
	if not isTable(value) then return false end
	local kind = (value :: any)[KIND_KEY]
	if kind == "Observable" or kind == "Subject" or kind == "BehaviorSubject" or kind == "ReplaySubject" then
		return true
	end
	return isFunction(value.subscribe) and isFunction(value.pipe)
end

local function arrRemove(arr: { any }, item: any)
	for i = #arr, 1, -1 do
		if arr[i] == item then
			table.remove(arr, i)
			return
		end
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
SubscriptionMethods.__index = SubscriptionMethods

function SubscriptionMethods:closed(): boolean
	return self._closed
end

function SubscriptionMethods:add(teardown: TeardownLogic)
	if teardown == nil then return end
	if self._closed then
		if isFunction(teardown) then
			pcall(teardown :: () -> ())
		elseif isSubscription(teardown) then
			(teardown :: Subscription):unsubscribe()
		end
		return
	end
	table.insert(self._teardowns, teardown)
end

function SubscriptionMethods:remove(teardown: TeardownLogic)
	if teardown == nil then return end
	arrRemove(self._teardowns, teardown)
end

function SubscriptionMethods:unsubscribe()
	if self._closed then return end
	self._closed = true
	local teardowns = self._teardowns
	self._teardowns = {}
	for i = #teardowns, 1, -1 do
		local t = teardowns[i]
		local ok: boolean
		if isFunction(t) then
			ok = pcall(t :: () -> ())
		elseif isSubscription(t) then
			ok = pcall(function()
				return (t :: Subscription):unsubscribe()
			end)
		end
		if not ok then
			-- Continue cleanup even if one teardown fails.
		end
	end
end

local function createSubscription(initialTeardown: TeardownLogic?): Subscription
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
		state._teardowns = {}
		for i = #teardowns, 1, -1 do
			local t = teardowns[i]
			local ok: boolean
			local err: any = nil
			if isFunction(t) then
				ok, err = pcall(t :: () -> ())
			elseif isSubscription(t) then
				ok, err = pcall(function()
					return (t :: Subscription):unsubscribe()
				end)
			end
			if not ok then
				state._observer.error("Uncaught error in subscriber teardown: " .. tostring(err))
			end
		end
	end

	local methods = { _observer = observer }

	function methods:closed(): boolean
		return state._closed
	end

	function methods:add(teardown: TeardownLogic)
		if teardown == nil then return end
		if state._closed then
			if isFunction(teardown) then
				pcall(teardown :: () -> ())
			elseif isSubscription(teardown) then
				(teardown :: Subscription):unsubscribe()
			end
			return
		end
		table.insert(state._teardowns, teardown)
	end

	function methods:next(value: any)
		if state._closed then return end
		state._observer.next(value)
	end

	function methods:error(err: any)
		if state._closed then return end
		state._closed = true
		pcall(state._observer.error, err)
		cleanup()
	end

	function methods:complete()
		if state._closed then return end
		state._closed = true
		pcall(state._observer.complete)
		cleanup()
	end

	function methods:unsubscribe()
		if state._closed then return end
		state._closed = true
		cleanup()
	end

	return methods :: any
end

local function toObserver(
	observerOrNext: IncompleteObserver<any> | ((value: any) -> ())?,
	errorHandler: ((err: any) -> ())?,
	completeHandler: (() -> ())?
): Observer<any>
	if isFunction(observerOrNext) then
		return buildObserver(observerOrNext :: (value: any) -> (), errorHandler, completeHandler)
	end
	if isTable(observerOrNext) then
		local o = observerOrNext :: IncompleteObserver<any>
		return buildObserver(o.next, o.error or errorHandler, o.complete or completeHandler)
	end
	return buildObserver(nil, errorHandler, completeHandler)
end

local ObservableMethods: Observable<any> = {} :: Observable<any>

local function pipeFrom(self: Observable<any>, ...)
	local ops = { ... }
	local current = self
	for _, op in ipairs(ops) do
		current = op(current)
	end
	return current
end

-- Resolves operator names on an Observable to their RoRx factory, threading
-- `self` through as the source. This makes every RoRx operator chainable as a
-- method with zero extra wiring. Used only for EXTENSION: registered operators
-- that don't have an explicit entry in ObservableMethods.
local function resolveObservableIndex(self, key)
	local method = (ObservableMethods :: any)[key]
	if method ~= nil then return method end

	local operatorFactory = RoRx[key]
	if isFunction(operatorFactory) then
		return function(_, ...)
			return pipeFrom(self, operatorFactory(...))
		end
	end

	return nil
end

local ObservableMeta = {
	__index = resolveObservableIndex,
	__tostring = function(self)
		return ("RoRx.%s"):format(self[KIND_KEY] or "Observable")
	end,
}

local function createObservable(subscribeFn: (subscriber: Subscriber<any>) -> TeardownLogic): Observable<any>
	return setmetatable(
		{ _subscribe = subscribeFn },
		ObservableMeta
	) :: any
end

;(ObservableMethods :: any).subscribe = function(self, observerOrNext, errorHandler, completeHandler): Subscription
	local observer = toObserver(observerOrNext, errorHandler, completeHandler)
	local subscriber = createSubscriber(observer)

	local ok, teardownOrErr = pcall(function()
		return (self :: any)._subscribe(subscriber)
	end)

	if not ok then
		subscriber:error(teardownOrErr)
		return createSubscription()
	end

	if not subscriber:closed() and teardownOrErr ~= nil then
		subscriber:add(teardownOrErr)
	end

	local root = createSubscription()
	root:add(function()
		subscriber:unsubscribe()
	end)
	return root
end

;(ObservableMethods :: any).pipe = function(self, ...)
	return pipeFrom(self, ...)
end

-- An empty observable that immediately completes without emitting any values.
RoRx.EMPTY = createObservable(function(subscriber)
	subscriber:complete()
	return nil
end)

-- An observable that never emits and never completes.
RoRx.NEVER = createObservable(function(_)
	return nil
end)

-- Creates an observable that emits the provided values in sequence then completes.
function RoRx.of(...: any): Observable<any>
	local values = { ... }
	return createObservable(function(subscriber: Subscriber<any>)
		for _, value in ipairs(values) do
			if subscriber:closed() then return nil end
			subscriber:next(value)
		end
		subscriber:complete()
		return nil
	end)
end

-- Creates an observable from an array, emitting each element in sequence.
function RoRx.fromArray(values: { any }): Observable<any>
	return createObservable(function(subscriber: Subscriber<any>)
		for _, value in ipairs(values) do
			if subscriber:closed() then return nil end
			subscriber:next(value)
		end
		subscriber:complete()
		return nil
	end)
end

-- Creates an observable from various input types.
-- Passes through an existing Observable; converts an array-like table.
function RoRx.from(input: Observable<any> | { any }): Observable<any>
	if isObservable(input) then
		return input :: Observable<any>
	end
	return RoRx.fromArray(input :: { any })
end

-- Emits an error immediately on subscription.
-- Accepts an error value or a factory function for lazy evaluation.
function RoRx.throwError(errFactory: (() -> any) | any): Observable<any>
	return createObservable(function(subscriber)
		local err = if isFunction(errFactory) then (errFactory :: () -> any)() else errFactory
		subscriber:error(err)
		return nil
	end)
end

-- Creates an observable that emits sequential numbers starting from 0 after
-- dueMs, then optionally continues at intervalMs.
function RoRx.timer(dueMs: number, intervalMs: number?): Observable<number>
	return createObservable(function(subscriber)
		local running = true
		local count = 0
		task.spawn(function()
			task.wait(dueMs / 1000)
			if not running or subscriber:closed() then return end
			subscriber:next(count)
			count += 1
			if intervalMs == nil then
				subscriber:complete()
				return
			end
			while running and not subscriber:closed() do
				task.wait((intervalMs :: number) / 1000)
				if running and not subscriber:closed() then
					subscriber:next(count)
					count += 1
				end
			end
		end)
		return function()
			running = false
		end
	end)
end

-- Creates an observable that emits sequential numbers every periodMs.
-- The first emission happens after the first period elapses.
function RoRx.interval(periodMs: number): Observable<number>
	if periodMs <= 0 then
		return RoRx.throwError("interval: periodMs must be > 0")
	end
	return createObservable(function(subscriber)
		local count = 0
		local elapsedMs = 0
		local connection = RunService.Heartbeat:Connect(function(dt)
			if subscriber:closed() then return end
			elapsedMs += dt * 1000
			while elapsedMs >= periodMs do
				elapsedMs -= periodMs
				subscriber:next(count)
				count += 1
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)
end

-- Creates an observable from a Roblox event signal.
-- Emits a single value when the event has one argument, or an array for multi.
function RoRx.fromSignal(signal: RBXScriptSignal): Observable<any>
	return createObservable(function(subscriber)
		local connection = signal:Connect(function(...)
			if subscriber:closed() then return end
			local args = { ... }
			if #args == 1 then
				subscriber:next(args[1])
			else
				subscriber:next(args)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)
end

-- Creates an observable that emits the delta time (seconds) on each Heartbeat.
function RoRx.fromHeartbeat(): Observable<number>
	return createObservable(function(subscriber)
		local connection = RunService.Heartbeat:Connect(function(dt)
			if not subscriber:closed() then
				subscriber:next(dt)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)
end

-- Creates an observable that emits each Player that joins.
-- Also emits all currently connected players immediately on subscription.
function RoRx.fromPlayerAdded(): Observable<Player>
	return createObservable(function(subscriber)
		for _, player in ipairs(Players:GetPlayers()) do
			if subscriber:closed() then return nil end
			subscriber:next(player)
		end
		local connection = Players.PlayerAdded:Connect(function(player)
			if not subscriber:closed() then
				subscriber:next(player)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)
end

-- Creates an observable that emits each Player that leaves.
function RoRx.fromPlayerRemoved(): Observable<Player>
	return createObservable(function(subscriber)
		local connection = Players.PlayerRemoving:Connect(function(player)
			if not subscriber:closed() then
				subscriber:next(player)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)
end

-- Creates an observable that emits each direct child added to an instance.
function RoRx.fromChildAdded(instance: Instance): Observable<Instance>
	return createObservable(function(subscriber)
		local connection = instance.ChildAdded:Connect(function(child)
			if not subscriber:closed() then
				subscriber:next(child)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)
end

-- Creates an observable that emits each direct child removed from an instance.
function RoRx.fromChildRemoved(instance: Instance): Observable<Instance>
	return createObservable(function(subscriber)
		local connection = instance.ChildRemoved:Connect(function(child)
			if not subscriber:closed() then
				subscriber:next(child)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)
end

-- Creates an observable that emits a {child, parent} table whenever the
-- ancestry of the given instance changes.
function RoRx.fromAncestryChanged(instance: Instance): Observable<{ [string]: Instance }>
	return createObservable(function(subscriber)
		local connection = instance.AncestryChanged:Connect(function(child, parent)
			if not subscriber:closed() then
				subscriber:next({ child = child, parent = parent })
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)
end

-- Creates an observable that emits each descendant added anywhere under instance.
function RoRx.fromDescendantAdded(instance: Instance): Observable<Instance>
	return createObservable(function(subscriber)
		local connection = instance.DescendantAdded:Connect(function(descendant)
			if not subscriber:closed() then
				subscriber:next(descendant)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)
end

-- Creates an observable that emits each descendant about to be removed from
-- anywhere under instance.
function RoRx.fromDescendantRemoving(instance: Instance): Observable<Instance>
	return createObservable(function(subscriber)
		local connection = instance.DescendantRemoving:Connect(function(descendant)
			if not subscriber:closed() then
				subscriber:next(descendant)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)
end

-- Creates an observable that emits `instance` once when its parent becomes nil
-- (i.e. it is destroyed or unparented), then completes.
function RoRx.fromInstanceRemoved(instance: Instance): Observable<Instance>
	return createObservable(function(subscriber)
		local connection = instance.AncestryChanged:Connect(function(_, parent)
			if not subscriber:closed() and parent == nil then
				subscriber:next(instance)
				subscriber:complete()
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)
end

-- Creates an observable that emits the delta time on each RenderStep.
-- Returns NEVER on the server (RenderStep is client-only).
function RoRx.fromRenderStep(name: string, priority: number?): Observable<number>
	if RunService:IsServer() then
		return RoRx.NEVER
	end
	return createObservable(function(subscriber)
		local bindingName = name .. "_" .. tostring({}):sub(10)
		RunService:BindToRenderStep(bindingName, priority or Enum.RenderPriority.Last.Value, function(dt)
			if not subscriber:closed() then
				subscriber:next(dt)
			end
		end)
		return function()
			RunService:UnbindFromRenderStep(bindingName)
		end
	end)
end

-- Creates an observable that emits the new attribute value whenever the named
-- attribute changes on the given instance.
function RoRx.fromAttributeChanged(instance: Instance, attribute: string): Observable<any>
	return createObservable(function(subscriber)
		local connection = instance:GetAttributeChangedSignal(attribute):Connect(function()
			if not subscriber:closed() then
				subscriber:next(instance:GetAttribute(attribute))
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)
end

-- Creates an observable that emits the new value whenever the named property
-- changes on the given instance.
function RoRx.fromPropertyChanged(instance: Instance, property: string): Observable<any>
	local ok, signal = pcall(function()
		return instance:GetPropertyChangedSignal(property)
	end)
	if not ok then
		warn("[RoRx] fromPropertyChanged: property '" .. property .. "' does not exist on " .. tostring(instance))
		return RoRx.NEVER
	end
	return createObservable(function(subscriber)
		local connection = (signal :: RBXScriptSignal):Connect(function()
			if not subscriber:closed() then
				local readOk, value = pcall(function() return (instance :: any)[property] end)
				if readOk then
					subscriber:next(value)
				else
					subscriber:error(value)
				end
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)
end

-- Creates an observable that emits each character Model when the given player's
-- character loads. Returns NEVER when the argument is not a Player.
function RoRx.fromCharacterAdded(player: Player): Observable<Model>
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return RoRx.NEVER
	end
	return createObservable(function(subscriber)
		local connection = player.CharacterAdded:Connect(function(character)
			if not subscriber:closed() then
				subscriber:next(character)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)
end

-- Creates an observable that emits {instance, added} for every instance tagged
-- with `tag` via CollectionService. Emits existing tagged instances immediately.
function RoRx.fromTag(tag: string): Observable<{ instance: Instance, added: boolean }>
	return createObservable(function(subscriber)
		for _, instance in ipairs(CollectionService:GetTagged(tag)) do
			if not subscriber:closed() then
				subscriber:next({ instance = instance, added = true })
			end
		end
		local addedConn = CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
			if not subscriber:closed() then
				subscriber:next({ instance = instance, added = true })
			end
		end)
		local removedConn = CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
			if not subscriber:closed() then
				subscriber:next({ instance = instance, added = false })
			end
		end)
		return function()
			addedConn:Disconnect()
			removedConn:Disconnect()
		end
	end)
end

-- Makes an HTTP request and emits the response as {status, statusText, body,
-- rawBody, headers, ok}. JSON is decoded automatically unless parseJson = false.
function RoRx.http(
	config: {
		url: string,
		method: string?,
		headers: { [string]: string }?,
		body: string?,
		parseJson: boolean?,
	} | string
): Observable<any>
	return createObservable(function(subscriber)
		local httpEnabled: boolean = false
		pcall(function()
			httpEnabled = HttpService.HttpEnabled
		end)
		if not httpEnabled then
			subscriber:error(
				"[RoRx] http: HttpService.HttpEnabled is false. "
					.. "Enable it under Game Settings > Security."
			)
			return nil
		end

		local requestConfig: { [string]: any }
		if type(config) == "string" then
			requestConfig = { Url = config, Method = "GET" }
		else
			requestConfig = {
				Url = (config :: any).url,
				Method = ((config :: any).method or "GET"):upper(),
				Headers = (config :: any).headers,
				Body = (config :: any).body,
			}
		end

		local cancelled = false
		task.spawn(function()
			if cancelled or subscriber:closed() then return end
			local ok, response = pcall(function()
				return HttpService:RequestAsync(requestConfig)
			end)
			if cancelled or subscriber:closed() then return end
			if not ok then
				subscriber:error(response)
				return
			end
			local raw = response.Body
			local parsedBody: any = raw
			local parseJson = not (type(config) == "table" and (config :: any).parseJson == false)
			if parseJson then
				pcall(function()
					parsedBody = HttpService:JSONDecode(raw)
				end)
			end
			local emission = {
				status = response.StatusCode,
				statusText = response.StatusMessage,
				body = parsedBody,
				rawBody = raw,
				headers = response.Headers,
				ok = response.Success,
			}
			if response.Success then
				subscriber:next(emission)
				subscriber:complete()
			else
				subscriber:error(emission)
			end
		end)
		return function()
			cancelled = true
		end
	end)
end

-- Merges multiple observables into one, emitting all values as they arrive.
-- Completes when all sources complete; errors if any source errors.
function RoRx.merge(...: Observable<any> | { any }): Observable<any>
	local sources = { ... }
	return createObservable(function(subscriber)
		if #sources == 0 then
			subscriber:complete()
			return nil
		end
		local remaining = #sources
		local subs = {} :: { Subscription }
		local function onSourceComplete()
			remaining -= 1
			if remaining == 0 and not subscriber:closed() then
				subscriber:complete()
			end
		end
		for _, source in ipairs(sources) do
			local sub = RoRx.from(source):subscribe(buildObserver(
				function(value) subscriber:next(value) end,
				function(err) subscriber:error(err) end,
				onSourceComplete
				))
			table.insert(subs, sub)
		end
		return function()
			for _, sub in ipairs(subs) do sub:unsubscribe() end
		end
	end)
end

-- Concatenates observables sequentially — each source is subscribed only after
-- the previous completes.
function RoRx.concat(...: Observable<any> | { any }): Observable<any>
	local sources = { ... }
	return createObservable(function(subscriber)
		local index = 1
		local activeSub: Subscription? = nil
		local function subscribeNext()
			if subscriber:closed() then return end
			if index > #sources then
				subscriber:complete()
				return
			end
			local current = RoRx.from(sources[index])
			index += 1
			activeSub = current:subscribe(buildObserver(
				function(value) subscriber:next(value) end,
				function(err) subscriber:error(err) end,
				subscribeNext
				))
		end
		subscribeNext()
		return function()
			if activeSub ~= nil then activeSub:unsubscribe() end
		end
	end)
end

-- Emits an array of the latest values from all sources whenever any one emits.
-- Only starts emitting once every source has emitted at least once.
function RoRx.combineLatest(sources: { Observable<any> }): Observable<{ any }>
	return createObservable(function(subscriber)
		if #sources == 0 then
			subscriber:complete()
			return nil
		end

		local latest = {} :: { any }
		local hasValue = {} :: { boolean }
		local completed = {} :: { boolean }
		local filledCount = 0
		local subs = {} :: { Subscription }

		for i = 1, #sources do
			hasValue[i] = false
			completed[i] = false
		end

		for i, source in ipairs(sources) do
			local index = i
			local sub = source:subscribe(buildObserver(
				function(value)
					if subscriber:closed() then return end
					if not hasValue[index] then
						hasValue[index] = true
						filledCount += 1
					end
					latest[index] = value
					if filledCount == #sources then
						subscriber:next(table.clone(latest))
					end
				end,
				function(err) subscriber:error(err) end,
				function()
					completed[index] = true
					-- A source that completed without ever emitting means
					-- combineLatest can never reach the all-filled condition.
					if not hasValue[index] then
						subscriber:complete()
						return
					end
					local allDone = true
					for _, done in ipairs(completed) do
						if not done then allDone = false break end
					end
					if allDone and not subscriber:closed() then
						subscriber:complete()
					end
				end
				))
			table.insert(subs, sub)
		end

		return function()
			for _, sub in ipairs(subs) do sub:unsubscribe() end
		end
	end)
end

-- Maps each value through a projection function.
function RoRx.map(project: (value: any, index: number) -> any): OperatorFunction<any, any>
	return function(source: Observable<any>)
		return createObservable(function(subscriber)
			local index = 0
			return source:subscribe(buildObserver(
				function(value)
					local ok, mapped = pcall(project, value, index)
					index += 1
					if ok then subscriber:next(mapped) else subscriber:error(mapped) end
				end,
				function(err) subscriber:error(err) end,
				function() subscriber:complete() end
				))
		end)
	end
end

-- Forwards only values for which the predicate returns true.
function RoRx.filter(predicate: (value: any, index: number) -> boolean): MonoTypeOperatorFunction<any>
	return function(source: Observable<any>)
		return createObservable(function(subscriber)
			local index = 0
			return source:subscribe(buildObserver(
				function(value)
					local ok, allowed = pcall(predicate, value, index)
					index += 1
					if not ok then subscriber:error(allowed) return end
					if allowed then subscriber:next(value) end
				end,
				function(err) subscriber:error(err) end,
				function() subscriber:complete() end
				))
		end)
	end
end

-- Performs a side effect for each notification without altering the values.
function RoRx.tap(
	observerOrNext: IncompleteObserver<any> | ((value: any) -> ())?
): MonoTypeOperatorFunction<any>
	local tapObserver = toObserver(observerOrNext, nil, nil)
	return function(source: Observable<any>)
		return createObservable(function(subscriber)
			return source:subscribe(buildObserver(
				function(value)
					pcall(tapObserver.next, value)
					subscriber:next(value)
				end,
				function(err)
					pcall(tapObserver.error, err)
					subscriber:error(err)
				end,
				function()
					pcall(tapObserver.complete)
					subscriber:complete()
				end
				))
		end)
	end
end

-- Emits at most `count` values then completes.
function RoRx.take(count: number): MonoTypeOperatorFunction<any>
	return function(source: Observable<any>)
		return createObservable(function(subscriber)
			if count <= 0 then
				subscriber:complete()
				return nil
			end
			local seen = 0
			return source:subscribe(buildObserver(
				function(value)
					seen += 1
					subscriber:next(value)
					if seen >= count then subscriber:complete() end
				end,
				function(err) subscriber:error(err) end,
				function() subscriber:complete() end
				))
		end)
	end
end

-- Ignores the first `count` values then forwards the rest.
function RoRx.skip(count: number): MonoTypeOperatorFunction<any>
	return function(source: Observable<any>)
		return createObservable(function(subscriber)
			local seen = 0
			return source:subscribe(buildObserver(
				function(value)
					seen += 1
					if seen > count then subscriber:next(value) end
				end,
				function(err) subscriber:error(err) end,
				function() subscriber:complete() end
				))
		end)
	end
end

-- Accumulates all values and emits the result when the source completes.
function RoRx.reduce(
	accumulator: (acc: any, value: any, index: number) -> any,
	seed: any
): OperatorFunction<any, any>
	return function(source: Observable<any>)
		return createObservable(function(subscriber)
			local acc = seed
			local index = 0
			return source:subscribe(buildObserver(
				function(value)
					local ok, nextAcc = pcall(accumulator, acc, value, index)
					index += 1
					if ok then acc = nextAcc else subscriber:error(nextAcc) end
				end,
				function(err) subscriber:error(err) end,
				function() subscriber:next(acc) subscriber:complete() end
				))
		end)
	end
end

-- Like reduce, but emits the running accumulated value on every source emission.
function RoRx.scan(
	accumulator: (acc: any, value: any, index: number) -> any,
	seed: any
): OperatorFunction<any, any>
	return function(source: Observable<any>)
		return createObservable(function(subscriber)
			local acc = seed
			local index = 0
			return source:subscribe(buildObserver(
				function(value)
					local ok, nextAcc = pcall(accumulator, acc, value, index)
					index += 1
					if ok then
						acc = nextAcc
						subscriber:next(acc)
					else
						subscriber:error(nextAcc)
					end
				end,
				function(err) subscriber:error(err) end,
				function() subscriber:complete() end
				))
		end)
	end
end

-- Collects all values into an array and emits it on completion.
function RoRx.toArray(): OperatorFunction<any, { any }>
	return RoRx.reduce(function(acc: { any }, value: any)
		table.insert(acc, value)
		return acc
	end, {} :: { any })
end

-- Emits only when the current value differs from the last emitted value.
function RoRx.distinctUntilChanged(
	comparator: ((a: any, b: any) -> boolean)?
): MonoTypeOperatorFunction<any>
	local compare = comparator or function(a: any, b: any) return a == b end
	return function(source: Observable<any>)
		return createObservable(function(subscriber)
			local hasLast = false
			local last: any
			return source:subscribe(buildObserver(
				function(value)
					if not hasLast then
						hasLast = true
						last = value
						subscriber:next(value)
						return
					end
					if not compare(last, value) then
						last = value
						subscriber:next(value)
					end
				end,
				function(err) subscriber:error(err) end,
				function() subscriber:complete() end
				))
		end)
	end
end

-- Delays forwarding until the source has been silent for dueMs milliseconds.
-- A pending value is flushed synchronously when the source completes.
function RoRx.debounceTime(dueMs: number): MonoTypeOperatorFunction<any>
	return function(source: Observable<any>)
		return createObservable(function(subscriber)
			local timerThread: thread? = nil
			local hasValue = false
			local lastValue: any
			local sub = source:subscribe(buildObserver(
				function(value)
					hasValue = true
					lastValue = value
					if timerThread ~= nil then task.cancel(timerThread) timerThread = nil end
					timerThread = task.delay(dueMs / 1000, function()
						timerThread = nil
						if hasValue and not subscriber:closed() then
							hasValue = false
							subscriber:next(lastValue)
						end
					end)
				end,
				function(err)
					if timerThread ~= nil then task.cancel(timerThread) timerThread = nil end
					subscriber:error(err)
				end,
				function()
					if timerThread ~= nil then task.cancel(timerThread) timerThread = nil end
					if hasValue then hasValue = false subscriber:next(lastValue) end
					subscriber:complete()
				end
				))
			return function()
				sub:unsubscribe()
				if timerThread ~= nil then task.cancel(timerThread) timerThread = nil end
			end
		end)
	end
end

-- Emits the first value, then ignores subsequent values until durationMs elapses.
function RoRx.throttleTime(durationMs: number): MonoTypeOperatorFunction<any>
	return function(source: Observable<any>)
		return createObservable(function(subscriber)
			local lastEmitTime = -math.huge
			local sub = source:subscribe(buildObserver(
				function(value)
					local now = os.clock() * 1000
					if now - lastEmitTime >= durationMs then
						lastEmitTime = now
						subscriber:next(value)
					end
				end,
				function(err) subscriber:error(err) end,
				function() subscriber:complete() end
				))
			return function() sub:unsubscribe() end
		end)
	end
end

-- Catches errors and replaces the errored stream with the observable returned
-- by the selector function.
function RoRx.catchError(
	selector: (err: any, caught: Observable<any>) -> Observable<any>
): OperatorFunction<any, any>
	return function(source: Observable<any>)
		return createObservable(function(subscriber)
			local activeSub: Subscription? = nil
			local function subscribeTo(current: Observable<any>)
				if activeSub ~= nil then activeSub:unsubscribe() activeSub = nil end
				activeSub = current:subscribe(buildObserver(
					function(value) subscriber:next(value) end,
					function(err)
						local ok, replacement = pcall(selector, err, source)
						if not ok then subscriber:error(replacement) return end
						subscribeTo(replacement)
					end,
					function() subscriber:complete() end
					))
			end
			subscribeTo(source)
			return function()
				if activeSub ~= nil then activeSub:unsubscribe() end
			end
		end)
	end
end

-- Resubscribes to the source up to `count` times on error.
function RoRx.retry(count: number?, delayMs: number?): MonoTypeOperatorFunction<any>
	local retries = count or math.huge
	return function(source: Observable<any>)
		return createObservable(function(subscriber)
			local attempt = 0
			local activeSub: Subscription? = nil
			local retryTask: thread? = nil
			local stopped = false

			local function resubscribe()
				if stopped or subscriber:closed() then return end
				if activeSub ~= nil then
					activeSub:unsubscribe()
					activeSub = nil
				end
				activeSub = source:subscribe(buildObserver(
					function(value) subscriber:next(value) end,
					function(err)
						if stopped or subscriber:closed() then return end
						if attempt < retries then
							attempt += 1
							local delay = (delayMs and delayMs > 0) and delayMs or 0
							-- Always go through task.delay (even at 0ms) to keep the
							-- call stack flat and prevent synchronous spin-loops.
							retryTask = task.delay(delay / 1000, function()
								retryTask = nil
								resubscribe()
							end)
						else
							subscriber:error(err)
						end
					end,
					function() subscriber:complete() end
					))
			end

			-- Defer the initial subscription so the teardown closure is registered
			-- before any synchronous error can fire resubscribe recursively.
			task.defer(function()
				if not stopped then resubscribe() end
			end)

			return function()
				stopped = true
				if activeSub ~= nil then activeSub:unsubscribe() activeSub = nil end
				if retryTask ~= nil then task.cancel(retryTask) retryTask = nil end
			end
		end)
	end
end

-- Prepends the source with the provided values.
-- NOTE: signature is { T } (array) not ...T — see Observable<T> type note.
function RoRx.startWith(values: { any }): MonoTypeOperatorFunction<any>
	return function(source: Observable<any>)
		return RoRx.concat(RoRx.fromArray(values), source)
	end
end

-- Appends the provided values after the source completes.
-- NOTE: signature is { T } (array) not ...T — see Observable<T> type note.
function RoRx.endWith(values: { any }): MonoTypeOperatorFunction<any>
	return function(source: Observable<any>)
		return RoRx.concat(source, RoRx.fromArray(values))
	end
end

-- Projects each source value to an inner Observable and merges all of them
-- concurrently up to the optional `concurrent` limit.
function RoRx.mergeMap(
	project: (value: any, index: number) -> Observable<any>,
	concurrent: number?
): OperatorFunction<any, any>
	local maxConcurrent = concurrent or math.huge
	return function(source: Observable<any>)
		return createObservable(function(subscriber)
			local active = 0
			local index = 0
			local sourceDone = false
			local queue = {} :: { { value: any, index: number } }
			local innerSubs = {} :: { Subscription }

			local function checkDone()
				if sourceDone and active == 0 and #queue == 0 then
					subscriber:complete()
				end
			end

			local function startInner(value: any, i: number)
				active += 1
				local ok, innerOrErr = pcall(project, value, i)
				if not ok then subscriber:error(innerOrErr) return end
				local innerSub: Subscription
				innerSub = (innerOrErr :: Observable<any>):subscribe(buildObserver(
					function(innerValue) subscriber:next(innerValue) end,
					function(err) subscriber:error(err) end,
					function()
						active -= 1
						arrRemove(innerSubs, innerSub)
						if #queue > 0 then
							local item = table.remove(queue, 1)
							startInner(item.value, item.index)
						else
							checkDone()
						end
					end
					))
				table.insert(innerSubs, innerSub)
			end

			local outerSub = source:subscribe(buildObserver(
				function(value)
					local i = index
					index += 1
					if active < maxConcurrent then
						startInner(value, i)
					else
						table.insert(queue, { value = value, index = i })
					end
				end,
				function(err) subscriber:error(err) end,
				function() sourceDone = true checkDone() end
				))

			return function()
				outerSub:unsubscribe()
				for _, s in ipairs(innerSubs) do s:unsubscribe() end
			end
		end)
	end
end

-- Projects each source value to an inner Observable, cancelling the previous
-- inner subscription whenever a new source value arrives.
function RoRx.switchMap(
	project: (value: any, index: number) -> Observable<any>
): OperatorFunction<any, any>
	return function(source: Observable<any>)
		return createObservable(function(subscriber)
			local index = 0
			local sourceDone = false
			local innerDone = true
			local innerSub: Subscription? = nil

			local function checkDone()
				if sourceDone and innerDone then subscriber:complete() end
			end

			local outerSub = source:subscribe(buildObserver(
				function(value)
					if innerSub ~= nil then innerSub:unsubscribe() innerSub = nil end
					innerDone = false
					local i = index
					index += 1
					local ok, innerOrErr = pcall(project, value, i)
					if not ok then subscriber:error(innerOrErr) return end
					innerSub = (innerOrErr :: Observable<any>):subscribe(buildObserver(
						function(innerValue) subscriber:next(innerValue) end,
						function(err) subscriber:error(err) end,
						function() innerDone = true innerSub = nil checkDone() end
						))
				end,
				function(err) subscriber:error(err) end,
				function() sourceDone = true checkDone() end
				))

			return function()
				outerSub:unsubscribe()
				if innerSub ~= nil then innerSub:unsubscribe() end
			end
		end)
	end
end

-- Projects each value to an inner Observable and subscribes to them one at a
-- time in order (mergeMap with concurrency 1).
function RoRx.concatMap(
	project: (value: any, index: number) -> Observable<any>
): OperatorFunction<any, any>
	return RoRx.mergeMap(project, 1)
end

-- When source emits, pairs its value with the latest from `other`.
-- Silently drops source emissions if `other` hasn't emitted yet.
function RoRx.withLatestFrom(other: Observable<any>): OperatorFunction<any, { any }>
	return function(source)
		return createObservable(function(subscriber)
			local latestOther: any = nil
			local hasOther = false

			local otherSub = other:subscribe(buildObserver(
				function(value) hasOther = true latestOther = value end,
				function(err) subscriber:error(err) end,
				function() end
				))

			local sourceSub = source:subscribe(buildObserver(
				function(value)
					if hasOther then subscriber:next({ value, latestOther }) end
				end,
				function(err) subscriber:error(err) end,
				function() subscriber:complete() end
				))

			return function()
				otherSub:unsubscribe()
				sourceSub:unsubscribe()
			end
		end)
	end
end

-- Emits {previous, current} for each consecutive pair. N values → N-1 pairs.
function RoRx.pairwise(): OperatorFunction<any, { any }>
	return function(source)
		return createObservable(function(subscriber)
			local hasPrev = false
			local prev: any = nil
			return source:subscribe(buildObserver(
				function(value)
					if hasPrev then subscriber:next({ prev, value }) end
					hasPrev = true
					prev = value
				end,
				function(err) subscriber:error(err) end,
				function() subscriber:complete() end
				))
		end)
	end
end

-- Collects values into fixed-size arrays of n, advancing by `skip` (default n).
-- skip < n → overlapping buffers; skip > n → gaps between buffers.
function RoRx.bufferCount(n: number, skip: number?): OperatorFunction<any, { any }>
	local step = skip or n
	return function(source)
		return createObservable(function(subscriber)
			local buffers = {} :: { { any } }
			local count = 0
			return source:subscribe(buildObserver(
				function(value)
					count += 1
					if (count - 1) % step == 0 then
						table.insert(buffers, {})
					end
					for _, buf in ipairs(buffers) do
						table.insert(buf, value)
					end
					local i = 1
					while i <= #buffers do
						if #buffers[i] >= n then
							subscriber:next(table.remove(buffers, i))
						else
							i += 1
						end
					end
				end,
				function(err) subscriber:error(err) end,
				function()
					for _, buf in ipairs(buffers) do
						if #buf > 0 and not subscriber:closed() then
							subscriber:next(buf)
						end
					end
					subscriber:complete()
				end
				))
		end)
	end
end

-- Collects values over rolling windows of ms milliseconds.
-- intervalMs controls how often a new window opens (defaults to ms).
function RoRx.bufferTime(ms: number, intervalMs: number?): OperatorFunction<any, { any }>
	local step = intervalMs or ms
	return function(source)
		return createObservable(function(subscriber)
			local buffers = {} :: { { values: { any }, timer: thread } }
			local intervalThread: thread? = nil
			local stopped = false

			local function openBuffer()
				if stopped or subscriber:closed() then return end
				local buf = { values = {}, timer = nil :: any }
				table.insert(buffers, buf)
				buf.timer = task.delay(ms / 1000, function()
					if stopped then return end
					for i, b in ipairs(buffers) do
						if b == buf then table.remove(buffers, i) break end
					end
					if not subscriber:closed() then
						subscriber:next(buf.values)
					end
				end)
			end

			openBuffer()

			if step > 0 then
				intervalThread = task.spawn(function()
					while not stopped do
						task.wait(step / 1000)
						openBuffer()
					end
				end)
			end

			local sub = source:subscribe(buildObserver(
				function(value)
					if stopped then return end
					for _, buf in ipairs(buffers) do
						table.insert(buf.values, value)
					end
				end,
				function(err)
					stopped = true
					if intervalThread then task.cancel(intervalThread) intervalThread = nil end
					for _, buf in ipairs(buffers) do task.cancel(buf.timer) end
					table.clear(buffers)
					subscriber:error(err)
				end,
				function()
					stopped = true
					if intervalThread then task.cancel(intervalThread) intervalThread = nil end
					for _, buf in ipairs(buffers) do
						task.cancel(buf.timer)
						if not subscriber:closed() then subscriber:next(buf.values) end
					end
					table.clear(buffers)
					subscriber:complete()
				end
				))

			return function()
				stopped = true
				sub:unsubscribe()
				if intervalThread then task.cancel(intervalThread) intervalThread = nil end
				for _, buf in ipairs(buffers) do task.cancel(buf.timer) end
				table.clear(buffers)
			end
		end)
	end
end

-- Emits only the first value (optionally matching a predicate) then completes.
-- Errors if the source completes without a matching value.
function RoRx.first(predicate: ((value: any, index: number) -> boolean)?): OperatorFunction<any, any>
	return function(source)
		return createObservable(function(subscriber)
			local index = 0
			local found = false
			return source:subscribe(buildObserver(
				function(value)
					local i = index
					index += 1
					if found then return end
					local matches = predicate == nil or predicate(value, i)
					if matches then
						found = true
						subscriber:next(value)
						subscriber:complete()
					end
				end,
				function(err) subscriber:error(err) end,
				function()
					if not found then subscriber:error("first: no matching value found") end
				end
				))
		end)
	end
end

-- Emits only the last value (optionally matching a predicate) on completion.
-- Errors if no matching value was found.
function RoRx.last(predicate: ((value: any, index: number) -> boolean)?): OperatorFunction<any, any>
	return function(source)
		return createObservable(function(subscriber)
			local index = 0
			local hasMatch = false
			local lastMatch: any = nil
			return source:subscribe(buildObserver(
				function(value)
					local i = index
					index += 1
					local matches = predicate == nil or predicate(value, i)
					if matches then hasMatch = true lastMatch = value end
				end,
				function(err) subscriber:error(err) end,
				function()
					if hasMatch then
						subscriber:next(lastMatch) subscriber:complete()
					else
						subscriber:error("last: no matching value found")
					end
				end
				))
		end)
	end
end

-- Completes the output observable as soon as `notifier` emits its first value.
function RoRx.takeUntil(notifier: Observable<any>): MonoTypeOperatorFunction<any>
	return function(source)
		return createObservable(function(subscriber)
			local notifierSub: Subscription? = nil
			notifierSub = notifier:subscribe(buildObserver(
				function(_)
					subscriber:complete()
					if notifierSub then notifierSub:unsubscribe() end
				end,
				function(err) subscriber:error(err) end,
				function() end
				))
			local sourceSub = source:subscribe(buildObserver(
				function(value) subscriber:next(value) end,
				function(err) subscriber:error(err) end,
				function()
					subscriber:complete()
					if notifierSub then notifierSub:unsubscribe() end
				end
				))
			return function()
				if notifierSub then notifierSub:unsubscribe() end
				sourceSub:unsubscribe()
			end
		end)
	end
end

-- Forwards values while the predicate returns true, then completes.
-- When inclusive = true, the value that fails the predicate is also emitted.
function RoRx.takeWhile(
	predicate: (value: any, index: number) -> boolean,
	inclusive: boolean?
): MonoTypeOperatorFunction<any>
	return function(source)
		return createObservable(function(subscriber)
			local index = 0
			return source:subscribe(buildObserver(
				function(value)
					local i = index
					index += 1
					local ok, passes = pcall(predicate, value, i)
					if not ok then subscriber:error(passes) return end
					if passes then
						subscriber:next(value)
					else
						if inclusive then subscriber:next(value) end
						subscriber:complete()
					end
				end,
				function(err) subscriber:error(err) end,
				function() subscriber:complete() end
				))
		end)
	end
end

-- Shorthand for switchMap(function() return inner end).
function RoRx.switchMapTo(inner: Observable<any>): OperatorFunction<any, any>
	return RoRx.switchMap(function() return inner end)
end

-- Shorthand for mergeMap(function() return inner end).
function RoRx.mergeMapTo(inner: Observable<any>, concurrent: number?): OperatorFunction<any, any>
	return RoRx.mergeMap(function() return inner end, concurrent)
end

-- Shorthand for concatMap(function() return inner end).
function RoRx.concatMapTo(inner: Observable<any>): OperatorFunction<any, any>
	return RoRx.concatMap(function() return inner end)
end

-- Emits a single boolean: true if all values satisfy the predicate, false on
-- the first mismatch (completing immediately).
function RoRx.every(predicate: (value: any, index: number) -> boolean): OperatorFunction<any, boolean>
	return function(source)
		return createObservable(function(subscriber)
			local index = 0
			return source:subscribe(buildObserver(
				function(value)
					local i = index
					index += 1
					local ok, passes = pcall(predicate, value, i)
					if not ok then subscriber:error(passes) return end
					if not passes then subscriber:next(false) subscriber:complete() end
				end,
				function(err) subscriber:error(err) end,
				function() subscriber:next(true) subscriber:complete() end
				))
		end)
	end
end

-- Emits the first value matching the predicate then completes.
-- Emits nil (rather than erroring) when no match is found.
function RoRx.find(predicate: (value: any, index: number) -> boolean): OperatorFunction<any, any>
	return function(source)
		return createObservable(function(subscriber)
			local index = 0
			local found = false
			return source:subscribe(buildObserver(
				function(value)
					if found then return end
					local i = index
					index += 1
					local ok, passes = pcall(predicate, value, i)
					if not ok then subscriber:error(passes) return end
					if passes then
						found = true
						subscriber:next(value)
						subscriber:complete()
					end
				end,
				function(err) subscriber:error(err) end,
				function()
					if not found then subscriber:next(nil) subscriber:complete() end
				end
				))
		end)
	end
end

-- Like find(), but emits the index of the matching value. Emits -1 if not found.
function RoRx.findIndex(predicate: (value: any, index: number) -> boolean): OperatorFunction<any, number>
	return function(source)
		return createObservable(function(subscriber)
			local index = 0
			local found = false
			return source:subscribe(buildObserver(
				function(value)
					if found then return end
					local i = index
					index += 1
					local ok, passes = pcall(predicate, value, i)
					if not ok then subscriber:error(passes) return end
					if passes then
						found = true
						subscriber:next(i)
						subscriber:complete()
					end
				end,
				function(err) subscriber:error(err) end,
				function()
					if not found then subscriber:next(-1) subscriber:complete() end
				end
				))
		end)
	end
end

-- Emits the count of values (optionally only those matching the predicate)
-- when the source completes.
function RoRx.count(predicate: ((value: any, index: number) -> boolean)?): OperatorFunction<any, number>
	return function(source)
		return createObservable(function(subscriber)
			local total = 0
			local index = 0
			return source:subscribe(buildObserver(
				function(value)
					local i = index
					index += 1
					if predicate == nil then
						total += 1
					else
						local ok, passes = pcall(predicate, value, i)
						if not ok then subscriber:error(passes) return end
						if passes then total += 1 end
					end
				end,
				function(err) subscriber:error(err) end,
				function() subscriber:next(total) subscriber:complete() end
				))
		end)
	end
end

-- Emits the minimum value when the source completes.
function RoRx.min(comparer: ((a: any, b: any) -> boolean)?): OperatorFunction<any, any>
	local isLess = comparer or function(a, b) return a < b end
	return function(source)
		return createObservable(function(subscriber)
			local hasValue = false
			local result: any = nil
			return source:subscribe(buildObserver(
				function(value)
					if not hasValue or isLess(value, result) then
						hasValue = true result = value
					end
				end,
				function(err) subscriber:error(err) end,
				function()
					if hasValue then
						subscriber:next(result) subscriber:complete()
					else
						subscriber:error("min: source was empty")
					end
				end
				))
		end)
	end
end

-- Emits the maximum value when the source completes.
function RoRx.max(comparer: ((a: any, b: any) -> boolean)?): OperatorFunction<any, any>
	local isGreater = comparer or function(a, b) return a > b end
	return function(source)
		return createObservable(function(subscriber)
			local hasValue = false
			local result: any = nil
			return source:subscribe(buildObserver(
				function(value)
					if not hasValue or isGreater(value, result) then
						hasValue = true result = value
					end
				end,
				function(err) subscriber:error(err) end,
				function()
					if hasValue then
						subscriber:next(result) subscriber:complete()
					else
						subscriber:error("max: source was empty")
					end
				end
				))
		end)
	end
end

-- Emits true if the source completes without emitting, false on the first emission.
function RoRx.isEmpty(): OperatorFunction<any, boolean>
	return function(source)
		return createObservable(function(subscriber)
			local emitted = false
			return source:subscribe(buildObserver(
				function(_)
					if not emitted then
						emitted = true
						subscriber:next(false)
						subscriber:complete()
					end
				end,
				function(err) subscriber:error(err) end,
				function()
					if not emitted then subscriber:next(true) subscriber:complete() end
				end
				))
		end)
	end
end

-- Emits a default value if the source completes without emitting; otherwise
-- passes through all source values unchanged.
function RoRx.defaultIfEmpty(defaultValue: any): MonoTypeOperatorFunction<any>
	return function(source)
		return createObservable(function(subscriber)
			local emitted = false
			return source:subscribe(buildObserver(
				function(value) emitted = true subscriber:next(value) end,
				function(err) subscriber:error(err) end,
				function()
					if not emitted then subscriber:next(defaultValue) end
					subscriber:complete()
				end
				))
		end)
	end
end

-- Suppresses all next emissions; only error and complete pass through.
function RoRx.ignoreElements(): MonoTypeOperatorFunction<any>
	return function(source)
		return createObservable(function(subscriber)
			return source:subscribe(buildObserver(
				function(_) end,
				function(err) subscriber:error(err) end,
				function() subscriber:complete() end
				))
		end)
	end
end

-- Creates a new Subject, which is a special type of Observable that allows
-- manually pushing values and controlling completion.
local function createSubject(): Subject<any>
	local observers = {} :: { Observer<any> }
	local isStopped = false
	local hasError = false
	local thrownError: any = nil

	local subject = createObservable(function(subscriber: Subscriber<any>)
		if hasError then subscriber:error(thrownError) return nil end
		if isStopped then subscriber:complete() return nil end
		local observer = buildObserver(
			function(value: any) subscriber:next(value) end,
			function(err) subscriber:error(err) end,
			function() subscriber:complete() end
		)
		table.insert(observers, observer)
		return function()
			arrRemove(observers, observer)
		end
	end)

	local api = subject :: any
	api[KIND_KEY] = "Subject"

	function api:next(value: any)
		if isStopped or hasError then return end
		for _, observer in ipairs(table.clone(observers)) do
			pcall(observer.next, value)
		end
	end

	function api:error(err: any)
		if isStopped or hasError then return end
		hasError = true
		thrownError = err
		isStopped = true
		for _, observer in ipairs(table.clone(observers)) do
			pcall(observer.error, err)
		end
		table.clear(observers)
	end

	function api:complete()
		if isStopped then return end
		isStopped = true
		for _, observer in ipairs(table.clone(observers)) do
			pcall(observer.complete)
		end
		table.clear(observers)
	end

	function api:asObservable()
		return subject
	end

	return api
end

-- Splits the source into nested observables; a new window Subject starts each
-- time windowBoundaries emits.
function RoRx.window(windowBoundaries: Observable<any>): OperatorFunction<any, Subject<any>>
	return function(source)
		return createObservable(function(subscriber)
			local currentWindow = createSubject()
			subscriber:next(currentWindow)

			local boundarySub = windowBoundaries:subscribe(buildObserver(
				function(_)
					currentWindow:complete()
					currentWindow = createSubject()
					if not subscriber:closed() then
						subscriber:next(currentWindow)
					end
				end,
				function(err)
					currentWindow:error(err)
					subscriber:error(err)
				end,
				function()
					currentWindow:complete()
					subscriber:complete()
				end
				))

			local sourceSub = source:subscribe(buildObserver(
				function(value) currentWindow:next(value) end,
				function(err)
					currentWindow:error(err)
					subscriber:error(err)
				end,
				function()
					currentWindow:complete()
					subscriber:complete()
				end
				))

			return function()
				-- Complete active window on early unsubscribe so window
				-- subscribers don't remain open indefinitely.
				currentWindow:complete()
				boundarySub:unsubscribe()
				sourceSub:unsubscribe()
			end
		end)
	end
end

-- Combines the source with one or more other observables by index position,
-- emitting value arrays. Completes when the shortest source completes.
function RoRx.zipWith(...: Observable<any>): OperatorFunction<any, { any }>
	local others = { ... }
	return function(source)
		return createObservable(function(subscriber)
			local allSources = { source }
			for _, o in ipairs(others) do table.insert(allSources, o) end

			local queues = {} :: { { any } }
			local completed = {} :: { boolean }
			local subs = {} :: { Subscription }

			for i = 1, #allSources do
				queues[i] = {}
				completed[i] = false
			end

			local function tryEmit()
				for _, q in ipairs(queues) do
					if #q == 0 then return end
				end
				local values = {}
				for i, q in ipairs(queues) do
					table.insert(values, table.remove(q, 1))
					if completed[i] and #q == 0 then
						subscriber:next(values)
						subscriber:complete()
						return
					end
				end
				subscriber:next(values)
			end

			for i, src in ipairs(allSources) do
				local idx = i
				local sub = src:subscribe(buildObserver(
					function(value) table.insert(queues[idx], value) tryEmit() end,
					function(err) subscriber:error(err) end,
					function()
						completed[idx] = true
						if #queues[idx] == 0 then subscriber:complete() end
					end
					))
				table.insert(subs, sub)
			end

			return function()
				for _, sub in ipairs(subs) do sub:unsubscribe() end
			end
		end)
	end
end

local function createBehaviorSubject(initialValue: any): BehaviorSubject<any>
	local base = createClass(
		"BehaviorSubject",
		createSubject()
	)
	base.value = initialValue

	local baseSubscribe = base._subscribe
	base._subscribe = function(subscriber)
		if not subscriber:closed() then
			subscriber:next(base.value)
		end
		return baseSubscribe(subscriber)
	end

	local baseNext = base.next
	function base:next(value: any)
		self.value = value
		baseNext(self, value)
	end

	function base:getValue(): any
		return self.value
	end

	return base
end

local function createReplaySubject(bufferSize: number?): Subject<any>
	local base = createClass(
		"ReplaySubject",
		createSubject()
	)
	local maxSize = bufferSize or math.huge
	local buffer = {} :: { any }

	local baseSubscribe = base._subscribe
	base._subscribe = function(subscriber)
		for _, value in ipairs(buffer) do
			if subscriber:closed() then break end
			subscriber:next(value)
		end
		return baseSubscribe(subscriber)
	end

	local baseNext = base.next
	function base:next(value: any)
		table.insert(buffer, value)
		while #buffer > maxSize do table.remove(buffer, 1) end
		baseNext(self, value)
	end

	return base
end

-- Multicasts the source through the provided Subject.
function RoRx.multicast(subject: Subject<any>): OperatorFunction<any, any>
	return function(source: Observable<any>)
		return createObservable(function(subscriber)
			local subjectSub = subject:subscribe(buildObserver(
				function(value) subscriber:next(value) end,
				function(err) subscriber:error(err) end,
				function() subscriber:complete() end
				))
			local sourceSub = source:subscribe(buildObserver(
				function(value) subject:next(value) end,
				function(err) subject:error(err) end,
				function() subject:complete() end
				))
			return function()
				subjectSub:unsubscribe()
				sourceSub:unsubscribe()
			end
		end)
	end
end

-- Shares a single subscription via a Subject. Tears down and resets the Subject
-- when the subscriber reference count reaches 0, enabling resubscription.
function RoRx.share(): MonoTypeOperatorFunction<any>
	return function(source: Observable<any>)
		local subject: Subject<any> = createSubject()
		local sourceSub: Subscription? = nil
		local refCount = 0

		return createObservable(function(subscriber)
			refCount += 1

			if sourceSub == nil then
				sourceSub = source:subscribe(buildObserver(
					function(value) subject:next(value) end,
					function(err)
						subject:error(err)
						sourceSub = nil
					end,
					function()
						subject:complete()
						sourceSub = nil
					end
					))
			end

			local inner = subject:subscribe(buildObserver(
				function(value) subscriber:next(value) end,
				function(err) subscriber:error(err) end,
				function() subscriber:complete() end
				))

			return function()
				inner:unsubscribe()
				refCount -= 1
				if refCount <= 0 and sourceSub ~= nil then
					local subToCancel = sourceSub
					sourceSub = nil
					subject = createSubject() -- reset before unsubscribe
					subToCancel:unsubscribe() -- last: prevents completing the fresh subject
				end
			end
		end)
	end
end

-- Like share, but replays the last `bufferSize` values to new subscribers.
function RoRx.shareReplay(bufferSize: number?): MonoTypeOperatorFunction<any>
	return function(source: Observable<any>)
		local replay = createReplaySubject(bufferSize or 1)
		return source:pipe(
			RoRx.multicast(replay),
			RoRx.share()
		)
	end
end

-- Composes a sequence of operator functions into a single operator function.
function RoRx.pipe(...: OperatorFunction<any, any>): OperatorFunction<any, any>
	local operators = { ... }
	return function(source: Observable<any>)
		local current: Observable<any> = source
		for _, operator in ipairs(operators) do
			current = operator(current)
		end
		return current
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

function RoRx.isSubject(value: any): boolean
	if not isObservable(value) then return false end
	local kind = (value :: any)[KIND_KEY]
	if kind == "Subject" or kind == "BehaviorSubject" or kind == "ReplaySubject" then
		return true
	end
	local candidate: any = value
	return isFunction(candidate.next)
		and isFunction(candidate.error)
		and isFunction(candidate.complete)
		and isFunction(candidate.asObservable)
end

function RoRx.isSubscription(value: any): boolean
	return isSubscription(value)
end

function RoRx.isBehaviorSubject(value: any): boolean
	if hasKind(value, "BehaviorSubject") then return true end
	return RoRx.isSubject(value) and isFunction(value.getValue)
end

function RoRx.isCleanupRegistry(value: any): boolean
	if hasKind(value, "CleanupRegistry") then return true end
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
RoRx.ReplaySubject = { new = createReplaySubject }
RoRx.Subscription = { new = createSubscription }
RoRx.State = { new = createState }
RoRx.CleanupRegistry = { new = createCleanupRegistry }

RoRx.asyncScheduler = {
	now = function(): number
		return os.clock() * 1000
	end,
	schedule = function(work: (state: any?) -> (), delayMs: number?, state: any?): Subscription
		local cancelled = false
		local sub = createSubscription(function()
			cancelled = true
		end)
		local function run()
			if not cancelled then pcall(work, state) end
		end
		if delayMs ~= nil and delayMs > 0 then
			task.delay(delayMs / 1000, run)
		else
			task.defer(run)
		end
		return sub
	end,
}

setmetatable(RoRx, {
	__tostring = function()
		return "RoRxLibrary " .. RoRx.VERSION
	end,
})

return RoRx
