import { describe, test, expect } from "bun:test";
import { isHomeopathic } from "../src/logic";
import { TestDbBuilder } from "./fixtures";
import type { Product } from "../src/types";

describe("Homeopathic Product Filtering", () => {
  describe("isHomeopathic function", () => {
    test("detects CH dilutions", () => {
      expect(isHomeopathic("ARNICA 5CH")).toBe(true);
      expect(isHomeopathic("Arnica 9CH granules")).toBe(true);
      expect(isHomeopathic("NUX VOMICA 15CH")).toBe(true);
    });

    test("detects DH dilutions", () => {
      expect(isHomeopathic("PULSATILLA 4DH")).toBe(true);
      expect(isHomeopathic("Selenium 12DH")).toBe(true);
      expect(isHomeopathic("Calcarea Carbonica 30DH")).toBe(true);
    });

    test("detects range dilutions", () => {
      expect(isHomeopathic("ACTAEA RACEMOSA 2CH à 30CH et 4DH à 60DH")).toBe(true);
      expect(isHomeopathic("Rhus Tox 4CH-30CH")).toBe(true);
    });

    test("detects Lehning/Boiron context", () => {
      expect(isHomeopathic("ABIES PECTINATA LEHNING, degré de dilution compris entre 2CH et 30CH")).toBe(true);
      expect(isHomeopathic("LEHNING product")).toBe(true);
      expect(isHomeopathic("BOIRON Arnica Montana 9CH")).toBe(true);
      expect(isHomeopathic("NUX VOMICA", "", "LEHNING")).toBe(true);
    });

    test("ignores non-homeopathic products", () => {
      expect(isHomeopathic("PARACETAMOL 500MG")).toBe(false);
      expect(isHomeopathic("IBUPROFENE 400mg")).toBe(false);
      expect(isHomeopathic("AMOXICILLINE 1g")).toBe(false);
    });

    test("handles edge cases", () => {
      expect(isHomeopathic("CHLORHYDRATE DE PROCAINE")).toBe(false); // Contains "CH" but not dilution
      expect(isHomeopathic("ACHETE 100mg")).toBe(false); // Contains "CH" but not dilution
      expect(isHomeopathic("DH WATER")).toBe(false); // Contains "DH" but not dilution
    });
  });

  describe("Integration with TestDbBuilder", () => {
    test("homeopathic products should be filterable in test data", () => {
      const builder = new TestDbBuilder();

      // Add a conventional product
      builder.addSpecialty("60000001", "PARACETAMOL 500mg", true, ["PARA"]);

      // Add homeopathic products
      builder.addSpecialty("60000002", "ARNICA 9CH", false, ["ARNI"]);
      builder.addSpecialty("60000003", "NUX VOMICA LEHNING 5CH", false, ["NUX"]);

      // Test our filtering logic
      const products = builder.getProducts();

      // Simulate filtering that would happen in pipeline
      const conventionalProducts = products.filter(p =>
        !isHomeopathic(p.label, "", "")
      );

      expect(conventionalProducts).toHaveLength(1);
      expect(conventionalProducts[0].label).toBe("PARACETAMOL 500mg");
    });
  });
});