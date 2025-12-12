#!/usr/bin/env bun
/**
 * Sync Tool for Pharma Scan
 *
 * This script synchronizes the backend-generated database schema and golden DB
 * to the appropriate locations in the Flutter project.
 */

import { promises as fs } from "fs";
import { join, dirname } from "path";

// Paths
const SCRIPT_DIR = dirname(import.meta.path);
const BACKEND_DIR = dirname(SCRIPT_DIR); // backend_pipeline
const PROJECT_ROOT = dirname(BACKEND_DIR); // project root

const SCHEMA_SRC = join(BACKEND_DIR, "data", "schema.sql");
const SCHEMA_DST = join(PROJECT_ROOT, "lib", "core", "database", "dbschema.drift");

const DB_SRC = join(BACKEND_DIR, "data", "reference.db");
const DB_DST_DIR = join(PROJECT_ROOT, "test", "assets");
const DB_DST = join(DB_DST_DIR, "golden.db");

// Logging
const logger = {
  info: (msg: string) => console.log(`[INFO] ${new Date().toISOString()} - ${msg}`),
  error: (msg: string) => console.error(`[ERROR] ${new Date().toISOString()} - ${msg}`),
};

async function syncSchema(): Promise<void> {
  try {
    logger.info(`Copying schema: ${SCHEMA_SRC} -> ${SCHEMA_DST}`);
    await fs.copyFile(SCHEMA_SRC, SCHEMA_DST);
    logger.info("Schema synchronized successfully");
  } catch (e) {
    logger.error(`Failed to sync schema: ${e}`);
    throw e;
  }
}

async function syncGoldenDb(): Promise<void> {
  try {
    logger.info(`Ensuring directory: ${DB_DST_DIR}`);
    await fs.mkdir(DB_DST_DIR, { recursive: true });

    logger.info(`Copying golden DB: ${DB_SRC} -> ${DB_DST}`);
    await fs.copyFile(DB_SRC, DB_DST);
    logger.info("Golden DB synchronized successfully");
  } catch (e) {
    logger.error(`Failed to sync golden DB: ${e}`);
    throw e;
  }
}

async function main(): Promise<void> {
  try {
    await syncSchema();
    await syncGoldenDb();
    logger.info("All synchronizations completed successfully");
  } catch (e) {
    logger.error(`Synchronization failed: ${e}`);
    process.exit(1);
  }
}

if (import.meta.main) {
  main();
}