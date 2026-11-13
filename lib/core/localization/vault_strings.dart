import 'package:flutter/widgets.dart';

/// Native date/numeric presentation is Indian; financial amounts use exact Money.
final class VaultStrings {
  const VaultStrings(this.locale);
  final Locale locale;
  String text(String key) =>
      (locale.languageCode == 'hi' ? _hi[key] : null) ?? _en[key] ?? key;
  static const _en = <String, String>{
    'dashboard': 'Overview',
    'transactions': 'Transactions',
    'accounts': 'Accounts',
    'assets': 'Assets',
    'liabilities': 'Loans & lending',
    'documents': 'Documents',
    'business': 'Business',
    'settings': 'Settings',
    'save': 'Save',
    'cancel': 'Cancel',
    'income': 'Income',
    'expense': 'Expense',
    'transfer': 'Transfer',
    'backup': 'Backup & recovery',
    'family': 'Family',
    'search': 'Search',
    'lock': 'Lock vault',
    'reports': 'Reports',
  };
  static const _hi = <String, String>{
    'dashboard': 'सारांश',
    'transactions': 'लेनदेन',
    'accounts': 'खाते',
    'assets': 'संपत्ति',
    'liabilities': 'ऋण और उधार',
    'documents': 'दस्तावेज़',
    'business': 'व्यवसाय',
    'settings': 'सेटिंग्स',
    'save': 'सहेजें',
    'cancel': 'रद्द करें',
    'income': 'आय',
    'expense': 'खर्च',
    'transfer': 'स्थानांतरण',
    'backup': 'बैकअप और पुनर्प्राप्ति',
    'family': 'परिवार',
    'search': 'खोजें',
    'lock': 'वॉल्ट लॉक करें',
    'reports': 'रिपोर्ट',
  };
}
