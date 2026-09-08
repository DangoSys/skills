---
name: repo-install
description: Install and initialize a source-code repository for local development. Use when a user asks to install, bootstrap, set up, or prepare a checkout, archive, or remote repository; detect the documented setup path, initialize dependencies safely, verify the result, and ask about a proxy after a network failure. Do not use to install Codex skills; use skill-installer for that.
---

# Repository Install

1. Inspect the repository root, status, documented setup files, manifests, lockfiles, and submodule state before changing anything. Read `AGENTS.md` only when it exists.
2. Follow the documented setup path before inferring one from a package manifest. Preserve lockfiles, user configuration, and uncommitted changes. Do not install globally or delete build output without explicit approval.
3. Initialize only required repository-owned dependencies, then run the smallest documented configure, build, or smoke check. Report commands, results, and any remaining manual step.

## Network Failure

After the first clearly network-related failure from a clone, submodule update, dependency download, or install:

1. Stop retrying.
2. State the failed operation and ask the user whether an HTTP/HTTPS or SOCKS proxy is available.
3. If provided, confirm whether it applies only to the command, current shell, or project configuration. Reuse an existing proxy environment variable when present; do not persist credentials or change global Git configuration without permission.
4. Without a proxy, report available local-cache or offline options and what remains unavailable.

## Buckyball

For a fresh Buckyball checkout, follow the documented repository setup: install Nix, then run `./scripts/nix/build-all.sh` from the repository root. Use project `bbdev_*` MCP tools for subsequent compiler, workload, simulation, synthesis, and test operations; poll every returned `trace_id` to terminal success. Do not call `bbdev` CLI or `nix develop -c bbdev ...` directly.
