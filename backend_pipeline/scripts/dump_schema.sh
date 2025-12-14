#!/bin/bash

# Script pour dumper le schéma de la base de données vers Flutter
# Utilise sqlite3 CLI pour générer un schéma propre et compatible Drift

set -e

# Chemins
DB_PATH="data/reference.db"
FLUTTER_SCHEMA_PATH="../lib/core/database/reference_schema.drift"
BACKUP_DIR="schema_backups"

# Créer le répertoire de backup si nécessaire
mkdir -p "$BACKUP_DIR"

# Vérifier que la base de données existe
if [ ! -f "$DB_PATH" ]; then
    echo "❌ Database file not found: $DB_PATH"
    echo "Run 'bun run build' first to generate the database"
    exit 1
fi

echo "🔍 Dumping schema from: $DB_PATH"
echo "📝 Writing Flutter schema to: $FLUTTER_SCHEMA_PATH"

# Backup existing schema if it exists
if [ -f "$FLUTTER_SCHEMA_PATH" ]; then
    backup_file="$BACKUP_DIR/reference_schema_$(date +%Y%m%d_%H%M%S).drift"
    cp "$FLUTTER_SCHEMA_PATH" "$backup_file"
    echo "💾 Backed up existing schema to: $backup_file"
fi

# Créer le fichier de schéma Drift
cat > "$FLUTTER_SCHEMA_PATH" << 'EOF'
-- REFERENCE SCHEMA - Tables de référence générées par le backend TypeScript
-- Ces tables sont importées depuis la base de données reference.db
-- Généré automatiquement par scripts/dump_schema.sh

EOF

# Utiliser sqlite3 pour dumper les tables et indexes
echo "-- Tables:" >> "$FLUTTER_SCHEMA_PATH"
sqlite3 "$DB_PATH" ".mode list" ".headers off" "SELECT sql || ';' FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND sql IS NOT NULL ORDER BY name;" >> "$FLUTTER_SCHEMA_PATH"

echo "" >> "$FLUTTER_SCHEMA_PATH"
echo "-- Virtual Tables:" >> "$FLUTTER_SCHEMA_PATH"
sqlite3 "$DB_PATH" ".mode list" ".headers off" "SELECT sql || ';' FROM sqlite_master WHERE type = 'table' AND name LIKE 'search_index%' AND sql IS NOT NULL ORDER BY name;" >> "$FLUTTER_SCHEMA_PATH"

echo "" >> "$FLUTTER_SCHEMA_PATH"
echo "-- Indexes:" >> "$FLUTTER_SCHEMA_PATH"
sqlite3 "$DB_PATH" ".mode list" ".headers off" "SELECT sql || ';' FROM sqlite_master WHERE type = 'index' AND name NOT LIKE 'sqlite_%' AND sql IS NOT NULL ORDER BY tbl_name, name;" >> "$FLUTTER_SCHEMA_PATH"

echo "✅ Schema dumped successfully to: $FLUTTER_SCHEMA_PATH"

# Nettoyer les fichiers temporaires générés précédemment
rm -rf ../lib/core/database/generated_tables.drift
rm -f ../lib/core/database/backend_tables.drift 2>/dev/null || true

echo "🧹 Cleaned up temporary files"
echo "🎯 Ready for Flutter build_runner!"