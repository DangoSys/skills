---
name: report
description: Define the only fields allowed in Singular Agent work reports.
---

# Singular Report

Report windows may display only fields explicitly emitted by a loaded skill or by the graph/agent runtime contract. The client must not invent progress, percentage, ETA, summary, or health fields. Missing report data is an error shown in the window.

The graph contract supplies `id`, `name`, `status`, group membership, router role, and node geometry. The agent runtime supplies session identity, routing, handoff, spawn, and failure events. A skill may add a report payload only when its own skill contract names the field and its runtime event carries that field. The initial report window shows only these graph-contract fields; no progress or summary is inferred.
