#!/usr/bin/env bun
/**
 * Backend Pipeline for Pharma Scan Database Update
 *
 * This script automates the medication database update process by:
 * 1. Fetching the latest release from GitHub
 * 2. Downloading the database asset
 * 3. Verifying checksums
 * 4. Updating the local databases
 * 5. Generating JSON exports for web version
 */

import { Database } from "bun:sqlite";
import { createHash } from "crypto";
import { createGzip } from "zlib";
import { promises as fs } from "fs";
import { mkdtemp } from "fs";
import { tmpdir } from "os";
import { join, dirname } from "path";

// Configuration
const GITHUB_REPO = "felixdm100/pharma_scan"; // Replace with actual repo
const DATABASE_NAME = "reference.db";
const CHECKSUMS_NAME = "checksums.txt";
const BACKUP_SUFFIX = ".backup";

// Paths
const SCRIPT_DIR = dirname(import.meta.path);
const BACKEND_DIR = dirname(SCRIPT_DIR); // backend_pipeline
const PROJECT_ROOT = dirname(BACKEND_DIR); // project root
const DATA_DIR = join(BACKEND_DIR, "data");
const OUTPUT_DIR = join(BACKEND_DIR, "output");
const FLUTTER_ASSETS_DIR = join(PROJECT_ROOT, "assets");

// Logging
const logger = {
  info: (msg: string) => console.log(`[INFO] ${new Date().toISOString()} - ${msg}`),
  error: (msg: string) => console.error(`[ERROR] ${new Date().toISOString()} - ${msg}`),
  warning: (msg: string) => console.warn(`[WARN] ${new Date().toISOString()} - ${msg}`),
};

interface Release {
  tag_name: string;
  published_at: string;
  assets: Asset[];
}

interface Asset {
  name: string;
  browser_download_url: string;
}

class DatabaseUpdater {
  private githubToken?: string;

  constructor(githubToken?: string) {
    this.githubToken = githubToken;
  }

  private async fetchWithAuth(url: string): Promise<Response> {
    const headers: Record<string, string> = {};
    if (this.githubToken) {
      headers.Authorization = `token ${this.githubToken}`;
    }
    return fetch(url, { headers });
  }

  async getLatestRelease(): Promise<Release> {
    const url = `https://api.github.com/repos/${GITHUB_REPO}/releases/latest`;
    logger.info(`Fetching latest release from ${url}`);

    const response = await this.fetchWithAuth(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch release: ${response.statusText}`);
    }
    const release: Release = await response.json();

    logger.info(`Latest release: ${release.tag_name} (${release.published_at})`);
    return release;
  }

  findDatabaseAssets(release: Release): { databaseUrl?: string; checksumUrl?: string } {
    let databaseUrl: string | undefined;
    let checksumUrl: string | undefined;

    for (const asset of release.assets) {
      if (asset.name === DATABASE_NAME) {
        databaseUrl = asset.browser_download_url;
      } else if (asset.name === CHECKSUMS_NAME) {
        checksumUrl = asset.browser_download_url;
      }
    }

    return { databaseUrl, checksumUrl };
  }

  async downloadFile(url: string, destination: string): Promise<void> {
    logger.info(`Downloading ${url} to ${destination}`);

    const response = await this.fetchWithAuth(url);
    if (!response.ok) {
      throw new Error(`Failed to download: ${response.statusText}`);
    }

    await fs.mkdir(dirname(destination), { recursive: true });

    const buffer = await response.arrayBuffer();
    await fs.writeFile(destination, new Uint8Array(buffer));

    const stats = await fs.stat(destination);
    logger.info(`Downloaded ${destination} (${stats.size} bytes)`);
  }

  async parseChecksums(checksumFile: string): Promise<Record<string, string>> {
    const checksums: Record<string, string> = {};
    const content = await fs.readFile(checksumFile, 'utf-8');
    for (const line of content.split('\n')) {
      const trimmed = line.trim();
      if (trimmed && !trimmed.startsWith('#')) {
        const parts = trimmed.split(/\s+/, 2);
        if (parts.length === 2) {
          const [hash, filename] = parts;
          checksums[filename] = hash;
        }
      }
    }
    return checksums;
  }

  async verifyChecksum(filePath: string, expectedChecksum: string): Promise<boolean> {
    const hash = createHash('sha256');
    const content = await fs.readFile(filePath);
    hash.update(content);
    const actualChecksum = hash.digest('hex');
    return actualChecksum.toLowerCase() === expectedChecksum.toLowerCase();
  }

  async backupDatabase(dbPath: string): Promise<void> {
    try {
      await fs.access(dbPath);
      const backupPath = `${dbPath}${BACKUP_SUFFIX}`;
      logger.info(`Creating backup: ${backupPath}`);
      await fs.copyFile(dbPath, backupPath);
    } catch {
      logger.warning(`Database file not found: ${dbPath}`);
    }
  }

  async restoreBackup(dbPath: string): Promise<boolean> {
    const backupPath = `${dbPath}${BACKUP_SUFFIX}`;
    try {
      await fs.access(backupPath);
      logger.info(`Restoring from backup: ${backupPath}`);
      await fs.copyFile(backupPath, dbPath);
      return true;
    } catch {
      logger.error("No backup file found");
      return false;
    }
  }

  async updateDatabases(newDbPath: string): Promise<void> {
    // Update backend database
    const backendDb = join(DATA_DIR, "reference.db");
    logger.info(`Updating backend database: ${backendDb}`);
    await fs.copyFile(newDbPath, backendDb);

    // Update Flutter assets database
    const flutterDb = join(FLUTTER_ASSETS_DIR, "reference.db");
    try {
      await fs.access(dirname(flutterDb));
      logger.info(`Updating Flutter database: ${flutterDb}`);
      await fs.copyFile(newDbPath, flutterDb);
    } catch {
      logger.warning(`Flutter assets directory not found: ${dirname(flutterDb)}`);
    }
  }

  async runUpdate(force: boolean = false): Promise<boolean> {
    try {
      // Get latest release info
      const release = await this.getLatestRelease();
      const releaseTag = release.tag_name;

      // Check if we're already on latest version
      const versionFile = join(DATA_DIR, "current_version.txt");
      if (!force) {
        try {
          const currentVersion = (await fs.readFile(versionFile, 'utf-8')).trim();
          if (currentVersion === releaseTag) {
            logger.info(`Already on latest version: ${releaseTag}`);
            return true;
          }
        } catch {
          // Version file doesn't exist, continue
        }
      }

      // Find database and checksum assets
      const { databaseUrl, checksumUrl } = this.findDatabaseAssets(release);

      if (!databaseUrl) {
        logger.error("Database file not found in release assets");
        return false;
      }

      if (!checksumUrl) {
        logger.error("Checksum file not found in release assets");
        return false;
      }

      // Create temporary directory
      const tempDir = await new Promise<string>((resolve, reject) => {
        mkdtemp(join(tmpdir(), 'pharma-update-'), (err, dir) => {
          if (err) reject(err);
          else resolve(dir);
        });
      });

      try {
        // Download checksums first
        const checksumFile = join(tempDir, CHECKSUMS_NAME);
        await this.downloadFile(checksumUrl, checksumFile);

        // Parse checksums
        const checksums = await this.parseChecksums(checksumFile);

        if (!(DATABASE_NAME in checksums)) {
          logger.error(`No checksum found for ${DATABASE_NAME}`);
          return false;
        }

        const expectedChecksum = checksums[DATABASE_NAME];

        // Download database
        const newDbFile = join(tempDir, DATABASE_NAME);
        await this.downloadFile(databaseUrl, newDbFile);

        // Verify checksum
        if (!(await this.verifyChecksum(newDbFile, expectedChecksum))) {
          logger.error("Checksum verification failed!");
          return false;
        }

        logger.info("Checksum verification passed");

        // Backup existing databases
        await this.backupDatabase(join(DATA_DIR, "reference.db"));
        await this.backupDatabase(join(FLUTTER_ASSETS_DIR, "reference.db"));

        try {
          // Update databases
          await this.updateDatabases(newDbFile);

          // Update version file
          await fs.mkdir(DATA_DIR, { recursive: true });
          await fs.writeFile(versionFile, releaseTag, 'utf-8');

          logger.info(`Successfully updated to version ${releaseTag}`);
          return true;

        } catch (e) {
          logger.error(`Update failed: ${e}`);
          // Attempt to restore from backup
          await this.restoreBackup(join(DATA_DIR, "reference.db"));
          await this.restoreBackup(join(FLUTTER_ASSETS_DIR, "reference.db"));
          return false;
        }

      } finally {
        // Clean up temp dir
        await fs.rm(tempDir, { recursive: true, force: true });
      }

    } catch (e) {
      logger.error(`Pipeline failed: ${e}`);
      return false;
    }
  }
}

// CLI argument parsing
function parseArgs() {
  const args = process.argv.slice(2);
  let token: string | undefined;
  let force = false;

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--token':
        token = args[++i];
        break;
      case '--force':
        force = true;
        break;
      default:
        console.error(`Unknown argument: ${args[i]}`);
        process.exit(1);
    }
  }

  return { token, force };
}

async function main() {
  const { token, force } = parseArgs();

  const updater = new DatabaseUpdater(token);

  // Run full update pipeline
  const success = await updater.runUpdate(force);
  process.exit(success ? 0 : 1);
}

if (import.meta.main) {
  main();
}