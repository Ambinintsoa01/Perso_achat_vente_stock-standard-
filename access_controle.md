# Cassier(e)
Pour le/la caissier(e), les acces sont simples:
### 1. Effectuer la commande
### 2. Générer la facture
### 3. Valider la livraison
### 4. Valider le paiement

---

# Admin
Sur Excel, un commerçant passe son temps à saisir des lignes, calculer des formules qui finissent par casser, et il est incapable d'avoir une vision claire en 5 secondes sur son téléphone.

Voici exactement ce que l'administrateur (le patron de la boutique) a **réellement besoin de voir** pour chaque module, et les arguments « tueurs » face à Excel.

---

### 1. Module Vente & Caisse

#### Ce que le patron veut voir en un coup d'œil :

* **Le tiroir-caisse exact par moyen de paiement :**
* Combien en espèces (Cash) ?
* Combien sur MVola / Orange Money / Airtel Money ? *(Dans Excel, les marchands mélangent souvent l'argent liquide et leur solde Mobile Money personnel).*


* **Le bénéfice net de la journée (pas seulement le chiffre d'affaires) :**
* Exemple : *« Tu as encaissé 180 000 Ar aujourd'hui, dont 55 000 Ar de marge nette réelle. »*


* **Le carnet de dettes actives (« Alaina ambany maso ») :**
* Le total global de l'argent dehors.
* La liste des clients avec les dates de promesse de paiement dépassées.



#### Le vrai plus par rapport à Excel :

* **Verrouillage des prix et remises :** Dans Excel, un employé peut changer un chiffre en douce. Ton outil enregistre qui a vendu, à quelle heure, et alerte si une remise anormale a été accordée.
* **Génération de ticket immédiat :** Impression Bluetooth 58mm ou envoi d'un reçu WhatsApp en un clic.

---

### 2. Module Stock

#### Ce que le patron veut voir en un coup d'œil :

* **La valeur totale de sa boutique :**
* Combien d'argent dort sur les cintres (Valeur d'achat vs Valeur marchande).


* **Les alertes de rupture imminente :**
* *« T-shirt blanc taille L : reste 2 pièces »* (en rouge fluo en haut du tableau de bord).


* **Le stock dormant (le stock mort) :**
* Les articles entrés il y a plus de 45 jours et qui ne se vendent pas *(l'argent bloqué qu'il faut solder d'urgence)*.



#### Le vrai plus par rapport à Excel :

* **Décrémentation automatique infaillible :** Dans Excel, si tu vends, il faut penser à aller sur l'autre onglet soustraire 1. Personne ne le fait en plein rush, ce qui fausse tout le stock. Avec ton outil, **1 vente = -1 article instantané**.
* **Détection du coulage / vol :** Lors de l'inventaire mensuel, le patron clique sur un bouton : le logiciel compare le stock théorique et le stock compté, et affiche l'écart en Ariary (*ex: 3 t-shirts manquants = 45 000 Ar de perte inexpliquée*).

---

### 3. Module Achat & Approvisionnement

#### Ce que le patron veut voir en un coup d'œil :

* **L'historique des prix d'achat :**
* Voir comment le prix du fournisseur / grossiste a évolué (ex: la balle de t-shirts ou le paquet acheté 12 000 Ar le mois dernier est passé à 14 000 Ar).


* **Les dettes fournisseurs :**
* Combien il doit encore au grossiste ou au transporteur.


* **Conseil de réapprovisionnement :**
* Le top 5 des articles les plus rentables du mois qu'il faut absolument racheter.



#### Le vrai plus par rapport à Excel :

* **Calcul automatique du Coût Moyen Unitaire :** Quand il rachète le même modèle à des prix différents, le système recalcule automatiquement sa marge sans qu'il ait besoin de connaître des formules complexes.

---

### Le tableau de bord du patron : Le résumé en 4 cartes

Quand le patron ouvre l'application le soir, il ne doit pas voir des tableaux interminables, mais **4 indicateurs clés** :

| Carte | Donnée affichée | Pourquoi c'est vital pour lui |
| --- | --- | --- |
| **Caisse du jour** | Total encaissé (Détail Espèces / Mobile Money) | Faire sa clôture de caisse en 1 minute sans recompter 10 fois. |
| **Bénéfice du jour** | Marge brute réalisée aujourd'hui | Savoir s'il a gagné sa journée après avoir payé le loyer/salaires. |
| **Dettes à récupérer** | Montant total impayé + 3 clients en retard | Récupérer son argent avant qu'il ne soit trop tard. |
| **Alertes Stock** | Nombre de références proches de 0 | Savoir quoi recommander demain matin chez le grossiste. |

### L'argument massue face au client :

> *« Excel, c'est un carnet numérique qui attend que tu fasses les calculs. Mon application est un assistant qui te prévient quand un t-shirt va manquer, calcule ton bénéfice automatiquement à chaque vente, et te dit exactement combien d'argent tes clients te doivent sans que tu aies à feuilleter un cahier. »*