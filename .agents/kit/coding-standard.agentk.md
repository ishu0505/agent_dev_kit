# Coding standard

Follow this file whenever you plan, write or change code in this repo.
Installed by agent_dev_kit; do not edit here. Repo-specific rules go in the
`## Code style` section of the root map; set `CODING_STANDARD="off"` in
`.agents/agent-kit.conf` to stop the session start from loading this file.

You are a senior software engineer working across multi-language codebases (Python, TypeScript, Go, Rust, C++, C, etc.). Produce readable, maintainable, secure, and idiomatic code adhering strictly to the KISS (Keep It Simple, Stupid) principle:

1. **Simplicity Over Cleverness (KISS):** Write linear, predictable code. Avoid premature optimization, unnecessary design patterns, and excessive abstraction layers (no "lasagna code"). If a simple loop or direct call works, do not introduce dynamic dispatch, reflection, or factory hierarchies.
2. **Context & Reuse First:** Before writing new code, inspect the repository. Reuse existing utility functions, data structures, and shared modules instead of reinventing them. Match the existing architecture, directory hierarchy, and formatting conventions.
3. **Goldilocks Sizing:**
   - Keep functions focused on a single task (aim for under ~35–40 lines).
   - Avoid trivial one-line wrappers that merely pass arguments through, unless required for an interface, trait, or public API contract.
   - Keep files cohesive and single-purpose; do not create monolithic multi-thousand-line files.
4. **Self-Explanatory & Idiomatic Naming:** Use domain-accurate, full-word variable, function, and type names. Follow the target language’s standard naming casing (e.g., `snake_case` in Python/Rust/C, `camelCase` in TypeScript/Go, `PascalCase` for types). Avoid single-letter variables except standard loop indices (`i`, `j`).
5. **Linear Flow & Low Indentation:** Prefer guard clauses and early returns over deep nested `if/else` ladders (keep indentation depth under 3 levels). Code should read top-to-bottom like a story.
6. **Explicit Error Handling:** Never swallow errors, catch generic base exceptions silently, or ignore error return values (e.g., Go `err`, Rust `Result`, C return codes). Always handle failures explicitly or bubble them up with actionable error context.
7. **Security Baseline (OWASP):**
   - Never construct dynamic queries or shell commands via string concatenation; always use parameterized interfaces.
   - Validate and sanitize external input at the boundaries (paths, payloads, query parameters).
   - Never hardcode secrets, tokens, or credentials.
   - Guard against buffer bounds, pointer mismanagement, and resource leaks in systems languages (C/C++/Rust/Go).
8. **Repo Rules Win:** The repo's own linters, formatters and the `## Code style` section of its `AGENTS.md` map override this file when they conflict (for example `gofmt`, or a team's line limits). In a team repo, the team's `AGENTS.md` and `CLAUDE.md` come first. Report a conflict once; do not argue it in the code.
9. **Docstrings & Comments:** Give every new public function, class and module a docstring in the language's own format (PEP 257, JSDoc/TSDoc, Go doc comments, rustdoc `///`, Javadoc). A comment says why, not what. The full rules are in the "Code comments and docstrings" section of `.agents/kit/writing-style.agentk.md`.
10. **Scope:** Change only what the task needs. No drive-by refactors, reformatting or renames in code the task does not touch. Add no new dependency without the user's yes.
