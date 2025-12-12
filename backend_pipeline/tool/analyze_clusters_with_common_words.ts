import { ReferenceDatabase } from "../src/db";
import fs from "fs";
import path from "path";

interface ClusterAnalysis {
  cluster_id: string;
  cluster_name: string;
  cluster_princeps: string | null;
  product_count: number;
  products: Array<{
    cis_code: string;
    nom_canonique: string;
    principes_actifs_communs: string[];
    words: string[];
  }>;
  common_words: Array<{
    word: string;
    products: string[]; // cis_codes qui contiennent ce mot
  }>;
}

function extractWords(text: string): string[] {
  if (!text) return [];
  // Normaliser en majuscules et extraire les mots (séparés par espaces, virgules, +)
  return text
    .toUpperCase()
    .split(/[\s,+\-]+/)
    .map(w => w.trim())
    .filter(w => w.length > 0);
}

function findCommonWords(products: Array<{ cis_code: string; words: string[] }>): Array<{ word: string; products: string[] }> {
  const wordToProducts = new Map<string, Set<string>>();
  
  // Pour chaque produit, enregistrer tous ses mots
  for (const product of products) {
    for (const word of product.words) {
      if (!wordToProducts.has(word)) {
        wordToProducts.set(word, new Set());
      }
      wordToProducts.get(word)!.add(product.cis_code);
    }
  }
  
  // Filtrer les mots qui apparaissent dans au moins 2 produits
  const commonWords: Array<{ word: string; products: string[] }> = [];
  for (const [word, cisCodes] of wordToProducts.entries()) {
    if (cisCodes.size >= 2) {
      commonWords.push({
        word,
        products: Array.from(cisCodes)
      });
    }
  }
  
  return commonWords;
}

async function analyzeClusters() {
  const dbPath = process.env.DB_PATH || "./data/reference.db";
  const db = new ReferenceDatabase(dbPath);
  
  console.log("🔍 Analyzing clusters with common words in substance_label...");
  
  // Récupérer tous les clusters avec leurs produits et principes_actifs_communs
  const query = `
    SELECT 
      ms.cluster_id,
      cn.cluster_name,
      cn.cluster_princeps,
      ms.cis_code,
      ms.nom_canonique,
      ms.principes_actifs_communs
    FROM medicament_summary ms
    LEFT JOIN cluster_names cn ON ms.cluster_id = cn.cluster_id
    WHERE ms.cluster_id IS NOT NULL
      AND ms.principes_actifs_communs IS NOT NULL
      AND typeof(ms.principes_actifs_communs) = 'text'
      AND json_valid(ms.principes_actifs_communs) = 1
    ORDER BY ms.cluster_id, ms.cis_code
  `;
  
  const rows = db.runQuery<{
    cluster_id: string;
    cluster_name: string | null;
    cluster_princeps: string | null;
    cis_code: string;
    nom_canonique: string;
    principes_actifs_communs: string;
  }>(query);
  
  // Grouper par cluster_id
  const clustersMap = new Map<string, Array<{
    cis_code: string;
    nom_canonique: string;
    principes_actifs_communs: string[];
  }>>();
  
  for (const row of rows) {
    if (!row.cluster_id) continue;
    
    try {
      const principes = JSON.parse(row.principes_actifs_communs);
      if (!Array.isArray(principes)) continue;
      
      if (!clustersMap.has(row.cluster_id)) {
        clustersMap.set(row.cluster_id, []);
      }
      
      clustersMap.get(row.cluster_id)!.push({
        cis_code: row.cis_code,
        nom_canonique: row.nom_canonique,
        principes_actifs_communs: principes
      });
    } catch (e) {
      // Ignorer les erreurs de parsing JSON
      continue;
    }
  }
  
  // Analyser chaque cluster
  const results: ClusterAnalysis[] = [];
  
  for (const [clusterId, products] of clustersMap.entries()) {
    // Filtrer les clusters avec plus de 2 produits
    if (products.length <= 2) continue;
    
    // Extraire les mots de chaque produit (depuis principes_actifs_communs)
    const productsWithWords = products.map(p => ({
      cis_code: p.cis_code,
      nom_canonique: p.nom_canonique,
      principes_actifs_communs: p.principes_actifs_communs,
      words: p.principes_actifs_communs.flatMap(principe => extractWords(principe))
    }));
    
    // Trouver les mots communs entre produits
    const commonWords = findCommonWords(productsWithWords);
    
    // Ne garder que les clusters avec au moins un mot en commun
    if (commonWords.length === 0) continue;
    
    // Récupérer les métadonnées du cluster
    const firstProduct = products[0];
    const clusterMeta = db.runQuery<{
      cluster_name: string | null;
      cluster_princeps: string | null;
    }>(`
      SELECT cluster_name, cluster_princeps
      FROM cluster_names
      WHERE cluster_id = ?
    `, [clusterId])[0];
    
    results.push({
      cluster_id: clusterId,
      cluster_name: clusterMeta?.cluster_name || null,
      cluster_princeps: clusterMeta?.cluster_princeps || null,
      product_count: products.length,
      products: productsWithWords.map(p => ({
        cis_code: p.cis_code,
        nom_canonique: p.nom_canonique,
        principes_actifs_communs: p.principes_actifs_communs,
        words: p.words
      })),
      common_words: commonWords
    });
  }
  
  // Trier par nombre de produits décroissant
  results.sort((a, b) => b.product_count - a.product_count);
  
  // Enregistrer dans un fichier JSON
  const outputPath = path.join("data", "audit", "clusters_with_common_words.json");
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, JSON.stringify(results, null, 2), "utf-8");
  
  console.log(`✅ Found ${results.length} clusters with common words`);
  console.log(`📄 Results saved to: ${outputPath}`);
  
  // Afficher quelques statistiques
  if (results.length > 0) {
    const totalProducts = results.reduce((sum, r) => sum + r.product_count, 0);
    const avgProducts = totalProducts / results.length;
    const maxProducts = Math.max(...results.map(r => r.product_count));
    
    console.log(`\n📊 Statistics:`);
    console.log(`   Total clusters: ${results.length}`);
    console.log(`   Total products: ${totalProducts}`);
    console.log(`   Average products per cluster: ${avgProducts.toFixed(2)}`);
    console.log(`   Max products in a cluster: ${maxProducts}`);
    
    // Afficher les 5 premiers clusters
    console.log(`\n🔝 Top 5 clusters:`);
    for (let i = 0; i < Math.min(5, results.length); i++) {
      const r = results[i];
      console.log(`   ${i + 1}. ${r.cluster_id} (${r.product_count} products, ${r.common_words.length} common words)`);
      console.log(`      Name: ${r.cluster_name || 'N/A'}`);
      console.log(`      Common words: ${r.common_words.slice(0, 5).map(cw => cw.word).join(', ')}${r.common_words.length > 5 ? '...' : ''}`);
    }
  }
}

analyzeClusters().catch(console.error);
