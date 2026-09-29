# Directives et Règles du Projet Perso_achat_vente_stock_standard

## 1. Règle Globale d'Affichage des Listes : Filtre de Date Obligatoire
- **Toutes les listes de données temporelles** (transactions, mouvements, commandes, factures, livraisons) dans tous les modules (Caisse, Stock, Achats, Ventes, Inventaires, etc.) **DOIVENT impérativement comporter un filtre de date**.
- Ce filtre doit proposer :
  1. Des raccourcis de période rapides :
     - **Tous** (aucun filtre de date)
     - **Aujourd'hui** (jour courant)
     - **7 jours** (7 derniers jours glissants)
     - **Ce mois** (du 1er au dernier jour du mois en cours)
  2. Un sélecteur de période personnalisée via `showDateRangePicker` ou sélecteur de calendrier.
  3. L'affichage clair de la période active avec possibilité de la réinitialiser (`✕`).
- Les services de données correspondants doivent accepter `DateTime? dateDebut` et `DateTime? dateFin` et filtrer les dates via `DATE(...) >= ? AND DATE(...) <= ?`.

## 2. Charte Graphique & UI
- Thème épuré Noir & Blanc contrasté (Cartes noires pour les totaux et synthèses, badges ronds d'état, boutons arrondis 12-16px).
- Robustesse responsive : toujours utiliser `FittedBox` sur les montants, `Flexible`/`Expanded` ou `Wrap` sur les lignes avec textes variables pour éviter tout overflow.
