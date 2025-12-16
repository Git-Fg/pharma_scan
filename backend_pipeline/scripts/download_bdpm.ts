import { write } from "bun";
import { existsSync, mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import iconv from "iconv-lite";

// Configuration
const BASE_URL = "https://base-donnees-publique.medicaments.gouv.fr";
const DATA_DIR = "./data";

// Mapping explicite : URL Source -> Nom Local Forcé
const FILES_TO_DOWNLOAD = [
  { remotePath: "/download/file/CIS_bdpm.txt", localName: "CIS_bdpm.txt", encoding: "windows-1252" },
  { remotePath: "/download/file/CIS_CIP_bdpm.txt", localName: "CIS_CIP_bdpm.txt", encoding: "utf-8" },
  { remotePath: "/download/file/CIS_COMPO_bdpm.txt", localName: "CIS_COMPO_bdpm.txt", encoding: "windows-1252" },
  { remotePath: "/download/file/CIS_GENER_bdpm.txt", localName: "CIS_GENER_bdpm.txt", encoding: "windows-1252" },
  { remotePath: "/download/file/CIS_CPD_bdpm.txt", localName: "CIS_CPD_bdpm.txt", encoding: "windows-1252" },
  { remotePath: "/download/file/CIS_HAS_SMR_bdpm.txt", localName: "CIS_HAS_SMR_bdpm.txt", encoding: "windows-1252" },
  { remotePath: "/download/file/CIS_HAS_ASMR_bdpm.txt", localName: "CIS_HAS_ASMR_bdpm.txt", encoding: "windows-1252" },
  { remotePath: "/download/file/HAS_LiensPageCT_bdpm.txt", localName: "HAS_LiensPageCT_bdpm.txt", encoding: "windows-1252" },
  { remotePath: "/download/file/CIS_CIP_Dispo_Spec.txt", localName: "CIS_CIP_Dispo_Spec.txt", encoding: "windows-1252" },
  { remotePath: "/download/file/CIS_MITM.txt", localName: "CIS_MITM.txt", encoding: "windows-1252" },
  // CAS SPÉCIAL : le serveur renvoie souvent un nom horodaté pour ce fichier
  { remotePath: "/download/CIS_InfoImportantes.txt", localName: "CIS_InfoImportante.txt", encoding: "utf-8" },
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

    // Try download with timeout and a couple retries to avoid hanging on a single slow request
    const maxRetries = 2;
    let attempt = 0;
    let success = false;
    while (attempt <= maxRetries && !success) {
      attempt++;
      try {
        process.stdout.write(`⬇️  Downloading ${file.localName} (attempt ${attempt})... `);

        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 120_000); // 2 minutes

        const response = await fetch(url, { signal: controller.signal });
        clearTimeout(timeout);

        if (!response.ok) throw new Error(`HTTP ${response.status} - ${response.statusText}`);

        const finalUrl = (response as any).url || url;
        const contentLength = response.headers.get?.('content-length') || 'unknown';
        process.stdout.write(`(from: ${finalUrl}, size: ${contentLength}) `);

        // Les fichiers BDPM sont généralement encodés en Windows-1252 (aka CP1252)
        // Sauf exceptions notées explicitement (ex: CIS_CIP_bdpm.txt est en UTF-8)
        const buffer = await response.arrayBuffer();

        let utf8Buffer: Uint8Array;
        if (file.encoding === "utf-8") {
          // Déjà en UTF-8, on ne touche à rien (ou on s'assure juste que c'est propre, mais fetch renvoie les bytes bruts)
          utf8Buffer = new Uint8Array(buffer);
        } else {
          // Conversion Windows-1252 -> UTF-8
          const decodedText = iconv.decode(Buffer.from(buffer), file.encoding || 'windows-1252');
          utf8Buffer = iconv.encode(decodedText, 'utf-8');
        }

        const bytesWritten = await write(localPath, utf8Buffer);
        const sizeKo = (bytesWritten / 1024).toFixed(1);
        console.log(`✅ Done (${sizeKo} Ko)`);
        success = true;
      } catch (error: any) {
        // If aborted due to timeout, indicate it explicitly
        if (error?.name === 'AbortError') {
          console.error(`\n⏱️ Timeout downloading ${file.localName} (attempt ${attempt})`);
        } else {
          console.error(`\n❌ Error downloading ${file.localName} (attempt ${attempt}):`, error?.message ?? error);
        }

        if (attempt > maxRetries) {
          console.error(`⚠️ Giving up downloading ${file.localName} after ${attempt} attempts`);
        } else {
          console.log(`🔁 Retrying ${file.localName}...`);
        }
      }
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
