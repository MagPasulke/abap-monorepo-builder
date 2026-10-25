# Funktionale Spezifikation: ABAP-Pakete in ein Git-Monorepo übernehmen

**Status:** Offen  
**Stand:** Ergebnis der funktionalen Grill-me-Session; ergänzt um die Entscheidungen der technischen Session (siehe `specs/technical.md`).  
**Umsetzung:** Noch nicht begonnen.

## 1. Ziel und Rahmen

### F-001 – SAP-GUI-Report
**Status:** Offen

Ein einfacher SAP-GUI-Report übernimmt vorhandene ABAP-Pakete und ihre Objekte in ein gemeinsames Git-Monorepo. Im SAP-System entsteht pro Komponente ein separates abapGit-Repository; alle verwenden dieselbe Remote-URL.

### F-002 – Entwicklungsrahmen
**Status:** Offen

Die Entwicklung erfolgt mittels ARC-1 auf dem lokalen SAP-System. Vor der technischen Session installiert der Anwender die abapGit Developer Edition. Die funktionale Spezifikation legt noch keine konkrete API- oder Implementierungslösung fest.

### F-003 – Vorhandene SAP-Inhalte
**Status:** Offen

Die ausgewählten Pakete, Unterpakete und ABAP-Objekte existieren bereits. Der Report legt keine neuen ABAP-Pakete oder Fachobjekte an und verändert deren fachlichen Inhalt nicht.

## 2. Eingaben

### F-004 – ABAP-Pakete
**Status:** Offen

Die Paketauswahl ist obligatorisch und erfolgt über Select-Options. Einzelwerte, Wildcards, Intervalle und Ausschlüsse werden unterstützt.

### F-005 – Git-URL
**Status:** Offen

Die Git-URL ist obligatorisch. Das Remote-Repository muss bereits existieren und mindestens eine Datei enthalten. Der Report legt kein Remote-Repository an.

### F-006 – Folder Logic
**Status:** Offen

Die Folder Logic ist obligatorisch. Zur Auswahl stehen die abapGit-Varianten PREFIX, FULL und MIXED.

### F-007 – Top Folder
**Status:** Offen

Top Folder ist optional und bezeichnet einen relativen Pfad im Remote. Mehrere Pfadebenen, beispielsweise `abap/backend`, sind zulässig. Absolute Pfade und übergeordnete Pfadsegmente (`..`) sind unzulässig.

## 3. Auswahl und Komponentenbildung

### F-008 – Vollständiger Paketbaum
**Status:** Offen

Jedes als Komponentenwurzel ausgewählte Paket wird einschließlich seines vollständigen Unterpaketbaums verarbeitet.

### F-009 – Überlappende Auswahl
**Status:** Offen

Nach Auflösung der gesamten Select-Options-Auswahl werden doppelte Treffer zusammengefasst. Sind ein Oberpaket und dessen Unterpakete ausgewählt, wird nur das oberste ausgewählte Paket als Komponentenwurzel verarbeitet. Die Zusammenfassung wird im Ergebnis kenntlich gemacht.

### F-010 – Bedeutung von Ausschlüssen
**Status:** Offen

Ausschlüsse beeinflussen nur die Auswahl der Komponentenwurzeln, nicht den Inhalt eines ausgewählten Paketbaums. Beispiel: Wird `ZAPP` ausgewählt und sein Unterpaket `ZAPP_TEST` ausgeschlossen, bleibt `ZAPP_TEST` Bestandteil der Komponente `ZAPP`.

### F-011 – Auswahl ohne Treffer
**Status:** Offen

Enthält die aufgelöste Auswahl keine vorhandenen Pakete, endet der Report mit einer deutlichen Ausgabe und ohne Änderungen, Branch oder PR. Nicht vorhandene Namen innerhalb einer ansonsten gültigen Auswahl verhindern die Verarbeitung vorhandener Pakete nicht.

### F-012 – Bestehende abapGit-Zuordnungen
**Status:** Offen

Ist eine Komponentenwurzel bereits einem abapGit-Repository zugeordnet oder überschneidet sich ihr Paketbaum mit einer bestehenden Repository-Zuordnung, wird die betroffene Komponente mit Fehlermeldung übersprungen. Bestehende Zuordnungen werden nicht verändert. Andere Komponenten werden weiterverarbeitet.

## 4. Ordnerstruktur

### F-013 – Startordner pro Komponente
**Status:** Offen

Der Startordner eines lokalen abapGit-Repositories lautet `/topFolder/component/src/`. Ohne Top Folder lautet er `/component/src/`.

### F-014 – Komponentenname
**Status:** Offen

Der Komponentenname wird aus dem vollständigen Top-Level-Paketnamen nach der vereinbarten FULL-nahen Namensnormalisierung gebildet: Ein führendes `$` entfällt, Namespace-Trennzeichen `/` werden durch `#` ersetzt und der Name wird kleingeschrieben.

| Root-Paket | Komponentenordner |
| --- | --- |
| `ZAPP` | `zapp` |
| `/ACME/APP` | `#acme#app` |
| `$APP` | `app` |

Diese Regel ist eine ausdrücklich vereinbarte Ableitung für den Komponentenordner, nicht die automatische Abbildung des Root-Pakets durch die abapGit Folder Logic.

### F-015 – Kollision von Komponentenpfaden
**Status:** Offen

Ergeben mehrere ausgewählte Komponenten denselben Komponentenpfad, werden alle betroffenen Komponenten als fehlerhaft übersprungen. Es gibt keine automatische Umbenennung oder Zusammenführung.

### F-016 – Unterpaketpfade
**Status:** Offen

Die gewählte Folder Logic steuert die Unterpaketpfade unterhalb des Startordners. Das Root-Paket selbst liegt direkt im Startordner. Die tatsächliche Paket-Elternbeziehung bestimmt die Ordnerhierarchie.

- **PREFIX:** Für ein Unterpaket wird der Namenspräfix des unmittelbaren Elternpakets entfernt. Fehlt dieser Präfix, entsteht ein Fehler.
- **FULL:** Der vollständige Unterpaketname bildet das Ordnersegment; ein führendes `$` entfällt.
- **MIXED:** Für jedes Unterpaket wird der Namenspräfix des Root-Pakets entfernt. Fehlt dieser Präfix, entsteht ein Fehler.

Die weitere Normalisierung der Unterpaketsegmente richtet sich nach abapGit. Es wird keine eigene alternative Folder Logic implementiert.

Beispiel für `ZAPP → ZAPP_CORE → ZAPP_CORE_UTIL`, jeweils relativ zum Startordner:

| Folder Logic | Unterpaketpfad |
| --- | --- |
| PREFIX | `core/util/` |
| FULL | `zapp_core/zapp_core_util/` |
| MIXED | `core/core_util/` |

## 5. Branch, Repository-Anlage und Veröffentlichung

### F-017 – Gemeinsamer Arbeitsbranch
**Status:** Offen

Pro Lauf wird ein neuer, eindeutig benannter Arbeitsbranch verwendet. Basis und PR-Ziel ist der Default-Branch des Remotes. Es erfolgt kein direkter Push auf den Default-Branch.

### F-018 – Offline-Anlage und Online-Umstellung
**Status:** Offen

Pro Komponente wird zunächst ein Offline-Repository angelegt. Anschließend werden Startordner und Folder Logic gesetzt und das Repository auf ein Online-Repository mit gemeinsamer Remote-URL und gemeinsamem Arbeitsbranch umgestellt.

### F-019 – Inhalte übertragen
**Status:** Offen

Die vorhandenen ABAP-Inhalte der Komponenten werden über abapGit in den gemeinsamen Arbeitsbranch übertragen. Git-Handling erfolgt über abapGit-APIs; die unterstützten Git-Anbieter richten sich nach abapGit, nicht nach einer eigenen Anbieterliste des Reports.

*Ergänzung technische Session:* Übertragen werden nur neue und geänderte Dateien. Dateien, die nur im Remote innerhalb des Komponentenordners existieren, werden nicht gelöscht; ihre Anzahl wird in der Ergebnisliste ausgewiesen. Objekte, die abapGit nicht serialisieren kann, führen zu einem Teilerfolg der Komponente.

### F-020 – Keine eigene Git-Konfliktbehandlung
**Status:** Offen

Der Report verwendet das reguläre Push-Verhalten von abapGit. Er führt weder Force-Pushes noch eine automatische Konfliktauflösung aus. Abgewiesene Pushes werden protokolliert; die Konfliktbehandlung übernimmt der Anwender in Git. Ein bereits vorhandener Komponentenordner im Remote ist allein kein Grund, eine Komponente zu überspringen. Eine gesonderte Aktualisierungs- oder Konfliktstrategie gehört nicht zum Umfang.

### F-021 – Ein gemeinsamer PR
**Status:** Offen

Pro Lauf entsteht genau ein gemeinsamer PR für die erfolgreich übertragenen Änderungen. Fehlgeschlagene Komponenten werden nicht als erfolgreich übernommen ausgewiesen. Sind keine Komponenten erfolgreich oder entstehen keine Git-Änderungen, wird kein PR erstellt.

*Ergänzung technische Session:* Automatische PR-Erstellung gibt es nur für `github.com`. Bei anderen Anbietern (einschließlich GitHub Enterprise Server) werden Repositories, Arbeitsbranch und Push wie bei GitHub ausgeführt, aber kein PR erstellt. Der Lauf gilt dann als Teilerfolg; die Ausgabe nennt den Branch mit dem Hinweis, den PR manuell anzulegen.

### F-022 – PR-Inhalt und Freigabe
**Status:** Offen

Der PR wird normal, nicht als Draft, angelegt. Titel und Beschreibung werden automatisch erzeugt. Die Beschreibung fasst erfolgreiche, fehlgeschlagene und übersprungene Komponenten zusammen. Reviewer-Zuweisung, Review, Freigabe und Merge erfolgen manuell. Der Report führt keinen Merge durch.

### F-023 – Zustand nach PR-Erstellung
**Status:** Offen

Die lokalen abapGit-Repositories bleiben nach dem Lauf auf dem Arbeitsbranch. Der Report wartet nicht auf den Merge und überwacht ihn nicht. Nach dem Merge stellt der Anwender die Repositories selbst auf den Default-Branch um.

### F-024 – Dauerhafte getrennte Nutzung
**Status:** Offen

Die getrennten lokalen Repositories müssen auch nach dem Merge dauerhaft für ihre jeweilige Komponente nutzbar sein, einschließlich Status, Pull und Push. Eine nur einmalig korrekte PR-Erstellung reicht nicht aus.

*Ergänzung technische Session:* Startordner und Folder Logic werden nur in den lokalen abapGit-Repositories gehalten; die Datei `/.abapgit.xml` im Remote wird vom Report weder gelesen noch geschrieben. Wer das Monorepo auf einem anderen System verbindet, muss Startordner, Folder Logic und den Ausschluss von `/.abapgit.xml` dort selbst setzen.

## 6. Fehler und Teilerfolge

### F-025 – Komponentenbezogene Fehler
**Status:** Offen

Der Lauf verarbeitet, was möglich ist. Ein komponentenbezogener Fehler verhindert nicht die Verarbeitung anderer Komponenten. Gemeinsame Fehler, beispielsweise ein nicht erreichbares Remote, können die weitere Veröffentlichung verhindern.

### F-026 – Keine automatische Rücknahme
**Status:** Offen

Bereits angelegte lokale Repositories und erfolgreiche Git-Schritte bleiben bei späteren Fehlern bestehen. Das gilt auch, wenn die Online-Umstellung oder der Push einer Komponente scheitert. Der erreichte Zustand wird ausgegeben; eine Bereinigung erfolgt manuell.

### F-027 – PR-Erstellung schlägt fehl
**Status:** Offen

Sind Änderungen bereits gepusht, aber die PR-Erstellung scheitert, bleiben Branch, Änderungen und lokale Repositories erhalten. Die Ausgabe nennt Branch und Fehler, damit der Anwender den PR manuell erstellen kann. Ein Push ohne erforderlichen PR ist kein vollständig erfolgreicher Gesamtlauf.

### F-028 – Keine automatische Wiederaufnahme
**Status:** Offen

Eine automatische Wiederaufnahme früherer Läufe gehört nicht zum Umfang. Ein erneuter Lauf überspringt bereits zugeordnete Pakete gemäß F-012. Manuelle Bereinigung oder Fortsetzung liegt beim Anwender.

## 7. Ausgabe und Anmeldung

### F-029 – Einfache Ergebnisliste
**Status:** Offen

Am Ende wird eine einfache, farbige WRITE-Ausgabe angezeigt. Pro Komponente enthält sie Paket, Komponentenpfad, erreichten Verarbeitungsschritt, Erfolg beziehungsweise Fehler oder Überspringen sowie eine verständliche Begründung. Auch Teilerfolge und bestehende Zuordnungen sind erkennbar.

### F-030 – Zusammenfassung
**Status:** Offen

Die Ausgabe enthält eine Zusammenfassung sowie den Arbeitsbranch und, falls erstellt, den PR-Link. Eine persistente Laufhistorie oder zusätzliche Protokollverwaltung ist nicht vorgesehen.

### F-031 – Authentifizierung und Zugangsdaten
**Status:** Offen

Die Anmeldung erfolgt über abapGit-APIs. Zugangsdaten werden nicht als Reportparameter, in Varianten oder im Protokoll gespeichert. Fehlende Berechtigungen werden als verständlicher Fehler des betroffenen Schritts ausgegeben.

*Ergänzung technische Session:* Die Anmeldung erfolgt über das Login-Popup von abapGit (Benutzer und Passwort bzw. Personal Access Token) zu Beginn des Laufs. Der Report ist deshalb nur im Dialog ausführbar; ein Start im Hintergrund wird mit einer Meldung abgelehnt.

## 8. Noch technisch nachzuweisen

### F-032 – APIs der Developer Edition
**Status:** Offen

Nach Installation der abapGit Developer Edition sind die API-Unterstützung für den gesamten Ablauf einschließlich PR-Erstellung sowie die dauerhafte Trennung mehrerer Komponenten bei gleicher Remote-URL zu prüfen. Die funktionalen Anforderungen sind dadurch noch nicht technisch bestätigt. Fehlende PR-Unterstützung darf nicht stillschweigend durch einen reinen Push ersetzt werden.

Die lesende Vorprüfung der bisherigen Standalone-Version 1.128.0 belegte Branch-Erstellung und Push, aber keine PR-Erstellung. Außerdem wurde ein möglicher Konflikt zwischen gemeinsamer Remote-Konfiguration `/.abapgit.xml` und unterschiedlichen lokalen Startordnern gefunden. Diese Befunde sind keine Aussage über die noch zu installierende Developer Edition.

*Ergebnis technische Session (Developer Edition, lesend geprüft):* Branch-Anlage und Push sind über abapGit-APIs möglich. Eine PR-Erstellung bietet abapGit nur rudimentär für GitHub (immer als Entwurf, ohne Rückgabe des Links); der Report erstellt den PR daher mit eigenem Code auf Basis der HTTP-, Anmelde- und JSON-Bausteine von abapGit (T-026). Der `/.abapgit.xml`-Konflikt wird über die lokale abapGit-Einstellung `exclude_remote_paths` gelöst (T-023). Der Nachweis gegen ein echtes Remote steht noch aus.

## 9. Vom Anwender genannter Umgebungskontext

Die folgenden Angaben dokumentieren die genannte Umgebung; daraus ergibt sich keine zusätzliche Kompatibilitätszusage:

```text
SAP GUI for Java 8.10 rev 8
Version ID: 081000040800
2025-11-04 20:13:25 +0000
ccde1gl0559, 810_REL, 2287085
Java VM: SAP SE Version 21.0.9+10-LTS
OS: Linux(amd64) Version 7.0.0-38-generic
```
