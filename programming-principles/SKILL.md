---
name: programming-principles
description: Apply the repository's programming rules during implementation or code review. Use when a user asks for coding principles, requests a code change, or asks whether a design is unnecessarily complex.
---

# Programming Principles

Apply these rules:

1. **Keep It Simple (KISS).** Prefer direct, readable code. Do not introduce a pile of helpers, wrappers, abstractions, or indirection for a one-off operation.
2. **No fallback.** Do not silently recover from an unexpected state, invent a default, truncate data, or continue with partial results. Raise an error immediately when behavior is outside the contract.
3. **No unnecessary defensive programming.** Do not add checks for conditions that the type system, caller contract, or an operation already guarantees. If the operation naturally fails and exits, let it fail. Add a check only when it changes the error contract or prevents destructive side effects.
4. **Break compatibility decisively.** Do not preserve obsolete APIs, aliases, migration shims, dual formats, or old behavior unless compatibility is explicitly part of the task. Make the clean architectural change and update its callers.
5. **Do not write documentation.** Do not create new docs, guides, changelogs, migration notes, or explanatory compatibility text. After a code change, update an existing document only when the changed behavior requires it, and preserve that document's existing format. Do not add notices such as “removed” or “previously supported” to preserve old context.

These rules govern implementation choices, not the user's explicit requirements. When a requirement conflicts with a rule, follow the user's requirement and call out the trade-off briefly.
