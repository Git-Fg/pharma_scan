import path from 'path';
import fs from 'fs';
import { ReferenceDatabase } from './db';
import type { GroupMember } from './types';

// Import pipeline phases
import { runIngestion, validateIngestion } from './pipeline/01_ingestion';
import { runProfiling, validateProfiling } from './pipeline/02_profiling';
import { runElection, validateElection } from './pipeline/03_election';
import { runClustering, validateClustering } from './pipeline/04_clustering';
import { runNaming, validateNaming } from './pipeline/05_naming';
import { runIntegration, validateIntegration } from './pipeline/06_integration';
import { runSchemaExport, validateSchemaExport } from './pipeline/07_export_schema';

const DATA_DIR = process.env.DATA_DIR || './data';
const DB_PATH = process.env.DB_PATH || './output/reference.db';

interface ValidationReport {
    phase: string;
    issues: string[];
}

async function validatePipeline(reports: ValidationReport[]): Promise<boolean> {
    const allIssues = reports.flatMap(r => r.issues);

    if (allIssues.length > 0) {
        console.error('\n❌ VALIDATION FAILED:');
        allIssues.forEach(i => console.error(`  - ${i}`));
        return false;
    }

    console.log('\n✅ All validations passed');
    return true;
}

async function main() {
    console.log('🚀 Starting PharmaScan Backend Pipeline\n');

    const validationReports: ValidationReport[] = [];

    try {
        // Phase 1: Ingestion
        const ingestion = await runIngestion(DATA_DIR, path.join(process.cwd(), 'wip_bdpm', 'output'));
        validationReports.push(validateIngestion(ingestion));

        // Phase 2: Chemical Profiling
        const profiling = await runProfiling(ingestion.cisData, DATA_DIR);
        validationReports.push(validateProfiling(profiling));

        // Phase 3: Princeps Election
        const election = await runElection(ingestion.cisData, ingestion.generData);
        validationReports.push(validateElection(election));

        // Phase 4: Chemical Clustering
        const clustering = await runClustering(ingestion.generData, profiling.profiles);
        validationReports.push(validateClustering(clustering));

        // Phase 5: LCS Naming
        const naming = await runNaming(clustering.superClusters, election.elections);
        validationReports.push(validateNaming(naming));

        // Phase 6: Orphan Integration
        const integration = await runIntegration(
            naming.namedClusters,
            ingestion.cisData,
            profiling.profiles,
            election.elections
        );
        validationReports.push(validateIntegration(integration));

        // Phase 7: Schema Export (NEW)
        const schemaExportPath = path.join(process.cwd(), 'output');
        const schemaResult = await runSchemaExport(DB_PATH, schemaExportPath);
        validationReports.push(validateSchemaExport(schemaResult));

        // Run validation
        const validationPassed = await validatePipeline(validationReports);

        if (!validationPassed) {
            console.error('\n⚠️  Pipeline completed with validation warnings');
            process.exit(1);
        }

        // Initialize database and persist results
        console.log('\n💾 Persisting to database...');

        // Ensure clean state
        if (fs.existsSync(DB_PATH)) {
            console.log('   (Removing old database)');
            fs.rmSync(DB_PATH, { force: true });
            // Wait for filesystem to sync to prevent SQLITE_IOERR_SHORT_READ
            await new Promise(resolve => setTimeout(resolve, 200));
        }

        const db = new ReferenceDatabase(DB_PATH);
        db.disableForeignKeys();

        // 0. Extract and Insert Laboratories (Dependencies: None)
        const uniqueLabs = Array.from(new Set(ingestion.cisData.map(c => c.lab).filter(l => l && l.trim() !== ''))).sort();

        // Insert "Unknown" lab at ID 0 just in case
        db.insertLaboratories([{ id: 0, name: "INCONNU" }]);
        // Insert parsed labs
        db.insertLaboratories(uniqueLabs.map(name => ({ name })));

        const labMap = db.getLaboratoryMap();
        const unknownLabId = labMap.get("INCONNU") || 0;

        // 1. Insert Specialites (Filter out Homeopathy)
        const validCisSet = new Set<string>();
        const specialites = ingestion.cisData
            .filter(c => !c.isHomeo && c.cis && c.cis.trim().length > 0)
            .map(c => {
                validCisSet.add(c.cis);
                return {
                    cisCode: c.cis,
                    nomSpecialite: c.originalName,
                    formePharmaceutique: c.shape,
                    voiesAdministration: c.voies,
                    statutAdministratif: c.status,
                    procedureType: c.procedure,
                    etatCommercialisation: c.commercialStatus,
                    dateAmm: c.dateAmm,
                    titulaireId: labMap.get(c.lab) ?? unknownLabId,
                    isSurveillance: c.isSurveillance,
                    conditionsPrescription: '',
                    atcCode: ''
                };
            });
        db.insertSpecialites(specialites);

        // 2. Populate Summary (Dependencies: Specialites)
        db.populateMedicamentSummary();
        db.updateMedicamentSummaryPrinciples(profiling.profiles);

        // 3. Insert Generic Groups
        // Deduplicate groups by ID
        const uniqueGroups = Array.from(new Map(ingestion.generData.map(g => [g.groupId, g])).values());
        const generics = uniqueGroups.map(g => ({
            groupId: g.groupId,
            libelle: g.groupLabel,
            princepsLabel: '',
            moleculeLabel: '',
            rawLabel: g.groupLabel,
            parsingMethod: 'BDPM'
        }));
        db.insertGeneriqueGroups(generics);

        // 4. Insert Group Members
        const cisToCips = new Map<string, string[]>();
        ingestion.cipData.forEach(cip => {
            if (!cisToCips.has(cip.cis)) cisToCips.set(cip.cis, []);
            cisToCips.get(cip.cis)?.push(cip.cip13 || cip.cip7);
        });

        const expandedMembers: GroupMember[] = [];
        ingestion.generData.forEach(g => {
            // Only add members if the CIS is valid (non-homeo)
            if (validCisSet.has(g.cis)) {
                const cips = cisToCips.get(g.cis) || [];
                const typeNum = parseInt(g.type, 10) || 0;
                cips.forEach(cip => {
                    expandedMembers.push({
                        codeCip: cip,
                        groupId: g.groupId,
                        type: typeNum,
                        sortOrder: parseInt(g.sortOrder) || 0
                    });
                });
            }
        });
        db.insertGroupMembers(expandedMembers);


        // 5. Insert Medicaments (CIPs)
        db.insertMedicaments(ingestion.cipData
            .filter(c => validCisSet.has(c.cis))
            .map(c => ({
                codeCip: c.cip13 || c.cip7,
                cisCode: c.cis,
                presentationLabel: c.presentationLabel,
                commercialisationStatut: c.commercialisationStatus,
                tauxRemboursement: c.tauxRemboursement,
                prixPublic: c.priceFormatted ?? undefined,
                agrementCollectivites: c.agrement,
                isHospital: 0 // Computed
            })));

        // 6. Persist Clusters
        db.insertFinalClusters(integration.finalClusters);

        db.populateProductScanCache();
        db.refreshMaterializedViews();
        db.enableForeignKeys();
        console.log('\n✨ Pipeline Completed Successfully!');
        console.log(`   - Total clusters: ${integration.finalClusters.length}`);
        console.log(`   - Orphans attached: ${integration.orphansAttached}`);
        console.log(`   - Total CIS processed: ${ingestion.cisData.length}`);

    } catch (error) {
        console.error('\n❌ Pipeline Failed:', error);
        process.exit(1);
    }
}

main().catch((err) => {
    console.error('❌ Unhandled Error:', err);
    process.exit(1);
});
