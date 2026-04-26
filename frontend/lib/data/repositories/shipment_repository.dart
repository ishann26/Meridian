import 'package:meridian/data/models/shipment.dart';

/// Contract for shipment data access.
///
/// Implementations: [MockShipmentService] (now), FirebaseShipmentService (later).
abstract class ShipmentRepository {
  /// Fetch all shipments.
  Future<List<Shipment>> getAll();

  /// Fetch a single shipment by ID.
  Future<Shipment?> getById(String id);

  /// Fetch shipments filtered by status.
  Future<List<Shipment>> getByStatus(ShipmentStatus status);

  /// Fetch shipments filtered by transport mode.
  Future<List<Shipment>> getByMode(TransportMode mode);

  /// Count of shipments currently in transit or delayed.
  Future<int> getActiveCount();
}
