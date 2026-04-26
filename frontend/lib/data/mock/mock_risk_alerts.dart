import 'package:meridian/data/models/risk_alert.dart';

/// Four seed risk alerts at different severity levels.
final List<RiskAlert> mockRiskAlerts = [
  RiskAlert(
    id: 'RSK-001',
    title: 'Typhoon Approaching South China Sea',
    description:
        'Category 3 typhoon projected to cross major shipping lanes '
        'between Shanghai and Singapore within 72 hours. Expect 2–4 day '
        'delays for vessels in the region.',
    severity: RiskSeverity.critical,
    category: RiskCategory.weather,
    affectedRegion: 'South China Sea',
    detectedAt: DateTime(2026, 4, 25, 14, 30),
    confidence: 0.92,
    affectedShipmentIds: ['SHP-002'],
    recommendation:
        'Reroute SHP-002 via the Lombok Strait to avoid the storm '
        'path. Estimated +1.5 days but avoids 3-day weather hold.',
  ),
  RiskAlert(
    id: 'RSK-002',
    title: 'Port of Rotterdam Congestion Spike',
    description:
        'Container dwell times at Rotterdam have increased 40% over '
        'the past week due to labor shortages and a backlog of 12 vessels '
        'waiting for berth allocation.',
    severity: RiskSeverity.high,
    category: RiskCategory.portCongestion,
    affectedRegion: 'Rotterdam, Netherlands',
    detectedAt: DateTime(2026, 4, 24, 9, 15),
    confidence: 0.87,
    affectedShipmentIds: ['SHP-001'],
    recommendation:
        'Divert SHP-001 to Antwerp (120km south) and use road '
        'transport for the last mile. Saves ~2 days vs waiting for '
        'Rotterdam berth.',
  ),
  RiskAlert(
    id: 'RSK-003',
    title: 'New Customs Regulation — India Textiles',
    description:
        'India\'s CBIC has introduced additional documentation '
        'requirements for interstate textile shipments effective Apr 26. '
        'Expect 12–24h additional processing at checkpoints.',
    severity: RiskSeverity.medium,
    category: RiskCategory.regulatory,
    affectedRegion: 'India — Interstate',
    detectedAt: DateTime(2026, 4, 23, 18, 0),
    confidence: 0.95,
    affectedShipmentIds: ['SHP-004'],
    recommendation:
        'Pre-file the new GST annexure forms before SHP-004 reaches '
        'the Telangana–Karnataka border to avoid checkpoint hold.',
  ),
  RiskAlert(
    id: 'RSK-004',
    title: 'Supplier Lead-Time Increase — Electronics',
    description:
        'Key semiconductor supplier in Shenzhen reports 15% longer '
        'lead times due to raw material shortages. May impact future '
        'electronics shipments from the region.',
    severity: RiskSeverity.low,
    category: RiskCategory.supplierDelay,
    affectedRegion: 'Shenzhen, China',
    detectedAt: DateTime(2026, 4, 22, 11, 45),
    confidence: 0.73,
    affectedShipmentIds: [],
    recommendation:
        'No immediate action needed. Monitor supplier updates and '
        'consider pre-ordering buffer stock for Q3 shipments.',
  ),
];
