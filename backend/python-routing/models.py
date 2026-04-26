from dataclasses import dataclass
from typing import List, Optional

@dataclass
class Node:
    """Represents a physical location in the logistics network."""
    id: str
    lat: float
    lng: float

@dataclass
class Edge:
    """Represents a connection between two nodes."""
    from_node: str
    to_node: str
    distance: float
    base_time: float
    transport_type: str  # 'air' or 'sea'

@dataclass
class EdgeContext:
    """Dynamic context factors affecting route cost."""
    weather_risk: float
    congestion: float
    disruption_flag: bool

@dataclass
class RerouteInput:
    """Input structure for rerouting logic."""
    shipment_id: str
    current_node: str
    destination_node: str
    current_route: List[str]
    context: EdgeContext

@dataclass
class RerouteOutput:
    """Output structure for reroute decision."""
    shipment_id: str
    action: str  # 'REROUTED' or 'UNCHANGED'
    new_route: List[str]
    estimated_time: float
    improvement: float
    reason: Optional[str]
