import Foundation

/// App strings. The language follows the Mac's, with English as the fallback.
enum L {
    static let lang: String = {
        for pref in Locale.preferredLanguages {
            let code = pref.lowercased()
            if code.hasPrefix("zh") { return "zh" }
            let short = String(code.prefix(2))
            if table[short] != nil { return short }
        }
        return "en"
    }()

    /// Dates follow the same language as the rest of the app.
    static var locale: Locale { Locale(identifier: Locale.preferredLanguages.first ?? "en") }

    static func t(_ key: String) -> String { table[lang]?[key] ?? table["en"]?[key] ?? key }
    static func f(_ key: String, _ args: CVarArg...) -> String { String(format: t(key), arguments: args) }

    static let table: [String: [String: String]] = [
        "en": [
            "card.session": "Current Session", "card.weekly": "Weekly Limit (All Models)",
            "reset.done": "Reset done", "reset.minutes": "Resets in %dm",
            "reset.hours": "Resets in %dh %dm", "reset.at": "Resets %@", "nodata": "No data yet",
            "updated.waiting": "Waiting for data", "updated.now": "Updated just now",
            "updated.minutes": "Updated %dm ago", "updated.hours": "Updated %dh ago", "updated.days": "Updated %dd ago",
            "refresh": "Refresh", "refresh.failed": "Refresh failed", "cli.missing": "Claude Code not found",
            "status.ok": "Operational", "status.unknown": "Unknown", "quit": "Quit",
            "settings": "Settings", "settings.session": "Show session usage", "settings.weekly": "Show weekly usage",
            "settings.mod": "Show usage in Claude Code",
            "settings.mod.help": "Adds a usage line under the prompt, for new Claude Code sessions.",
            "settings.login": "Launch at login", "donate": "Support the project ♥",
            "update": "Claude Code v%@ → v%@ available",
            "mod.session": "Session", "mod.week": "Week",
        ],
        "fr": [
            "card.session": "Session en cours", "card.weekly": "Limite hebdo (tous modèles)",
            "reset.done": "Réinitialisée", "reset.minutes": "Réinitialisation dans %d min",
            "reset.hours": "Réinitialisation dans %d h %d min", "reset.at": "Réinitialisation %@", "nodata": "Pas encore de données",
            "updated.waiting": "En attente de données", "updated.now": "À l'instant",
            "updated.minutes": "Il y a %d min", "updated.hours": "Il y a %d h", "updated.days": "Il y a %d j",
            "refresh": "Actualiser", "refresh.failed": "Échec de l'actualisation", "cli.missing": "Claude Code introuvable",
            "status.ok": "Opérationnel", "status.unknown": "Inconnu", "quit": "Quitter",
            "settings": "Réglages", "settings.session": "Afficher l'usage de la session", "settings.weekly": "Afficher l'usage de la semaine",
            "settings.mod": "Afficher l'usage dans Claude Code",
            "settings.mod.help": "Ajoute une ligne d'usage sous la zone de saisie, pour les nouvelles sessions de Claude Code.",
            "settings.login": "Lancer au démarrage", "donate": "Soutenir le projet ♥",
            "update": "Claude Code v%@ → v%@ disponible",
            "mod.session": "Session", "mod.week": "Semaine",
        ],
        "es": [
            "card.session": "Sesión actual", "card.weekly": "Límite semanal (todos los modelos)",
            "reset.done": "Restablecido", "reset.minutes": "Se restablece en %d min",
            "reset.hours": "Se restablece en %d h %d min", "reset.at": "Se restablece %@", "nodata": "Aún no hay datos",
            "updated.waiting": "Esperando datos", "updated.now": "Ahora mismo",
            "updated.minutes": "Hace %d min", "updated.hours": "Hace %d h", "updated.days": "Hace %d d",
            "refresh": "Actualizar", "refresh.failed": "Error al actualizar", "cli.missing": "Claude Code no encontrado",
            "status.ok": "Operativo", "status.unknown": "Desconocido", "quit": "Salir",
            "settings": "Ajustes", "settings.session": "Mostrar uso de la sesión", "settings.weekly": "Mostrar uso semanal",
            "settings.mod": "Mostrar uso en Claude Code",
            "settings.mod.help": "Añade una línea de uso bajo el campo de texto, para las nuevas sesiones de Claude Code.",
            "settings.login": "Abrir al iniciar sesión", "donate": "Apoyar el proyecto ♥",
            "update": "Claude Code v%@ → v%@ disponible",
            "mod.session": "Sesión", "mod.week": "Semana",
        ],
        "it": [
            "card.session": "Sessione corrente", "card.weekly": "Limite settimanale (tutti i modelli)",
            "reset.done": "Azzerato", "reset.minutes": "Si azzera tra %d min",
            "reset.hours": "Si azzera tra %d h %d min", "reset.at": "Si azzera %@", "nodata": "Nessun dato",
            "updated.waiting": "In attesa di dati", "updated.now": "Proprio ora",
            "updated.minutes": "%d min fa", "updated.hours": "%d h fa", "updated.days": "%d g fa",
            "refresh": "Aggiorna", "refresh.failed": "Aggiornamento non riuscito", "cli.missing": "Claude Code non trovato",
            "status.ok": "Operativo", "status.unknown": "Sconosciuto", "quit": "Esci",
            "settings": "Impostazioni", "settings.session": "Mostra uso della sessione", "settings.weekly": "Mostra uso settimanale",
            "settings.mod": "Mostra uso in Claude Code",
            "settings.mod.help": "Aggiunge una riga di utilizzo sotto il campo di testo, per le nuove sessioni di Claude Code.",
            "settings.login": "Apri all'avvio", "donate": "Sostieni il progetto ♥",
            "update": "Claude Code v%@ → v%@ disponibile",
            "mod.session": "Sessione", "mod.week": "Settimana",
        ],
        "de": [
            "card.session": "Aktuelle Sitzung", "card.weekly": "Wochenlimit (alle Modelle)",
            "reset.done": "Zurückgesetzt", "reset.minutes": "Zurücksetzung in %d Min.",
            "reset.hours": "Zurücksetzung in %d Std. %d Min.", "reset.at": "Zurücksetzung %@", "nodata": "Noch keine Daten",
            "updated.waiting": "Warte auf Daten", "updated.now": "Gerade eben",
            "updated.minutes": "Vor %d Min.", "updated.hours": "Vor %d Std.", "updated.days": "Vor %d T.",
            "refresh": "Aktualisieren", "refresh.failed": "Aktualisierung fehlgeschlagen", "cli.missing": "Claude Code nicht gefunden",
            "status.ok": "In Betrieb", "status.unknown": "Unbekannt", "quit": "Beenden",
            "settings": "Einstellungen", "settings.session": "Sitzungsnutzung anzeigen", "settings.weekly": "Wochennutzung anzeigen",
            "settings.mod": "Nutzung in Claude Code anzeigen",
            "settings.mod.help": "Fügt unter dem Eingabefeld eine Nutzungszeile hinzu, für neue Claude-Code-Sitzungen.",
            "settings.login": "Bei Anmeldung starten", "donate": "Projekt unterstützen ♥",
            "update": "Claude Code v%@ → v%@ verfügbar",
            "mod.session": "Sitzung", "mod.week": "Woche",
        ],
        "pt": [
            "card.session": "Sessão atual", "card.weekly": "Limite semanal (todos os modelos)",
            "reset.done": "Reiniciado", "reset.minutes": "Reinicia em %d min",
            "reset.hours": "Reinicia em %d h %d min", "reset.at": "Reinicia %@", "nodata": "Ainda sem dados",
            "updated.waiting": "Aguardando dados", "updated.now": "Agora mesmo",
            "updated.minutes": "Há %d min", "updated.hours": "Há %d h", "updated.days": "Há %d d",
            "refresh": "Atualizar", "refresh.failed": "Falha ao atualizar", "cli.missing": "Claude Code não encontrado",
            "status.ok": "Operacional", "status.unknown": "Desconhecido", "quit": "Encerrar",
            "settings": "Ajustes", "settings.session": "Mostrar uso da sessão", "settings.weekly": "Mostrar uso semanal",
            "settings.mod": "Mostrar uso no Claude Code",
            "settings.mod.help": "Adiciona uma linha de uso abaixo do campo de texto, para novas sessões do Claude Code.",
            "settings.login": "Abrir ao iniciar sessão", "donate": "Apoiar o projeto ♥",
            "update": "Claude Code v%@ → v%@ disponível",
            "mod.session": "Sessão", "mod.week": "Semana",
        ],
        "zh": [
            "card.session": "当前会话", "card.weekly": "每周限额（所有模型）",
            "reset.done": "已重置", "reset.minutes": "%d 分钟后重置",
            "reset.hours": "%d 小时 %d 分钟后重置", "reset.at": "%@ 重置", "nodata": "暂无数据",
            "updated.waiting": "正在等待数据", "updated.now": "刚刚更新",
            "updated.minutes": "%d 分钟前更新", "updated.hours": "%d 小时前更新", "updated.days": "%d 天前更新",
            "refresh": "刷新", "refresh.failed": "刷新失败", "cli.missing": "未找到 Claude Code",
            "status.ok": "运行正常", "status.unknown": "未知", "quit": "退出",
            "settings": "设置", "settings.session": "显示会话用量", "settings.weekly": "显示每周用量",
            "settings.mod": "在 Claude Code 中显示用量",
            "settings.mod.help": "在输入框下方添加一行用量信息，适用于新的 Claude Code 会话。",
            "settings.login": "登录时启动", "donate": "支持本项目 ♥",
            "update": "Claude Code v%@ → v%@ 可用",
            "mod.session": "会话", "mod.week": "本周",
        ],
        "ja": [
            "card.session": "現在のセッション", "card.weekly": "週間上限（全モデル）",
            "reset.done": "リセット済み", "reset.minutes": "%d 分後にリセット",
            "reset.hours": "%d 時間 %d 分後にリセット", "reset.at": "%@ にリセット", "nodata": "データなし",
            "updated.waiting": "データを待機中", "updated.now": "たった今更新",
            "updated.minutes": "%d 分前に更新", "updated.hours": "%d 時間前に更新", "updated.days": "%d 日前に更新",
            "refresh": "更新", "refresh.failed": "更新に失敗", "cli.missing": "Claude Code が見つかりません",
            "status.ok": "正常稼働中", "status.unknown": "不明", "quit": "終了",
            "settings": "設定", "settings.session": "セッション使用量を表示", "settings.weekly": "週間使用量を表示",
            "settings.mod": "Claude Code に使用量を表示",
            "settings.mod.help": "入力欄の下に使用量の行を追加します（新しい Claude Code セッションに適用）。",
            "settings.login": "ログイン時に起動", "donate": "プロジェクトを支援 ♥",
            "update": "Claude Code v%@ → v%@ が利用可能",
            "mod.session": "セッション", "mod.week": "週間",
        ],
    ]
}
