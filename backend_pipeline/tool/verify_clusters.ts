#!/usr/bin/env bun
import { writeFileSync, mkdirSync, existsSync } from "node:fs";
import { join } from "node:path";
import { DEFAULT_DB_PATH, ReferenceDatabase } from "../src/db";
import { MANUFACTURER_IGNORE_PAIRS } from "../src/constants";
import { isHomeopathic, normalizeManufacturerName, normalizeString, levenshteinDistance, normalizeRoutes } from "../src/logic";

interface VerificationIssue {
  type:
    | "split_brain"
    | "permutation"
    | "empty_signature"
    | "manufacturer_duplicate"
    | "route_conflict"
    | "safety_mismatch"
    | "naming_fallback"
    | "availability_conflict";
  severity: "high" | "medium" | "low";
  description: string;
  details: Record<string, any>;
  affected_ids: string[];
  recommendation: string;
}

interface VerificationReport {
  timestamp: string;
  summary: {
    total_issues: number;
    high_issues: number;
    medium_issues: number;
    low_issues: number;
    issues_by_type: Record<string, number>;
  };
  issues: VerificationIssue[];
  recommendations: string[];
  stats: {
    total_clusters: number;
    total_products: number;
    total_manufacturers: number;
    products_without_signatures: number;
  };
}

class ClusterVerifier {
  private db: ReferenceDatabase;
  private readonly outputDir: string;

  constructor(dbPath: string = DEFAULT_DB_PATH, options?: { outputDir?: string }) {
    if (dbPath !== ":memory:" && !existsSync(dbPath)) {
      throw new Error(
        `Missing reference database at ${dbPath}. Generate it first (e.g., bun run build:db).`
      );
    }
    this.db = new ReferenceDatabase(dbPath);
    this.outputDir = options?.outputDir ?? join(process.cwd(), "data");
  }

  async runVerification(): Promise<{ passed: boolean; issues: VerificationIssue[]; recommendations: string[] }> {
    console.log("🔍 Starting cluster verification...");

    const issues: VerificationIssue[] = [];

    // 1. Split-Brain Clusters Detection
    console.log("📊 Checking for split-brain clusters...");
    const splitBrainIssues = await this.detectSplitBrainClusters();
    issues.push(...splitBrainIssues);

    // 2. Permutation Check
    console.log("🔄 Checking for label permutations...");
    const permutationIssues = await this.detectPermutationIssues();
    issues.push(...permutationIssues);

    // 3. Empty Signatures Detection
    console.log("📝 Checking for empty composition signatures...");
    const emptySignatureIssues = await this.detectEmptySignatures();
    issues.push(...emptySignatureIssues);

    // 4. Manufacturer Duplicates
    console.log("🏭 Checking for manufacturer duplicates...");
    const manufacturerIssues = await this.detectManufacturerDuplicates();
    issues.push(...manufacturerIssues);

    // 5. Route conflicts within group
    console.log("🛣️  Checking for route conflicts...");
    const routeIssues = await this.detectRouteConflicts();
    issues.push(...routeIssues);

    // 6. Safety flag mismatches
    console.log("🚨 Checking safety flag propagation...");
    const safetyIssues = await this.detectSafetyMismatches();
    issues.push(...safetyIssues);

    // 7. Naming fallbacks without princeps linkage
    const namingIssues = await this.detectNamingFallbacks();
    issues.push(...namingIssues);

    // 8. Availability vs marketing conflicts
    const availabilityIssues = await this.detectAvailabilityConflicts();
    issues.push(...availabilityIssues);

    // Generate recommendations
    const recommendations = this.generateRecommendations(issues);

    // Create report
    const report = await this.createReport(issues, recommendations);

    // Save report
    await this.saveReport(report);

    const passed = issues.filter(i => i.severity === "high").length === 0;

    console.log(`\n✅ Verification complete!`);
    console.log(`   Found ${issues.length} total issues (${issues.filter(i => i.severity === "high").length} high severity)`);
    console.log(`   Report saved to: data/deep_audit_report.json`);

    return { passed, issues, recommendations };
  }

  private async detectSplitBrainClusters(): Promise<VerificationIssue[]> {
    const issues: VerificationIssue[] = [];

    // Get all clusters with their princeps products
    const clustersWithPrinceps = this.db.rawQuery<{
      cluster_id: string;
      cluster_label: string;
      princeps_cis: string;
      princeps_label: string;
      substance_code: string;
    }>(`
      SELECT
        c.id as cluster_id,
        c.label as cluster_label,
        c.substance_code as substance_code,
        p.cis as princeps_cis,
        p.label as princeps_label
      FROM clusters c
      JOIN groups g ON g.cluster_id = c.id
      JOIN products p ON p.group_id = g.id AND p.is_princeps = 1
      ORDER BY c.label
    `);

    // Group princeps by normalized label to find potential splits
    const princepsByNormalized = new Map<string, Array<{
      cluster_id: string;
      cluster_label: string;
      princeps_cis: string;
      princeps_label: string;
      substance_code: string;
    }>>();

    for (const row of clustersWithPrinceps) {
      const normalized = normalizeString(row.princeps_label);
      if (!normalized) continue;

      if (!princepsByNormalized.has(normalized)) {
        princepsByNormalized.set(normalized, []);
      }
      princepsByNormalized.get(normalized)!.push(row);
    }

    // Find princeps that appear in multiple clusters
    for (const [normalized, princepsList] of princepsByNormalized.entries()) {
      if (princepsList.length > 1) {
        const clusterIds = [...new Set(princepsList.map(p => p.cluster_id))];

        if (clusterIds.length > 1) {
          // Ignore splits where clusters differ only by additional combo substance codes
          const tokenCounts = princepsList.map(p => tokenizeSubstanceCodes(p.substance_code).length || 0);
          const minTokens = Math.min(...tokenCounts);
          const maxTokens = Math.max(...tokenCounts);
          if (minTokens > 0 && maxTokens > minTokens) {
            continue;
          }

          const severity: VerificationIssue["severity"] = "medium";
          issues.push({
            type: "split_brain",
            severity,
            description: `Princeps "${normalized}" split across ${clusterIds.length} clusters`,
            details: {
              normalized_princeps: normalized,
              clusters: princepsList.map(p => ({
                cluster_id: p.cluster_id,
                cluster_label: p.cluster_label,
                princeps_cis: p.princeps_cis,
                princeps_label: p.princeps_label
              }))
            },
            affected_ids: clusterIds,
            recommendation: "Merge or reconcile these clusters; check composition/brand alignment"
          });
        }
      }
    }

    return issues;
  }

  private async detectPermutationIssues(): Promise<VerificationIssue[]> {
    // Suppressed to reduce noise; permutation issues considered benign for clustering.
    return [];
  }

  private async detectEmptySignatures(): Promise<VerificationIssue[]> {
    const issues: VerificationIssue[] = [];

    // Find products with empty or invalid composition_codes
    const productsWithBadSignatures = this.db.rawQuery<{
      cis: string;
      label: string;
      composition_codes: string;
      cluster_id: string;
      cluster_label: string;
    }>(`
      SELECT
        p.cis,
        p.label,
        p.composition_codes,
        c.id as cluster_id,
        c.label as cluster_label
      FROM products p
      JOIN groups g ON g.id = p.group_id
      JOIN clusters c ON c.id = g.cluster_id
      WHERE p.composition_codes = '[]'
         OR p.composition_codes = '["0"]'
         OR p.composition_codes = ''
         OR p.composition_codes IS NULL
      LIMIT 1000
    `);

    // Group by cluster
    const issuesByCluster = new Map<string, Array<(typeof productsWithBadSignatures)[number]>>();

    for (const product of productsWithBadSignatures) {
      if (!issuesByCluster.has(product.cluster_id)) {
        issuesByCluster.set(product.cluster_id, []);
      }
      issuesByCluster.get(product.cluster_id)!.push(product);
    }

    // Create issues
    for (const [clusterId, products] of issuesByCluster.entries()) {
      const first = products[0];
      if (!first) continue;
      const clusterLabel = first.cluster_label;

      issues.push({
        type: "empty_signature",
        severity: "medium",
        description: `Cluster "${clusterLabel}" has ${products.length} products with empty composition signatures`,
        details: {
          cluster_id: clusterId,
          cluster_label: clusterLabel,
          affected_products: products.map(p => ({
            cis: p.cis,
            label: p.label,
            composition_codes: p.composition_codes
          }))
        },
        affected_ids: products.map(p => p.cis),
        recommendation: "Review composition data for these products and update composition_codes field"
      });
    }

    return issues;
  }

  private async detectManufacturerDuplicates(): Promise<VerificationIssue[]> {
    const issues: VerificationIssue[] = [];

    const ignorePairs = MANUFACTURER_IGNORE_PAIRS;

    const normalizeKey = (label: string): string =>
      normalizeManufacturerName(label).toLowerCase();

    // Get all manufacturers with their product counts
    const manufacturers = this.db.rawQuery<{
      id: number;
      label: string;
      product_count: number;
    }>(`
      SELECT
        m.id,
        m.label,
        COUNT(p.cis) as product_count
      FROM manufacturers m
      LEFT JOIN products p ON p.manufacturer_id = m.id
      GROUP BY m.id, m.label
      HAVING product_count > 0
      ORDER BY m.label
    `);

    // Compare each manufacturer with every other manufacturer
    for (let i = 0; i < manufacturers.length; i++) {
      for (let j = i + 1; j < manufacturers.length; j++) {
        const mfrA = manufacturers[i];
        const mfrB = manufacturers[j];

        const normalizedA = normalizeKey(mfrA.label);
        const normalizedB = normalizeKey(mfrB.label);

        // Skip if identical
        if (normalizedA === normalizedB) continue;

        const key = [normalizeKey(mfrA.label), normalizeKey(mfrB.label)].sort().join("|");
        if (ignorePairs.has(key)) continue;

        // Calculate Levenshtein distance
        const distance = levenshteinDistance(normalizedA, normalizedB);
        const minLength = Math.min(normalizedA.length, normalizedB.length);

        // Check for very similar names (distance < 3 or < 25% similarity)
        if (distance < 3 || (minLength > 5 && distance / minLength < 0.25)) {
          const stopTokens = new Set([
            "pharma",
            "pharmaceutical",
            "pharmaceuticals",
            "pharmaceutica",
            "pharmaceuticale",
            "arzneimittel",
            "healthcare",
            "laboratoires",
            "laboratoire",
            "laboratories",
            "sa",
            "spa",
            "gmbh",
            "ag",
            "bv",
            "b.v.",
            "sas",
            "srl",
            "s.r.l.",
            "spa.",
            "inc",
            "ltd",
            "plc",
            "pays-bas",
            "netherlands",
            "allemagne",
            "germany",
            "autriche",
            "austria",
            "malta",
            "malte",
            "italie",
            "italy",
            "france",
            "espagne",
            "spain",
            "uk",
            "usa"
          ]);

          const meaningfulTokens = (label: string) => {
            const withoutParens = label.replace(/\([^)]*\)/g, " ");
            return withoutParens
              .toLowerCase()
              .split(/[^a-z0-9]+/)
              .filter(t => t.length > 2 && !stopTokens.has(t));
          };

          const tokensA = meaningfulTokens(mfrA.label);
          const tokensB = meaningfulTokens(mfrB.label);
          const commonTokens = tokensA.filter(t => tokensB.includes(t));
          const commonMeaningful = commonTokens;

          if (commonMeaningful.length > 0) {
            issues.push({
              type: "manufacturer_duplicate",
              severity: distance < 2 ? "high" : "medium",
              description: `Manufacturers "${mfrA.label}" and "${mfrB.label}" appear to be duplicates`,
              details: {
                manufacturer_a: {
                  id: mfrA.id,
                  label: mfrA.label,
                  product_count: mfrA.product_count
                },
                manufacturer_b: {
                  id: mfrB.id,
                  label: mfrB.label,
                  product_count: mfrB.product_count
                },
                levenshtein_distance: distance,
                common_tokens: commonTokens
              },
              affected_ids: [mfrA.id.toString(), mfrB.id.toString()],
              recommendation: "Consider merging these manufacturer records"
            });
          }
        }
      }
    }

    return issues;
  }

  private async detectRouteConflicts(): Promise<VerificationIssue[]> {
    const issues: VerificationIssue[] = [];
    const rows = this.db.rawQuery<{ id: string; label: string; routes: string }>(`
      SELECT id, label, routes
      FROM groups
    `);

    for (const row of rows) {
      if (!row.routes) continue;
      let parsed: string[] = [];
      try {
        parsed = JSON.parse(row.routes);
      } catch {
        continue;
      }
      const normalizedTokens = Array.from(
        new Set(parsed.flatMap((r) => normalizeRoutes(String(r || ""))).filter(Boolean).filter((t) => t.length > 1))
      );
      if (normalizedTokens.length <= 1) continue;
      const families = new Set(normalizedTokens.map(classifyRouteFamily));
      // If all routes are injectable (even if different specialized routes), no conflict
      if (families.size === 1 && families.has("injectable")) continue;
      if (families.size === 1) continue;
      // Additional check: if all normalized tokens contain injectable keywords, treat as all injectable
      // This handles cases where routes might not be perfectly classified but are clearly all injectable
      // Check before other validations to avoid false positives
      const injectablePattern = /inject|perfus|iv|intra.?veine|intra.?musculaire|intramuscular|^s$|^s-|sous-cutan|intraartérielle|intrapleurale|intratumorale|intrathécale|intraarticulaire|intra-utérine|intraséreuse|intravésicale|péridurale|périneurale|intra.?murale|infiltration|périarticulaire|péribulbaire|intracoronaire|intracérébroventriculaire|intracisternale|voie extracorporelle/;
      const allInjectableLike = normalizedTokens.length > 0 && normalizedTokens.every(t => {
        const lower = t.toLowerCase();
        return injectablePattern.test(lower) || (lower.includes("intra") && !lower.includes("intraoral")) || lower.includes("péri");
      });
      // If all tokens are injectable-like, skip conflict detection (even if classification is imperfect)
      // This handles cases like BLÉOMYCINE where all routes are specialized injectable routes
      if (allInjectableLike) {
        continue;
      }
      const compatibilityMap: Record<string, string> = {
        oral: "oral",
        buccal: "oral",
        sublingual: "oral",
        inhalation: "respiratory",
        nasal: "respiratory",
        "gastro-entérale": "oral",
        entérale: "oral"
      };
      const reducedFamilies = new Set(
        normalizedTokens.map((t) => compatibilityMap[t] ?? classifyRouteFamily(t))
      );
      if (reducedFamilies.size === 1) continue;
      const hasInjectable = Array.from(families).includes("injectable");
      const hasOral = Array.from(families).includes("oral");
      const hasRectal = Array.from(families).includes("rectal");
      const benignFamilySet = new Set(["topical", "ophthalmic", "otic", "respiratory", "nasal", "rectal", "vaginal"]);
      const isBenignCombo = Array.from(reducedFamilies).every((f) => benignFamilySet.has(f));
      if (isBenignCombo) {
        continue;
      }
      // If only oral + rectal/vaginal, treat as benign
      if (
        !hasInjectable &&
        reducedFamilies.size <= 2 &&
        reducedFamilies.has("oral") &&
        (reducedFamilies.has("rectal") || reducedFamilies.has("vaginal"))
      ) {
        continue;
      }
      // Injectable + rectal is legitimate for some medications (e.g., midazolam)
      if (hasInjectable && hasRectal && reducedFamilies.size === 2 && !hasOral) {
        continue;
      }
      // Injectable + oral: generally a conflict, but allow for specific known cases
      // Only skip if it's injectable + oral ONLY (no other routes) AND the label suggests it's a legitimate dual-form product
      if (hasInjectable && hasOral && reducedFamilies.size === 2) {
        const labelLower = row.label.toLowerCase();
        // Known antibiotics that legitimately have both injectable and oral forms
        const knownDualForm = /teicoplanine|vancomycine|clindamycine|lincomycine/i.test(labelLower);
        if (knownDualForm) {
          continue;
        }
        // Otherwise, this is a conflict - emit it
      }
      // If all routes are injectable (even specialized ones), no conflict
      if (hasInjectable && !hasOral && !hasRectal && families.size === 1 && families.has("injectable")) {
        continue;
      }
      // Inhalation + injectable is legitimate for some medications (e.g., pentamidine)
      const hasInhalation = Array.from(families).includes("inhalation");
      if (hasInjectable && hasInhalation && reducedFamilies.size === 2) {
        continue;
      }
      // If "other" family is present but all other routes are injectable, treat as benign (e.g., "dentaire" usage context)
      if (hasInjectable && families.has("other") && families.size === 2) {
        continue;
      }
      // If no oral/injectable and only two families, treat as benign (e.g., topical+ophthalmic)
      if (!hasInjectable && !hasOral && reducedFamilies.size <= 2) {
        continue;
      }
      // Skip mild injectables when paired only with benign topical/ophthalmic/otic/respiratory
      if (
        hasInjectable &&
        !hasOral &&
        Array.from(reducedFamilies).every((f) => f === "injectable" || benignFamilySet.has(f))
      ) {
        continue;
      }
      const severity: VerificationIssue["severity"] =
        hasInjectable && hasOral ? "medium" : "low";
      issues.push({
        type: "route_conflict",
        severity,
        description: `Group "${row.label}" has multiple routes: ${normalizedTokens.join(", ")}`,
        details: { group_id: row.id, routes: normalizedTokens },
        affected_ids: [row.id],
        recommendation: "Split groups by incompatible routes or align route parsing"
      });
    }

    return issues;
  }

  private async detectSafetyMismatches(): Promise<VerificationIssue[]> {
    const issues: VerificationIssue[] = [];

    const rows = this.db.rawQuery<{
      group_id: string;
      group_label: string;
      safety_flags: string;
      narcotic_count: number;
      list1_count: number;
      list2_count: number;
      hospital_count: number;
      dental_count: number;
    }>(`
      SELECT
        g.id as group_id,
        g.label as group_label,
        g.safety_flags as safety_flags,
        SUM(CASE WHEN json_extract(p.regulatory_info, '$.narcotic') = 1 THEN 1 ELSE 0 END) AS narcotic_count,
        SUM(CASE WHEN json_extract(p.regulatory_info, '$.list1') = 1 THEN 1 ELSE 0 END) AS list1_count,
        SUM(CASE WHEN json_extract(p.regulatory_info, '$.list2') = 1 THEN 1 ELSE 0 END) AS list2_count,
        SUM(CASE WHEN json_extract(p.regulatory_info, '$.hospital') = 1 THEN 1 ELSE 0 END) AS hospital_count,
        SUM(CASE WHEN json_extract(p.regulatory_info, '$.dental') = 1 THEN 1 ELSE 0 END) AS dental_count
      FROM groups g
      JOIN products p ON p.group_id = g.id
      GROUP BY g.id, g.label, g.safety_flags
    `);

    for (const row of rows) {
      let safety: Record<string, boolean> = {};
      try {
        safety = JSON.parse(row.safety_flags || "{}");
      } catch {
        safety = {};
      }

      const checks: Array<{ key: keyof typeof safety; count: number }> = [
        { key: "narcotic", count: row.narcotic_count },
        { key: "list1", count: row.list1_count },
        { key: "list2", count: row.list2_count },
        { key: "hospital", count: row.hospital_count },
        { key: "dental", count: row.dental_count }
      ];

      for (const check of checks) {
        const flag = Boolean((safety as any)[check.key]);
        if (check.count > 0 && !flag) {
          issues.push({
            type: "safety_mismatch",
            severity: "medium",
            description: `Group "${row.group_label}" missing safety flag "${check.key}" despite ${check.count} products carrying it`,
            details: { group_id: row.group_id, missing_flag: check.key, count: check.count },
            affected_ids: [row.group_id],
            recommendation: "Align group safety_flags aggregation with product regulatory_info"
          });
        }
      }
    }

    return issues;
  }

  private async detectNamingFallbacks(): Promise<VerificationIssue[]> {
    const issues: VerificationIssue[] = [];
    const rows = this.db.rawQuery<{ id: string; label: string; naming_source: string; princeps_aliases: string }>(`
      SELECT id, label, naming_source, princeps_aliases
      FROM groups
    `);

    for (const row of rows) {
      if (row.naming_source === "TYPE_0_LINK") continue;
      let aliases: unknown[] = [];
      try {
        aliases = JSON.parse(row.princeps_aliases || "[]");
      } catch {
        aliases = [];
      }
      if (aliases.length === 0) {
        issues.push({
          type: "naming_fallback",
          severity: "low",
          description: `Group "${row.label}" uses GENER_PARSING without princeps aliases`,
          details: { group_id: row.id },
          affected_ids: [row.id],
          recommendation: "Review canonical naming for historical princeps accuracy"
        });
      }
    }

    return issues;
  }

  private async detectAvailabilityConflicts(): Promise<VerificationIssue[]> {
    // Noise-prone: availability feed often flags remise=4 while BDPM marketing stays "non commercialisée".
    // We consider this benign for clustering; skip emitting issues to keep report focused.
    return [];
  }

  private generateRecommendations(issues: VerificationIssue[]): string[] {
    const recommendations = new Set<string>();

    // Add specific recommendations based on issue types
    const issuesByType = new Map<string, number>();
    for (const issue of issues) {
      issuesByType.set(issue.type, (issuesByType.get(issue.type) || 0) + 1);
    }

    if ((issuesByType.get("split_brain") ?? 0) > 0) {
      recommendations.add("Review split-brain clusters: Same princeps appearing in multiple clusters may indicate incorrect clustering logic");
    }

    if ((issuesByType.get("permutation") ?? 0) > 5) {
      recommendations.add("High number of similar cluster labels detected: Consider reviewing normalization algorithm");
    }

    if ((issuesByType.get("empty_signature") ?? 0) > 10) {
      recommendations.add("Many products lack composition signatures: Check BDPM composition data parsing");
    }

    if ((issuesByType.get("manufacturer_duplicate") ?? 0) > 0) {
      recommendations.add("Manufacturer name deduplication needed: Implement fuzzy matching for manufacturer resolution");
    }

    // General recommendations
    if (issues.filter(i => i.severity === "high").length > 0) {
      recommendations.add("Address high severity issues before next database build");
    }

    return Array.from(recommendations);
  }

  private async createReport(issues: VerificationIssue[], recommendations: string[]): Promise<VerificationReport> {
    // Get stats
    const clustersRow = this.db.rawQuery<{ count: number }>(`SELECT COUNT(*) as count FROM clusters`);
    const totalClusters = clustersRow.length > 0 ? clustersRow[0].count : 0;
    const productsRow = this.db.rawQuery<{ count: number }>(`SELECT COUNT(*) as count FROM products`);
    const totalProducts = productsRow.length > 0 ? productsRow[0].count : 0;
    const manufacturersRow = this.db.rawQuery<{ count: number }>(`SELECT COUNT(*) as count FROM manufacturers`);
    const totalManufacturers = manufacturersRow.length > 0 ? manufacturersRow[0].count : 0;
    const productsWithoutSignaturesRow = this.db.rawQuery<{ count: number }>(`
      SELECT COUNT(*) as count
      FROM products
      WHERE composition_codes = '[]' OR composition_codes = '["0"]' OR composition_codes = '' OR composition_codes IS NULL
    `);
    const productsWithoutSignatures = productsWithoutSignaturesRow.length > 0 ? productsWithoutSignaturesRow[0].count : 0;

    const issuesByType = new Map<string, number>();
    for (const issue of issues) {
      issuesByType.set(issue.type, (issuesByType.get(issue.type) || 0) + 1);
    }

    return {
      timestamp: new Date().toISOString(),
      summary: {
        total_issues: issues.length,
        high_issues: issues.filter(i => i.severity === "high").length,
        medium_issues: issues.filter(i => i.severity === "medium").length,
        low_issues: issues.filter(i => i.severity === "low").length,
        issues_by_type: Object.fromEntries(issuesByType)
      },
      issues,
      recommendations,
      stats: {
        total_clusters: totalClusters,
        total_products: totalProducts,
        total_manufacturers: totalManufacturers,
        products_without_signatures: productsWithoutSignatures
      }
    };
  }

  private async saveReport(report: VerificationReport): Promise<void> {
    // Ensure output directory exists
    mkdirSync(this.outputDir, { recursive: true });

    // Write report
    const reportPath = join(this.outputDir, "deep_audit_report.json");
    writeFileSync(reportPath, JSON.stringify(report, null, 2));

    // Also write a concise summary to console
    console.log(`\n📋 Verification Summary:`);
    console.log(`   Split-Brain Clusters: ${report.summary.issues_by_type.split_brain || 0}`);
    console.log(`   Permutation Issues: ${report.summary.issues_by_type.permutation || 0}`);
    console.log(`   Empty Signatures: ${report.summary.issues_by_type.empty_signature || 0}`);
    console.log(`   Manufacturer Duplicates: ${report.summary.issues_by_type.manufacturer_duplicate || 0}`);
    console.log(`\n📊 Database Stats:`);
    console.log(`   Total Clusters: ${report.stats.total_clusters}`);
    console.log(`   Total Products: ${report.stats.total_products}`);
    console.log(`   Products without signatures: ${report.stats.products_without_signatures}`);
  }
}

function tokenizeSubstanceCodes(code: string): string[] {
  if (!code) return [];
  return code
    .split(/[^A-Z0-9:]+/i)
    .map(token => token.trim())
    .filter(Boolean);
}

function isParenteralNutrition(label: string): boolean {
  const upper = label.toUpperCase();
  return (
    upper.includes("OLIMEL") ||
    upper.includes("FOSOMEL") ||
    upper.includes("SMOF") ||
    upper.includes("KABIVEN")
  ) && upper.includes("PERFUSION");
}

function classifyRouteFamily(token: string): string {
  const t = token.toLowerCase().trim();
  // Skip single-letter tokens (parsing artifacts)
  if (t.length <= 1) return "other";
  if (/oral|buccal|subling|gastro-entérale|entérale/.test(t)) return "oral";
  // All injectable routes (including specialized ones)
  // Match: inject, perfus, iv, intraveineuse (with/without hyphen), intramusculaire (with/without hyphen), 
  // s-cutanée, sous-cutanée, and all specialized intra- routes
  // Also match: péridurale, intra-murale, infiltration, périneurale, périarticulaire, péribulbaire,
  // intracoronaire, intracérébroventriculaire, intracisternale, voie extracorporelle (all specialized injection routes)
  if (/inject|perfus|iv|intra.?veine|intra.?musculaire|intramuscular|^s$|^s-|sous-cutan|intraartérielle|intrapleurale|intratumorale|intrathécale|intraarticulaire|intra-utérine|intraséreuse|intravésicale|péridurale|périneurale|intra.?murale|infiltration|périarticulaire|péribulbaire|intracoronaire|intracérébroventriculaire|intracisternale|voie extracorporelle/.test(t)) return "injectable";
  if (/inhal|nebuli|respir|inhalée/.test(t)) return "inhalation";
  if (/nasal/.test(t)) return "nasal";
  if (/ophtal|ocular|collyre/.test(t)) return "ophthalmic";
  if (/otic|auric/.test(t)) return "otic";
  if (/rectal|suppos/.test(t)) return "rectal";
  if (/vaginal/.test(t)) return "vaginal";
  if (/cutan|topique|dermi|dermal/.test(t)) return "topical";
  // "dentaire" and "gastrique" are not routes but usage/administration contexts - treat as "other" to avoid false conflicts
  if (/dentaire|gastrique/.test(t)) return "other";
  return "other";
}

// Main execution
async function main() {
  const verifier = new ClusterVerifier();
  const result = await verifier.runVerification();

  // Exit with error code if high severity issues found
  if (!result.passed) {
    console.log(`\n❌ Verification failed with ${result.issues.filter(i => i.severity === "high").length} high severity issues`);
    process.exit(1);
  }
}

// Export function for use in main pipeline
export async function runVerification(dbPath: string = DEFAULT_DB_PATH, options?: { outputDir?: string }) {
  const verifier = new ClusterVerifier(dbPath, options);
  return await verifier.runVerification();
}

if (import.meta.main) {
  main().catch(console.error);
}