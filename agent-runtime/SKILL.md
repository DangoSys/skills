---
name: agent-runtime
description: Implement or review Singular agent, router, group, nesting, spawning, handoff, and message runtime behavior on Harness services.
---

# Agent Runtime

Use after `graph-contract` is fixed. Keep runtime behavior in the agent plugin; do not make the graph or web plugin drive an agent loop.

## Harness integration

- Read the checked-in Harness type declarations before using an API. Prefer `ctx.agents.create`, `ctx.agents.resume`, `ctx.agents.get`, `ctx.sessions`, and the configured session persistence service.
- A created or resumed agent is the exact live identity. Keep its disposer with the owner that created it. Do not infer authority from ambient initiator state alone.
- Attach graph ownership and listeners through Cordis effects so unload removes routes, listeners, timers, and live handles in order.
- Persist agent conversation through the existing session log/persistence path. Do not invent a second session file format.

## Router and group rules

- A router is the leader of exactly one group and the group's public endpoint.
- Human input enters the router session. The router may dispatch explicit work to members, create a child group, or create standalone agents for independent exploration and comparison.
- Any agent may spawn another agent. A standalone agent may also continue spawning unless a future contract says otherwise.
- Creating a group makes the creating agent its router immediately. The graph operation must publish the router and group relationship atomically with the successful runtime creation.
- A router can be a member of a parent group. Parent members send to that router as to one ordinary node; the parent never reaches through it to hidden child members.
- A router may finish and become `done` or `idle`. Later input resumes the same session. Never silently replace it or elect a backup.

## Dispatch

- Route a message to one explicit endpoint. Group-internal dispatch is the router's decision; do not broadcast by default.
- A parent-to-child-group message is addressed to the child router. The router may answer the sender directly or dispatch internally according to the runtime contract; preserve sender and receiver ids on the message.
- Temporary cross-group or cross-root messages do not create graph edges. Give them a durable message/session event only when the product contract requires replay.
- Handoff records the brief and changes responsibility to the child. The parent may summarize but must not continue the handed-off work.

## Failure and lifecycle

- Boundary schema errors, missing live identities, duplicate ids, invalid transitions, persistence failures, and child-loop failures are errors. Propagate them to the caller and surface them in the UI.
- Do not add fallback agents, silent retries, empty-success results, automatic takeover, or defensive checks for impossible internal states.
- Make creation, graph publication, and session attachment one explicit ordered transaction. Never leave a graph node that has no live session or a live session that is not represented by the graph.
- Dispose in reverse ownership order: stop/drain the agent loop, flush the session, remove runtime registration, then remove graph ownership. Do not delete persisted history as a recovery shortcut.

## Runtime tests

Cover one root, multiple roots, router-as-parent-member, nested group routing, standalone fan-out, handoff, same-session resume after `done`, explicit message routing, and failure propagation. Assert that no hidden member is reachable through a child router and that no temporary message creates a durable edge.
