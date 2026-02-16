import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class AppDatabase {
  Database? _db;
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    DatabaseFactory factory;
    if (kIsWeb) {
      factory = databaseFactoryFfiWeb;
    } else if (defaultTargetPlatform == TargetPlatform.windows || 
               defaultTargetPlatform == TargetPlatform.linux || 
               defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
    } else {
      factory = databaseFactory;
    }
    final basePath = await factory.getDatabasesPath();
    final dbPath = p.join(basePath, 'dishr.db');
    final db = await factory.openDatabase(dbPath, options: OpenDatabaseOptions(
      version: 13,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE menu_items(
            id INTEGER PRIMARY KEY,
            name TEXT,
            category TEXT,
            price REAL,
            image TEXT,
            sold_out INTEGER,
            modifiers TEXT,
            upsell_ids TEXT,
            instruction_templates TEXT,
            special_flags TEXT,
            available_days TEXT,
            available_start TEXT,
            available_end TEXT,
            stock INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE orders(
            id TEXT PRIMARY KEY,
            table_label TEXT,
            status TEXT,
            total REAL,
            time TEXT,
            payment_method TEXT,
            created_at INTEGER,
            ready_at INTEGER,
            settled_at INTEGER
          )
        ''');
        await db.execute('CREATE INDEX idx_orders_created_at ON orders(created_at)');
        await db.execute('CREATE INDEX idx_orders_settled_at ON orders(settled_at)');
        await db.execute('''
          CREATE TABLE order_events(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id TEXT,
            timestamp INTEGER,
            event TEXT,
            data TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE order_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id TEXT,
            menu_item_id INTEGER,
            name_snapshot TEXT,
            price_snapshot REAL,
            quantity INTEGER,
            instructions TEXT,
            addons TEXT,
            modifiers TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_order_items_order ON order_items(order_id)');
        await db.execute('''
          CREATE TABLE tables(
            id INTEGER PRIMARY KEY,
            number INTEGER,
            status TEXT,
            capacity INTEGER,
            order_id TEXT
          )
        ''');
        await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
        await db.execute('''
          CREATE TABLE expenses(
            id TEXT PRIMARY KEY,
            amount REAL,
            category TEXT,
            note TEXT,
            timestamp INTEGER
          )
        ''');
        final categoriesJson = jsonEncode(['All','Starters','Main Course','South Indian','Breads','Desserts','Beverages']);
        await db.insert('settings', {'key': 'categories', 'value': categoriesJson});
        final today = DateTime.now();
        final yy = (today.year % 100).toString().padLeft(2, '0');
        final mm = today.month.toString().padLeft(2, '0');
        final dd = today.day.toString().padLeft(2, '0');
        final dateStr = '$yy$mm$dd';
        await db.insert('settings', {'key': 'takeoutTokenNumber', 'value': '1'});
        await db.insert('settings', {'key': 'takeoutTokenDate', 'value': dateStr});
        await db.insert('menu_items', {
          'id': 1,
          'name': 'Paneer Tikka',
          'category': 'Starters',
          'price': 220,
          'image': '',
          'sold_out': 0,
          'modifiers': jsonEncode([]),
          'upsell_ids': jsonEncode([]),
          'instruction_templates': jsonEncode(['Less Spicy','Extra Spicy']),
          'special_flags': jsonEncode([]),
          'available_days': jsonEncode(['Mon','Tue','Wed','Thu','Fri','Sat','Sun']),
          'available_start': null,
          'available_end': null,
          'stock': null,
        });
        await db.insert('menu_items', {
          'id': 2,
          'name': 'Chicken Biryani',
          'category': 'Main Course',
          'price': 280,
          'image': '',
          'sold_out': 0,
          'modifiers': jsonEncode([]),
          'upsell_ids': jsonEncode([]),
          'instruction_templates': jsonEncode(['Less Oil','Extra Masala']),
          'special_flags': jsonEncode([]),
          'available_days': jsonEncode(['Mon','Tue','Wed','Thu','Fri','Sat','Sun']),
          'available_start': null,
          'available_end': null,
          'stock': null,
        });
        await db.insert('menu_items', {
          'id': 3,
          'name': 'Masala Dosa',
          'category': 'South Indian',
          'price': 160,
          'image': '',
          'sold_out': 0,
          'modifiers': jsonEncode([]),
          'upsell_ids': jsonEncode([]),
          'instruction_templates': jsonEncode(['Less Oil','Extra Chutney']),
          'special_flags': jsonEncode([]),
          'available_days': jsonEncode(['Mon','Tue','Wed','Thu','Fri','Sat','Sun']),
          'available_start': null,
          'available_end': null,
          'stock': null,
        });
        await db.insert('menu_items', {
          'id': 4,
          'name': 'Butter Naan',
          'category': 'Breads',
          'price': 60,
          'image': '',
          'sold_out': 0,
          'modifiers': jsonEncode([]),
          'upsell_ids': jsonEncode([]),
          'instruction_templates': jsonEncode(['Extra Butter']),
          'special_flags': jsonEncode([]),
          'available_days': jsonEncode(['Mon','Tue','Wed','Thu','Fri','Sat','Sun']),
          'available_start': null,
          'available_end': null,
          'stock': null,
        });
        await db.insert('menu_items', {
          'id': 5,
          'name': 'Gulab Jamun',
          'category': 'Desserts',
          'price': 120,
          'image': '',
          'sold_out': 0,
          'modifiers': jsonEncode([]),
          'upsell_ids': jsonEncode([]),
          'instruction_templates': jsonEncode(['Warm','Cold']),
          'special_flags': jsonEncode([]),
          'available_days': jsonEncode(['Mon','Tue','Wed','Thu','Fri','Sat','Sun']),
          'available_start': null,
          'available_end': null,
          'stock': null,
        });
        await db.insert('menu_items', {
          'id': 6,
          'name': 'Cold Coffee',
          'category': 'Beverages',
          'price': 140,
          'image': '',
          'sold_out': 0,
          'modifiers': jsonEncode([]),
          'upsell_ids': jsonEncode([]),
          'instruction_templates': jsonEncode(['Less Sugar']),
          'special_flags': jsonEncode([]),
          'available_days': jsonEncode(['Mon','Tue','Wed','Thu','Fri','Sat','Sun']),
          'available_start': null,
          'available_end': null,
          'stock': null,
        });
        await db.insert('menu_items', {
          'id': 7,
          'name': 'Dal Makhani',
          'category': 'Main Course',
          'price': 240,
          'image': '',
          'sold_out': 0,
          'modifiers': jsonEncode([]),
          'upsell_ids': jsonEncode([]),
          'instruction_templates': jsonEncode(['Less Cream']),
          'special_flags': jsonEncode([]),
          'available_days': jsonEncode(['Mon','Tue','Wed','Thu','Fri','Sat','Sun']),
          'available_start': null,
          'available_end': null,
          'stock': null,
        });
        await db.insert('menu_items', {
          'id': 8,
          'name': 'Spring Rolls',
          'category': 'Starters',
          'price': 180,
          'image': '',
          'sold_out': 0,
          'modifiers': jsonEncode([]),
          'upsell_ids': jsonEncode([]),
          'instruction_templates': jsonEncode(['Extra Sauce']),
          'special_flags': jsonEncode([]),
          'available_days': jsonEncode(['Mon','Tue','Wed','Thu','Fri','Sat','Sun']),
          'available_start': null,
          'available_end': null,
          'stock': null,
        });
        for (var n = 1; n <= 8; n++) {
          await db.insert('tables', {
            'id': n,
            'number': n,
            'status': 'available',
            'capacity': 4,
            'order_id': null
          });
        }
        await db.execute('''
          CREATE TABLE ingredients(
          id TEXT PRIMARY KEY,
          name TEXT,
            category TEXT,
            base_unit TEXT,
            stock REAL DEFAULT 0,
            min_threshold REAL DEFAULT 0,
            supplier TEXT
          )
        ''');
        await db.insert('ingredients', {'id':'ING001','name':'Paneer','category':'Dairy','base_unit':'g','stock':2000,'min_threshold':500,'supplier':'Local'});
        await db.insert('ingredients', {'id':'ING002','name':'Curd','category':'Dairy','base_unit':'g','stock':1500,'min_threshold':400,'supplier':'Local'});
        await db.insert('ingredients', {'id':'ING003','name':'Spice Mix','category':'Spices','base_unit':'g','stock':1000,'min_threshold':200,'supplier':'Local'});
        await db.insert('ingredients', {'id':'ING004','name':'Oil','category':'Oils','base_unit':'ml','stock':3000,'min_threshold':800,'supplier':'Local'});
        await db.insert('ingredients', {'id':'ING005','name':'Rice','category':'Grains','base_unit':'g','stock':5000,'min_threshold':1000,'supplier':'Local'});
        await db.insert('ingredients', {'id':'ING006','name':'Chicken','category':'Meat','base_unit':'g','stock':3000,'min_threshold':700,'supplier':'Local'});
        await db.insert('ingredients', {'id':'ING007','name':'Biryani Masala','category':'Spices','base_unit':'g','stock':800,'min_threshold':200,'supplier':'Local'});
        await db.insert('ingredients', {'id':'ING008','name':'Dosa Batter','category':'Batter','base_unit':'g','stock':4000,'min_threshold':1000,'supplier':'Local'});
        await db.insert('ingredients', {'id':'ING009','name':'Potato Masala','category':'Veg','base_unit':'g','stock':2500,'min_threshold':600,'supplier':'Local'});
        await db.insert('ingredients', {'id':'ING010','name':'Flour','category':'Bakery','base_unit':'g','stock':4000,'min_threshold':900,'supplier':'Local'});
        await db.insert('ingredients', {'id':'ING011','name':'Butter','category':'Dairy','base_unit':'g','stock':1200,'min_threshold':300,'supplier':'Local'});
        await db.insert('ingredients', {'id':'ING012','name':'Yeast','category':'Bakery','base_unit':'g','stock':300,'min_threshold':50,'supplier':'Local'});
        await db.insert('ingredients', {'id':'ING013','name':'Khoya Mix','category':'Dessert','base_unit':'g','stock':1200,'min_threshold':300,'supplier':'Local'});
        await db.insert('ingredients', {'id':'ING014','name':'Sugar Syrup','category':'Dessert','base_unit':'ml','stock':1500,'min_threshold':400,'supplier':'Local'});
        await db.insert('ingredients', {'id':'ING015','name':'Milk','category':'Dairy','base_unit':'ml','stock':3000,'min_threshold':800,'supplier':'Local'});
        await db.insert('ingredients', {'id':'ING016','name':'Coffee','category':'Beverage','base_unit':'g','stock':500,'min_threshold':100,'supplier':'Local'});
        await db.insert('ingredients', {'id':'ING017','name':'Sugar','category':'Beverage','base_unit':'g','stock':2000,'min_threshold':500,'supplier':'Local'});
        await db.insert('ingredients', {'id':'ING018','name':'Black Lentils','category':'Legumes','base_unit':'g','stock':2500,'min_threshold':600,'supplier':'Local'});
        await db.insert('ingredients', {'id':'ING019','name':'Cream','category':'Dairy','base_unit':'ml','stock':1200,'min_threshold':300,'supplier':'Local'});
        await db.insert('ingredients', {'id':'ING020','name':'Roll Wrapper','category':'Bakery','base_unit':'pc','stock':200,'min_threshold':50,'supplier':'Local'});
        await db.insert('ingredients', {'id':'ING021','name':'Veg Mix','category':'Veg','base_unit':'g','stock':3000,'min_threshold':800,'supplier':'Local'});
        await db.execute('''
          CREATE TABLE recipes(
            menu_item_id INTEGER,
            ingredient_id TEXT,
            qty REAL,
            unit TEXT,
            PRIMARY KEY(menu_item_id, ingredient_id)
          )
        ''');
        await db.insert('recipes', {'menu_item_id':1,'ingredient_id':'ING001','qty':150.0,'unit':'g'});
        await db.insert('recipes', {'menu_item_id':1,'ingredient_id':'ING002','qty':50.0,'unit':'g'});
        await db.insert('recipes', {'menu_item_id':1,'ingredient_id':'ING003','qty':10.0,'unit':'g'});
        await db.insert('recipes', {'menu_item_id':1,'ingredient_id':'ING004','qty':10.0,'unit':'ml'});
        await db.insert('recipes', {'menu_item_id':2,'ingredient_id':'ING005','qty':200.0,'unit':'g'});
        await db.insert('recipes', {'menu_item_id':2,'ingredient_id':'ING006','qty':150.0,'unit':'g'});
        await db.insert('recipes', {'menu_item_id':2,'ingredient_id':'ING007','qty':8.0,'unit':'g'});
        await db.insert('recipes', {'menu_item_id':2,'ingredient_id':'ING004','qty':15.0,'unit':'ml'});
        await db.insert('recipes', {'menu_item_id':3,'ingredient_id':'ING008','qty':200.0,'unit':'g'});
        await db.insert('recipes', {'menu_item_id':3,'ingredient_id':'ING009','qty':120.0,'unit':'g'});
        await db.insert('recipes', {'menu_item_id':3,'ingredient_id':'ING004','qty':10.0,'unit':'ml'});
        await db.insert('recipes', {'menu_item_id':4,'ingredient_id':'ING010','qty':120.0,'unit':'g'});
        await db.insert('recipes', {'menu_item_id':4,'ingredient_id':'ING011','qty':10.0,'unit':'g'});
        await db.insert('recipes', {'menu_item_id':4,'ingredient_id':'ING012','qty':2.0,'unit':'g'});
        await db.insert('recipes', {'menu_item_id':5,'ingredient_id':'ING013','qty':100.0,'unit':'g'});
        await db.insert('recipes', {'menu_item_id':5,'ingredient_id':'ING014','qty':50.0,'unit':'ml'});
        await db.insert('recipes', {'menu_item_id':6,'ingredient_id':'ING015','qty':200.0,'unit':'ml'});
        await db.insert('recipes', {'menu_item_id':6,'ingredient_id':'ING016','qty':10.0,'unit':'g'});
        await db.insert('recipes', {'menu_item_id':6,'ingredient_id':'ING017','qty':15.0,'unit':'g'});
        await db.insert('recipes', {'menu_item_id':7,'ingredient_id':'ING018','qty':150.0,'unit':'g'});
        await db.insert('recipes', {'menu_item_id':7,'ingredient_id':'ING019','qty':20.0,'unit':'ml'});
        await db.insert('recipes', {'menu_item_id':7,'ingredient_id':'ING011','qty':10.0,'unit':'g'});
        await db.insert('recipes', {'menu_item_id':8,'ingredient_id':'ING020','qty':2.0,'unit':'pc'});
        await db.insert('recipes', {'menu_item_id':8,'ingredient_id':'ING021','qty':100.0,'unit':'g'});
        await db.insert('recipes', {'menu_item_id':8,'ingredient_id':'ING004','qty':15.0,'unit':'ml'});
        await db.execute('''
          CREATE TABLE inventory_txns(
            id TEXT PRIMARY KEY,
            ingredient_id TEXT,
            type TEXT,
            qty REAL,
            unit TEXT,
            cost_per_unit REAL,
            supplier TEXT,
            invoice TEXT,
            note TEXT,
            timestamp INTEGER,
            related_order_id TEXT,
            kot_number TEXT,
            reason TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE employees(
            id TEXT PRIMARY KEY,
            employee_code TEXT,
            name TEXT,
            role TEXT,
            status TEXT,
            photo TEXT,
            gross_salary REAL,
            net_salary REAL,
            personal TEXT,
            salary TEXT,
            deductions TEXT,
            payment TEXT,
            employment TEXT,
            documents TEXT,
            pin TEXT,
            created_at INTEGER,
            updated_at INTEGER,
            deleted INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE role_configs(
            id TEXT PRIMARY KEY,
            name TEXT,
            permissions TEXT,
            pin TEXT,
            updated_at INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 13) {
          try {
            await db.execute('ALTER TABLE employees ADD COLUMN deleted INTEGER DEFAULT 0');
          } catch (_) {}
        }
        if (oldVersion < 12) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS role_configs(
              id TEXT PRIMARY KEY,
              name TEXT,
              permissions TEXT,
              pin TEXT,
              updated_at INTEGER
            )
          ''');
        }
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS expenses(
              id TEXT PRIMARY KEY,
              amount REAL,
              category TEXT,
              note TEXT,
              timestamp INTEGER
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE orders ADD COLUMN settled_at INTEGER');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_settled_at ON orders(settled_at)');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS order_events(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              order_id TEXT,
              timestamp INTEGER,
              event TEXT,
              data TEXT
            )
          ''');
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS ingredients(
              id TEXT PRIMARY KEY,
              name TEXT,
              category TEXT,
              base_unit TEXT,
              stock REAL DEFAULT 0,
              min_threshold REAL DEFAULT 0,
              supplier TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS recipes(
              menu_item_id INTEGER,
              ingredient_id TEXT,
              qty REAL,
              unit TEXT,
              PRIMARY KEY(menu_item_id, ingredient_id)
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS inventory_txns(
              id TEXT PRIMARY KEY,
              ingredient_id TEXT,
              type TEXT,
              qty REAL,
              unit TEXT,
              cost_per_unit REAL,
              supplier TEXT,
              invoice TEXT,
              note TEXT,
              timestamp INTEGER,
              related_order_id TEXT,
              kot_number TEXT,
              reason TEXT
            )
          ''');
        }
        if (oldVersion < 7) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS employees(
              id TEXT PRIMARY KEY,
              employee_code TEXT,
              name TEXT,
              role TEXT,
              status TEXT,
              photo TEXT,
              gross_salary REAL,
              net_salary REAL,
              personal TEXT,
              salary TEXT,
              deductions TEXT,
              payment TEXT,
              employment TEXT,
              documents TEXT,
              created_at INTEGER,
              updated_at INTEGER
            )
          ''');
        }
        if (oldVersion < 8) {
          try {
             await db.execute('ALTER TABLE menu_items ADD COLUMN stock INTEGER');
          } catch (_) {}
        }
        if (oldVersion < 9) {
          try {
             await db.execute('ALTER TABLE employees ADD COLUMN pin TEXT');
          } catch (_) {}
        }
        if (oldVersion < 10) {
          try {
             await db.execute('ALTER TABLE employees ADD COLUMN pin TEXT');
          } catch (_) {}
        }
        if (oldVersion < 11) {
          try {
             await db.execute('ALTER TABLE employees ADD COLUMN pin TEXT');
          } catch (_) {}
        }
      },
    ));
    return db;
  }
}
