import 'package:flutter/material.dart';

import '../../features/inventory/data/inventory_repository.dart';
import '../models/enums.dart';
import '../models/inventory_node.dart';

/// Leading/fallback icon matching inventory browse cards.
IconData inventoryNodeIcon(InventoryNode node) {
  return switch (node.nodeKind) {
    InventoryNodeKind.furniture => Icons.weekend_outlined,
    InventoryNodeKind.storageLocation => Icons.grid_view_outlined,
    InventoryNodeKind.item =>
      node.isContainer ? Icons.work_outline : Icons.inventory_2_outlined,
  };
}

/// Builds a list subtitle that always leads with location when available.
String inventoryNodeSubtitle(
  InventoryNode node, {
  String? locationPath,
  PackedNodeInfo? packed,
}) {
  final parts = <String>[
    if (locationPath != null && locationPath.trim().isNotEmpty)
      locationPath.trim(),
    node.kindLabel,
    if (node.itemCategory != null) node.itemCategory!.label,
  ];
  if (node.quantity != null) {
    parts.add(
      [
        _formatQty(node.quantity!),
        if (node.quantityUnit != null) node.quantityUnit!,
      ].join(' '),
    );
  }
  if (node.purchasePrice != null) {
    parts.add(
      '${node.currency ?? ''} ${_formatQty(node.purchasePrice!)}'.trim(),
    );
  }
  if (packed != null) {
    parts.add(
      'Packed · ${packed.tripName}'
      '${packed.packedIntoName != null ? ' (${packed.packedIntoName})' : ''}',
    );
  }
  return parts.join(' · ');
}

String _formatQty(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}

/// One name per line, or comma/semicolon separated. Trims blanks.
List<String> parseBulkItemNames(String raw) {
  return raw
      .split(RegExp(r'[\n,;]+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
}
