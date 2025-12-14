// Deprecated wrapper: re-export the implementation from `scripts/` to
// preserve backwards compatibility while the file is being moved.
// This file can be removed in a follow-up once callers have settled.
console.warn("Deprecation: 'tool/download_bdpm.ts' is deprecated; use 'scripts/download_bdpm.ts' instead.");
export { downloadBdpm } from "../scripts/download_bdpm";
