---
name: role-identity
description: Resolve the operator GitHub identity and maintainer status via role. Use before identity-gated work.
---

# role-identity

1. If not logged in, tell the user to open the sidebar **任务面板** (or any surface that starts role login). Do not start login through chat tools.
2. Call `role_whoami`. Read `login` and `maintainers["owner/repo"]`.
3. Treat `maintainers[repo] === true` as maintain-or-admin on that repo. Do not invent alternate auth (`GH_TOKEN`, `gh auth`).
4. If any tool throws, stop and surface the error. Do not retry with a different credential source.
