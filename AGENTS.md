# ZMONO – ABAP monorepo builder

SAP GUI report `ZMONO_IMPORT` that moves existing ABAP packages into one shared Git monorepo: one abapGit repository per component (package tree), all on the same remote URL, pushed to a shared branch, finished with one GitHub pull request. It builds on internal, unreleased abapGit APIs (abapGit Developer Edition on the SAP system).

## Workflow

Work follows Matt Pocock's engineering skills (`.opencode/skills/`; `/ask-matt` routes to the right one):

1. `/grill-with-docs` sharpens an idea and records terms in `GLOSSARY.md`, decisions in `docs/adr/`. Detour through `/prototype` when a question needs running code.
2. Multi-session work: `/to-spec` publishes a spec as GitHub issue, `/to-tickets` splits it into tracer-bullet tickets with blocking edges.
3. `/implement` per ticket (fresh context each) or `/implement-spec` for the whole spec; both build test-first with `/tdd` and close with `/code-review`. `/pr` shapes the PR body.
4. `/retro` turns lessons into checks, coding standards or steering.

On-ramps: `/triage` for incoming issues, `/diagnosing-bugs` for hard bugs, `/wayfinder` for efforts too foggy for one session.

## Architecture

- `ZCL_MONO_IMPORTER` orchestrates; `ZCL_MONO_FACTORY` wires the real implementations.
- Only the gateways (`ZCL_MONO_REPO_GATEWAY`, `ZCL_MONO_REMOTE_GATEWAY`), `ZCL_MONO_PACKAGE_SOURCE` and `ZCL_MONO_PR_CLIENT_GITHUB` call abapGit. They are the anti-corruption layer: keep abapGit types and calls inside them.
- Dependencies are injected via constructor, so the business logic is unit-tested with test doubles of the `ZIF_MONO_*` interfaces.
- `ZCL_MONO_RESULT` is the single source for the report output. Errors: `ZCX_MONO_COMPONENT_ERROR` fails one component, `ZCX_MONO_GLOBAL_ERROR` aborts the run. All texts in message class `ZMONO`.

## Conventions

- Clean ABAP without Hungarian prefixes; types `ty_*`; selection screen `p_*`/`s_*`. abapGit parameter names (`iv_*` …) stay as abapGit defines them. `abaplint.jsonc` enforces the rest.
- SAP package `$ZABAPMONOREPO` (local, not transportable).
- Commits and PR titles follow Conventional Commits (`feat: …`, `fix: …`, `chore: …`, `docs: …`). PRs are squash-merged with the PR title as commit message, so the PR title must be a valid conventional commit.

## Verification

- `npm test`: abaplint, TypeScript typecheck and ABAP Unit transpiled to JavaScript (off-stack, no SAP system). `zmono_import` is excluded from the transpiled run (selection screen).
- Known red: `ltcl_importer->imports_all_components` fails off-stack due to a transpiler bug with `BEGIN OF ENUM … STRUCTURE` (abaplint/transpiler#2280). It passes on SAP.
- The authoritative check is ABAP Unit and syntax on the SAP system, see SAP sync.

## ABAP documentation

Research ABAP language, SAP APIs and released objects with the `sap-docs-abap` MCP server (`https://mcp-abap.marianzeis.de/mcp`).

## SAP system access

The ARC-1 MCP server (`sap-trial`) connects to the local SAP system. Use it to look things up directly on the system: read sources, search objects, check syntax, run ATC and ABAP Unit, inspect dumps. Lint runs with this project's `abaplint.jsonc`.

## SAP sync

Custom tools in `.opencode/tools/` connect to the SAP system via ADT, using credentials from `.env` (template `.env.example`):

- `adt_gitpull`: abapGit pull of this repository on the SAP system (`checkErrors=true` adds an ATC syntax check). Skill `adt-gitpull`.
- `adt_checkerrors`: ATC `SYNTAX_CHECK` on `SAP_ROOT_PACKAGE`. Skill `adt-checkerrors`.
- `adt_rununit`: ABAP Unit tests on the SAP system. Skill `adt-rununit`.

Use them only in interactive chat, on explicit user request.

## Issues and domain docs

- Issues: GitHub Issues via `gh`, see `docs/agents/issue-tracker.md`.
- Triage labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`, see `docs/agents/triage-labels.md`.
- Domain docs: single context, `GLOSSARY.md` and `docs/adr/` at the repo root, see `docs/agents/domain.md`.
