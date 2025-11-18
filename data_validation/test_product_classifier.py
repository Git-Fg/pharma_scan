import sys
import unittest
from pathlib import Path

CURRENT_DIR = Path(__file__).resolve().parent
if str(CURRENT_DIR) not in sys.path:
    sys.path.insert(0, str(CURRENT_DIR))

from product_classifier import parse_medicament_name


class MedicamentParserTests(unittest.TestCase):
    def test_multi_dosage_and_formulation(self):
        sample = "ABACAVIR/LAMIVUDINE ACCORD 600 mg/300 mg, comprimé pelliculé"
        parsed = parse_medicament_name(sample)

        self.assertEqual(parsed["canonical_name"], "ABACAVIR/LAMIVUDINE")
        self.assertEqual(parsed["dosages"], ["600 mg", "300 mg"])
        self.assertEqual(parsed["formulation"], "comprimé pelliculé")

    def test_homeopathic_dilution_detection(self):
        sample = "A.D.N. BOIRON, degré de dilution compris entre 4CH et 30CH"
        parsed = parse_medicament_name(sample)

        self.assertEqual(parsed["canonical_name"], "A.D.N. BOIRON, degré de dilution compris entre et")
        self.assertEqual(parsed["dosages"], ["4CH", "30CH"])
        self.assertIsNone(parsed["formulation"])

    def test_laboratory_suffix_removed(self):
        sample = "IMATINIB TEVA 100 mg, comprimé pelliculé"
        parsed = parse_medicament_name(sample)

        self.assertEqual(parsed["canonical_name"], "IMATINIB")
        self.assertEqual(parsed["dosages"], ["100 mg"])
        self.assertEqual(parsed["formulation"], "comprimé pelliculé")

    def test_equivalency_statement(self):
        sample = "ACEBUTOLOL (CHLORHYDRATE DE) équivalant à ACEBUTOLOL 200 mg"
        parsed = parse_medicament_name(sample)

        self.assertEqual(
            parsed["canonical_name"],
            "ACEBUTOLOL (CHLORHYDRATE DE) équivalant à ACEBUTOLOL",
        )
        self.assertEqual(parsed["dosages"], ["200 mg"])

    def test_collyre_with_dual_units(self):
        sample = "BIMATOPROST/TIMOLOL BIOGARAN 0,3 mg/mL + 5 mg/mL, collyre en solution"
        parsed = parse_medicament_name(sample)

        self.assertEqual(parsed["canonical_name"], "BIMATOPROST/TIMOLOL")
        self.assertEqual(parsed["dosages"], ["0,3 mg/mL", "5 mg/mL"])
        self.assertEqual(parsed["formulation"], "collyre en solution")

    def test_par_ml_suffix_is_removed(self):
        sample = (
            "AMOXICILLINE ACIDE CLAVULANIQUE ALMUS 100 mg/12,5 mg par mL ENFANTS, "
            "poudre pour suspension buvable en flacon"
        )
        parsed = parse_medicament_name(sample)

        self.assertEqual(parsed["canonical_name"], "AMOXICILLINE ACIDE CLAVULANIQUE")
        self.assertEqual(parsed["dosages"], ["100 mg", "12,5 mg"])
        self.assertEqual(
            parsed["formulation"], "poudre pour suspension buvable en flacon"
        )

    def test_solution_lavage_case(self):
        sample = (
            "BORAX/ACIDE BORIQUE EG 12 mg/18 mg/ml, solution pour lavage ophtalmique en récipient unidose"
        )
        parsed = parse_medicament_name(sample)

        self.assertEqual(parsed["canonical_name"], "BORAX/ACIDE BORIQUE")
        self.assertEqual(parsed["dosages"], ["12 mg", "18 mg"])
        self.assertEqual(
            parsed["formulation"],
            "solution pour lavage ophtalmique en récipient unidose",
        )

    def test_percentage_only_strength(self):
        sample = "DUPHALAC 66,5 POUR CENT, solution buvable en flacon"
        parsed = parse_medicament_name(sample)

        self.assertEqual(parsed["canonical_name"], "DUPHALAC")
        self.assertEqual(parsed["dosages"], ["66,5 %"])
        self.assertEqual(parsed["formulation"], "solution buvable en flacon")

    def test_multiword_lab_suffix_removed(self):
        sample = "PREGABALINE VIATRIS PHARMA 150 mg, gélule"
        parsed = parse_medicament_name(sample)

        self.assertEqual(parsed["canonical_name"], "PREGABALINE")
        self.assertEqual(parsed["dosages"], ["150 mg"])
        self.assertEqual(parsed["formulation"], "gélule")

    def test_dual_dosage_with_lab_suffix(self):
        sample = (
            "PERINDOPRIL TOSILATE/INDAPAMIDE TEVA 5 mg/1,25 mg, comprimé pelliculé sécable"
        )
        parsed = parse_medicament_name(sample)

        self.assertEqual(parsed["canonical_name"], "PERINDOPRIL TOSILATE/INDAPAMIDE")
        self.assertEqual(parsed["dosages"], ["5 mg", "1,25 mg"])
        self.assertEqual(parsed["formulation"], "comprimé pelliculé sécable")

    def test_ratio_dosage_keeps_denominator_unit(self):
        sample = "LIDOCAINE ACCORD 10 mg/mL, solution injectable"
        parsed = parse_medicament_name(sample)

        self.assertEqual(parsed["canonical_name"], "LIDOCAINE")
        self.assertEqual(parsed["dosages"], ["10 mg/mL"])
        self.assertEqual(parsed["formulation"], "solution injectable")

    def test_lp_suffix_removes_lab_before_suffix(self):
        sample = "KETOPROFENE ARROW LP 100 mg, comprimé sécable à libération prolongée"
        parsed = parse_medicament_name(sample)

        self.assertEqual(parsed["canonical_name"], "KETOPROFENE LP")
        self.assertEqual(parsed["dosages"], ["100 mg"])
        self.assertEqual(
            parsed["formulation"], "comprimé sécable à libération prolongée"
        )

    def test_suffix_sans_conservateur_removed(self):
        sample = "XYLOCAINE 10 mg/ml SANS CONSERVATEUR, solution injectable"
        parsed = parse_medicament_name(sample)

        self.assertEqual(parsed["canonical_name"], "XYLOCAINE")
        self.assertEqual(parsed["dosages"], ["10 mg/ml"])
        self.assertEqual(parsed["formulation"], "solution injectable")

    def test_suffix_sans_sucre_removed_and_formulation_detected(self):
        sample = "NICORETTE FRUIT SANS SUCRE 2 mg, gomme à mâcher médicamenteuse"
        parsed = parse_medicament_name(sample)

        self.assertEqual(parsed["canonical_name"], "NICORETTE FRUIT SANS SUCRE")
        self.assertEqual(parsed["dosages"], ["2 mg"])
        self.assertEqual(
            parsed["formulation"], "gomme à mâcher médicamenteuse"
        )

    def test_par_expression_normalized_to_ratio(self):
        sample = "LIDOCAINE AGUETTANT 10 mg par ml, solution injectable"
        parsed = parse_medicament_name(sample)

        self.assertEqual(parsed["canonical_name"], "LIDOCAINE")
        self.assertEqual(parsed["dosages"], ["10 mg/ml"])
        self.assertEqual(parsed["formulation"], "solution injectable")

    def test_lab_suffix_removed_case_insensitive(self):
        sample = "CHLORHYDRATE DE LIDOCAINE Renaudin 10 mg/mL, solution injectable"
        parsed = parse_medicament_name(sample)

        self.assertEqual(parsed["canonical_name"], "CHLORHYDRATE DE LIDOCAINE")
        self.assertEqual(parsed["dosages"], ["10 mg/mL"])
        self.assertEqual(parsed["formulation"], "solution injectable")

    def test_formulation_extraction_from_mid_sentence(self):
        sample = "HEXTRIL 0,1 POUR CENT, bain de bouche, flacon"
        parsed = parse_medicament_name(sample)

        self.assertEqual(parsed["canonical_name"], "HEXTRIL")
        self.assertEqual(parsed["dosages"], ["0,1 %"])
        self.assertEqual(parsed["formulation"], "bain de bouche")

    def test_formulation_detection_with_long_phrase(self):
        sample = "BENDAMUSTINE ACCORD 2,5 mg/mL, poudre pour solution à diluer pour perfusion"
        parsed = parse_medicament_name(sample)

        self.assertEqual(parsed["canonical_name"], "BENDAMUSTINE")
        self.assertEqual(parsed["dosages"], ["2,5 mg/mL"])
        self.assertEqual(
            parsed["formulation"], "poudre pour solution à diluer pour perfusion"
        )

    def test_formulation_detection_removes_denominator_suffixes(self):
        sample = (
            "MOMETASONE ARROW 50 microgrammes/dose, suspension pour pulvérisation nasale"
        )
        parsed = parse_medicament_name(sample)

        self.assertEqual(parsed["canonical_name"], "MOMETASONE")
        self.assertEqual(parsed["dosages"], ["50 microgrammes/dose"])
        self.assertEqual(
            parsed["formulation"], "suspension pour pulvérisation nasale"
        )

    def test_passtille_formulation_removed_from_canonical(self):
        sample = "STREPSILS LIDOCAINE, pastille"
        parsed = parse_medicament_name(sample)

        self.assertEqual(parsed["canonical_name"], "STREPSILS LIDOCAINE")
        self.assertEqual(parsed["dosages"], [])
        self.assertEqual(parsed["formulation"], "pastille")

    def test_micronise_dosage_inferred(self):
        sample = "FENOFIBRATE FOURNIER 67 micronisé, gélule"
        parsed = parse_medicament_name(sample)

        self.assertEqual(parsed["canonical_name"], "FENOFIBRATE FOURNIER 67 micronisé")
        self.assertEqual(parsed["dosages"], ["67 mg"])
        self.assertEqual(parsed["formulation"], "gélule")


if __name__ == "__main__":
    unittest.main()

