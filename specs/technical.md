# Technische Spezifikation: ABAP-Pakete in ein Git-Monorepo übernehmen

**Status:** Abgestimmt, umgesetzt bis zum manuell testbaren Stand  
**Stand:** Ergebnis der technischen Grill-me-Session (2026-10-25); bezieht sich auf `specs/functional.md`. Abweichungen aus der Umsetzung sind als *Umsetzung:* markiert.  
**Umsetzung:** Alle Objekte in `$ZABAPMONOREPO` aktiv, 34 ABAP-Unit-Tests grün, ATC (`DEFAULT`) ohne Befunde der Priorität 1/2. Manueller Test gegen GitHub steht aus.

Grundsatz: abapGit-APIs der lokal installierten Developer Edition werden wiederverwendet, wo immer möglich. Eigener Code entsteht nur dort, wo abapGit keine passende API bietet oder die vorhandene fachlich nicht passt.

## 1. Rahmen

### T-001 – Ablage und Namensraum
Lokales Paket `$ZABAPMONOREPO` (nicht transportierbar, analog abapGit `$ABAPGIT*`). Objektnamen: `ZMONO_*`, `ZCL_MONO_*`, `ZIF_MONO_*`, `ZCX_MONO_*`.

### T-002 – Codierrichtlinien
Clean ABAP. Keine Präfixe in eigenem Code (`iv_`, `lv_`, `gt_` …). Beim Aufruf von abapGit-Methoden bleiben deren Parameternamen unverändert. Ausnahme: Selektionsbildparameter (`p_`, `s_`) gemäß abaplint-Regel `selection_screen_naming`.

### T-003 – Nur Dialogbetrieb
Der Report bricht bei `sy-batch = abap_true` mit klarer Meldung ab, da das abapGit-Login-Popup (T-020) nur im Dialog funktioniert. Fortschrittsanzeige über `zcl_abapgit_progress=>get_instance( )`. Bekanntes Restrisiko: Dialog-Timeout (`rdisp/max_wprun_time`) bei sehr vielen Komponenten.

### T-004 – Verarbeitung streng sequenziell
Alle Komponenten pushen auf denselben Branch; keine Parallelisierung (kein aRFC, kein SPTA).

## 2. Architektur

### T-010 – Objekte und Verantwortungen

| Objekt | Verantwortung |
| --- | --- |
| `ZMONO_IMPORT` (Report) | Selektionsbild, Eingabeprüfung, Factory-Aufruf, WRITE-Ausgabe aus `ZCL_MONO_RESULT`, Einbindung Login-Popup (T-020) |
| `ZIF_MONO_TYPES` | Typen, ENUMs (Schritt, Status), Konstanten |
| `ZCL_MONO_PACKAGE_RESOLVER` | Select-Options auflösen, Paketbaum, Überlappungen zusammenfassen (F-008 bis F-011) |
| `ZCL_MONO_PATH_BUILDER` | Komponentenname, Startordner, Top-Folder-Validierung, Pfadkollisionen, Folder-Logic-Vorabprüfung (F-007, F-013 bis F-016) |
| `ZCL_MONO_IMPORTER` | Orchestrierung: gemeinsame Vorabprüfungen, Ablauf pro Komponente, PR |
| `ZCL_MONO_RESULT` | Ergebnis pro Komponente und Laufdaten |
| `ZIF_MONO_PACKAGE_SOURCE` / `ZCL_MONO_PACKAGE_SOURCE` | `TDEVC`-Auflösung der Select-Options, Zugriff auf `ZIF_ABAPGIT_SAP_PACKAGE` |
| `ZIF_MONO_REPO_GATEWAY` / `ZCL_MONO_REPO_GATEWAY` | abapGit-Repositories: list, new_offline, konfigurieren, online schalten, Branch, Stage, Push |
| `ZIF_MONO_REMOTE_GATEWAY` / `ZCL_MONO_REMOTE_GATEWAY` | URL-Prüfung, Default-Branch, Anmeldung inkl. Wiederholung |
| `ZIF_MONO_PR_CLIENT` / `ZCL_MONO_PR_CLIENT_GITHUB` | PR-Erstellung auf GitHub |
| `ZCL_MONO_FACTORY` | Erzeugt den Importer mit den echten Implementierungen |
| `ZCX_MONO_ERROR` (abstrakt), `ZCX_MONO_COMPONENT_ERROR`, `ZCX_MONO_GLOBAL_ERROR` | Fehler (T-030) |
| Nachrichtenklasse `ZMONO` | Alle Texte |

### T-011 – Abhängigkeiten
Alle Abhängigkeiten werden per Konstruktor injiziert. Nur die Gateway-Implementierungen und die Paketquelle rufen abapGit direkt auf (Anti-Corruption-Layer). Die Fachlogik ist ohne abapGit über Test-Doubles testbar.

### T-012 – Ergebnismodell
`ZIF_MONO_TYPES` definiert:
- ENUM Schritt: `resolved → checked → created → configured → online → on_branch → pushed | no_changes`
- ENUM Status: `success | partial | failed | skipped`

`ZCL_MONO_RESULT` hält pro Komponente: Root-Paket, Komponentenpfad, zuletzt erreichter Schritt, Status, Begründung, `merged_from` (F-009), Anzahl nicht gelöschter Remote-Dateien (T-024), Serialisierungswarnungen (T-025). Laufdaten: Arbeitsbranch, Default-Branch, PR-Link, gemeinsamer Fehler. Die WRITE-Ausgabe (F-029, F-030) liest ausschließlich dieses Objekt.

## 3. Selektionsbild

### T-013 – Parameter

| Parameter | Typ | Eigenschaften |
| --- | --- | --- |
| `s_pack` | `tdevc-devclass` | Select-Options, `OBLIGATORY` |
| `p_giturl` | `string` | `LOWER CASE`, `OBLIGATORY` |
| `p_logic` | Listbox PREFIX / FULL / MIXED | `OBLIGATORY`, ohne Vorbelegung |
| `p_topfld` | `string` | `LOWER CASE`, optional |

Prüfungen in `AT SELECTION-SCREEN` über `ZCL_MONO_PATH_BUILDER` (Top Folder) bzw. URL-Prüfung. Die Namen `p_url`, `p_user`, `p_pass`, `p_cmnt` und Selektionsbild 1002 sind durch das abapGit-Include belegt (T-020).

## 4. Paketauflösung und Vorabprüfungen

### T-014 – Paketauflösung
- Select-Options: `SELECT devclass FROM tdevc WHERE devclass IN @packages`.
- Unter-/Oberpakete: `zcl_abapgit_factory=>get_sap_package( )->list_subpackages( )` / `list_superpackages( )`.
- Überlappung: Für jeden Treffer werden die Oberpakete gegen eine Hashed-Tabelle der Treffer geprüft; nur oberste ausgewählte Pakete werden Komponentenwurzeln.

### T-015 – Bestehende Zuordnungen (F-012)
Eigene Vorabprüfung gegen `repo_srv->list( )` in beide Richtungen (Root in bestehendem Repo-Baum; bestehendes Repo-Paket im eigenen Baum). Die Prüfung in `new_offline` / `validate_package` bleibt als Sicherheitsnetz.

### T-016 – Folder-Logic-Vorabprüfung (F-016)
Vor `new_offline` wird für jedes Unterpaket `zcl_abapgit_folder_logic=>get_instance( )->package_to_path( )` mit einem temporären `zcl_abapgit_dot_abapgit=>build_default( )` (gewählte Folder Logic und Startordner gesetzt) aufgerufen. Eine Exception (z. B. fehlender Präfix bei PREFIX/MIXED) macht die Komponente fehlerhaft, bevor ein Repository entsteht. Keine eigene Folder Logic.

### T-017 – Remote-Vorabprüfung (F-005)
Gemeinsam, vor allen Änderungen:
1. `repo_srv->validate_url( iv_chk_exists = abap_false )`.
2. Default-Branch über `zcl_abapgit_git_factory=>get_git_transport( )->branches( url )->get_head_symref( )`.
3. Kein HEAD/Branch → Remote leer → gemeinsamer Fehler. Eine gesonderte Prüfung auf „mindestens eine Datei“ entfällt.

### T-018 – Anbietererkennung
GitHub = URL passt auf `github\.com/([^/]+)/([^/]+)` (gleiche Regex wie `ZCL_ABAPGIT_PR_ENUMERATOR`), `.git`-Endung wird entfernt. GitHub Enterprise Server und alle anderen Anbieter gelten als „ohne PR-Unterstützung“ (T-027).

## 5. Anmeldung

### T-020 – Wiederverwendung des abapGit-Login-Popups
abapGit fragt im Dialog nicht selbst nach Zugangsdaten, sondern wirft `ZCX_ABAPGIT_AUTH_REQUIRED`. Das Popup ist Selektionsbild 1002 im Include `ZABAPGIT_PASSWORD_DIALOG`; `ZCL_ABAPGIT_PASSWORD_DIALOG` ruft es per `PERFORM password_popup IN PROGRAM (sy-cprog)` auf.

Umsetzung:
- Report: `INCLUDE zabapgit_password_dialog.` und Ereignisverdrahtung wie in `ZABAPGIT`:
  - `INITIALIZATION`: `lcl_password_dialog=>on_screen_init( )`
  - `AT SELECTION-SCREEN OUTPUT`: bei `sy-dynnr = lcl_password_dialog=>c_dynnr` → `on_screen_output( )`
  - `AT SELECTION-SCREEN`: bei `sy-dynnr = lcl_password_dialog=>c_dynnr` → `on_screen_event( sscrfields-ucomm )`
- `ZCL_MONO_REMOTE_GATEWAY` fängt `ZCX_ABAPGIT_AUTH_REQUIRED`, verhält sich wie `ZCL_ABAPGIT_GUI->request_credentials` (Popup, `zcl_abapgit_login_manager=>set_basic`, Login-Name über `persist user` merken) und wiederholt die Aktion einmal. Abbruch im Popup → gemeinsamer Fehler.
- Die erste Remote-Aktion ist T-017; danach sind die Zugangsdaten für den Host gespeichert und werden auch vom PR-Client (T-026) gefunden.
- Am Laufende: `zcl_abapgit_login_manager=>clear( )`.
- Zugangsdaten werden weder im Hauptselektionsbild noch im Protokoll gespeichert (F-031).

*Umsetzung:* Das Popup wird nicht erst bei `ZCX_ABAPGIT_AUTH_REQUIRED`, sondern **vor** dem ersten Remote-Zugriff aufgerufen (`ZCL_MONO_REMOTE_GATEWAY->connect`). Grund: Bei öffentlichen Repositories gelingt das Lesen anonym und erst der Push würde an der fehlenden Anmeldung scheitern. Wird die Anmeldung abgewiesen, wird das Popup bis zu dreimal erneut angezeigt.

## 6. Ablauf pro Komponente

### T-021 – Branch
Name `refs/heads/abap-import/<JJJJMMTT-HHMMSS>`. Das erste erfolgreich online geschaltete Repository wählt den Default-Branch und legt den Arbeitsbranch per `create_branch` an; alle weiteren Repositories wählen ihn per `select_branch`. Scheitert die Branch-Anlage, ist das ein gemeinsamer Fehler.

### T-022 – Repository-Anlage und Konfiguration
Reihenfolge:
1. `repo_srv->new_offline( iv_name = <Root-Paket>, iv_package, iv_folder_logic )`; übrige Parameter abapGit-Defaults (`iv_main_lang_only = abap_false`, `iv_ign_subpkg = abap_false`, `iv_abap_lang_vers` leer).
2. `dot_abapgit->set_starting_folder( '/<topFolder>/<component>/src/' )`.
3. Lokale Einstellungen: `exclude_remote_paths = '/.abapgit.xml'`, `display_name = <Komponentenpfad>`, `labels = 'monorepo'`. **Muss vor dem Online-Schalten und vor jeder Status-/Stage-Berechnung erfolgen.**
4. `switch_repo_type( iv_offline = abap_false )`; danach Repository über `repo_srv->get( key )` neu holen (alte Referenz ist nach Reinstanziierung veraltet).
5. `set_url( <Git-URL> )`, Branch gemäß T-021.

### T-023 – `.abapgit.xml`
Durch `exclude_remote_paths = '/.abapgit.xml'` wird die Root-`.abapgit.xml` des Remotes weder gelesen (`find_remote_dot_abapgit` nutzt im installierten Stand `get_files_remote( )`, das die Ausschlüsse anwendet) noch gepusht (`get_files_local` entfernt sie lokal). Startordner und Folder Logic liegen nur in den lokalen Repository-Metadaten. Remote-Dateien außerhalb des Startordners werden von abapGit ignoriert und beim Push unverändert übernommen. Damit bleiben die Repositories dauerhaft getrennt nutzbar (F-024).

### T-024 – Stage und Push
Nicht über `ZCL_ABAPGIT_BACKGROUND_PUSH_FI` (fester Commit-Text), sondern:
1. `repo->refresh( )` unmittelbar vor dem Staging (verhindert veralteten Parent nach dem Push der vorherigen Komponente).
2. `zcl_abapgit_stage_logic=>get_stage_logic( )->get( repo )`.
3. Alle `local`-Dateien per `stage->add( )`. **Keine Löschungen:** `remote`-Dateien (nur im Remote vorhanden) werden nicht gestaged; ihre Anzahl wird im Ergebnis ausgewiesen.
4. Leere Stage → Schritt `no_changes`, kein Commit.
5. Commit-Text `Import component <Root-Paket>`; Committer nach abapGit-Kette: `persist user` (repo-spezifisch, dann Default) → Benutzerstammsatz → Fallback `<sy-uname>@localhost`.
6. `zcl_abapgit_repo_factory=>get_repo_push( repo )->push( )`. Ein Commit pro Komponente. Abgewiesene Pushes werden protokolliert (F-020); kein Force-Push.

### T-025 – Serialisierungswarnungen
Pro Komponente wird ein `ZIF_ABAPGIT_LOG` übergeben. Warnungen oder Fehler (z. B. nicht unterstützte Objekttypen) führen zum Status `partial`; Anzahl und erste Meldungen stehen in der Begründung. Gepusht wird trotzdem.

## 7. Pull Request

### T-026 – Eigener GitHub-PR-Client
`ZCL_ABAPGIT_PR_ENUM_GITHUB->create_pull_request` wird nicht verwendet: Sie erzeugt fest einen Entwurf (widerspricht F-022; scheitert bei privaten Repos im GitHub-Free-Tarif), escaped kein JSON und liefert weder Nummer noch Link.

`ZCL_MONO_PR_CLIENT_GITHUB` verwendet abapGit-Infrastruktur:
- `zcl_abapgit_http_agent=>create( )` (SSL, Proxy), Header `Accept: application/vnd.github.v3+json`, `X-GitHub-Api-Version: 2022-11-28`, `Authorization` aus `zcl_abapgit_login_manager=>get( )` für `https://github.com/...`.
- Payload mit `zcl_abapgit_ajson` (`title`, `body`, `head`, `base`, `draft = false`) → `POST https://api.github.com/repos/<owner>/<repo>/pulls`.
- Antwort: `response->json( )->get( '/html_url' )`, `get_integer( '/number' )`; bei `is_ok( ) = abap_false` Fehler mit `code( )` und `error( )`.
- Titel: `ABAP import: <n> components (<branch>)`. Beschreibung: Markdown mit Abschnitten Erfolge, Teilerfolge, Fehler, Übersprungene.
- PR nur, wenn mindestens eine Komponente `pushed` erreicht hat (`no_changes` zählt nicht).
- Scheitert die PR-Erstellung, gilt F-027.

Benötigte PAT-Berechtigungen: `contents:write`, `pull_requests:write`.

### T-027 – Andere Anbieter
Branch-Anlage und Push wie bei GitHub; kein PR. Gesamtergebnis: Teilerfolg mit Hinweis „PR manuell anlegen“ und Branchnamen.

## 8. Fehlerbehandlung

### T-030 – Exception-Design
- `ZCX_MONO_ERROR`: abstrakt, erbt von `CX_STATIC_CHECK`, implementiert `IF_T100_DYN_MSG`; Attribut für den fehlgeschlagenen Schritt.
- `ZCX_MONO_COMPONENT_ERROR`: Komponente fehlerhaft, Verarbeitung der nächsten Komponente geht weiter.
- `ZCX_MONO_GLOBAL_ERROR`: weitere Veröffentlichung wird abgebrochen (F-025).
- Gateways fangen `ZCX_ABAPGIT_EXCEPTION` und reichen sie als `previous` in der passenden Unterklasse weiter.
- Keine Rücknahme bereits erreichter Zustände (F-026). Kein eigenes `ROLLBACK`; abapGit committet intern.

*Umsetzung:* `ZCX_MONO_ERROR` hat kein Schritt-Attribut; den erreichten Schritt führt der Importer im Ergebnis. Stattdessen liefert `get_full_text( )` den Meldungstext samt Texten aller `previous`-Exceptions (z. B. die abapGit-Fehlermeldung). Die Repository-Gateway-Methoden schließen jeden Schritt mit `COMMIT WORK` ab, damit erreichte Zustände auch bei späteren Abbrüchen erhalten bleiben.

## 9. Qualitätssicherung

### T-040 – Tests
ABAP Unit für: Pfadbildung und Normalisierung (Beispieltabellen aus F-014/F-016 als Testmethoden), Top-Folder-Validierung, Überlappung und Kollisionen, PR-Text und JSON-Aufbau, Importer-Ablauf mit Test-Doubles der Gateways. Gegen ein echtes Remote nur manuell.

### T-041 – Prüfungen in der Umsetzung (ARC-1)
1. `SAPLint` vor jeder Aktivierung mit `abaplint.jsonc` im Workspace (verlinkt über `SAP_ABAPLINT_CONFIG` in `~/.config/arc-1/.env`). Basis: ARC-1-Preset `onprem`; zusätzlich `no_prefixes`; `errorNamespace` auf eigene Objekte beschränkt, damit abapGit-Typen als void gelten.
2. Nach Aktivierung `SAPDiagnose`: Syntax, ABAP Unit, ATC.
3. ATC immer explizit mit Variante `DEFAULT` (Systemvorgabe `ZABAP_CLOUD_DEVELOPMENT` ist für klassisches ABAP ungeeignet), Timeout 600 s, blockierend nur Priorität 1 und 2. Ein unvollständiger ATC-Lauf gilt nicht als bestanden und wird gemeldet.
4. Danach manueller Test gegen ein GitHub-Testrepository mit mindestens einer Datei.

*Umsetzung:*
- `abaplint.jsonc` aktiviert alle Preset-Regeln plus die 25 im Preset abgeschalteten, mit vollständiger Standardkonfiguration je Regel (abaplint ergänzt fehlende Optionen nicht). Namensregeln verbieten Präfixe, statt sie zu verlangen. `description_empty` bleibt aus (benötigt die Klassen-XML, die ARC-1 nicht übergibt). `errorNamespace` umfasst nur lokale Präfixe.
- ARC-1 lintet jede Quelle einzeln. Verweise auf andere eigene Objekte (Oberklassen, implementierte Interfaces, das abapGit-Include) melden `check_syntax`, `implement_methods`, `superclass_final` und `unused_types` daher zwangsläufig als Fehler. Diese Meldungen werden bei der Auswertung ignoriert; Testklassen-Includes werden als Programm gelintet. Geschrieben wird mit `lintBeforeWrite = false`; maßgeblich ist die anschließende SAP-Aktivierung.
- `SAP_ALLOWED_PACKAGES=$TMP,$ZABAPMONOREPO,$ZMONO_DEMO*` in `~/.config/arc-1/.env`.
- ATC-Restbefunde (Priorität 3): nicht übersetzbare Literale im PR-Text (bewusst Englisch) und im eingebundenen abapGit-Include. Der Zugriff auf `TDEVC` mit Range erfolgt explizit `BYPASSING BUFFER`.

## 10. Testdaten

Lokale Testpakete mit Demo-Klassen für den manuellen Test:

| Paket | Oberpaket | Zweck |
| --- | --- | --- |
| `$ZMONO_DEMO_APP` | – | Komponente mit Unterpaketbaum |
| `$ZMONO_DEMO_APP_CORE` | `$ZMONO_DEMO_APP` | Unterpaket |
| `$ZMONO_DEMO_APP_CORE_UTIL` | `$ZMONO_DEMO_APP_CORE` | Beispiel aus F-016 (PREFIX `core/util/`, FULL `zmono_demo_app_core/zmono_demo_app_core_util/`, MIXED `core/core_util/`) |
| `$ZMONO_DEMO_APP_UI` | `$ZMONO_DEMO_APP` | Unterpaket |
| `$ZMONO_DEMO_LIB` | – | Komponente mit Interface im Unterpaket |
| `$ZMONO_DEMO_LIB_API` | `$ZMONO_DEMO_LIB` | Unterpaket |
| `$ZMONO_DEMO_TOOL` | – | Komponente ohne Unterpakete |
| `$ZMONO_DEMO_MISC` | – | Komponente mit Präfixverstoß |
| `$ZMONO_DEMO_FOREIGN` | `$ZMONO_DEMO_MISC` | scheitert bei PREFIX/MIXED, funktioniert bei FULL |
| `$ZMONO_DEMO_EMPTY` | – | Komponente ohne Objekte |

Die Pfade aus F-016 und das Fehlverhalten von `$ZMONO_DEMO_FOREIGN` wurden mit einem temporären Integrationstest gegen die echten abapGit-APIs bestätigt.

## 11. Offene Risiken

- Exakter GitHub-Fehlertext bei Non-Fast-Forward ist ungetestet.
- ATC-Laufzeit auf dem System: Ein Probelauf war nach 120 s noch nicht abgeschlossen.
- Abhängigkeit von internen, nicht freigegebenen abapGit-APIs; durch die Gateways gekapselt.
