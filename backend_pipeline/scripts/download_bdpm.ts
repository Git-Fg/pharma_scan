import { write } from "bun";
import { existsSync, mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";

// Configuration
const BASE_URL = "https://base-donnees-publique.medicaments.gouv.fr";
const DATA_DIR = "./data";

// Mapping explicite : URL Source -> Nom Local Forcé
const FILES_TO_DOWNLOAD = [
  { remotePath: "/download/file/CIS_bdpm.txt", localName: "CIS_bdpm.txt" },
  { remotePath: "/download/file/CIS_CIP_bdpm.txt", localName: "CIS_CIP_bdpm.txt" },
  { remotePath: "/download/file/CIS_COMPO_bdpm.txt", localName: "CIS_COMPO_bdpm.txt" },
  { remotePath: "/download/file/CIS_GENER_bdpm.txt", localName: "CIS_GENER_bdpm.txt" },
  { remotePath: "/download/file/CIS_CPD_bdpm.txt", localName: "CIS_CPD_bdpm.txt" },
  { remotePath: "/download/file/CIS_HAS_SMR_bdpm.txt", localName: "CIS_HAS_SMR_bdpm.txt" },
  { remotePath: "/download/file/CIS_HAS_ASMR_bdpm.txt", localName: "CIS_HAS_ASMR_bdpm.txt" },
  { remotePath: "/download/file/HAS_LiensPageCT_bdpm.txt", localName: "HAS_LiensPageCT_bdpm.txt" },
  { remotePath: "/download/file/CIS_CIP_Dispo_Spec.txt", localName: "CIS_CIP_Dispo_Spec.txt" },
  { remotePath: "/download/file/CIS_MITM.txt", localName: "CIS_MITM.txt" },
  // CAS SPÉCIAL : le serveur renvoie souvent un nom horodaté pour ce fichier
  { remotePath: "/download/CIS_InfoImportantes.txt", localName: "CIS_InfoImportante.txt" },
];

export async function downloadBdpm(opts: { force?: boolean } = {}): Promise<void> {
  console.log("🚀 Starting BDPM Download Tool");

  if (!existsSync(DATA_DIR)) {
    mkdirSync(DATA_DIR, { recursive: true });
    console.log(`📂 Created directory: ${DATA_DIR}`);
  }

  const force = !!opts.force;

  for (const file of FILES_TO_DOWNLOAD) {
    const localPath = join(DATA_DIR, file.localName);
    const url = `${BASE_URL}${file.remotePath}`;

    if (existsSync(localPath) && !force) {
      console.log(`⏭️  Skipped (exists): ${file.localName}`);
      continue;
    }

    try {
      process.stdout.write(`⬇️  Downloading ${file.localName}... `);
      const response = await fetch(url);
      if (!response.ok) throw new Error(`HTTP ${response.status} - ${response.statusText}`);

      // Bun.write accepte directement la Response body
      const bytesWritten = await write(localPath, response);
      const sizeKo = (bytesWritten / 1024).toFixed(1);
      console.log(`✅ Done (${sizeKo} Ko)`);
    } catch (error) {
      console.error(`\n❌ Error downloading ${url}:`, error);
    }
  }

  console.log("✨ Download process finished.");
}

// Runner when executed directly
if (import.meta.main) {
  const force = process.argv.includes("--force");
  downloadBdpm({ force }).catch((e) => {
    console.error("Download script failed:", e);
    process.exit(1);
  });
}
