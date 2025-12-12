-- Schema SQL pour les tables spécifiques Flutter
-- Ces tables sont créées localement et ne sont pas dans le fichier téléchargé

CREATE TABLE IF NOT EXISTS app_settings (
        id INTEGER PRIMARY KEY DEFAULT 1,
        theme_mode TEXT DEFAULT 'system',
        update_frequency TEXT DEFAULT 'daily',
        bdpm_version TEXT,
        last_sync_epoch INTEGER,
        source_hashes TEXT DEFAULT '{}',
        source_dates TEXT DEFAULT '{}',
        haptic_feedback_enabled BOOLEAN DEFAULT 1,
        preferred_sorting TEXT DEFAULT 'princeps',
        scan_history_limit INTEGER DEFAULT 100
      );

CREATE TABLE IF NOT EXISTS restock_items (
        cip TEXT PRIMARY KEY NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        is_checked BOOLEAN NOT NULL DEFAULT 0,
        added_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      );
CREATE INDEX IF NOT EXISTS idx_restock_added ON restock_items(added_at);

CREATE TABLE IF NOT EXISTS scanned_boxes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cip TEXT NOT NULL,
        serial_number TEXT,
        batch_number TEXT,
        expiry_date INTEGER,
        scanned_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        UNIQUE(cip, serial_number)
      );
CREATE INDEX IF NOT EXISTS idx_unique_box ON scanned_boxes(cip, serial_number);
