import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DbHelper {
  static final DbHelper instance = DbHelper._init();
  static Database? _database;

  DbHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('achat_vente_stock.db');
    return _database!;
  }

  static void initFfiIfNeeded() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  @visibleForTesting
  static void setDatabaseForTesting(Database? db) {
    _database = db;
  }

  @visibleForTesting
  Future<void> populateTestDb(Database db) async {
    await _createDB(db, 1);
    await _ensureTablesExist(db);
  }

  Future<Database> _initDB(String filePath) async {
    String path;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      final docDir = await getApplicationDocumentsDirectory();
      path = join(docDir.path, 'PersoAchatVenteStock', filePath);
      final dir = Directory(dirname(path));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    }

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onOpen: (db) async {
        await _ensureTablesExist(db);
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Profils & Utilisateurs
    await db.execute('''
      CREATE TABLE profil (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero INTEGER NOT NULL UNIQUE,
        code TEXT NOT NULL UNIQUE,
        libelle TEXT NOT NULL,
        description TEXT,
        actif INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
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
      )
    ''');

    // 2. Lookup Tables
    await db.execute('''
      CREATE TABLE statut (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero INTEGER NOT NULL UNIQUE,
        code TEXT NOT NULL UNIQUE,
        libelle TEXT NOT NULL,
        description TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE mode_paiement (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero INTEGER NOT NULL UNIQUE,
        code TEXT NOT NULL UNIQUE,
        libelle TEXT NOT NULL,
        actif INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE type_caisse (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero INTEGER NOT NULL UNIQUE,
        code TEXT NOT NULL UNIQUE,
        libelle TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE type_mouvement_stock (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero INTEGER NOT NULL UNIQUE,
        code TEXT NOT NULL UNIQUE,
        libelle TEXT NOT NULL,
        sens INTEGER NOT NULL CHECK (sens IN (1, -1)),
        actif INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE type_mouvement_caisse (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero INTEGER NOT NULL UNIQUE,
        code TEXT NOT NULL UNIQUE,
        libelle TEXT NOT NULL,
        sens INTEGER NOT NULL CHECK (sens IN (1, -1)),
        actif INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE type_client (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero INTEGER NOT NULL UNIQUE,
        code TEXT NOT NULL UNIQUE,
        libelle TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE devise (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero INTEGER NOT NULL UNIQUE,
        code TEXT NOT NULL UNIQUE,
        libelle TEXT NOT NULL,
        symbole TEXT DEFAULT 'Ar',
        actif INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE categorie (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        nom TEXT NOT NULL,
        description TEXT,
        id_parent INTEGER REFERENCES categorie(id) ON DELETE SET NULL,
        actif INTEGER DEFAULT 1,
        created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
      )
    ''');

    await db.execute('''
      CREATE TABLE unite_mesure (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        nom TEXT NOT NULL,
        actif INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE depot (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        nom TEXT NOT NULL,
        adresse TEXT,
        telephone TEXT,
        actif INTEGER DEFAULT 1,
        created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
      )
    ''');

    await db.execute('''
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
        cout_moyen_unitaire REAL DEFAULT 0.00,
        prix_vente_standard REAL DEFAULT 0.00,
        taux_tva REAL DEFAULT 20.00,
        seuil_alerte_stock REAL DEFAULT 0.000,
        suivi_stock INTEGER DEFAULT 1,
        actif INTEGER DEFAULT 1,
        created_at TEXT DEFAULT (DATETIME('now', 'localtime')),
        updated_at TEXT DEFAULT (DATETIME('now', 'localtime'))
      )
    ''');

    // 3. Tiers
    await db.execute('''
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
      )
    ''');

    await db.execute('''
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
      )
    ''');

    // 4. Multi-Caisse & Trésorerie
    await db.execute('''
      CREATE TABLE caisse (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        nom TEXT NOT NULL,
        id_type_caisse INTEGER NOT NULL REFERENCES type_caisse(id) ON DELETE RESTRICT,
        numero_compte TEXT,
        solde_initial REAL DEFAULT 0.00,
        solde_actuel REAL DEFAULT 0.00,
        id_devise INTEGER NOT NULL REFERENCES devise(id) ON DELETE RESTRICT,
        actif INTEGER DEFAULT 1,
        created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
      )
    ''');

    await db.execute('''
      CREATE TABLE mouvement_caisse (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_caisse INTEGER NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,
        id_type_mouvement INTEGER NOT NULL REFERENCES type_mouvement_caisse(id) ON DELETE RESTRICT,
        id_mode_paiement INTEGER NOT NULL REFERENCES mode_paiement(id) ON DELETE RESTRICT,
        id_utilisateur INTEGER REFERENCES utilisateur(id) ON DELETE SET NULL,
        montant REAL NOT NULL CHECK (montant > 0),
        solde_avant REAL NOT NULL,
        solde_apres REAL NOT NULL,
        date_mouvement TEXT DEFAULT (DATETIME('now', 'localtime')),
        reference_piece TEXT,
        description TEXT,
        created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
      )
    ''');

    await db.execute('''
      CREATE TABLE transfert_caisse (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero_transfert TEXT NOT NULL UNIQUE,
        id_caisse_source INTEGER NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,
        id_caisse_destination INTEGER NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,
        montant REAL NOT NULL CHECK (montant > 0),
        frais_transfert REAL DEFAULT 0.00,
        id_statut INTEGER NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
        id_utilisateur INTEGER REFERENCES utilisateur(id) ON DELETE SET NULL,
        date_transfert TEXT DEFAULT (DATETIME('now', 'localtime')),
        motif TEXT,
        created_at TEXT DEFAULT (DATETIME('now', 'localtime')),
        CONSTRAINT chk_transfert_caisses_distinctes CHECK (id_caisse_source <> id_caisse_destination)
      )
    ''');

    // 5. Workflow Vente & Achat & Stock
    await db.execute('''
      CREATE TABLE commande_achat (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero_commande TEXT NOT NULL UNIQUE,
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
      )
    ''');

    await db.execute('''
      CREATE TABLE commande_vente (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero_commande TEXT NOT NULL UNIQUE,
        id_client INTEGER NOT NULL REFERENCES client(id) ON DELETE RESTRICT,
        id_depot_source INTEGER NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
        id_statut INTEGER NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
        id_utilisateur INTEGER REFERENCES utilisateur(id) ON DELETE SET NULL,
        date_commande TEXT DEFAULT (DATE('now', 'localtime')),
        date_livraison_souhaitee TEXT,
        montant_ht REAL DEFAULT 0.00,
        montant_tva REAL DEFAULT 0.00,
        montant_ttc REAL DEFAULT 0.00,
        marge_brute REAL DEFAULT 0.00,
        notes TEXT,
        created_at TEXT DEFAULT (DATETIME('now', 'localtime')),
        updated_at TEXT DEFAULT (DATETIME('now', 'localtime'))
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_depot (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_depot INTEGER NOT NULL REFERENCES depot(id) ON DELETE CASCADE,
        id_article INTEGER NOT NULL REFERENCES article(id) ON DELETE CASCADE,
        quantite_reelle REAL NOT NULL DEFAULT 0.000,
        quantite_reservee REAL NOT NULL DEFAULT 0.000,
        quantite_en_commande REAL NOT NULL DEFAULT 0.000,
        derniere_mise_a_jour TEXT DEFAULT (DATETIME('now', 'localtime')),
        CONSTRAINT uq_depot_article UNIQUE (id_depot, id_article)
      )
    ''');

    await db.execute('''
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
        reference_document TEXT,
        date_mouvement TEXT DEFAULT (DATETIME('now', 'localtime')),
        remarque TEXT
      )
    ''');

    // 6. Index
    await db.execute('CREATE INDEX idx_caisse_type_caisse ON caisse(id_type_caisse)');
    await db.execute('CREATE INDEX idx_mvt_caisse_caisse ON mouvement_caisse(id_caisse)');
    await db.execute('CREATE INDEX idx_mvt_caisse_type ON mouvement_caisse(id_type_mouvement)');

    // 7. Données initiales de démarrage (Seed)
    await _insertSeedData(db);
  }

  Future<void> _insertSeedData(Database db) async {
    // Profils
    await db.rawInsert('''
      INSERT INTO profil (numero, code, libelle, description) VALUES
      (1, 'ADMIN', 'Administrateur', 'Accès complet'),
      (11, 'CAISSIER', 'Caissier(e)', 'Gestion des commandes et encaissements')
    ''');

    // Utilisateur par défaut
    await db.rawInsert('''
      INSERT INTO utilisateur (id_profil, nom, prenom, nom_utilisateur, mot_de_passe_hash) VALUES
      (1, 'Admin', 'Gérant', 'admin', 'admin123')
    ''');

    // Statuts
    await db.rawInsert('''
      INSERT INTO statut (numero, code, libelle, description) VALUES
      (1, 'CREE', 'Créé / Brouillon', 'Document initié'),
      (11, 'VALIDE', 'Validé', 'Confirmé et actif'),
      (21, 'ANNULE', 'Annulé', 'Sans effet'),
      (31, 'PARTIEL', 'Partiel', 'Partiellement traité'),
      (41, 'SOLDE', 'Soldé', 'Terminé')
    ''');

    // Modes de paiement
    await db.rawInsert('''
      INSERT INTO mode_paiement (numero, code, libelle) VALUES
      (1, 'ESPECES', 'Espèces / Cash'),
      (11, 'VIREMENT', 'Virement Bancaire'),
      (21, 'CHEQUE', 'Chèque'),
      (31, 'MVOLA', 'MVola'),
      (41, 'ORANGE_MONEY', 'Orange Money'),
      (51, 'AIRTEL_MONEY', 'Airtel Money'),
      (61, 'CARTE', 'Carte Bancaire')
    ''');

    // Types de caisses
    await db.rawInsert('''
      INSERT INTO type_caisse (numero, code, libelle) VALUES
      (1, 'CAISSE_PHYSIQUE', 'Caisse Physique / Espèces'),
      (11, 'BANQUE', 'Compte Bancaire'),
      (21, 'MOBILE_MONEY', 'Compte Mobile Money')
    ''');

    // Types mouvements caisse
    await db.rawInsert('''
      INSERT INTO type_mouvement_caisse (numero, code, libelle, sens) VALUES
      (1, 'ENCAISSEMENT_VENTE', 'Encaissement Vente', 1),
      (11, 'DECAISSEMENT_ACHAT', 'Décaissement Fournisseur', -1),
      (21, 'TRANSFERT_INTERNE_DEBIT', 'Transfert Sortant', -1),
      (31, 'TRANSFERT_INTERNE_CREDIT', 'Transfert Entrant', 1),
      (41, 'DEPENSE_DIVERSE', 'Dépense / Charge', -1),
      (51, 'APPORT_FONDS', 'Apport de Fonds', 1)
    ''');

    // Types mouvements stock
    await db.rawInsert('''
      INSERT INTO type_mouvement_stock (numero, code, libelle, sens) VALUES
      (1, 'ENTREE_ACHAT', 'Entrée Réception Achat', 1),
      (11, 'SORTIE_VENTE', 'Sortie Livraison Vente', -1),
      (21, 'AJUSTEMENT_POSITIF', 'Ajustement Positif', 1),
      (31, 'AJUSTEMENT_NEGATIF', 'Ajustement Négatif', -1)
    ''');

    // Types clients
    await db.rawInsert('''
      INSERT INTO type_client (numero, code, libelle) VALUES
      (1, 'PARTICULIER', 'Particulier'),
      (11, 'ENTREPRISE', 'Entreprise')
    ''');

    // Devises
    await db.rawInsert('''
      INSERT INTO devise (numero, code, libelle, symbole) VALUES
      (1, 'MGA', 'Ariary', 'Ar'),
      (11, 'EUR', 'Euro', '€'),
      (21, 'USD', 'Dollar US', '\$')
    ''');

    // Unités
    await db.rawInsert('''
      INSERT INTO unite_mesure (code, nom) VALUES
      ('PCS', 'Pièce(s)'),
      ('KG', 'Kilogramme')
    ''');

    // Dépôt par défaut
    await db.rawInsert('''
      INSERT INTO depot (code, nom, adresse) VALUES
      ('DEP-01', 'Dépôt Principal', 'Boutique')
    ''');

    // Caisses initiales : Cash, MVola, Orange Money, BNI (avec quelques soldes de départ pour tester immédiatement !)
    await db.rawInsert('''
      INSERT INTO caisse (code, nom, id_type_caisse, id_devise, numero_compte, solde_initial, solde_actuel) VALUES
      ('CSH-01', 'Tiroir-Caisse Espèces', 1, 1, 'Caisse Centrale', 250000.0, 250000.0),
      ('MVOLA-01', 'Compte MVola Pro', 3, 1, '034 00 000 00', 480000.0, 480000.0),
      ('OM-01', 'Compte Orange Money', 3, 1, '032 00 000 00', 150000.0, 150000.0),
      ('BNI-01', 'Compte BNI Entreprise', 2, 1, '00005 00001 12345678901 23', 1200000.0, 1200000.0)
    ''');

    // Mouvements d'ouverture initiaux pour traçabilité
    await db.rawInsert('''
      INSERT INTO mouvement_caisse (id_caisse, id_type_mouvement, id_mode_paiement, id_utilisateur, montant, solde_avant, solde_apres, reference_piece, description) VALUES
      (1, 6, 1, 1, 250000.0, 0.0, 250000.0, 'SOLDE-DEP-01', 'Apport initial fond de caisse espèces'),
      (2, 6, 4, 1, 480000.0, 0.0, 480000.0, 'SOLDE-DEP-02', 'Solde de départ MVola Pro'),
      (3, 6, 5, 1, 150000.0, 0.0, 150000.0, 'SOLDE-DEP-03', 'Solde de départ Orange Money'),
      (4, 6, 2, 1, 1200000.0, 0.0, 1200000.0, 'SOLDE-DEP-04', 'Solde de départ compte BNI')
    ''');
  }

  Future<void> _ensureTablesExist(Database db) async {
    // Vérifier et créer les tables d'achat manquantes si nécessaire
    await db.execute('''
      CREATE TABLE IF NOT EXISTS commande_achat_ligne (
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
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS facture_fournisseur (
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
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS paiement_achat (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero_paiement TEXT NOT NULL UNIQUE,
        id_facture_fournisseur INTEGER NOT NULL REFERENCES facture_fournisseur(id) ON DELETE RESTRICT,
        id_caisse INTEGER NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,
        id_mode_paiement INTEGER NOT NULL REFERENCES mode_paiement(id) ON DELETE RESTRICT,
        id_utilisateur INTEGER REFERENCES utilisateur(id) ON DELETE SET NULL,
        date_paiement TEXT DEFAULT (DATE('now', 'localtime')),
        montant REAL NOT NULL CHECK (montant > 0),
        reference_transaction TEXT,
        notes TEXT,
        created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
      )
    ''');

    // Assurer qu'il y a au moins un fournisseur par défaut
    final countRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM fournisseur');
    final count = (countRes.first['cnt'] as num?)?.toInt() ?? 0;
    if (count == 0) {
      await db.rawInsert('''
        INSERT INTO fournisseur (code, raison_sociale, nom_contact, telephone, email) VALUES
        ('FOURN-01', 'Grossiste Principal & Bazar', 'M. Razafy', '034 11 222 33', 'contact@grossiste.mg')
      ''');
    }

    // Tables pour le module Ventes
    await db.execute('''
      CREATE TABLE IF NOT EXISTS commande_vente_ligne (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_commande_vente INTEGER NOT NULL REFERENCES commande_vente(id) ON DELETE CASCADE,
        id_article INTEGER NOT NULL REFERENCES article(id) ON DELETE RESTRICT,
        quantite REAL NOT NULL CHECK (quantite > 0),
        prix_unitaire REAL NOT NULL CHECK (prix_unitaire >= 0),
        taux_remise REAL DEFAULT 0.00,
        montant_ht REAL NOT NULL,
        montant_ttc REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS facture_client (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero_facture TEXT NOT NULL UNIQUE,
        id_client INTEGER NOT NULL REFERENCES client(id) ON DELETE RESTRICT,
        id_commande_vente INTEGER REFERENCES commande_vente(id) ON DELETE SET NULL,
        id_statut INTEGER NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
        date_facture TEXT DEFAULT (DATE('now', 'localtime')),
        date_echeance TEXT,
        montant_ht REAL DEFAULT 0.00,
        montant_tva REAL DEFAULT 0.00,
        montant_ttc REAL DEFAULT 0.00,
        montant_paye REAL DEFAULT 0.00,
        created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS paiement_vente (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero_paiement TEXT NOT NULL UNIQUE,
        id_facture_client INTEGER NOT NULL REFERENCES facture_client(id) ON DELETE RESTRICT,
        id_caisse INTEGER NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,
        id_mode_paiement INTEGER NOT NULL REFERENCES mode_paiement(id) ON DELETE RESTRICT,
        id_utilisateur INTEGER REFERENCES utilisateur(id) ON DELETE SET NULL,
        date_paiement TEXT DEFAULT (DATE('now', 'localtime')),
        montant REAL NOT NULL CHECK (montant > 0),
        reference_transaction TEXT,
        notes TEXT,
        created_at TEXT DEFAULT (DATETIME('now', 'localtime'))
      )
    ''');

    // Assurer qu'il y a au moins un client par défaut (Client Comptoir)
    final countClientRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM client');
    final countClient = (countClientRes.first['cnt'] as num?)?.toInt() ?? 0;
    if (countClient == 0) {
      await db.rawInsert('''
        INSERT INTO client (code, nom_complet, id_type_client, telephone, email) VALUES
        ('CLI-001', 'Client Comptoir (Passage)', 1, '034 00 000 00', 'client@passage.mg')
      ''');
    }
  }
}
