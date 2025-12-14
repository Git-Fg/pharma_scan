import { describe, expect, test } from "bun:test";
import { parseSafetyAlertsOptimized } from "../src/parsing";
import { ReferenceDatabase } from "../src/db";

function toAsync(rows: string[][]) {
  return (async function* () {
    for (const r of rows) yield r;
  })();
}

describe("Safety Alerts Parsing & DB", () => {
  test("parseSafetyAlertsOptimized deduplicates identical HTML alerts", async () => {
    const rows = [
      ["CIS00001", "2020-02-10", "2026-02-10", '<a href="https://ansm.sante.fr/notice1">Mycoph\u00e9nolate &eacute;</a>'],
      ["CIS00002", "2020-02-10", "2026-02-10", '<a href="https://ansm.sante.fr/notice1">Mycoph\u00e9nolate &eacute;</a>'],
      ["CIS00003", "2021-01-01", "2022-01-01", '<a href="https://ansm.sante.fr/notice2">Autre message</a>']
    ];

    const { alerts, links } = await parseSafetyAlertsOptimized(toAsync(rows));
    expect(alerts.length).toBe(2);
    expect(links.length).toBe(3);
    // First alert should be the duplicated one
    expect(alerts[0].url).toBe("https://ansm.sante.fr/notice1");
    expect(alerts[0].message).toContain("Mycoph");
  });

  test("DB insertion stores unique alerts and links", () => {
    const db = new ReferenceDatabase(":memory:");

    const alerts = [
      { message: "Alerte 1", url: "https://a/1", dateDebut: "2020-01-01", dateFin: "" },
      { message: "Alerte 2", url: "https://a/2", dateDebut: "2021-01-01", dateFin: "" }
    ];
    const links = [
      { cis: "CIS00001", alertIndex: 0 },
      { cis: "CIS00002", alertIndex: 0 },
      { cis: "CIS00003", alertIndex: 1 }
    ];

    // For this unit test we disable FK checks to simplify insertion of links
    db.db.run("PRAGMA foreign_keys = OFF;");
    db.insertSafetyAlerts(alerts, links);
    db.db.run("PRAGMA foreign_keys = ON;");

    const totalAlerts = db.db.query("SELECT COUNT(*) as c FROM safety_alerts").get() as { c: number };
    const totalLinks = db.db.query("SELECT COUNT(*) as c FROM cis_safety_links").get() as { c: number };

    expect(totalAlerts.c).toBe(2);
    expect(totalLinks.c).toBe(3);
  });
});
