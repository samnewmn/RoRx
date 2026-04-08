# RoRx, Reactive Extensions for Roblox Studio
RoRx is a Reactive Extensions library for Roblox, adapted from the battle-tested RxJS pattern for Luau and Studio compatibility. It gives you a unified model for working with anything that produces values over time — signals, remotes, properties, timers, player events — treating all of them as composable streams you can transform, combine, filter, and cancel with a consistent set of tools.
The core premise is simple: instead of wiring up connections manually, tracking state in loose variables, and remembering to clean everything up, you describe what your data pipeline should look like and let RoRx handle the rest.

Roblox development has a problem that most codebases just learn to live with. Connections that outlive the things they reference. Race conditions between character spawns and DataStore loads. RemoteEvent handlers with no rate limiting. Round systems held together by a handful of booleans that three different scripts can write to.
None of these are hard problem individually. They're hard because the standard tools — Connect, task.spawn, task.wait, pcall — give you no structure for composing them. Every solution is bespoke. Every cleanup is manual. Every race condition is a surprise.
RoRx doesn't replace those tools. It gives you a layer on top of them that makes the relationships between async operations explicit, readable, and safe by default.

## Installation
RoRx is a standalone module which can be dragged and dropped into VS Code or your Roblox Studio game directly, available in the releases section: https://github.com/samnewmn/RoRx/releases/latest
