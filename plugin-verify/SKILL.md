---
name: plugin-verify
description: Plan, split, build, and verify Singular DSH plugins under the Harness quality workflow and strict failure policy.
---

# Plugin Verify

Use when creating, splitting, or reviewing a Singular plugin. This is the delivery workflow, not a user-facing document.

## Split first

Keep one responsibility per plugin and keep its authored source under 750 lines total. Keep every authored source file at 200 lines or fewer. Count host source, client source, and schema code; generated `lib` output and tests do not justify an oversized source plugin. Split only at a real ownership boundary:

- `graph`: graph records, events, persistence projection, and invariants.
- `agent`: Harness agent/session integration, router dispatch, spawn, group, handoff, and messaging.
- `web`: strict host routes, snapshots, event stream, and chat commands.
- `canvas`: browser rendering, graph layout, and floating chat-window UI.

Do not introduce `common`, `utils`, or a helper package before duplication is proven. Cross-plugin contracts should be small exported types/events, not a shared mutable store.

## Implementation rules

1. Start from the graph contract and write only the records/events needed by the current slice.
2. Reuse Harness services and lifecycle effects. Follow existing `inject`, `ctx.tools.register`, `ctx.webServer.register`, and client-injection patterns.
3. Validate external schemas and persisted records at the boundary. Internal impossible states may throw naturally; do not add defensive fallback branches.
4. Propagate errors. No silent retry, takeover, empty success, stale-data fallback, or compatibility branch unless the contract explicitly requires it.
5. Keep temporary design notes out of the repository. Skills are the durable AI-facing instructions; delete scratch plans after the slice is implemented.

## Verification order

- Typecheck and build every package from a clean dependency graph.
- Validate the packaged artifact, not only TypeScript source. Use an isolated Harness profile and the resolved plugin bundle.
- Start the real composition, check strict HTTP routes and event delivery, then exercise browser behavior.
- Restart with the same persistence directory and verify graph, agent sessions, group transcripts, statuses, and floating-window state according to their ownership boundaries.
- Test failure paths: duplicate ids, invalid transitions, unknown records, missing sessions, route errors, and persistence errors must be observable failures.
- Run `git diff --check`, check every source file is at most 200 lines, and check the plugin source total is at most 750 lines before handoff.

## Handoff gate

Do not claim a slice complete until its package builds, its artifact loads in the real Harness composition, the focused runtime/client tests pass, and recovery has been exercised where persistence is involved. Record only code and durable skills; remove temporary AI notes.
