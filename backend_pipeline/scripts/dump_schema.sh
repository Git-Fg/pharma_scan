#!/bin/bash

# Script pour dumper le schéma de la base de données vers Flutter
# Utilise sqlite3 CLI pour générer un schéma propre et compatible Drift

set -e

# Chemins
DB_PATH="data/reference.db"
FLUTTER_SCHEMA_PATH="../lib/core/database/reference_schema.drift"


# Vérifier que la base de données existe
if [ ! -f "$DB_PATH" ]; then
    echo "❌ Database file not found: $DB_PATH"
    echo "Run 'bun run build' first to generate the database"
    exit 1
fi

echo "🔍 Dumping schema from: $DB_PATH"
echo "📝 Writing Flutter schema to: $FLUTTER_SCHEMA_PATH"



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

# --- Synchronize Database Artifacts ---
echo "📦 Synchronizing Database Artifacts..."

# Source (Backend output)
SRC_DB="data/reference.db"

# Destination (Flutter Test Assets)
TEST_ASSET_DEST="../assets/test/reference.db"

if [ -f "$SRC_DB" ]; then
    echo "   -> Copying to Test Assets: $TEST_ASSET_DEST"
    cp "$SRC_DB" "$TEST_ASSET_DEST"

    # Destination (App Assets for Ship & Copy)
    APP_ASSET_DEST="../assets/database/reference.db.gz"
    
    # Create directory if not exists
    mkdir -p "../assets/database"

    echo "   -> Compressing and Copying to App Assets: $APP_ASSET_DEST"
    gzip -c "$SRC_DB" > "$APP_ASSET_DEST"
    
    echo "✅ Database artifacts synchronized."
else
    echo "❌ Error: $SRC_DB not found. Run 'bun run build' first."
    exit 1
fi

echo "🎯 Ready for Flutter build_runner!"