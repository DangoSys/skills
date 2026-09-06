---
name: collaboration-panel
description: Work through GitHub issues assigned to you and PRs requesting your review via the harness collaboration-panel and organisation identity.
---

# 协作面板

## When

User asks about assigned issues, review requests, or "任务面板" / PR board for organisation-managed repos.

## Workflow

1. Prefer the sidebar **协作面板**. Opening it while logged out starts GitHub device login in the panel (no chat tool).
2. Scope is only repos from organisation config. Do not query other remotes.
3. Issues: you are assignee. PRs: you are requested_reviewer. Open only.
4. After reading a PR/issue in the panel, do the real work in the matching workspace repo (`ensure_repo` when needed). Quality gates stay with harness skills, not this panel.
5. Read-only: never claim GitHub write through this plugin.

## Fail loud

Auth and API failures must be visible. Do not invent empty success.
