# Functional Specification: Transferring ABAP Packages into a Git Monorepo

**Status:** Open  
**As of:** Result of the functional grill-me session; supplemented by the decisions of the technical session (see `specs/technical.md`).  
**Implementation:** Not started yet.

## 1. Goal and Scope

### F-001 – SAP GUI Report
**Status:** Open

A simple SAP GUI report transfers existing ABAP packages and their objects into a shared Git monorepo. In the SAP system, a separate abapGit repository is created per component; all of them use the same remote URL.

### F-002 – Development Framework
**Status:** Open

Development is done using ARC-1 on the local SAP system. Before the technical session, the user installs the abapGit Developer Edition. The functional specification does not yet define a concrete API or implementation solution.

### F-003 – Existing SAP Content
**Status:** Open

The selected packages, subpackages and ABAP objects already exist. The report does not create new ABAP packages or business objects and does not change their functional content.

## 2. Inputs

### F-004 – ABAP Packages
**Status:** Open

Package selection is mandatory and is done via select options. Single values, wildcards, intervals and exclusions are supported.

### F-005 – Git URL
**Status:** Open

The Git URL is mandatory. The remote repository must already exist and contain at least one file. The report does not create a remote repository.

### F-006 – Folder Logic
**Status:** Open

The folder logic is mandatory. The abapGit variants PREFIX, FULL and MIXED are available for selection.

### F-007 – Top Folder
**Status:** Open

Top folder is optional and denotes a relative path in the remote. Multiple path levels, for example `abap/backend`, are permitted. Absolute paths and parent path segments (`..`) are not permitted.

## 3. Selection and Component Formation

### F-008 – Complete Package Tree
**Status:** Open

Each package selected as a component root is processed including its complete subpackage tree.

### F-009 – Overlapping Selection
**Status:** Open

After the entire select-options selection has been resolved, duplicate hits are merged. If a parent package and its subpackages are selected, only the topmost selected package is processed as the component root. The merge is made visible in the result.

### F-010 – Meaning of Exclusions
**Status:** Open

Exclusions only affect the selection of the component roots, not the content of a selected package tree. Example: If `ZAPP` is selected and its subpackage `ZAPP_TEST` is excluded, `ZAPP_TEST` remains part of the component `ZAPP`.

### F-011 – Selection Without Hits
**Status:** Open

If the resolved selection contains no existing packages, the report ends with a clear output and without changes, branch or PR. Non-existent names within an otherwise valid selection do not prevent the processing of existing packages.

### F-012 – Existing abapGit Assignments
**Status:** Open

If a component root is already assigned to an abapGit repository or its package tree overlaps with an existing repository assignment, the affected component is skipped with an error message. Existing assignments are not changed. Other components continue to be processed.

## 4. Folder Structure

### F-013 – Starting Folder per Component
**Status:** Open

The starting folder of a local abapGit repository is `/topFolder/component/src/`. Without a top folder it is `/component/src/`.

### F-014 – Component Name
**Status:** Open

The component name is derived from the full top-level package name after the agreed FULL-like name normalization: A leading `$` is dropped, namespace separators `/` are replaced by `#`, and the name is converted to lowercase.

| Root package | Component folder |
| --- | --- |
| `ZAPP` | `zapp` |
| `/ACME/APP` | `#acme#app` |
| `$APP` | `app` |

This rule is an explicitly agreed derivation for the component folder, not the automatic mapping of the root package by the abapGit folder logic.

### F-015 – Collision of Component Paths
**Status:** Open

If several selected components result in the same component path, all affected components are skipped as failed. There is no automatic renaming or merging.

### F-016 – Subpackage Paths
**Status:** Open

The chosen folder logic controls the subpackage paths below the starting folder. The root package itself lies directly in the starting folder. The actual package parent relationship determines the folder hierarchy.

- **PREFIX:** For a subpackage, the name prefix of the immediate parent package is removed. If this prefix is missing, an error occurs.
- **FULL:** The full subpackage name forms the folder segment; a leading `$` is dropped.
- **MIXED:** For each subpackage, the name prefix of the root package is removed. If this prefix is missing, an error occurs.

Further normalization of the subpackage segments follows abapGit. No custom alternative folder logic is implemented.

Example for `ZAPP → ZAPP_CORE → ZAPP_CORE_UTIL`, each relative to the starting folder:

| Folder logic | Subpackage path |
| --- | --- |
| PREFIX | `core/util/` |
| FULL | `zapp_core/zapp_core_util/` |
| MIXED | `core/core_util/` |

## 5. Branch, Repository Creation and Publication

### F-017 – Shared Working Branch
**Status:** Open

A new, uniquely named working branch is used per run. The base and PR target is the default branch of the remote. There is no direct push to the default branch.

### F-018 – Offline Creation and Online Switch
**Status:** Open

An offline repository is created first for each component. Afterwards, the starting folder and folder logic are set and the repository is switched to an online repository with the shared remote URL and shared working branch.

### F-019 – Transferring Content
**Status:** Open

The existing ABAP content of the components is transferred into the shared working branch via abapGit. Git handling is done via abapGit APIs; the supported Git providers follow abapGit, not a separate provider list of the report.

*Addition from technical session:* Only new and changed files are transferred. Files that exist only in the remote within the component folder are not deleted; their number is shown in the result list. Objects that abapGit cannot serialize lead to a partial success of the component.

### F-020 – No Custom Git Conflict Handling
**Status:** Open

The report uses the regular push behavior of abapGit. It performs neither force pushes nor automatic conflict resolution. Rejected pushes are logged; conflict handling is up to the user in Git. A component folder that already exists in the remote is not, by itself, a reason to skip a component. A separate update or conflict strategy is not in scope.

### F-021 – One Shared PR
**Status:** Open

Exactly one shared PR is created per run for the successfully transferred changes. Failed components are not reported as successfully transferred. If no components are successful or no Git changes arise, no PR is created.

*Addition from technical session:* Automatic PR creation exists only for `github.com`. For other providers (including GitHub Enterprise Server), repositories, working branch and push are executed as for GitHub, but no PR is created. The run is then considered a partial success; the output names the branch with a note to create the PR manually.

### F-022 – PR Content and Approval
**Status:** Open

The PR is created as a normal PR, not as a draft. Title and description are generated automatically. The description summarizes successful, failed and skipped components. Reviewer assignment, review, approval and merge are done manually. The report does not perform a merge.

### F-023 – State After PR Creation
**Status:** Open

The local abapGit repositories remain on the working branch after the run. The report does not wait for the merge and does not monitor it. After the merge, the user switches the repositories to the default branch themselves.

### F-024 – Permanent Separate Use
**Status:** Open

The separate local repositories must remain permanently usable for their respective component even after the merge, including status, pull and push. A PR that is merely created correctly once is not sufficient.

*Addition from technical session:* The starting folder and folder logic are kept only in the local abapGit repositories; the file `/.abapgit.xml` in the remote is neither read nor written by the report. Anyone connecting the monorepo on another system must set the starting folder, folder logic and the exclusion of `/.abapgit.xml` there themselves.

## 6. Errors and Partial Successes

### F-025 – Component-Related Errors
**Status:** Open

The run processes what is possible. A component-related error does not prevent the processing of other components. Common errors, for example an unreachable remote, may prevent further publication.

### F-026 – No Automatic Rollback
**Status:** Open

Already created local repositories and successful Git steps remain in place in case of later errors. This also applies if the online switch or the push of a component fails. The state reached is output; cleanup is done manually.

### F-027 – PR Creation Fails
**Status:** Open

If changes have already been pushed but PR creation fails, the branch, changes and local repositories are retained. The output names the branch and the error so that the user can create the PR manually. A push without the required PR is not a fully successful overall run.

### F-028 – No Automatic Resumption
**Status:** Open

Automatic resumption of earlier runs is not in scope. A repeated run skips already assigned packages in accordance with F-012. Manual cleanup or continuation is up to the user.

## 7. Output and Login

### F-029 – Simple Result List
**Status:** Open

At the end, a simple, colored WRITE output is displayed. For each component it contains the package, component path, processing step reached, success or error or skipped, and an understandable reason. Partial successes and existing assignments are also recognizable.

### F-030 – Summary
**Status:** Open

The output contains a summary as well as the working branch and, if created, the PR link. A persistent run history or additional log management is not planned.

### F-031 – Authentication and Credentials
**Status:** Open

Login is done via abapGit APIs. Credentials are not stored as report parameters, in variants or in the log. Missing authorizations are output as an understandable error of the affected step.

*Addition from technical session:* Login is done via the abapGit login popup (user and password or personal access token) at the start of the run. The report can therefore only be executed in dialog; a start in the background is rejected with a message.

## 8. Still to Be Verified Technically

### F-032 – Developer Edition APIs
**Status:** Open

After installing the abapGit Developer Edition, the API support for the entire flow including PR creation, as well as the permanent separation of several components with the same remote URL, must be verified. The functional requirements are therefore not yet technically confirmed. Missing PR support must not be silently replaced by a plain push.

The read-only preliminary check of the previous standalone version 1.128.0 demonstrated branch creation and push, but not PR creation. In addition, a possible conflict was found between the shared remote configuration `/.abapgit.xml` and different local starting folders. These findings are not a statement about the Developer Edition that is still to be installed.

*Result of technical session (Developer Edition, checked read-only):* Branch creation and push are possible via abapGit APIs. abapGit offers PR creation only rudimentarily for GitHub (always as a draft, without returning the link); the report therefore creates the PR with its own code based on the HTTP, login and JSON building blocks of abapGit (T-026). The `/.abapgit.xml` conflict is solved via the local abapGit setting `exclude_remote_paths` (T-023). Verification against a real remote is still pending.

## 9. Environment Context Stated by the User

The following details document the stated environment; no additional compatibility commitment results from them:

```text
SAP GUI for Java 8.10 rev 8
Version ID: 081000040800
2025-11-04 20:13:25 +0000
ccde1gl0559, 810_REL, 2287085
Java VM: SAP SE Version 21.0.9+10-LTS
OS: Linux(amd64) Version 7.0.0-38-generic
```
