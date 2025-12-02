# PharmaScan 💊

<p align="center">
  <img src="https://github.com/user-attachments/assets/e3212341-9e88-4c8f-bcfc-d93a1324879a" height="300" alt="vide1">
  <img src="https://github.com/user-attachments/assets/26dd4b71-9646-4a4f-9a17-31af22504669" height="300" alt="vid3">
</p>

**L'assistant de poche pour le rangement et les équivalences.**

PharmaScan est un projet personnel, conçu pour combler des problèmes très spécifiques pour les étudiants en pharmacie et pharmaciens, particulièrement pour les petites et moyennes pharmacies où les boîtes sont triées en fonction des princeps dans les tiroirs.

En toute honnêteté, elle ne représente rien de révolutionnaire, mais j'avais envie de combler ce besoin un dimanche après-midi en voyant la pluie tomber, afin d'accélérer mon apprentissage des équivalences et d'arrêter de perdre du temps lors des réceptions de commandes.

## À quoi ça sert concrètement ?

L'idée est simple : fluidifier le flux de travail "Réception -> Rangement".

Elle permet de scanner rapidement et efficacement les codes Data Matrix GS1 des boîtes de médicaments, afin d'en afficher le **princeps lié** (le nom de marque original) sans avoir à cliquer sur un quelconque bouton. C'est l'outil idéal quand vous avez une boîte de *Générique X* en main et que vous devez la ranger dans le tiroir du *Princeps Y*.

En bonus, elle offre un accès direct vers :

- 📉 Les informations de rupture et tension (via la base officielle).
- 🔗 Les produits liés et les groupes génériques complets.
- 💶 Les prix et taux de remboursement.
- 📄 Les RCP (Résumé des Caractéristiques du Produit) via l'ANSM.

## Philosophie "Zéro Friction"

La plupart des applis demandent trop de clics. PharmaScan prend le contre-pied :

1. **Scanner "Always-On"** : La caméra reste active. Vous scannez une boîte, le résultat s'affiche, vous scannez la suivante. Pas besoin de fermer/rouvrir.
2. **Offline-First** : Tout est stocké en local sur votre téléphone. Ça marche au sous-sol, sans réseau, et c'est instantané.
3. **Zéro Pub / Zéro Télémétrie** : Vos données restent chez vous. Notamment, la télémétrie technique par défaut du scanner (Google ML Kit) a été désactivée manuellement.

## Comment ça marche (Techniquement)

Pour les curieux ou les devs qui passent par là, c'est une application Flutter qui tourne avec une base de données SQLite locale.

- **Source de données** : Base de Données Publique des Médicaments (BDPM - France).
- **Mise à jour** : L'appli télécharge les fichiers officiels, les nettoie, et reconstruit sa propre base optimisée pour la recherche (FTS5).
- **Architecture** : Conçue pour être robuste et maintenable (Riverpod, Drift, Shadcn UI).

## Installation

Le projet n'est pas (encore) sur les stores. C'est un outil open-source que vous pouvez compiler vous-même si vous avez l'âme d'un bricoleur.

```bash
# Pour les devs :
git clone https://github.com/votre-username/pharmascan.git
cd pharmascan
bash tool/run_session.sh
```

---

## Licence

Le code source de ce projet est distribué sous **Licence MIT**.

**Note sur les données :**
Les données de santé utilisées (BDPM) proviennent de l'ANSM et sont régies par la **Licence Ouverte v2.0 (Etalab)**.

---

*Ceci est un projet amateur développé sur mon temps libre. Bien que j'utilise les sources officielles (ANSM/BDPM), vérifiez toujours vos informations en cas de doute clinique.*
