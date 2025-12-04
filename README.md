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

Elle permet de :

1. **Scanner & Analyser** : Identifier instantanément le **princeps lié** d'un générique pour savoir dans quel tiroir le ranger.
2. **Lister & Ranger (Nouveau)** : Scanner une caisse entière en rafale ("Bip-Bip-Bip") pour constituer une **liste de rangement intelligente**. Les produits sont automatiquement triés par ordre alphabétique de leur Princeps (ou de leur nom), transformant le vrac en une liste ordonnée.

En bonus, elle offre un accès direct vers :

- 📉 Les alertes de rupture/tension.
- 📄 Les RCP et notices officielles.

## Philosophie "Zéro Friction"

1. **Scanner "Always-On"** : La caméra ne s'arrête jamais. Changez de mode (Analyse ou Rangement) à la volée.
2. **Feedback Sensoriel** : Grâce aux retours haptiques (vibrations nuancées), vous savez si un produit est trouvé ou inconnu sans même regarder l'écran.
3. **Offline-First** : Tout est stocké en local (SQLite). Ça marche au sous-sol, c'est instantané.

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
