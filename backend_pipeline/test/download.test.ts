import { describe, expect, test, beforeEach, afterEach } from "bun:test";
import { existsSync, readFileSync, rmSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { downloadBdpm } from "../scripts/download_bdpm";

describe("BDPM downloader", () => {
  const tmpDir = join(__dirname, "tmp_download_test");
  const origCwd = process.cwd();

  beforeEach(() => {
    try { rmSync(tmpDir, { recursive: true }); } catch { /* ignore */ }
    mkdirSync(tmpDir, { recursive: true });
    process.chdir(tmpDir);

    // Stub global fetch to avoid network in tests
    // @ts-ignore
    globalThis.fetch = (url: string) => Promise.resolve(new Response("ok"));
  });

  afterEach(() => {
    process.chdir(origCwd);
    // @ts-ignore
    delete globalThis.fetch;
    try { rmSync(tmpDir, { recursive: true }); } catch { /* ignore */ }
  });

  test("downloads and writes expected files", async () => {
    await downloadBdpm();

    const expected = [
      "CIS_bdpm.txt",
      "CIS_InfoImportante.txt",
    ];

    for (const name of expected) {
      const path = join(tmpDir, "data", name);
      expect(existsSync(path)).toBe(true);
      const content = readFileSync(path, "utf8");
      expect(content).toBe("ok");
    }
  });
});
