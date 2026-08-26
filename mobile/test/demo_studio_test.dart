import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeventory/features/homes/data/demo_studio_catalog.dart';
import 'package:homeventory/shared/models/enums.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DemoStudioCatalog catalog;

  setUpAll(() async {
    catalog = await DemoStudioCatalog.load();
  });

  test('demo studio matches the spreadsheet totals', () {
    expect(catalog.rooms.map((r) => r.name), ['Studio', 'Kitchen', 'Bathroom']);
    expect(catalog.inventoryEntries.length, 68);
    expect(catalog.inventoryEntries.length, catalog.expectedItemCount);
    expect(catalog.listedValue, 213925);
    expect(catalog.listedValue, catalog.expectedValue);
    expect(catalog.home.defaultCurrency, 'THB');
    expect(catalog.home.timezone, 'Asia/Bangkok');
    expect(catalog.home.name, demoStudioHomeName);
  });

  test('nested furniture holds the items named in the location column', () {
    final studio = catalog.rooms.first;
    final bed = studio.nodes.firstWhere((n) => n.name == 'Double bed frame');
    expect(bed.kind, InventoryNodeKind.furniture);
    expect(bed.container, isTrue);
    expect(
      bed.children.map((n) => n.name),
      containsAll([
        'Queen mattress',
        'Beige fitted sheet set',
        'Beige duvet',
        'Sleeping pillow',
      ]),
    );

    final wardrobe = studio.nodes.firstWhere(
      (n) => n.name == 'Two-door wardrobe',
    );
    final left = wardrobe.children.firstWhere((n) => n.name == 'Left section');
    expect(left.kind, InventoryNodeKind.storageLocation);
    expect(
      left.children.map((n) => n.name),
      containsAll(['White work shirt', 'Casual T-shirt', 'Trousers']),
    );
  });

  test('clothing and kitchen categories follow the spreadsheet types', () {
    final shirts = catalog.inventoryEntries.firstWhere(
      (n) => n.name == 'White work shirt',
    );
    expect(shirts.kind, InventoryNodeKind.item);
    expect(shirts.category, ItemCategory.clothing);

    final water = catalog.inventoryEntries.firstWhere(
      (n) => n.name == 'Bottled water',
    );
    expect(water.category, ItemCategory.edible);
    expect(water.quantity, 6);

    final duvet = catalog.inventoryEntries.firstWhere(
      (n) => n.name == 'Beige duvet',
    );
    expect(duvet.category, ItemCategory.misc);

    final tv = catalog.inventoryEntries.firstWhere(
      (n) => n.name == 'Flat-screen television',
    );
    expect(tv.category, ItemCategory.electronics);
    expect(tv.price, 12990);
  });

  test('every photo key resolves to a bundled jpeg', () async {
    expect(
      catalog.photos.keys,
      containsAll([
        'overview',
        'sleeping',
        'living',
        'media',
        'kitchen',
        'bathroom',
      ]),
    );
    for (final path in catalog.photos.values) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(1000));
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      expect(bytes[0], 0xFF);
      expect(bytes[1], 0xD8);
    }
  });
}
