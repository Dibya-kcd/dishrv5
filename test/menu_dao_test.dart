import 'package:flutter_test/flutter_test.dart';
import 'package:dishr/data/repository.dart';
import 'package:dishr/models/menu_item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('MenuDao operations and parsing robustness', () async {
    final factory = databaseFactoryFfi;
    final tempDir = await Directory.systemTemp.createTemp('dishr_test_db_');
    factory.setDatabasesPath(tempDir.path);
    final basePath = await factory.getDatabasesPath();
    final dbPath = p.join(basePath, 'dishr.db');
    
    // We can delete the DB file before test to start fresh
    if (File(dbPath).existsSync()) {
      await factory.deleteDatabase(dbPath);
    }

    final repo = Repository.instance;
    // Trigger init
    await repo.menu.listMenu(); 

    // 1. Insert valid item
    final item = MenuItem(
      id: 999,
      name: 'Test Item',
      category: 'Test',
      price: 100,
      image: '',
      modifiers: [{'name': 'Mod1', 'priceDelta': 10}],
      upsellIds: [1, 2],
      instructionTemplates: ['No Spicy'],
      specialFlags: ['Vegan'],
      availableDays: ['Mon'],
    );
    
    await repo.menu.upsertMenuItems([item], fromSync: true);
    
    var items = await repo.menu.listMenu();
    var fetched = items.firstWhere((i) => i.id == 999);
    expect(fetched.name, 'Test Item');
    expect(fetched.modifiers.length, 1);
    expect(fetched.modifiers.first['name'], 'Mod1');
    expect(fetched.upsellIds, [1, 2]);
    expect(fetched.soldOut, false);

    // 2. Toggle Sold Out
    await repo.menu.toggleSoldOut(999, true, fromSync: true);
    items = await repo.menu.listMenu();
    fetched = items.firstWhere((i) => i.id == 999);
    expect(fetched.soldOut, true);

    // 3. Test Robustness with Invalid JSON
    // We open the DB directly to inject bad data
    final db = await factory.openDatabase(dbPath);
    await db.insert('menu_items', {
      'id': 1000,
      'name': 'Bad JSON Item',
      'category': 'Test',
      'price': 50,
      'image': '',
      'sold_out': 0,
      'modifiers': '{bad_json}',
      'upsell_ids': '[1, "nan"]', // "nan" should be handled gracefully if parsing fails or returns -1
      'instruction_templates': null,
      'special_flags': 'not_a_list',
      'available_days': '',
      'stock': 10
    });
    // await db.close(); // Keep open to avoid affecting Repository's connection if shared

    items = await repo.menu.listMenu();
    final badItem = items.firstWhere((i) => i.id == 1000);
    
    // Modifiers should be empty list due to parsing error catch
    expect(badItem.modifiers, isEmpty);
    
    // Upsell IDs: [1, "nan"] -> "nan" parses to null or throws, tryParse returns null -> -1 -> filtered out.
    // Wait, let's see logic: 
    // e.toString() -> "nan" -> int.tryParse("nan") -> null -> ?? -1 -> -1. where(v >= 0) -> filters out -1.
    // So we should get [1].
    // Wait, jsonDecode('[1, "nan"]') works? Yes.
    expect(badItem.upsellIds, [1]); 
    
    // instruction_templates was null -> handled
    expect(badItem.instructionTemplates, isEmpty);
    
    // special_flags was 'not_a_list' -> jsonDecode might throw or return string.
    // if returns string, 'is List' check fails. returns [].
    // if throws, catch returns [].
    expect(badItem.specialFlags, isEmpty);

    // available_days was empty string -> returns []
    expect(badItem.availableDays, isEmpty);
    
    expect(badItem.stock, 10);
  });
}
