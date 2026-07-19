# Documentation

This folder documents the money-app so that development stays consistent over time — same
architecture, same conventions, same coding and UI patterns. It is written for contributors
(human or AI) who need to understand how the app is built and extend it the same way.

## Structure

- [architecture.md](architecture.md) — the layered stack, startup sequence, dependency
  injection, and the event-driven refresh flow.
- [conventions.md](conventions.md) — the governing rules: the meta-rule, folder structure,
  file naming, file-size guideline, generalization, language, DI, storage, git workflow.
- [coding-style.md](coding-style.md) — formatting, comments, method ordering, build
  decomposition, naming, and async/state patterns.
- [ui-patterns.md](ui-patterns.md) — visual patterns: screen and dialog shells, buttons,
  colors, and which selector component to use.
- [data-layer.md](data-layer.md) — `BaseModel`, `BaseRepository`, the typed column DSL, the
  map-method convention, and the events system.
- [migrations.md](migrations.md) — the migration framework, startup sync, idempotency, and
  the recipe for adding a migration.
- [tech-debt.md](tech-debt.md) — the full inventory of existing code that does not match the
  defined patterns.
- [features/](features/) — one functional doc per feature: `accounts.md`, `movements.md`,
  `categories.md`, `statistics.md`, `backups.md`, and the cross-cutting `currency.md`.

The design specs and implementation plans that produced this documentation live under
[superpowers/](superpowers/).

## Maintenance policy

**Keep the docs in sync with the code, in the same change.** Whenever a change touches
something documented here, or introduces something that should be documented (a new feature,
a new pattern, a new convention, resolved or newly-created tech debt), update the relevant doc
**as part of that change** — never defer it. When a change defines a new pattern (see the
meta-rule in [conventions.md](conventions.md)), document the pattern before or alongside the
code that first uses it.

## What to document

- Architecture and the responsibilities of each layer.
- Conventions, coding style, and UI patterns — anything a future change should imitate.
- New patterns agreed via the meta-rule.
- Feature behavior (what exists, from the user's perspective) plus key code references.
- Cross-cutting behavior (e.g. currency conversion).
- Known tech debt (in `tech-debt.md`) and backlog ideas (in the root `README.md` TODO list).

## What NOT to document

- Things that are obvious from reading the code, or line-by-line restatements of a function.
- Transient implementation minutiae and one-off details.
- Anything already captured by git history or the code itself.
- Exhaustive method-by-method dumps — feature docs stay functional and reference the code.

## Routing guide

- Intentional pattern → `conventions.md`, `coding-style.md`, or `ui-patterns.md`.
- Known issue / code that breaks a pattern → `tech-debt.md`.
- Future work idea → the root [README.md](../README.md) TODO list.
- New or changed feature → the matching file under `features/`.

## Markdown style

All docs are markdown-lint clean: fenced code blocks specify a language (```dart, ```text,
```bash), lists are surrounded by blank lines, and each file has a single top-level heading.
