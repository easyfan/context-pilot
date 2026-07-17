# context-pilot

**Safe-to-forget-Protokoll für das Claude-Code-Kontextfenster.**

[English](README.md) | [中文](README-zh.md) | [Français](README-fr.md) | [Русский](README-ru.md)

`/clear, dann mach weiter mit X` ist eine Anweisung, die kein Modell
ausführen kann: Der Kontext, der sie ausspricht, wird von ihr selbst
zerstört. context-pilot kompiliert diese unaussprechbare Anweisung in drei
Harness-Schritte — vor dem Clear ein selbstgenügsames Handoff schreiben,
den Menschen `/clear` drücken lassen, danach das Handoff automatisch in die
kalte Session einspeisen. Ergebnis: Eine lange Session überquert einen
Kontext-Wipe **verlustfrei**, statt einen fetten Kontext (eine Token-Steuer
pro Runde) mitzuschleppen oder auf verlustbehaftetes Auto-Compact
zurückzufallen.

Schwester-Plugin von [quota-pilot](https://github.com/easyfan/quota-pilot):
quota-pilot parkt eine Session über ein Rate-Limit-Fenster (Winterschlaf);
context-pilot trägt eine Session über einen Kontext-Wipe (Amnesie mit Brief
an sich selbst). Entscheidender Unterschied: quota-pilots Checkpoint ist
eine Versicherung, context-pilots Handoff ist das **gesamte Gedächtnis**
der nächsten Session — deshalb hat sein Gate Vetorecht.

## Komponenten

| Komponente | Funktion |
|---|---|
| **Skill** (`context-pilot`) | Das Schreibseiten-Protokoll: Entscheidungsregel (weiterarbeiten / clear / compact), Sechs-Komponenten-Audit für alles, was nur im Gespräch lebt, Kaltleser-Schreibregeln und ein Selbstgenügsamkeits-Gate mit Vetorecht. |
| **Befehl** (`/clear-then <nächster Schritt>`) | Führt das Protokoll mit explizit gegebenem nächsten Schritt aus und übergibt dann die `/clear`-Taste an dich. |
| **SessionStart-Hook** (`context_deliver.sh`) | Source-agnostische Zustellung: Nach `/clear` (Stock-Claude *oder* happy-App) wird ein frisches `context-handoff.md` mit Kaltleser-Präambel injiziert und danach konsumiert (umbenannt). |
| **PostToolUse-Hook** (`context_sample.sh`) | Sampling: beobachtet die Kontextauslastung; ab 70 % (konfigurierbar) wird ein Grenz-Evaluierungsalarm injiziert, höchstens einmal pro Cooldown. |

## Die Entscheidungsregel

Drei Eingaben: **t** (verbleibende Arbeit), **H** (nötige Handoff-Größe),
**N** (Abstand zur Decke — nur Dringlichkeit).

- **t klein** → einfach fertig machen; jeder Transfer ist Overhead.
- **Selbstgenügsamkeit unerreichbar** → **nicht** clearen; bis zu einer
  echten Grenze arbeiten oder Auto-Compact akzeptieren.
- **Gate besteht, H klein** → Handoff schreiben, `/clear` einladen.
- **Grauzone** → Compact. Compact versagt *weich* (das Modell spürt die
  Lücke und kann nachlesen); ein schlechtes Clear versagt *still* (die neue
  Session weiß nicht, was sie nicht weiß).

Das Handoff erfasst per Audit: Ziel, konkreter nächster Schritt,
**Entscheidungen inkl. explizit verworfener Alternativen**, Fallstricke,
ehrlichen unverifizierten Zustand, mündliche Nutzer-Constraints — plus eine
Session-Karte auf das alte Transcript (das den Clear auf der Platte
überlebt). Zeiger, nie kopierter Inhalt.

## Installation

Als Plugin:

```
/plugin marketplace add easyfan/context-pilot
/plugin install context-pilot@context-pilot
```

Manuell:

```bash
git clone https://github.com/easyfan/context-pilot.git
cd context-pilot && ./install.sh          # --dry-run Vorschau, --uninstall Entfernen
```

## Konfiguration

Optionale `~/.claude/context-pilot/config.json`:

```json
{
  "context_window": 200000,
  "warn_pct": 70,
  "cooldown_minutes": 15,
  "check_seconds": 60
}
```

> **Hinweis für Modelle mit 1M-Fenster:** `context_window` ist standardmäßig `200000`. Wenn Ihr Modell ein Kontextfenster von 1M Tokens hat (z. B. `[1m]`-Modell-IDs), setzen Sie den Wert auf `1000000` — mit dem Standardwert werden Warnungen viel zu früh ausgelöst und können eine Auslastung über 100 % melden.

Zustellungs-Frischefenster: `CONTEXT_PILOT_FRESH_SECONDS`, Standard 900.

## Dateien

```
skills/context-pilot/SKILL.md   das Protokoll
commands/clear-then.md          /clear-then
hooks/context_deliver.sh        SessionStart-Zustellung (consume-once)
hooks/context_sample.sh         PostToolUse-Sampling
hooks/hooks.json                Plugin-Hook-Registrierung
install.sh                      manueller Installer
evals/evals.json                Verhaltens-Evalset (+26pp vs. ohne Skill)
```

## Lizenz

MIT
