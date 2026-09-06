---
name: graph-contract
description: Define or review the Singular graph schema and invariants before changing graph, group, agent, or communication code.
---

# Graph Contract

Use this skill before implementing or changing the graph truth. Keep the contract small and explicit. The graph is not a projection of chat logs, and the canvas is not allowed to mutate it.

## Model

- A graph has a stable id and one or more root agent ids. Multiple roots are valid.
- An agent is the smallest visible node. It owns one continuable Harness session and its independent transcript.
- New agents carry creator-selected canvas geometry (`x`, `y`, positive `width`/`height`) and a declared shape. The canvas never infers positions or appearance; legacy records without geometry are read-only history and must surface an error in the canvas.
- A group is a boundary plus a shared transcript. Its members remain visible as individual agent nodes.
- Every group has exactly one router agent. A router is the group leader and the only human-facing endpoint for that group.
- A router may also be an ordinary member of one parent group while routing exactly one child group. Membership and router responsibility are separate relations.
- Any agent may spawn agents. A router may additionally create standalone agents that belong to no group.
- Persistent edges express spawn and handoff. A temporary message is not a graph edge.

## Visibility and routing

- A human talks to the router to drive a group; the human does not address group members as a group workflow.
- Members of one group are mutually visible in that group's graph view.
- A parent-group node addresses a child group through the child router endpoint. The sender treats that endpoint as one ordinary agent and cannot address hidden child members directly.
- The child router chooses whether and how to dispatch inside its group. Never auto-broadcast a message to all members.
- Cross-group and cross-root cooperation is temporary communication. Do not add durable graph edges for it.

## Invariants

Reject the operation when any invariant is violated; do not repair, substitute, or silently drop data.

1. Agent ids, group ids, root ids, and edge ids are stable and unique within their namespace.
2. A group has one router, and one router has at most one group responsibility.
3. A group membership references a live agent node. A router can be a member of a parent group and the router of its child group.
4. Spawn and handoff edges reference existing nodes and have one declared direction. Cycles are invalid unless a future contract explicitly adds them.
5. A child-group router is the only public endpoint for that child group.
6. Graph mutations come from runtime agents/services only. Canvas actions can change viewport and chat-window state, never nodes, groups, membership, or edges.
7. Unknown event kinds, states, or fields are errors at the protocol boundary.

## Persistence boundary

Reuse Harness session and session-persistence services for agent transcripts. Keep Singular's graph records and events in a Singular-owned schema; do not copy AgentTeams' disk protocol. A persisted record must be validated before it becomes live. Recovery must resume the same session and identity, not silently elect a replacement.

## Change checklist

Before coding, write the affected record/event shape in TypeScript and list the invariant it preserves. Update the runtime, web snapshot, and tests together. If the shape cannot be stated without a fallback or an optional repair path, stop and simplify the design.
