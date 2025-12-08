<objective>
Perform a comprehensive global review of the project's documentation and rules structure to ensure proper organization and clear separation of concerns:

1. **AGENTS.md** should serve as the main entry point and be completely self-sufficient
2. **Cursor rules** (.cursor/rules/*.mdc) should act as specialist optimized rules that are general enough for any Flutter mobile project with best practices
3. **Documents** (docs/*.md) should act as project-specific AI agent rules with detailed domain knowledge

The goal is to create a clean, well-organized documentation hierarchy where each layer has distinct responsibilities and there's no overlap or confusion between different types of documentation.
</objective>

<context>
This is a Flutter application for pharmaceutical scanning and medication management with the following key characteristics:

**Tech Stack:**
- Flutter/Dart with Riverpod 3.0 for state management
- Drift (SQLite) for offline-first database
- Shadcn UI for components
- AutoRoute for navigation
- Dart Mappable for data serialization

**Project Structure:**
- AGENTS.md: Main agent manifesto with workflow phases and core principles
- .cursor/rules/: 14 specialized rule files covering different aspects (UI, data, architecture, QA, etc.)
- docs/: Architecture, domain logic, and maintenance documentation
- lib/features/: Feature-first organization with domain/presentation separation

**Current Documentation Issues to Review:**
- Potential overlap between AGENTS.md and cursor rules
- Cursor rules that might be too project-specific instead of generally applicable
- Domain knowledge that might be scattered across multiple files
- Unclear boundaries between different documentation layers

**Key Domain Concepts:**
- BDPM (Base de Données Publique des Médicaments) integration
- FTS5 search with trigram tokenization
- Extension Types for zero-cost abstraction
- Hybrid parsing strategy for medication data
- Generic grouping and clustering logic
</context>

<analysis_requirements>
Thoroughly analyze the current documentation structure and identify:

1. **Content Overlap Analysis:**
   - Review AGENTS.md for content that should be in cursor rules
   - Check cursor rules for project-specific content that should be in docs
   - Identify domain knowledge scattered across multiple files
   - Find conflicting information between different documentation sources

2. **Organization Assessment:**
   - Verify AGENTS.md is self-sufficient and serves as proper main entry point
   - Assess if cursor rules are general enough for any Flutter project
   - Check if docs/ contains project-specific AI agent rules as intended
   - Validate the separation of concerns between layers

3. **Content Categorization:**
   - General Flutter/Riverpod/Shadcn patterns → should be in cursor rules
   - Project-specific business logic → should be in docs
   - Agent persona and workflow → should be in AGENTS.md
   - Domain-specific knowledge (pharmaceutical/BDPM) → should be in docs

4. **Clarity and Completeness:**
   - Identify missing documentation
   - Check for outdated information
   - Verify cross-references are correct
   - Ensure consistency in terminology and patterns

**Review these key files:**
- AGENTS.md (main agent manifesto)
- .cursor/rules/*.mdc (specialist rules)
- docs/ARCHITECTURE.md, docs/DOMAIN_LOGIC.md, docs/MAINTENANCE.md
- Any other documentation files in the project
</analysis_requirements>

<recommendations>
Based on your analysis, provide specific recommendations for:

1. **Content Restructuring:**
   - What should be moved between files
   - What should be merged or split
   - What should be added or removed

2. **Organization Improvements:**
   - Better ways to separate concerns
   - Improved hierarchical structure
   - Clearer entry points and navigation

3. **Standardization:**
   - Consistent formatting and structure
   - Unified terminology
   - Clear cross-reference patterns

4. **Documentation Hierarchy:**
   - Ensure AGENTS.md is truly self-sufficient
   - Make cursor rules generally applicable Flutter patterns
   - Consolidate project-specific knowledge in docs/
</recommendations>

<output_format>
Create a comprehensive report with the following sections:

1. **Executive Summary** - Brief overview of current state and main findings
2. **Content Overlap Analysis** - Detailed mapping of overlapping content between files
3. **Organization Assessment** - Evaluation of current structure vs intended structure
4. **Specific Issues Found** - List of problems with exact file references and line numbers
5. **Restructuring Recommendations** - Step-by-step plan for moving/merging/splitting content
6. **Standardization Guidelines** - Rules for maintaining documentation consistency
7. **Implementation Plan** - Priority-ordered action items for implementing the changes

Save the analysis to: `./analysis/documentation_structure_review.md`

Include specific examples of problematic content and exact recommendations for fixes.
</output_format>

<verification>
Before completing the review, verify:

- All 14 cursor rules files have been analyzed
- All documentation in docs/ has been reviewed
- AGENTS.md has been thoroughly examined
- Cross-references between files have been checked
- Recommendations are actionable and specific
- Proposed structure aligns with the stated goals

Ensure the final report provides clear, concrete steps for achieving the desired documentation organization.
</verification>

<success_criteria>
The review is successful when:

1. **Clear Structure Mapping:** All content has been categorized into the three intended layers (agents, cursor rules, docs)
2. **Overlap Elimination:** No duplicate or conflicting content between files
3. **Proper Separation:** Each layer has distinct, non-overlapping responsibilities
4. **Self-Sufficiency:** AGENTS.md stands alone as the main entry point
5. **Reusability:** Cursor rules are general enough for any Flutter project
6. **Project Specificity:** docs/ contains all project-specific domain knowledge
7. **Actionable Plan:** Specific steps are provided to implement the restructuring
</success_criteria>