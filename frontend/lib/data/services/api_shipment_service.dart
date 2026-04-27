import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:meridian/data/models/shipment.dart';
import 'package:meridian/data/repositories/shipment_repository.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Real API implementation for shipment data.
///
/// Connects to the Express API for REST calls and WebSockets for live updates.
class ApiShipmentService implements ShipmentRepository {
  ApiShipmentService({
    this.baseUrl = 'http://localhost:3000',
    this.wsUrl = 'ws://localhost:3000',
  });

  final String baseUrl;
  final String wsUrl;

  WebSocketChannel? _channel;

  /// Stream of shipment updates from the server.
  Stream<dynamic> get updates {
    _channel ??= WebSocketChannel.connect(Uri.parse(wsUrl));
    return _channel!.stream;
  }

  @override
  Future<List<Shipment>> getAll() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/shipments'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => Shipment.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('API Error (getAll): $e');
      return [];
    }
  }

  @override
  Future<Shipment?> getById(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/shipments/$id'));
      if (response.statusCode == 200) {
        return Shipment.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      print('API Error (getById): $e');
      return null;
    }
  }

  @override
  Future<List<Shipment>> getByStatus(ShipmentStatus status) async {
    final all = await getAll();
    return all.where((s) => s.status == status).toList();
  }

  @override
  Future<List<Shipment>> getByMode(TransportMode mode) async {
    final all = await getAll();
    return all.where((s) => s.mode == mode).toList();
  }

  @override
  Future<int> getActiveCount() async {
    final all = await getAll();
    return all.where((s) => s.status == ShipmentStatus.inTransit || s.status == ShipmentStatus.delayed).length;
  }

  void dispose() {
    _channel?.sink.close();
  }
}
