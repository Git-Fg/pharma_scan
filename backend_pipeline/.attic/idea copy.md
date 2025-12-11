Parsing Opti Idea : 

- If a group has a princeps => use its clean name (the one from CIS_MITM, cleaned up to remove the ", form" which is then attributed as canonic name to all the cis group) + we can still leverage the value on the 2nd row of the CIS_GENER_bdpm to get either if there is common word after latest em dash the "guaranteed" princeps name or the secondary princeps name (still usefull for future app, we should keep it somewhere)
- If a group has no princeps => Parse the "reference princeps" from CIS_GENER_bdpm by using the logic which parse the elements after the latest em dash of the 2nd column (to get its clean name we could try to leverage the longest term in common from the parsed after latest em dash of every line which has type = 1 for "real" generic) which is then attributed to canonical name for all the group.

- reunite those groups as cluster, with parsing as relevant 

- if any doubt, use the value from CIS_COMPO_bdpm FT (specially for one-compound drugs) to make sure it's really the same thing


And obviously all the other table to use the most possible relational logic while handeling the inherent fragility of the structure of the data. 


For the metadata : 
- Shortage must be kept per presentation, but "liste 1", "liste 2"... can be generalized to all the different elements from the same group as long as once is there
- "hospitalier" "stupéfiant" ... should be generalized to all the cis group 
- dose and compond from a medication should be generalized to all the element of the group of type 0 and 1 princeps-generic (it's more difficult for other kind of equivalent)
- price should be kept per presentation, but we'll have a lot of null value : happens
- CIS_bdpm.txt :  4rd column should be used to attribute the "voie d'administration" to an entire CIS group
- keywords such as "DENTAIRE", "HOSPITALIER", "STUPEFIANT", "LISTE I", "LISTE II" ... should be taken from CIS_CPD_bdpm 2nd column
- CIS_COMPO_bdpm should be used to obtain the precise composition + dose of each CIS group (FT only)
- CIS_CIP_Dispo_Spec should be used to gather

---


Parsing opti (version finale) — garder toute l’info pertinente, aucune perte : documentation complète, pas un résumé.

1) Source principale : CIS_BDPM + logique de masque

- Appliquer la logique de masque sur tous les enregistrements CIS_BDPM dès le départ : c’est robuste et doit produire un nom canonique utilisable partout.
- Type 0 (princeps) présent dans le groupe : prendre le nom du princeps depuis CIS_BDPM, le nettoyer (enlever la partie ", forme") et l’appliquer comme nom canonique du groupe de CIS. Conserver aussi la valeur de la 2ᵉ colonne de CIS_GENER_bdpm : après le dernier em dash, on peut obtenir le princeps “garanti” ou un princeps secondaire utile plus tard (à stocker).
- Pas de type 0 : extraire le “princeps historique” en parsant ce qui suit le dernier em dash de la 2ᵉ colonne de CIS_GENER_bdpm. On peut tenter la logique de masque dessus si elle est applicable.
- Génériques : le nom générique le plus propre (sans labo) est dans CIS_GENER : prendre la partie la plus à gauche avant le premier em dash ; jamais de laboratoire, jamais commençant par le sel. À garder pour confirmer FT/FT+SA.

2) Hiérarchie cible (à respecter dans les données et les tests)

- Cluster : molécule ou combo (ex. clamoxyl = amoxicilline ; cosimprel = bisoprolol + perindopril).
- Group : un dosage/forme précis (ex. clamoxyl 500). Les id de groupes sont souvent colocalisés (ex. group 57 = aldactone 50 ; 58 = aldactone 75) → utile pour tests de cohérence.
- CIS : variantes commerciales d’un même group (ex. clamoxyl 500mg Sandoz vs autre labo).
- CIP : plaquette de 20 / 50 cp ...

3) Consolidation princeps et nommage

- Nom canonique du groupe : priorité au type 0 via CIS_BDPM (clean, sans “, forme”). Sinon princeps historique parsé après le dernier em dash de CIS_GENER. Toujours garder les deux pistes (masqué + brut) pour traçabilité. A croiser avec les différents médicaments qui ont exactement les mêmes composés ou combinaisons de composés pour confimer les clusters voir les groupe avec les dose normalisées. 
- Conserver toutes les infos candidates (princeps garanti, princeps secondaire, nom générique clean) pour usage futur et tests.
- Si doute : cross-check avec FT (CIS_COMPO_bdpm) surtout pour mono-composant.

4) Parsing composition / dosage / voie

- Utiliser CIS_COMPO_bdpm pour la composition et le dosage précis (FT uniquement).
- Utiliser la 4ᵉ colonne de CIS_bdpm.txt pour attribuer la voie d’administration à tout le groupe de CIS.
- Aider le parsing quantité/concentration avec la voie d’admin + regex / méthode stat pour regrouper tous les princeps exacts dans un même cluster, même si dosages/voies diffèrent.

5) Autres sources croisées

- CIS_MITM : utile pour princeps direct quand présent.
- CIS_GENER : sert pour génériques (partie gauche avant le premier em dash) et pour princeps historique (après le dernier em dash).
- CIS_CPD_bdpm : récupérer les mots-clés “DENTAIRE”, “HOSPITALIER”, “STUPEFIANT”, “LISTE I/II” …
- CIS_CIP_Dispo_Spec : disponibilité CIP par présentation.

6) Métadonnées et propagation

- Rupture (shortage) : conserver par présentation.
- “Liste 1/2…”, “stupéfiant”, “hospitalier” : généraliser à tout le groupe de CIS dès qu’un élément le porte.
- Dose/composition : généraliser à tout le groupe pour types 0 et 1 (princeps/générique). Plus délicat pour autres équivalences.
- Prix : conserver par présentation ; accepter les nombreuses valeurs nulles.

7) Stratégie de robustesse et tests

- Toujours privilégier la logique relationnelle entre tables pour compenser la fragilité des formats.
- Multiplier les chemins de parsing (CIS_BDPM masque, CIS_MITM direct, CIS_GENER princeps historique, FT via CIS_COMPO) et conserver toutes les variantes pour permettre des tests backend.
- Tests à prévoir : cohérence des id de groupes colocalisés, concordance des noms canoniques vs générique clean, vérification via FT pour mono-composant, contrôle des voies d’admin partagées par group/cluster.
