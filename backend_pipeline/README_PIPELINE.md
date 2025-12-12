# Pharma Scan Backend Pipeline

This document describes the backend pipeline for automating medication database updates.

## Overview

The backend pipeline consists of several tools:

- `tool/release.ts`: Updates the medication database from GitHub releases
- `tool/sync.ts`: Synchronizes generated files (schema, golden DB) to Flutter project locations

### Release Tool

The `tool/release.ts` script automates the process of updating the medication database from GitHub releases. It performs the following operations:

1. Fetches the latest release information from GitHub
2. Downloads the database asset and checksum file
3. Verifies the SHA256 checksum
4. Creates backups of existing databases
5. Updates both backend and Flutter app databases
6. Updates the version tracking file

### Sync Tool

The `tool/sync.ts` script synchronizes backend-generated files to the appropriate Flutter project locations:

- Copies `data/schema.sql` → `lib/core/database/dbschema.drift`
- Copies `data/reference.db` → `test/assets/golden.db`

## Requirements

- Bun (for running the TypeScript scripts)
- See `package.json` for dependencies

## Installation

```bash
# Install dependencies
bun install
```

## Usage

### Update Database

Run the full pipeline to check for and download updates:

```bash
# Using bun
bun run update-db
```

### Force Update

Force an update even if already on the latest version:

```bash
bun run update-db-force
```

### Sync Generated Files

Synchronize schema and golden DB to Flutter project locations:

```bash
bun run sync
```

### Using GitHub Token

For private repositories or to avoid API rate limits:

```bash
bun run tool/release.ts --token YOUR_GITHUB_TOKEN
```

## Output Files

The script updates the following database files:
- `data/reference.db` - Backend database
- `../assets/reference.db` - Flutter app database

### Backup files:
- `data/reference.db.backup` - Backup of previous backend database
- `../assets/reference.db.backup` - Backup of previous Flutter database
      "administration_routes": "cutanée",
      "status": "Autorisation active",
      "procedure_type": "Procédure nationale",
      "surveillance": false,
## Configuration

The script can be configured by modifying the constants at the top of `tool/release.ts`:

- `GITHUB_REPO`: GitHub repository name (default: "felixdm100/pharma_scan")
- `DATABASE_NAME`: Expected database file name (default: "reference.db")
- `CHECKSUMS_NAME`: Expected checksum file name (default: "checksums.txt")

## Error Handling

The pipeline includes robust error handling:

- **Checksum verification**: Fails if checksum doesn't match
- **Backup creation**: Automatically creates backups before updates
- **Automatic rollback**: Restores from backup if update fails
- **Logging**: Detailed logs saved to `pipeline.log`

## Integration with CI/CD

The script can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Update Database
  run: |
    cd backend_pipeline
    bun run update-db --token ${{ secrets.GITHUB_TOKEN }}
```

## Development

### Testing

```bash
# Test with force update (will download but may not update if same version)
bun run update-db-force
```

### Logs

Check the pipeline logs for debugging:

```bash
tail -f pipeline.log
```

## Troubleshooting

### Common Issues

1. **Permission denied**: Ensure bun is installed and executable
2. **Database locked**: Close any applications using the database before running
3. **API rate limit**: Use a GitHub token to increase rate limits
4. **Checksum mismatch**: The download may be corrupted - try again

### Recovery

If an update fails, the script automatically attempts to restore from backup. Manual recovery:

```bash
# Restore from backup
cp data/reference.db.backup data/reference.db
cp ../assets/reference.db.backup ../assets/reference.db
```

## Security Considerations

- Always verify checksums before using downloaded databases
- Use HTTPS for all downloads
- Store GitHub tokens securely (environment variables, secrets manager)
- Review database contents before deployment in production