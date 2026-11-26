# ZMONO – ABAP monorepo builder

SAP GUI report that moves existing ABAP packages into one shared Git monorepo using abapGit. Each selected package (with its subpackages) becomes its own abapGit repository, but all of them point to the same remote. The report pushes all components to a new working branch and opens one pull request on GitHub.

> **Status:** implemented and unit-tested, but not yet verified end to end against a real remote repository.

## How it works

For each selected root package the report:

1. checks that the package is not already part of an abapGit repository and that its subpackages fit the chosen folder logic,
2. creates an offline abapGit repository, sets the starting folder `/<top folder>/<component>/src/` and switches it online to the shared remote,
3. creates the working branch `abap-import/<date>-<time>` (first component) or selects it (all others),
4. pushes new and changed files, one commit per component.

Finally it creates one pull request from the working branch to the default branch and prints a colored result list: status, step reached and reason per component, plus branch and PR link.

Behavior worth knowing:

- **Component folder:** root package name in lowercase, leading `$` dropped, `/` replaced by `#` (`/ACME/APP` → `#acme#app`).
- **Overlapping selection:** if a package and its subpackages are selected, only the topmost one becomes a component; exclusions only affect which packages become components.
- **No deletions:** files that exist only in the remote are kept; their number is shown in the result.
- **No rollback:** repositories and pushes already done stay in place if a later step fails; one failing component does not stop the others.
- **`/.abapgit.xml`:** excluded from each repository, so starting folder and folder logic live only in the local abapGit settings. Connecting the monorepo on another system needs the same local settings.
- **Pull requests:** only for `github.com`. For other Git hosts the branch is pushed and the result asks you to create the PR manually.

## Prerequisites

- SAP system with the **abapGit Developer Edition** installed (the report uses its internal APIs and includes `ZABAPGIT_PASSWORD_DIALOG`).
- An existing remote repository with at least one file (the report does not create remotes).
- For GitHub: a personal access token with `contents:write` and `pull_requests:write`.

## Installation

Clone this repository with abapGit into the local package `$ZABAPMONOREPO` and activate all objects.

## Usage

Run report `ZMONO_IMPORT` in dialog (background runs are rejected):

| Field | Description |
|---|---|
| Packages | Root packages: single values, wildcards, intervals, exclusions |
| Git URL | Remote repository URL |
| Folder logic | `PREFIX`, `FULL` or `MIXED` (abapGit folder logic for subpackages) |
| Top folder | Optional relative path in the remote, e.g. `abap/backend` |

At the start the abapGit login popup asks for user and password or token. After the PR is merged, switch the repositories to the default branch yourself.

## Development

```sh
npm ci
npm test   # abaplint, TypeScript typecheck, ABAP Unit transpiled to JavaScript
```

The unit tests run off-stack via the [abaplint transpiler](https://github.com/abaplint/transpiler). One test (`ltcl_importer->imports_all_components`) currently fails off-stack because of a transpiler bug, see abaplint/transpiler#2280; it passes on SAP.

Syncing to the SAP system and running ABAP Unit there is done with the opencode tools in `.opencode/tools/` (`adt_gitpull`, `adt_checkerrors`, `adt_rununit`). Copy `.env.example` to `.env` and fill in the SAP connection.

Agent workflow and architecture notes: [`AGENTS.md`](AGENTS.md).
