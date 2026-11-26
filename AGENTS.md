## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues (MagPasulke/abap-monorepo-builder) via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## SAP sync

Custom tools in `.opencode/tools/` connect to the SAP system via ADT, using credentials from `.env` (see `.env.example`):

- `adt_gitpull`: abapGit pull of this repository on the SAP system (`checkErrors=true` adds an ATC syntax check). See the `adt-gitpull` skill.
- `adt_checkerrors`: ATC `SYNTAX_CHECK` on `SAP_ROOT_PACKAGE`. See the `adt-checkerrors` skill.
- `adt_rununit`: ABAP Unit tests on the SAP system. See the `adt-rununit` skill.

Use them only in interactive chat and only when the user asks for it. Never call them autonomously.
