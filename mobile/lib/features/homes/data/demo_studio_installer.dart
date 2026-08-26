import 'package:flutter/services.dart';

import '../../../shared/models/enums.dart';
import '../../../shared/models/home.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../rooms/data/rooms_repository.dart';
import 'demo_studio_catalog.dart';
import 'homes_repository.dart';

/// Creates the bundled Bangkok studio home, rooms, nested inventory, and photos.
class DemoStudioInstaller {
  DemoStudioInstaller({
    required this.homes,
    required this.rooms,
    required this.inventory,
    AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle;

  final HomesRepository homes;
  final RoomsRepository rooms;
  final InventoryRepository inventory;
  final AssetBundle _bundle;

  Future<Home> install({void Function(String status)? onProgress}) async {
    final catalog = await DemoStudioCatalog.load(_bundle);
    onProgress?.call('Creating ${catalog.home.name}…');
    final home = await homes.createHome(
      name: catalog.home.name,
      description: catalog.home.description,
      addressText: catalog.home.addressText,
      timezone: catalog.home.timezone,
      defaultCurrency: catalog.home.defaultCurrency,
      residingSince: catalog.home.residingSince,
    );
    await _uploadPhoto(
      catalog,
      key: catalog.home.photo,
      upload: (bytes) => inventory.uploadHomeImage(
        homeId: home.id,
        bytes: bytes,
        mimeType: 'image/jpeg',
      ),
    );

    for (final roomDef in catalog.rooms) {
      onProgress?.call('Setting up ${roomDef.name}…');
      final room = await rooms.createRoom(
        homeId: home.id,
        name: roomDef.name,
        description: roomDef.description,
        sortOrder: roomDef.sortOrder,
      );
      await _uploadPhoto(
        catalog,
        key: roomDef.photo,
        upload: (bytes) => inventory.uploadRoomImage(
          homeId: home.id,
          roomId: room.id,
          bytes: bytes,
          mimeType: 'image/jpeg',
        ),
      );
      for (final node in roomDef.nodes) {
        await _createNode(
          catalog: catalog,
          homeId: home.id,
          roomId: room.id,
          parentNodeId: null,
          node: node,
          onProgress: onProgress,
        );
      }
    }
    return home;
  }

  Future<void> _createNode({
    required DemoStudioCatalog catalog,
    required String homeId,
    required String roomId,
    required String? parentNodeId,
    required DemoStudioNode node,
    void Function(String status)? onProgress,
  }) async {
    if (node.isInventoryEntry) {
      onProgress?.call('Adding ${node.name}…');
    }
    final created = await inventory.createNode(
      homeId: homeId,
      roomId: roomId,
      parentNodeId: parentNodeId,
      nodeKind: node.kind,
      name: node.name,
      description: node.description,
      isContainer: node.container || node.children.isNotEmpty,
      itemCategory: node.kind == InventoryNodeKind.item ? node.category : null,
      quantity: node.kind == InventoryNodeKind.storageLocation
          ? null
          : node.quantity,
      purchasePrice: node.kind == InventoryNodeKind.storageLocation
          ? null
          : node.price,
      currency: node.kind == InventoryNodeKind.storageLocation
          ? null
          : node.currency,
      purchaseDate: node.purchased,
    );
    await _uploadPhoto(
      catalog,
      key: node.photo,
      upload: (bytes) => inventory.uploadNodeImage(
        homeId: homeId,
        nodeId: created.id,
        bytes: bytes,
        mimeType: 'image/jpeg',
      ),
    );
    for (final child in node.children) {
      await _createNode(
        catalog: catalog,
        homeId: homeId,
        roomId: roomId,
        parentNodeId: created.id,
        node: child,
        onProgress: onProgress,
      );
    }
  }

  Future<void> _uploadPhoto(
    DemoStudioCatalog catalog, {
    required String? key,
    required Future<void> Function(Uint8List bytes) upload,
  }) async {
    if (key == null) return;
    final data = await _bundle.load(catalog.photoAsset(key));
    await upload(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }
}
