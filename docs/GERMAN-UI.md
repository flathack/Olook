# Deutsche Olook-Oberfläche

`ui/I18n.js` enthält eine lokale deutsche Übersetzungstabelle für Darstellungstexte. Die QML-Komponenten verwenden `I18n.tr(...)` für Menüs, Beschriftungen, Hinweise und Fehlermeldungen. Nicht bekannte Texte fallen auf ihren ursprünglichen Wert zurück. Die gemeinsamen Datums-/Ordnerhelfer zeigen deutsche Namen.

Die Übersetzung macht keine Netzwerkaufrufe und verändert keine Mailinhalte, Mailheader, Konto-IDs, Server-Ordnerpfade oder Befehlsnamen. Bei Erweiterungen dürfen Darstellungstexte nicht mit Protokollwerten verwechselt werden; insbesondere bleiben `To`, `Cc` und `Subject` als Header-Schlüssel unverändert.

Die deutschen Dateien wurden auf Petras ThinkPad installiert und in der echten Oberfläche geprüft. Dazu bestehen die Service-/Interaktionstests und die Privacy-Tests. Änderungen an der vollständigen Mailansicht benötigen nach Installation einen Neustart der Omarchy-Shell.
