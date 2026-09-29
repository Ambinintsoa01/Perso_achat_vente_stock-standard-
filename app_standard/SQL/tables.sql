-- =============================================================================
-- BASE DE DONNÉES SQLite : GESTION DES ACHATS, VENTES, STOCKS & TRÉSORERIE
-- Conforme aux spécifications access_controle.md & Design System standardisé
-- =============================================================================

PRAGMA foreign_keys = ON;

-- -----------------------------------------------------------------------------
-- 1. TABLES DE RÉFÉRENCE & PARAMÉTRAGE (LOOKUP TABLES)
-- -----------------------------------------------------------------------------

-- Profils d'utilisateurs (Gestion des rôles & droits d'accès)
CREATE TABLE profil (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero INTEGER NOT NULL UNIQUE,     -- 1: ADMIN, 11: CAISSIER, 21: MAGASINIER
    code TEXT NOT NULL UNIQUE,          -- 'ADMIN', 'CAISSIER', 'MAGASINIER'
    libelle TEXT NOT NULL,
    description TEXT,
    actif INTEGER DEFAULT 1
);

-- Table des utilisateurs associés à un profil
CREATE TABLE utilisateur (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    id_profil INTEGER NOT NULL REFERENCES profil(id) ON DELETE RESTRICT,
    nom TEXT NOT NULL,
    prenom TEXT,
    email TEXT UNIQUE,
    telephone TEXT,
    nom_utilisateur TEXT NOT NULL UNIQUE,
    mot_de_passe_hash TEXT NOT NULL,
    actif INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
);

-- Statuts des documents (achats, ventes, règlements, livraisons)
CREATE TABLE statut (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero INTEGER NOT NULL UNIQUE,     -- 1: créé, 11: validé, 21: annulé, 31: partiel, 41: terminé/soldé
    code TEXT NOT NULL UNIQUE,
    libelle TEXT NOT NULL,
    description TEXT
);

-- Modes de paiement (Espèces, Virement, Chèque, MVola, Orange Money, Airtel Money, Carte)
CREATE TABLE mode_paiement (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero INTEGER NOT NULL UNIQUE,     -- 1: ESPECES, 11: VIREMENT, 21: CHEQUE, 31: MVOLA, 41: ORANGE_MONEY, 51: AIRTEL_MONEY, 61: CARTE
    code TEXT NOT NULL UNIQUE,
    libelle TEXT NOT NULL,
    actif INTEGER DEFAULT 1
);

-- Types de caisses / comptes de trésorerie
CREATE TABLE type_caisse (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero INTEGER NOT NULL UNIQUE,     -- 1: CAISSE_PHYSIQUE, 11: BANQUE, 21: MOBILE_MONEY
    code TEXT NOT NULL UNIQUE,
    libelle TEXT NOT NULL
);

-- Types de mouvements de stock
CREATE TABLE type_mouvement_stock (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero INTEGER NOT NULL UNIQUE,     -- 1: ENTREE_ACHAT, 11: SORTIE_VENTE, 21: AJUSTEMENT_POS, 31: AJUSTEMENT_NEG, etc.
    code TEXT NOT NULL UNIQUE,
    libelle TEXT NOT NULL,
    sens INTEGER NOT NULL CHECK (sens IN (1, -1)), -- +1: Entrée, -1: Sortie
    actif INTEGER DEFAULT 1
);

-- Types de mouvements de caisse / trésorerie
CREATE TABLE type_mouvement_caisse (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero INTEGER NOT NULL UNIQUE,     -- 1: ENCAISSEMENT_VENTE, 11: DECAISSEMENT_ACHAT, 21: TRANSFERT_DEBIT, 31: TRANSFERT_CREDIT, etc.
    code TEXT NOT NULL UNIQUE,
    libelle TEXT NOT NULL,
    sens INTEGER NOT NULL CHECK (sens IN (1, -1)), -- +1: Entrée d'argent, -1: Sortie d'argent
    actif INTEGER DEFAULT 1
);

-- Types de clients
CREATE TABLE type_client (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero INTEGER NOT NULL UNIQUE,     -- 1: PARTICULIER, 11: ENTREPRISE, 21: AUTRE
    code TEXT NOT NULL UNIQUE,
    libelle TEXT NOT NULL
);

-- Devises monétaires
CREATE TABLE devise (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero INTEGER NOT NULL UNIQUE,     -- 1: MGA, 11: EUR, 21: USD
    code TEXT NOT NULL UNIQUE,
    libelle TEXT NOT NULL,
    symbole TEXT DEFAULT 'Ar',
    actif INTEGER DEFAULT 1
);

-- Catégories d'articles (avec support hiérarchique)
CREATE TABLE categorie (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    nom TEXT NOT NULL,
    description TEXT,
    id_parent INTEGER REFERENCES categorie(id) ON DELETE SET NULL,
    actif INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
);

-- Unités de mesure
CREATE TABLE unite_mesure (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,          -- U, KG, L, CRT, M
    nom TEXT NOT NULL,
    actif INTEGER DEFAULT 1
);

-- Dépôts / Magasins de stockage
CREATE TABLE depot (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    nom TEXT NOT NULL,
    adresse TEXT,
    telephone TEXT,
    actif INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
);

-- Articles / Produits
CREATE TABLE article (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    reference TEXT NOT NULL UNIQUE,
    code_barre TEXT UNIQUE,
    designation TEXT NOT NULL,
    description TEXT,
    image_url TEXT,
    id_categorie INTEGER REFERENCES categorie(id) ON DELETE RESTRICT,
    id_unite INTEGER REFERENCES unite_mesure(id) ON DELETE RESTRICT,
    prix_achat_estime REAL DEFAULT 0.00,
    cout_moyen_unitaire REAL DEFAULT 0.00, -- CUMP calculé automatiquement
    prix_vente_standard REAL DEFAULT 0.00,
    taux_tva REAL DEFAULT 20.00,
    seuil_alerte_stock REAL DEFAULT 0.000,
    suivi_stock INTEGER DEFAULT 1,      -- 1: Oui, 0: Non (prestation)
    actif INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (DATETIME('now', 'localtime')),
    updated_at TEXT DEFAULT (DATETIME('now', 'localtime'))
);

-- -----------------------------------------------------------------------------
-- 2. TIERS (Fournisseurs & Clients)
-- -----------------------------------------------------------------------------

CREATE TABLE fournisseur (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    raison_sociale TEXT NOT NULL,
    nom_contact TEXT,
    telephone TEXT,
    email TEXT,
    adresse TEXT,
    ville TEXT,
    nif TEXT,
    stat TEXT,
    delai_paiement_jours INTEGER DEFAULT 30,
    actif INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
);

CREATE TABLE client (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    nom_complet TEXT NOT NULL,
    id_type_client INTEGER NOT NULL REFERENCES type_client(id) ON DELETE RESTRICT,
    telephone TEXT,
    email TEXT,
    adresse TEXT,
    ville TEXT,
    nif TEXT,
    stat TEXT,
    solde_credit_max REAL DEFAULT 0.00,
    actif INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
);

-- -----------------------------------------------------------------------------
-- 3. GESTION MULTI-CAISSE & TRÉSORERIE
-- (Espèces, Banque, MVola, Orange Money, Airtel Money)
-- -----------------------------------------------------------------------------

CREATE TABLE caisse (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,              -- ex: 'CSH-01', 'BNI-MGA', 'MVOLA-01'
    nom TEXT NOT NULL,                    -- ex: 'Tiroir-Caisse Espèces', 'Compte BNI', 'MVola Boutique'
    id_type_caisse INTEGER NOT NULL REFERENCES type_caisse(id) ON DELETE RESTRICT,
    numero_compte TEXT,                    -- IBAN, RIB ou numéro mobile money
    solde_initial REAL DEFAULT 0.00,
    solde_actuel REAL DEFAULT 0.00,
    id_devise INTEGER NOT NULL REFERENCES devise(id) ON DELETE RESTRICT,
    actif INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
);

CREATE TABLE mouvement_caisse (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    id_caisse INTEGER NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,
    id_type_mouvement INTEGER NOT NULL REFERENCES type_mouvement_caisse(id) ON DELETE RESTRICT,
    id_mode_paiement INTEGER NOT NULL REFERENCES mode_paiement(id) ON DELETE RESTRICT,
    id_utilisateur INTEGER REFERENCES utilisateur(id) ON DELETE SET NULL, -- Traçabilité : qui a opéré
    id_journal_caisse INTEGER REFERENCES journal_caisse(id) ON DELETE SET NULL, -- Rattachement au journal de caisse
    montant REAL NOT NULL CHECK (montant > 0),
    solde_avant REAL NOT NULL,
    solde_apres REAL NOT NULL,
    date_mouvement TEXT DEFAULT (DATETIME('now', 'localtime')),
    reference_piece TEXT,
    description TEXT,
    created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
);

CREATE TABLE transfert_caisse (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero_transfert TEXT NOT NULL UNIQUE,  -- ex: TRF-2026-0001
    id_caisse_source INTEGER NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,
    id_caisse_destination INTEGER NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,
    montant REAL NOT NULL CHECK (montant > 0),
    frais_transfert REAL DEFAULT 0.00,      -- Frais de retrait / transfert opérateur
    id_statut INTEGER NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    id_utilisateur INTEGER REFERENCES utilisateur(id) ON DELETE SET NULL,
    date_transfert TEXT DEFAULT (DATETIME('now', 'localtime')),
    motif TEXT,
    created_at TEXT DEFAULT (DATETIME('now', 'localtime')),
    CONSTRAINT chk_transfert_caisses_distinctes CHECK (id_caisse_source <> id_caisse_destination)
);

-- -----------------------------------------------------------------------------
-- 3.1 JOURNAL DE CAISSE (Sessions journalières : Ouverture matin, Clôture soir)
-- -----------------------------------------------------------------------------

CREATE TABLE journal_caisse (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero_journal TEXT NOT NULL UNIQUE,     -- ex: 'JRN-20260929-001'
    date_journal TEXT NOT NULL,              -- Date du jour 'YYYY-MM-DD'
    date_ouverture TEXT NOT NULL DEFAULT (DATETIME('now', 'localtime')),
    date_fermeture TEXT,                     -- Horodatage de la clôture du soir
    id_utilisateur_ouverture INTEGER NOT NULL REFERENCES utilisateur(id) ON DELETE RESTRICT,
    id_utilisateur_fermeture INTEGER REFERENCES utilisateur(id) ON DELETE RESTRICT,
    solde_ouverture_total REAL NOT NULL DEFAULT 0.00,  -- Somme des soldes d'ouverture
    total_entrees REAL DEFAULT 0.00,                   -- Total encaissé dans la journée
    total_sorties REAL DEFAULT 0.00,                   -- Total décaissé dans la journée
    solde_theorique_total REAL DEFAULT 0.00,           -- Ouverture + Entrées - Sorties
    solde_reel_total REAL DEFAULT 0.00,                -- Montant physique réel compté le soir
    ecart_total REAL DEFAULT 0.00,                     -- Réel - Théorique
    statut TEXT NOT NULL DEFAULT 'OUVERT' CHECK (statut IN ('OUVERT', 'CLOTURE')),
    notes_ouverture TEXT,
    notes_fermeture TEXT,
    created_at TEXT DEFAULT (DATETIME('now', 'localtime')),
    updated_at TEXT DEFAULT (DATETIME('now', 'localtime'))
);

CREATE TABLE journal_caisse_ligne (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    id_journal_caisse INTEGER NOT NULL REFERENCES journal_caisse(id) ON DELETE CASCADE,
    id_caisse INTEGER NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,
    solde_ouverture REAL NOT NULL DEFAULT 0.00,    -- Solde de clôture de la veille (report) ou solde initial
    total_entrees REAL DEFAULT 0.00,               -- Total entrées de la journée sur ce compte
    total_sorties REAL DEFAULT 0.00,               -- Total sorties de la journée sur ce compte
    solde_theorique REAL DEFAULT 0.00,             -- solde_ouverture + total_entrees - total_sorties
    solde_reel REAL,                               -- Montant compté / constaté le soir à la fermeture
    ecart REAL DEFAULT 0.00,                       -- solde_reel - solde_theorique
    notes TEXT,
    CONSTRAINT uq_journal_caisse_ligne UNIQUE (id_journal_caisse, id_caisse)
);

-- -----------------------------------------------------------------------------
-- 4. WORKFLOW ACHAT (Fournisseurs)
-- -----------------------------------------------------------------------------

CREATE TABLE commande_achat (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero_commande TEXT NOT NULL UNIQUE,   -- ex: BCA-2026-0001
    id_fournisseur INTEGER NOT NULL REFERENCES fournisseur(id) ON DELETE RESTRICT,
    id_depot_destination INTEGER NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    id_statut INTEGER NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    id_utilisateur INTEGER REFERENCES utilisateur(id) ON DELETE SET NULL,
    date_commande TEXT DEFAULT (DATE('now', 'localtime')),
    date_livraison_prevue TEXT,
    montant_ht REAL DEFAULT 0.00,
    montant_tva REAL DEFAULT 0.00,
    montant_ttc REAL DEFAULT 0.00,
    remarques TEXT,
    created_at TEXT DEFAULT (DATETIME('now', 'localtime')),
    updated_at TEXT DEFAULT (DATETIME('now', 'localtime'))
);

CREATE TABLE commande_achat_ligne (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    id_commande_achat INTEGER NOT NULL REFERENCES commande_achat(id) ON DELETE CASCADE,
    id_article INTEGER NOT NULL REFERENCES article(id) ON DELETE RESTRICT,
    quantite_commandee REAL NOT NULL CHECK (quantite_commandee > 0),
    quantite_recue REAL DEFAULT 0.000 CHECK (quantite_recue >= 0),
    prix_unitaire_ht REAL NOT NULL CHECK (prix_unitaire_ht >= 0),
    taux_remise REAL DEFAULT 0.00,
    taux_tva REAL DEFAULT 20.00,
    montant_ht REAL NOT NULL,
    montant_ttc REAL NOT NULL
);

CREATE TABLE reception_achat (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero_reception TEXT NOT NULL UNIQUE,  -- ex: BRA-2026-0001
    id_commande_achat INTEGER REFERENCES commande_achat(id) ON DELETE SET NULL,
    id_fournisseur INTEGER NOT NULL REFERENCES fournisseur(id) ON DELETE RESTRICT,
    id_depot INTEGER NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    id_statut INTEGER NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    id_utilisateur INTEGER REFERENCES utilisateur(id) ON DELETE SET NULL,
    date_reception TEXT DEFAULT (DATETIME('now', 'localtime')),
    numero_bon_fournisseur TEXT,
    notes TEXT,
    created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
);

CREATE TABLE reception_achat_ligne (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    id_reception INTEGER NOT NULL REFERENCES reception_achat(id) ON DELETE CASCADE,
    id_commande_achat_ligne INTEGER REFERENCES commande_achat_ligne(id) ON DELETE SET NULL,
    id_article INTEGER NOT NULL REFERENCES article(id) ON DELETE RESTRICT,
    quantite_recue REAL NOT NULL CHECK (quantite_recue > 0),
    prix_achat_unitaire_ht REAL NOT NULL
);

CREATE TABLE facture_fournisseur (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero_facture TEXT NOT NULL UNIQUE,
    id_fournisseur INTEGER NOT NULL REFERENCES fournisseur(id) ON DELETE RESTRICT,
    id_commande_achat INTEGER REFERENCES commande_achat(id) ON DELETE SET NULL,
    id_statut INTEGER NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    date_facture TEXT DEFAULT (DATE('now', 'localtime')),
    date_echeance TEXT,
    montant_ht REAL DEFAULT 0.00,
    montant_tva REAL DEFAULT 0.00,
    montant_ttc REAL DEFAULT 0.00,
    montant_paye REAL DEFAULT 0.00,
    created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
);

CREATE TABLE paiement_achat (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero_paiement TEXT NOT NULL UNIQUE,   -- ex: PA-2026-0001
    id_facture_fournisseur INTEGER NOT NULL REFERENCES facture_fournisseur(id) ON DELETE RESTRICT,
    id_caisse INTEGER NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,
    id_mode_paiement INTEGER NOT NULL REFERENCES mode_paiement(id) ON DELETE RESTRICT,
    id_utilisateur INTEGER REFERENCES utilisateur(id) ON DELETE SET NULL,
    date_paiement TEXT DEFAULT (DATE('now', 'localtime')),
    montant REAL NOT NULL CHECK (montant > 0),
    reference_transaction TEXT,
    notes TEXT,
    created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
);

-- -----------------------------------------------------------------------------
-- 5. WORKFLOW VENTE (Clients)
-- -----------------------------------------------------------------------------

CREATE TABLE devis_vente (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero_devis TEXT NOT NULL UNIQUE,      -- ex: DEV-2026-0001
    id_client INTEGER NOT NULL REFERENCES client(id) ON DELETE RESTRICT,
    id_statut INTEGER NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    id_utilisateur INTEGER REFERENCES utilisateur(id) ON DELETE SET NULL,
    date_devis TEXT DEFAULT (DATE('now', 'localtime')),
    date_validite TEXT,
    montant_ht REAL DEFAULT 0.00,
    montant_tva REAL DEFAULT 0.00,
    montant_ttc REAL DEFAULT 0.00,
    conditions TEXT,
    created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
);

CREATE TABLE devis_vente_ligne (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    id_devis INTEGER NOT NULL REFERENCES devis_vente(id) ON DELETE CASCADE,
    id_article INTEGER NOT NULL REFERENCES article(id) ON DELETE RESTRICT,
    quantite REAL NOT NULL CHECK (quantite > 0),
    prix_unitaire_ht REAL NOT NULL CHECK (prix_unitaire_ht >= 0),
    taux_remise REAL DEFAULT 0.00,
    taux_tva REAL DEFAULT 20.00,
    montant_ht REAL NOT NULL,
    montant_ttc REAL NOT NULL
);

CREATE TABLE commande_vente (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero_commande TEXT NOT NULL UNIQUE,   -- ex: BCV-2026-0001
    id_client INTEGER NOT NULL REFERENCES client(id) ON DELETE RESTRICT,
    id_devis INTEGER REFERENCES devis_vente(id) ON DELETE SET NULL,
    id_depot_source INTEGER NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    id_statut INTEGER NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    id_utilisateur INTEGER REFERENCES utilisateur(id) ON DELETE SET NULL, -- Caissier qui a pris la commande
    date_commande TEXT DEFAULT (DATE('now', 'localtime')),
    date_livraison_souhaitee TEXT,
    montant_ht REAL DEFAULT 0.00,
    montant_tva REAL DEFAULT 0.00,
    montant_ttc REAL DEFAULT 0.00,
    marge_brute REAL DEFAULT 0.00,         -- Calcul automatique du bénéfice pour le patron
    notes TEXT,
    created_at TEXT DEFAULT (DATETIME('now', 'localtime')),
    updated_at TEXT DEFAULT (DATETIME('now', 'localtime'))
);

CREATE TABLE commande_vente_ligne (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    id_commande_vente INTEGER NOT NULL REFERENCES commande_vente(id) ON DELETE CASCADE,
    id_article INTEGER NOT NULL REFERENCES article(id) ON DELETE RESTRICT,
    quantite_commandee REAL NOT NULL CHECK (quantite_commandee > 0),
    quantite_livree REAL DEFAULT 0.000 CHECK (quantite_livree >= 0),
    prix_unitaire_ht REAL NOT NULL CHECK (prix_unitaire_ht >= 0),
    cout_unitaire_achat REAL DEFAULT 0.00, -- Coût figé au moment de la vente pour marge nette
    taux_remise REAL DEFAULT 0.00,
    taux_tva REAL DEFAULT 20.00,
    montant_ht REAL NOT NULL,
    montant_ttc REAL NOT NULL
);

CREATE TABLE livraison_vente (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero_livraison TEXT NOT NULL UNIQUE,  -- ex: BLV-2026-0001
    id_commande_vente INTEGER REFERENCES commande_vente(id) ON DELETE SET NULL,
    id_client INTEGER NOT NULL REFERENCES client(id) ON DELETE RESTRICT,
    id_depot INTEGER NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    id_statut INTEGER NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    id_utilisateur INTEGER REFERENCES utilisateur(id) ON DELETE SET NULL,
    date_livraison TEXT DEFAULT (DATETIME('now', 'localtime')),
    nom_livreur TEXT,
    adresse_livraison TEXT,
    notes TEXT,
    created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
);

CREATE TABLE livraison_vente_ligne (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    id_livraison INTEGER NOT NULL REFERENCES livraison_vente(id) ON DELETE CASCADE,
    id_commande_vente_ligne INTEGER REFERENCES commande_vente_ligne(id) ON DELETE SET NULL,
    id_article INTEGER NOT NULL REFERENCES article(id) ON DELETE RESTRICT,
    quantite_livree REAL NOT NULL CHECK (quantite_livree > 0),
    prix_vente_unitaire_ht REAL NOT NULL
);

CREATE TABLE facture_client (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero_facture TEXT NOT NULL UNIQUE,    -- ex: FAC-2026-0001
    id_client INTEGER NOT NULL REFERENCES client(id) ON DELETE RESTRICT,
    id_commande_vente INTEGER REFERENCES commande_vente(id) ON DELETE SET NULL,
    id_livraison INTEGER REFERENCES livraison_vente(id) ON DELETE SET NULL,
    id_statut INTEGER NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    id_utilisateur INTEGER REFERENCES utilisateur(id) ON DELETE SET NULL,
    date_facture TEXT DEFAULT (DATE('now', 'localtime')),
    date_echeance TEXT,                     -- Suivi "Alaina ambany maso"
    montant_ht REAL DEFAULT 0.00,
    montant_tva REAL DEFAULT 0.00,
    montant_ttc REAL DEFAULT 0.00,
    montant_paye REAL DEFAULT 0.00,
    created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
);

CREATE TABLE paiement_vente (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero_paiement TEXT NOT NULL UNIQUE,   -- ex: PV-2026-0001
    id_facture_client INTEGER NOT NULL REFERENCES facture_client(id) ON DELETE RESTRICT,
    id_caisse INTEGER NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,
    id_mode_paiement INTEGER NOT NULL REFERENCES mode_paiement(id) ON DELETE RESTRICT,
    id_utilisateur INTEGER REFERENCES utilisateur(id) ON DELETE SET NULL,
    date_paiement TEXT DEFAULT (DATE('now', 'localtime')),
    montant REAL NOT NULL CHECK (montant > 0),
    reference_transaction TEXT,
    notes TEXT,
    created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
);

-- -----------------------------------------------------------------------------
-- 6. GESTION DES STOCKS, MOUVEMENTS & INVENTAIRE (ANTI-COULAGE)
-- -----------------------------------------------------------------------------

CREATE TABLE stock_depot (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    id_depot INTEGER NOT NULL REFERENCES depot(id) ON DELETE CASCADE,
    id_article INTEGER NOT NULL REFERENCES article(id) ON DELETE CASCADE,
    quantite_reelle REAL NOT NULL DEFAULT 0.000,
    quantite_reservee REAL NOT NULL DEFAULT 0.000,
    quantite_en_commande REAL NOT NULL DEFAULT 0.000,
    derniere_mise_a_jour TEXT DEFAULT (DATETIME('now', 'localtime')),
    CONSTRAINT uq_depot_article UNIQUE (id_depot, id_article)
);

CREATE TABLE mouvement_stock (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    id_depot INTEGER NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    id_article INTEGER NOT NULL REFERENCES article(id) ON DELETE RESTRICT,
    id_type_mouvement INTEGER NOT NULL REFERENCES type_mouvement_stock(id) ON DELETE RESTRICT,
    id_utilisateur INTEGER REFERENCES utilisateur(id) ON DELETE SET NULL,
    quantite REAL NOT NULL CHECK (quantite > 0),
    prix_unitaire REAL DEFAULT 0.00,
    stock_avant REAL NOT NULL,
    stock_apres REAL NOT NULL,
    reference_document TEXT,                              -- Ex: 'BCV-2026-0001', 'BRA-2026-0001'
    date_mouvement TEXT DEFAULT (DATETIME('now', 'localtime')),
    remarque TEXT
);

-- Inventaire physique périodique & Détection du vol / coulage
CREATE TABLE inventaire (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero_inventaire TEXT NOT NULL UNIQUE, -- ex: INV-2026-09
    id_depot INTEGER NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    id_statut INTEGER NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    id_utilisateur INTEGER REFERENCES utilisateur(id) ON DELETE SET NULL,
    date_inventaire TEXT DEFAULT (DATETIME('now', 'localtime')),
    ecart_valeur_totale REAL DEFAULT 0.00, -- Perte/gain inexpliqué en Ariary
    remarques TEXT,
    created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
);

CREATE TABLE inventaire_ligne (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    id_inventaire INTEGER NOT NULL REFERENCES inventaire(id) ON DELETE CASCADE,
    id_article INTEGER NOT NULL REFERENCES article(id) ON DELETE RESTRICT,
    stock_theorique REAL NOT NULL,
    stock_compte REAL NOT NULL,
    ecart_quantite REAL NOT NULL,          -- stock_compte - stock_theorique
    prix_unitaire_achat REAL NOT NULL,
    ecart_valeur REAL NOT NULL,            -- ecart_quantite * prix_unitaire_achat
    justification TEXT
);

-- -----------------------------------------------------------------------------
-- 7. INDEX DE PERFORMANCE
-- -----------------------------------------------------------------------------

CREATE INDEX idx_utilisateur_profil ON utilisateur(id_profil);
CREATE INDEX idx_article_categorie ON article(id_categorie);
CREATE INDEX idx_article_reference ON article(reference);
CREATE INDEX idx_article_code_barre ON article(code_barre);
CREATE INDEX idx_stock_depot_article ON stock_depot(id_depot, id_article);

CREATE INDEX idx_client_type_client ON client(id_type_client);

CREATE INDEX idx_caisse_type_caisse ON caisse(id_type_caisse);
CREATE INDEX idx_caisse_devise ON caisse(id_devise);
CREATE INDEX idx_mvt_caisse_caisse ON mouvement_caisse(id_caisse);
CREATE INDEX idx_mvt_caisse_type ON mouvement_caisse(id_type_mouvement);
CREATE INDEX idx_mvt_caisse_journal ON mouvement_caisse(id_journal_caisse);
CREATE INDEX idx_transfert_caisse_src ON transfert_caisse(id_caisse_source);
CREATE INDEX idx_transfert_caisse_dest ON transfert_caisse(id_caisse_destination);

CREATE INDEX idx_journal_caisse_date ON journal_caisse(date_journal);
CREATE INDEX idx_journal_caisse_statut ON journal_caisse(statut);
CREATE INDEX idx_journal_caisse_ligne_journal ON journal_caisse_ligne(id_journal_caisse);
CREATE INDEX idx_journal_caisse_ligne_caisse ON journal_caisse_ligne(id_caisse);

CREATE INDEX idx_cmd_achat_fournisseur ON commande_achat(id_fournisseur);
CREATE INDEX idx_cmd_achat_statut ON commande_achat(id_statut);
CREATE INDEX idx_cmd_achat_ligne_cmd ON commande_achat_ligne(id_commande_achat);

CREATE INDEX idx_cmd_vente_client ON commande_vente(id_client);
CREATE INDEX idx_cmd_vente_statut ON commande_vente(id_statut);
CREATE INDEX idx_cmd_vente_ligne_cmd ON commande_vente_ligne(id_commande_vente);

CREATE INDEX idx_facture_client_client ON facture_client(id_client);
CREATE INDEX idx_facture_client_statut ON facture_client(id_statut);
CREATE INDEX idx_facture_client_echeance ON facture_client(date_echeance);

CREATE INDEX idx_paiement_vente_facture ON paiement_vente(id_facture_client);
CREATE INDEX idx_paiement_vente_caisse ON paiement_vente(id_caisse);

CREATE INDEX idx_mvt_stock_article_depot ON mouvement_stock(id_article, id_depot);
CREATE INDEX idx_mvt_stock_type ON mouvement_stock(id_type_mouvement);
CREATE INDEX idx_inventaire_depot ON inventaire(id_depot);

-- -----------------------------------------------------------------------------
-- 8. DONNÉES INITIALES (SEEDING DE BASE)
-- -----------------------------------------------------------------------------

-- 8.1 Profils utilisateurs (RBAC)
INSERT INTO profil (numero, code, libelle, description) VALUES
(1,  'ADMIN',      'Administrateur / Gérant', 'Accès complet : tableaux de bord, caisses, marges, stocks et achats'),
(11, 'CAISSIER',   'Caissier(e)',            'Effectuer commande, générer facture, valider livraison et paiement'),
(21, 'MAGASINIER', 'Magasinier',             'Gestion des réceptions, expéditions, transferts et inventaires');

-- 8.2 Utilisateur Administrateur par défaut
INSERT INTO utilisateur (id_profil, nom, prenom, nom_utilisateur, mot_de_passe_hash) VALUES
(1, 'Admin', 'Principal', 'admin', 'admin123');

-- 8.3 Statuts standardisés
INSERT INTO statut (numero, code, libelle, description) VALUES
(1,  'CREE',        'Créé / Brouillon',       'Document initié mais non encore validé'),
(11, 'VALIDE',      'Validé / En cours',      'Document validé et actif'),
(21, 'ANNULE',      'Annulé',                 'Document annulé sans effet opérationnel'),
(31, 'PARTIEL',     'Partiellement traité',   'Partiellement préparé, livré ou payé'),
(41, 'SOLDE',       'Soldé / Clôturé',        'Totalement traité, livré ou soldé');

-- 8.4 Modes de paiement usuels
INSERT INTO mode_paiement (numero, code, libelle) VALUES
(1,  'ESPECES',      'Espèces / Cash'),
(11, 'VIREMENT',     'Virement Bancaire'),
(21, 'CHEQUE',       'Chèque'),
(31, 'MVOLA',        'MVola'),
(41, 'ORANGE_MONEY', 'Orange Money'),
(51, 'AIRTEL_MONEY', 'Airtel Money'),
(61, 'CARTE',        'Carte Bancaire');

-- 8.5 Types de caisses
INSERT INTO type_caisse (numero, code, libelle) VALUES
(1,  'CAISSE_PHYSIQUE', 'Caisse Physique / Espèces'),
(11, 'BANQUE',          'Compte Bancaire'),
(21, 'MOBILE_MONEY',    'Compte Mobile Money');

-- 8.6 Types de clients
INSERT INTO type_client (numero, code, libelle) VALUES
(1,  'PARTICULIER', 'Particulier'),
(11, 'ENTREPRISE',  'Entreprise / Société'),
(21, 'AUTRE',       'Autre / Institutionnel');

-- 8.7 Devises
INSERT INTO devise (numero, code, libelle, symbole) VALUES
(1,  'MGA', 'Ariary',    'Ar'),
(11, 'EUR', 'Euro',      '€'),
(21, 'USD', 'Dollar US', '$');

-- 8.8 Types de mouvements de stock (+1: Entrée, -1: Sortie)
INSERT INTO type_mouvement_stock (numero, code, libelle, sens) VALUES
(1,  'ENTREE_ACHAT',         'Entrée Réception Achat',        1),
(11, 'SORTIE_VENTE',         'Sortie Livraison Vente',       -1),
(21, 'AJUSTEMENT_POSITIF',   'Ajustement Inventaire Positif', 1),
(31, 'AJUSTEMENT_NEGATIF',   'Ajustement Inventaire Négatif',-1),
(41, 'TRANSFERT_ENTREE',     'Transfert Dépôt Entrant',        1),
(51, 'TRANSFERT_SORTIE',     'Transfert Dépôt Sortant',       -1),
(61, 'RETOUR_CLIENT',        'Retour Produit Client',          1),
(71, 'RETOUR_FOURNISSEUR',   'Retour Produit Fournisseur',    -1);

-- 8.9 Types de mouvements de caisse (+1: Entrée d'argent, -1: Sortie d'argent)
INSERT INTO type_mouvement_caisse (numero, code, libelle, sens) VALUES
(1,  'ENCAISSEMENT_VENTE',       'Encaissement Règlement Client',        1),
(11, 'DECAISSEMENT_ACHAT',       'Décaissement Règlement Fournisseur',  -1),
(21, 'TRANSFERT_INTERNE_DEBIT',  'Transfert Interne (Sortie caisse)',    -1),
(31, 'TRANSFERT_INTERNE_CREDIT', 'Transfert Interne (Entrée caisse)',     1),
(41, 'DEPENSE_DIVERSE',          'Dépense Diverse / Charge',             -1),
(51, 'APPORT_FONDS',             'Apport de Fonds / Alimentation',        1);

-- 8.10 Unités de mesure par défaut
INSERT INTO unite_mesure (code, nom) VALUES
('PCS', 'Pièce(s)'),
('KG',  'Kilogramme'),
('L',   'Litre'),
('CRT', 'Carton');

-- 8.11 Dépôt principal par défaut
INSERT INTO depot (code, nom, adresse) VALUES
('DEP-01', 'Dépôt Principal / Magasin', 'Boutique');

-- 8.12 Caisses par défaut (Cash vs MVola vs Orange Money)
INSERT INTO caisse (code, nom, id_type_caisse, id_devise, solde_initial, solde_actuel) VALUES
('CSH-01',   'Tiroir-Caisse Espèces', 1, 1, 0.0, 0.0),
('MVOLA-01', 'Compte MVola Pro',      3, 1, 0.0, 0.0),
('OM-01',    'Compte Orange Money',   3, 1, 0.0, 0.0);
