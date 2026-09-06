---
name: canvas-client
description: Build or review the Singular canvas, graph snapshot, event stream, and floating agent or group chat windows.
---

# Canvas Client

Use for the web surface only. Singular is delivered as separate client plugins; they communicate with DOM events and never become a second graph authority.

## Plugin boundaries

- `canvas` owns the sidebar entry, graph snapshot/SSE lifecycle, canvas surface, and explicit four-direction viewport expansion tools.
- `node` renders every agent and group boundary from the snapshot. Agent-provided `node` geometry and `shape` are authoritative; missing geometry is an error.
- `connect` renders only persisted graph edges.
- `sticky` owns movable, minimizable, closable windows and clears them when the canvas closes.
- `chat` owns session conversation windows. `report` and `human` create their own sticky content. `bubble` owns the short notification queue and node focus action.
- Do not add a shared helper package or duplicate snapshot/SSE authority without a demonstrated need.

## Surface

- Keep traditional linear chat and the canvas as parallel first-class modes.
- Enter the canvas through the existing `sidebar.footer.action` slot; do not add a fixed corner launcher to the page body.
- Render every agent node, including agents inside groups. Render group boundaries as visual grouping, not as a black-box replacement node.
- Support multiple root graphs in one canvas view.
- Clicking the root opens its agent chat; the first user prompt is sent there.
- Clicking an agent opens that agent's independent chat. Clicking a group boundary opens the group's shared chat.
- Chat windows are independent floating notes: multiple may coexist, move, stick to a location, minimize, and close. These are UI-state operations only.
- Assistant and user message content belongs to the session chat window. Never mirror it into the notification queue.
- The notification queue contains only short host-emitted status notices such as task completion or failure. Clicking a notice clears that node's unread marker and focuses the node on the canvas.
- Show router status and group membership without adding controls that create, delete, reconnect, or reorder graph entities.
- Node position, dimensions, and shape are selected by the agent that creates the node and arrive in the graph snapshot. The canvas never auto-layouts or persists viewport changes as graph mutations.
- Expansion tools change only the local viewport plane; they do not modify graph records.

## Host/client split

- Host code exposes strict snapshot, graph event, session chat, notification, and message command routes using existing web-server and Cordis lifecycle patterns.
- The snapshot is the read source for the UI. Events invalidate or update that snapshot; the browser does not infer graph truth from optimistic local edits.
- Keep client injection and host plugins separate. Register every route, listener, and resource under an effect disposer.
- Use the existing Harness session identifiers to open agent transcripts. Use a group transcript id for a shared room; do not merge it into a member session.

## Error behavior

- Non-2xx responses, malformed snapshots, unknown event kinds, and closed sessions are visible errors. Do not show an empty canvas or substitute a stale snapshot.
- Reject graph mutation requests from the client. Chat and window-state commands are the only human actions in the first version.
- Do not hide loading, recovery, or runtime failure behind a fallback node or fake status.

## Client checks

Verify at desktop and narrow widths that nodes, group boundaries, and floating windows do not overlap incoherently. Exercise multiple windows, minimize/restore, close/reopen, nested groups, multiple roots, stream reconnect, and a full page reload against persisted state.
