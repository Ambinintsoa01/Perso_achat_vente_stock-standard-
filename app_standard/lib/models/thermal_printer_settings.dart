import 'package:shared_preferences/shared_preferences.dart';

class ThermalPrinterSettings {
  final String storeName;
  final String slogan;
  final String address;
  final String phone;
  final String email;
  final String nif;
  final String stat;
  final String footerMessage;
  final int paperWidth; // 58 ou 80 mm
  final bool autoPrintOnSale;
  final bool directPrint;
  final String? selectedPrinterName;
  final bool showQrCode;
  final bool showBarcode;
  final int nbCopies;

  const ThermalPrinterSettings({
    this.storeName = 'MON COMMERCE',
    this.slogan = 'Commerce Général & Distribution',
    this.address = 'Antananarivo, Madagascar',
    this.phone = '+261 34 00 000 00',
    this.email = '',
    this.nif = '',
    this.stat = '',
    this.footerMessage = 'Merci pour votre confiance !\nLes articles vendus ne sont ni repris ni échangés.',
    this.paperWidth = 80,
    this.autoPrintOnSale = false,
    this.directPrint = false,
    this.selectedPrinterName,
    this.showQrCode = true,
    this.showBarcode = false,
    this.nbCopies = 1,
  });

  bool get is80mm => paperWidth == 80;
  bool get is58mm => paperWidth == 58;

  ThermalPrinterSettings copyWith({
    String? storeName,
    String? slogan,
    String? address,
    String? phone,
    String? email,
    String? nif,
    String? stat,
    String? footerMessage,
    int? paperWidth,
    bool? autoPrintOnSale,
    bool? directPrint,
    String? selectedPrinterName,
    bool? showQrCode,
    bool? showBarcode,
    int? nbCopies,
  }) {
    return ThermalPrinterSettings(
      storeName: storeName ?? this.storeName,
      slogan: slogan ?? this.slogan,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      nif: nif ?? this.nif,
      stat: stat ?? this.stat,
      footerMessage: footerMessage ?? this.footerMessage,
      paperWidth: paperWidth ?? this.paperWidth,
      autoPrintOnSale: autoPrintOnSale ?? this.autoPrintOnSale,
      directPrint: directPrint ?? this.directPrint,
      selectedPrinterName: selectedPrinterName ?? this.selectedPrinterName,
      showQrCode: showQrCode ?? this.showQrCode,
      showBarcode: showBarcode ?? this.showBarcode,
      nbCopies: nbCopies ?? this.nbCopies,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeName': storeName,
      'slogan': slogan,
      'address': address,
      'phone': phone,
      'email': email,
      'nif': nif,
      'stat': stat,
      'footerMessage': footerMessage,
      'paperWidth': paperWidth,
      'autoPrintOnSale': autoPrintOnSale,
      'directPrint': directPrint,
      'selectedPrinterName': selectedPrinterName,
      'showQrCode': showQrCode,
      'showBarcode': showBarcode,
      'nbCopies': nbCopies,
    };
  }

  factory ThermalPrinterSettings.fromMap(Map<String, dynamic> map) {
    return ThermalPrinterSettings(
      storeName: map['storeName'] as String? ?? 'MON COMMERCE',
      slogan: map['slogan'] as String? ?? 'Commerce Général & Distribution',
      address: map['address'] as String? ?? 'Antananarivo, Madagascar',
      phone: map['phone'] as String? ?? '+261 34 00 000 00',
      email: map['email'] as String? ?? '',
      nif: map['nif'] as String? ?? '',
      stat: map['stat'] as String? ?? '',
      footerMessage: map['footerMessage'] as String? ??
          'Merci pour votre confiance !\nLes articles vendus ne sont ni repris ni échangés.',
      paperWidth: map['paperWidth'] as int? ?? 80,
      autoPrintOnSale: map['autoPrintOnSale'] as bool? ?? false,
      directPrint: map['directPrint'] as bool? ?? false,
      selectedPrinterName: map['selectedPrinterName'] as String?,
      showQrCode: map['showQrCode'] as bool? ?? true,
      showBarcode: map['showBarcode'] as bool? ?? false,
      nbCopies: map['nbCopies'] as int? ?? 1,
    );
  }

  static const _keyStoreName = 'tp_store_name';
  static const _keySlogan = 'tp_slogan';
  static const _keyAddress = 'tp_address';
  static const _keyPhone = 'tp_phone';
  static const _keyEmail = 'tp_email';
  static const _keyNif = 'tp_nif';
  static const _keyStat = 'tp_stat';
  static const _keyFooterMessage = 'tp_footer_message';
  static const _keyPaperWidth = 'tp_paper_width';
  static const _keyAutoPrintOnSale = 'tp_auto_print';
  static const _keyDirectPrint = 'tp_direct_print';
  static const _keySelectedPrinter = 'tp_selected_printer';
  static const _keyShowQrCode = 'tp_show_qrcode';
  static const _keyShowBarcode = 'tp_show_barcode';
  static const _keyNbCopies = 'tp_nb_copies';

  static Future<ThermalPrinterSettings> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return ThermalPrinterSettings(
      storeName: prefs.getString(_keyStoreName) ?? 'MON COMMERCE',
      slogan: prefs.getString(_keySlogan) ?? 'Commerce Général & Distribution',
      address: prefs.getString(_keyAddress) ?? 'Antananarivo, Madagascar',
      phone: prefs.getString(_keyPhone) ?? '+261 34 00 000 00',
      email: prefs.getString(_keyEmail) ?? '',
      nif: prefs.getString(_keyNif) ?? '',
      stat: prefs.getString(_keyStat) ?? '',
      footerMessage: prefs.getString(_keyFooterMessage) ??
          'Merci pour votre confiance !\nLes articles vendus ne sont ni repris ni échangés.',
      paperWidth: prefs.getInt(_keyPaperWidth) ?? 80,
      autoPrintOnSale: prefs.getBool(_keyAutoPrintOnSale) ?? false,
      directPrint: prefs.getBool(_keyDirectPrint) ?? false,
      selectedPrinterName: prefs.getString(_keySelectedPrinter),
      showQrCode: prefs.getBool(_keyShowQrCode) ?? true,
      showBarcode: prefs.getBool(_keyShowBarcode) ?? false,
      nbCopies: prefs.getInt(_keyNbCopies) ?? 1,
    );
  }

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStoreName, storeName);
    await prefs.setString(_keySlogan, slogan);
    await prefs.setString(_keyAddress, address);
    await prefs.setString(_keyPhone, phone);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyNif, nif);
    await prefs.setString(_keyStat, stat);
    await prefs.setString(_keyFooterMessage, footerMessage);
    await prefs.setInt(_keyPaperWidth, paperWidth);
    await prefs.setBool(_keyAutoPrintOnSale, autoPrintOnSale);
    await prefs.setBool(_keyDirectPrint, directPrint);
    if (selectedPrinterName != null) {
      await prefs.setString(_keySelectedPrinter, selectedPrinterName!);
    } else {
      await prefs.remove(_keySelectedPrinter);
    }
    await prefs.setBool(_keyShowQrCode, showQrCode);
    await prefs.setBool(_keyShowBarcode, showBarcode);
    await prefs.setInt(_keyNbCopies, nbCopies);
  }
}
