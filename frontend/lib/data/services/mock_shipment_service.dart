import 'package:meridian/data/models/shipment.dart';
import 'package:meridian/data/mock/mock_shipments.dart';
import 'package:meridian/data/repositories/shipment_repository.dart';

/// Mock implementation of [ShipmentRepository].
///
/// Returns data from [mockShipments]. Simulates async latency
/// so UI code handles loading states correctly from day one.
class MockShipmentService implements ShipmentRepository {
  static const _latency = Duration(milliseconds: 400);

  @override
  Future<List<Shipment>> getAll() async {
    await Future.delayed(_latency);
    return List.unmodifiable(mockShipments);
  }

  @override
  Future<Shipment?> getById(String id) async {
    await Future.delayed(_latency);
    try {
      return mockShipments.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Shipment>> getByStatus(ShipmentStatus status) async {
    await Future.delayed(_latency);
    return mockShipments.where((s) => s.status == status).toList();
  }

  @override
  Future<List<Shipment>> getByMode(TransportMode mode) async {
    await Future.delayed(_latency);
    return mockShipments.where((s) => s.mode == mode).toList();
  }

  @override
  Future<int> getActiveCount() async {
    await Future.delayed(_latency);
    return mockShipments
        .where((s) =>
            s.status == ShipmentStatus.inTransit ||
            s.status == ShipmentStatus.delayed)
        .length;
  }
}
