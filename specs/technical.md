# Technical Specification: Transferring ABAP Packages into a Git Monorepo

**Status:** Agreed, implemented up to the manually testable state  
**As of:** Result of the technical grill-me session (2026-10-25); refers to `specs/functional.md`. Deviations from the implementation are marked as *Implementation:*.  
**Implementation:** All objects in `$ZABAPMONOREPO` active, 34 ABAP Unit tests green, ATC (`DEFAULT`) without findings of priority 1/2. Manual test against GitHub is pending.

Principle: abapGit APIs of the locally installed Developer Edition are reused wherever possible. Custom code is created only where abapGit offers no suitable API or the existing one does not fit functionally.

## 1. Framework

### T-001 – Storage and Namespace
Local package `$ZABAPMONOREPO` (not transportable, analogous to abapGit `$ABAPGIT*`). Object names: `ZMONO_*`, `ZCL_MONO_*`, `ZIF_MONO_*`, `ZCX_MONO_*`.

### T-002 – Coding Guidelines
Clean ABAP. No prefixes in own code (`iv_`, `lv_`, `gt_` …). When calling abapGit methods, their parameter names remain unchanged. Exception: selection screen parameters (`p_`, `s_`) according to the abaplint rule `selection_screen_naming`.

### T-003 – Dialog Mode Only
The report aborts with a clear message when `sy-batch = abap_true`, since the abapGit login popup (T-020) only works in dialog. Progress display via `zcl_abapgit_progress=>get_instance( )`. Known residual risk: dialog timeout (`rdisp/max_wprun_time`) with a very large number of components.

### T-004 – Strictly Sequential Processing
All components push to the same branch; no parallelization (no aRFC, no SPTA).

## 2. Architecture

### T-010 – Objects and Responsibilities

| Object | Responsibility |
| --- | --- |
| `ZMONO_IMPORT` (report) | Selection screen, input validation, factory call, WRITE output from `ZCL_MONO_RESULT`, integration of login popup (T-020) |
| `ZIF_MONO_TYPES` | Types, ENUMs (step, status), constants |
| `ZCL_MONO_PACKAGE_RESOLVER` | Resolve select options, package tree, merge overlaps (F-008 to F-011) |
| `ZCL_MONO_PATH_BUILDER` | Component name, starting folder, top folder validation, path collisions, folder logic pre-check (F-007, F-013 to F-016) |
| `ZCL_MONO_IMPORTER` | Orchestration: common pre-checks, flow per component, PR |
| `ZCL_MONO_RESULT` | Result per component and run data |
| `ZIF_MONO_PACKAGE_SOURCE` / `ZCL_MONO_PACKAGE_SOURCE` | `TDEVC` resolution of the select options, access to `ZIF_ABAPGIT_SAP_PACKAGE` |
| `ZIF_MONO_REPO_GATEWAY` / `ZCL_MONO_REPO_GATEWAY` | abapGit repositories: list, new_offline, configure, switch online, branch, stage, push |
| `ZIF_MONO_REMOTE_GATEWAY` / `ZCL_MONO_REMOTE_GATEWAY` | URL check, default branch, login incl. retry |
| `ZIF_MONO_PR_CLIENT` / `ZCL_MONO_PR_CLIENT_GITHUB` | PR creation on GitHub |
| `ZCL_MONO_FACTORY` | Creates the importer with the real implementations |
| `ZCX_MONO_ERROR` (abstract), `ZCX_MONO_COMPONENT_ERROR`, `ZCX_MONO_GLOBAL_ERROR` | Errors (T-030) |
| Message class `ZMONO` | All texts |

### T-011 – Dependencies
All dependencies are injected via the constructor. Only the gateway implementations and the package source call abapGit directly (anti-corruption layer). The business logic is testable without abapGit via test doubles.

### T-012 – Result Model
`ZIF_MONO_TYPES` defines:
- ENUM step: `resolved → checked → created → configured → online → on_branch → pushed | no_changes`
- ENUM status: `success | partial | failed | skipped`

`ZCL_MONO_RESULT` holds per component: root package, component path, last step reached, status, reason, `merged_from` (F-009), number of undeleted remote files (T-024), serialization warnings (T-025). Run data: working branch, default branch, PR link, common error. The WRITE output (F-029, F-030) reads exclusively from this object.

## 3. Selection Screen

### T-013 – Parameters

| Parameter | Type | Properties |
| --- | --- | --- |
| `s_pack` | `tdevc-devclass` | Select options, `OBLIGATORY` |
| `p_giturl` | `string` | `LOWER CASE`, `OBLIGATORY` |
| `p_logic` | Listbox PREFIX / FULL / MIXED | `OBLIGATORY`, no default value |
| `p_topfld` | `string` | `LOWER CASE`, optional |

Checks in `AT SELECTION-SCREEN` via `ZCL_MONO_PATH_BUILDER` (top folder) and URL check respectively. The names `p_url`, `p_user`, `p_pass`, `p_cmnt` and selection screen 1002 are occupied by the abapGit include (T-020).

## 4. Package Resolution and Pre-Checks

### T-014 – Package Resolution
- Select options: `SELECT devclass FROM tdevc WHERE devclass IN @packages`.
- Subpackages/parent packages: `zcl_abapgit_factory=>get_sap_package( )->list_subpackages( )` / `list_superpackages( )`.
- Overlap: For each hit, the parent packages are checked against a hashed table of the hits; only the topmost selected packages become component roots.

### T-015 – Existing Assignments (F-012)
Own pre-check against `repo_srv->list( )` in both directions (root within an existing repo tree; existing repo package within own tree). The check in `new_offline` / `validate_package` remains as a safety net.

### T-016 – Folder Logic Pre-Check (F-016)
Before `new_offline`, `zcl_abapgit_folder_logic=>get_instance( )->package_to_path( )` is called for each subpackage with a temporary `zcl_abapgit_dot_abapgit=>build_default( )` (chosen folder logic and starting folder set). An exception (e.g. missing prefix with PREFIX/MIXED) makes the component fail before a repository is created. No custom folder logic.

### T-017 – Remote Pre-Check (F-005)
Common, before any changes:
1. `repo_srv->validate_url( iv_chk_exists = abap_false )`.
2. Default branch via `zcl_abapgit_git_factory=>get_git_transport( )->branches( url )->get_head_symref( )`.
3. No HEAD/branch → remote empty → common error. A separate check for "at least one file" is omitted.

### T-018 – Provider Detection
GitHub = URL matches `github\.com/([^/]+)/([^/]+)` (same regex as `ZCL_ABAPGIT_PR_ENUMERATOR`), `.git` suffix is removed. GitHub Enterprise Server and all other providers are considered "without PR support" (T-027).

## 5. Login

### T-020 – Reuse of the abapGit Login Popup
In dialog, abapGit does not ask for credentials itself, but throws `ZCX_ABAPGIT_AUTH_REQUIRED`. The popup is selection screen 1002 in the include `ZABAPGIT_PASSWORD_DIALOG`; `ZCL_ABAPGIT_PASSWORD_DIALOG` calls it via `PERFORM password_popup IN PROGRAM (sy-cprog)`.

Implementation:
- Report: `INCLUDE zabapgit_password_dialog.` and event wiring as in `ZABAPGIT`:
  - `INITIALIZATION`: `lcl_password_dialog=>on_screen_init( )`
  - `AT SELECTION-SCREEN OUTPUT`: if `sy-dynnr = lcl_password_dialog=>c_dynnr` → `on_screen_output( )`
  - `AT SELECTION-SCREEN`: if `sy-dynnr = lcl_password_dialog=>c_dynnr` → `on_screen_event( sscrfields-ucomm )`
- `ZCL_MONO_REMOTE_GATEWAY` catches `ZCX_ABAPGIT_AUTH_REQUIRED`, behaves like `ZCL_ABAPGIT_GUI->request_credentials` (popup, `zcl_abapgit_login_manager=>set_basic`, remember login name via `persist user`) and repeats the action once. Cancellation in the popup → common error.
- The first remote action is T-017; afterwards the credentials are stored for the host and are also found by the PR client (T-026).
- At the end of the run: `zcl_abapgit_login_manager=>clear( )`.
- Credentials are stored neither in the main selection screen nor in the log (F-031).

*Implementation:* The popup is called **before** the first remote access (`ZCL_MONO_REMOTE_GATEWAY->connect`), not only upon `ZCX_ABAPGIT_AUTH_REQUIRED`. Reason: For public repositories, reading succeeds anonymously and only the push would fail due to the missing login. If the login is rejected, the popup is displayed again up to three times.

## 6. Flow per Component

### T-021 – Branch
Name `refs/heads/abap-import/<YYYYMMDD-HHMMSS>`. The first repository successfully switched online selects the default branch and creates the working branch via `create_branch`; all further repositories select it via `select_branch`. If branch creation fails, this is a common error.

### T-022 – Repository Creation and Configuration
Order:
1. `repo_srv->new_offline( iv_name = <root package>, iv_package, iv_folder_logic )`; remaining parameters abapGit defaults (`iv_main_lang_only = abap_false`, `iv_ign_subpkg = abap_false`, `iv_abap_lang_vers` empty).
2. `dot_abapgit->set_starting_folder( '/<topFolder>/<component>/src/' )`.
3. Local settings: `exclude_remote_paths = '/.abapgit.xml'`, `display_name = <component path>`, `labels = 'monorepo'`. **Must be done before switching online and before any status/stage calculation.**
4. `switch_repo_type( iv_offline = abap_false )`; afterwards fetch the repository again via `repo_srv->get( key )` (the old reference is stale after re-instantiation).
5. `set_url( <Git URL> )`, branch according to T-021.

### T-023 – `.abapgit.xml`
Through `exclude_remote_paths = '/.abapgit.xml'`, the root `.abapgit.xml` of the remote is neither read (`find_remote_dot_abapgit` uses `get_files_remote( )` in the installed state, which applies the exclusions) nor pushed (`get_files_local` removes it locally). Starting folder and folder logic reside only in the local repository metadata. Remote files outside the starting folder are ignored by abapGit and carried over unchanged on push. This keeps the repositories permanently usable separately (F-024).

### T-024 – Stage and Push
Not via `ZCL_ABAPGIT_BACKGROUND_PUSH_FI` (fixed commit text), but:
1. `repo->refresh( )` immediately before staging (prevents a stale parent after the push of the previous component).
2. `zcl_abapgit_stage_logic=>get_stage_logic( )->get( repo )`.
3. Add all `local` files via `stage->add( )`. **No deletions:** `remote` files (existing only in the remote) are not staged; their number is shown in the result.
4. Empty stage → step `no_changes`, no commit.
5. Commit text `Import component <root package>`; committer according to the abapGit chain: `persist user` (repo-specific, then default) → user master record → fallback `<sy-uname>@localhost`.
6. `zcl_abapgit_repo_factory=>get_repo_push( repo )->push( )`. One commit per component. Rejected pushes are logged (F-020); no force push.

### T-025 – Serialization Warnings
A `ZIF_ABAPGIT_LOG` is passed per component. Warnings or errors (e.g. unsupported object types) lead to the status `partial`; number and first messages are stated in the reason. Pushing is done nevertheless.

## 7. Pull Request

### T-026 – Own GitHub PR Client
`ZCL_ABAPGIT_PR_ENUM_GITHUB->create_pull_request` is not used: It always creates a draft (contradicts F-022; fails for private repos in the GitHub Free plan), does not escape JSON, and returns neither number nor link.

`ZCL_MONO_PR_CLIENT_GITHUB` uses abapGit infrastructure:
- `zcl_abapgit_http_agent=>create( )` (SSL, proxy), headers `Accept: application/vnd.github.v3+json`, `X-GitHub-Api-Version: 2022-11-28`, `Authorization` from `zcl_abapgit_login_manager=>get( )` for `https://github.com/...`.
- Payload with `zcl_abapgit_ajson` (`title`, `body`, `head`, `base`, `draft = false`) → `POST https://api.github.com/repos/<owner>/<repo>/pulls`.
- Response: `response->json( )->get( '/html_url' )`, `get_integer( '/number' )`; if `is_ok( ) = abap_false`, error with `code( )` and `error( )`.
- Title: `ABAP import: <n> components (<branch>)`. Description: Markdown with sections successes, partial successes, errors, skipped.
- PR only if at least one component has reached `pushed` (`no_changes` does not count).
- If PR creation fails, F-027 applies.

Required PAT permissions: `contents:write`, `pull_requests:write`.

### T-027 – Other Providers
Branch creation and push as for GitHub; no PR. Overall result: partial success with the note "create PR manually" and the branch name.

## 8. Error Handling

### T-030 – Exception Design
- `ZCX_MONO_ERROR`: abstract, inherits from `CX_STATIC_CHECK`, implements `IF_T100_DYN_MSG`; attribute for the failed step.
- `ZCX_MONO_COMPONENT_ERROR`: component failed, processing of the next component continues.
- `ZCX_MONO_GLOBAL_ERROR`: further publication is aborted (F-025).
- Gateways catch `ZCX_ABAPGIT_EXCEPTION` and pass it on as `previous` in the appropriate subclass.
- No rollback of states already reached (F-026). No own `ROLLBACK`; abapGit commits internally.

*Implementation:* `ZCX_MONO_ERROR` has no step attribute; the importer keeps the step reached in the result. Instead, `get_full_text( )` returns the message text including the texts of all `previous` exceptions (e.g. the abapGit error message). The repository gateway methods conclude each step with `COMMIT WORK` so that states reached are preserved even in case of later aborts.

## 9. Quality Assurance

### T-040 – Tests
ABAP Unit for: path building and normalization (example tables from F-014/F-016 as test methods), top folder validation, overlap and collisions, PR text and JSON structure, importer flow with test doubles of the gateways. Against a real remote only manually.

### T-041 – Checks During Implementation (ARC-1)
1. `SAPLint` before each activation with `abaplint.jsonc` in the workspace (linked via `SAP_ABAPLINT_CONFIG` in `~/.config/arc-1/.env`). Basis: ARC-1 preset `onprem`; additionally `no_prefixes`; `errorNamespace` restricted to own objects so that abapGit types are treated as void.
2. After activation `SAPDiagnose`: syntax, ABAP Unit, ATC.
3. ATC always explicitly with variant `DEFAULT` (system default `ZABAP_CLOUD_DEVELOPMENT` is unsuitable for classic ABAP), timeout 600 s, blocking only priority 1 and 2. An incomplete ATC run is not considered passed and is reported.
4. Then manual test against a GitHub test repository with at least one file.

*Implementation:*
- `abaplint.jsonc` activates all preset rules plus the 25 switched off in the preset, with the full default configuration per rule (abaplint does not add missing options). Naming rules forbid prefixes instead of requiring them. `description_empty` stays off (requires the class XML, which ARC-1 does not pass). `errorNamespace` covers only local prefixes.
- ARC-1 lints each source individually. References to other own objects (superclasses, implemented interfaces, the abapGit include) therefore inevitably report `check_syntax`, `implement_methods`, `superclass_final` and `unused_types` as errors. These messages are ignored during evaluation; test class includes are linted as a program. Writing is done with `lintBeforeWrite = false`; the subsequent SAP activation is authoritative.
- `SAP_ALLOWED_PACKAGES=$TMP,$ZABAPMONOREPO,$ZMONO_DEMO*` in `~/.config/arc-1/.env`.
- Remaining ATC findings (priority 3): non-translatable literals in the PR text (deliberately English) and in the included abapGit include. The access to `TDEVC` with a range is done explicitly `BYPASSING BUFFER`.

## 10. Test Data

Local test packages with demo classes for the manual test:

| Package | Parent package | Purpose |
| --- | --- | --- |
| `$ZMONO_DEMO_APP` | – | Component with subpackage tree |
| `$ZMONO_DEMO_APP_CORE` | `$ZMONO_DEMO_APP` | Subpackage |
| `$ZMONO_DEMO_APP_CORE_UTIL` | `$ZMONO_DEMO_APP_CORE` | Example from F-016 (PREFIX `core/util/`, FULL `zmono_demo_app_core/zmono_demo_app_core_util/`, MIXED `core/core_util/`) |
| `$ZMONO_DEMO_APP_UI` | `$ZMONO_DEMO_APP` | Subpackage |
| `$ZMONO_DEMO_LIB` | – | Component with interface in subpackage |
| `$ZMONO_DEMO_LIB_API` | `$ZMONO_DEMO_LIB` | Subpackage |
| `$ZMONO_DEMO_TOOL` | – | Component without subpackages |
| `$ZMONO_DEMO_MISC` | – | Component with prefix violation |
| `$ZMONO_DEMO_FOREIGN` | `$ZMONO_DEMO_MISC` | fails with PREFIX/MIXED, works with FULL |
| `$ZMONO_DEMO_EMPTY` | – | Component without objects |

The paths from F-016 and the failure behavior of `$ZMONO_DEMO_FOREIGN` were confirmed with a temporary integration test against the real abapGit APIs.

## 11. Open Risks

- The exact GitHub error text for non-fast-forward is untested.
- ATC runtime on the system: A trial run had not finished after 120 s.
- Dependency on internal, non-released abapGit APIs; encapsulated by the gateways.
