import type { Specialite, GroupMember } from "./types";

/**
 * Normalization utilities for Controlled Vocabulary
 */

// 1. FORMS NORMALIZATION
export function extractForms(specialites: Specialite[]): Set<string> {
    const forms = new Set<string>();
    for (const s of specialites) {
        if (s.formePharmaceutique && s.formePharmaceutique.trim()) {
            forms.add(s.formePharmaceutique.trim());
        }
    }
    return forms;
}

export function inferFormFromGroup(
    myCis: string,
    groupId: string,
    groupMembers: GroupMember[],
    cisToForm: Map<string, string>
): { formId: number | null; isInferred: boolean } {
    // If my form is known, no need to infer (but we need to resolve ID outside)
    // This function is called when form is missing or we want to validate

    // Find other members of the group
    const peers = groupMembers.filter(m => m.groupId === groupId && m.codeCip !== myCis); // logic check: groupMembers uses CIP, but we need CIS linkage?
    // Actually group definition links CIP to Group. Specialite links CIS to Form.
    // We need a map CIP -> CIS to look up forms of peers.

    // Complexity: GroupMember has CIP. Specialite has CIS.
    // We need to bridge: Group -> CIP -> CIS -> Form.

    return { formId: null, isInferred: false };
}

// 2. ROUTES NORMALIZATION
export function extractRoutes(specialites: Specialite[]): Set<string> {
    const routes = new Set<string>();
    for (const s of specialites) {
        if (s.voiesAdministration) {
            // Split by semicolon (e.g. "Orale; Rectale")
            const parts = s.voiesAdministration.split(";");
            for (const part of parts) {
                const trimmed = part.trim();
                if (trimmed) {
                    routes.add(trimmed);
                }
            }
        }
    }
    return routes;
}
