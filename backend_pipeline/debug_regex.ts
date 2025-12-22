
const names = [
  "ABILIFY 1 mg/mL",
  "ABRAXANE 5 mg/mL",
  "ABRAXANE 5mg/ml",
  "ABECMA 260 - 500 x 1 000 000 cellules",
  "DOBUTAMINE PANPHARMA 12,5 mg/mL, solution pour perfusion", // Decimals with comma
  "DOLIPRANE 1000 mg, comprimé",
  "ADVIL 400 mg",
  "EFFERALGAN 1 g",
  "CLAMOXYL 500 mg",
  "TEST 1 000 UI",
  "TEST 1,5 g",
  "TEST 260-500", // Range without unit?
  "FENTANYL 12 µg/h"
];

function cleanProductName(name: string): string {
  if (!name) return "";

  let conceptName = name;
  if (name.includes(',')) {
    // Smart split: Split usually at ", " or ",[a-z]"
    // Avoid splitting "1,5" (digit,digit)

    const parts = name.split(/,(?=\s)/); // Simple check: Comma followed by space?

    // What if "DOLIPRANE 1000mg,comprimé"? (No space)
    // Usually BDPM has space.

    conceptName = parts[0];
  }

  // Regex patterns
  // Number: digits, maybe decimal with dot or comma, maybe space separators
  const numberPat = "(?:\\d+(?:[.,]\\d+)?(?:\\s\\d+)*)";

  // Unit: extensive list
  const unitPat = "(?:mg|g|ml|l|ui|u\\.i\\.|cp|µg|mcg|cellules|unités|millions|%|dose|h)(?:\\/[a-z0-9]+)*";

  // Separator: - or x
  const sepPat = "[-x]";

  // Build a "Tail Pattern" that matches a sequence of these items at the end of the string.
  // Must start with a space to avoid cutting inside a word.
  // Chain = \s+ TOKEN ( \s* TOKEN )* $

  const token = `(?:${numberPat}|${unitPat}|${sepPat})`;
  const tailRegexSource = `(?:\\s+${token}(?:\\s*${token})*)$`;

  const tailRegex = new RegExp(tailRegexSource, 'i');

  let cleaned = conceptName.replace(tailRegex, '').trim();

  console.log(`'${name}' \n   -> Split: '${conceptName}' \n   -> Clean: '${cleaned}'`);
  return cleaned;
}

names.forEach(cleanProductName);
