from typing import Dict, List
from models import Node, Edge

class Graph:
    """A directed graph representing the logistics network."""
    
    def __init__(self):
        self.nodes: Dict[str, Node] = {}
        self.adjacency_list: Dict[str, List[Edge]] = {}

    def add_node(self, node: Node) -> None:
        """Adds a new node to the graph."""
        if node.id not in self.nodes:
            self.nodes[node.id] = node
            self.adjacency_list[node.id] = []

    def add_edge(self, edge: Edge) -> None:
        """Adds a new edge to the graph. Nodes must exist."""
        if edge.from_node not in self.nodes or edge.to_node not in self.nodes:
            raise ValueError(f"Nodes {edge.from_node} or {edge.to_node} do not exist.")
        self.adjacency_list[edge.from_node].append(edge)

    def get_neighbors(self, node_id: str) -> List[Edge]:
        """Returns all outgoing edges from the given node."""
        return self.adjacency_list.get(node_id, [])

def build_mock_graph() -> Graph:
    """Constructs a mock global logistics network."""
    graph = Graph()

    # Ports
    ports = [
        Node("port_shanghai", 31.23, 121.47),
        Node("port_singapore", 1.35, 103.81),
        Node("port_rotterdam", 51.92, 4.47),
        Node("port_los_angeles", 33.72, -118.26),
    ]

    # Airports
    airports = [
        Node("airport_hong_kong", 22.30, 113.91),
        Node("airport_frankfurt", 50.03, 8.57),
        Node("airport_jfk_ny", 40.64, -73.77),
        Node("airport_tokyo", 35.54, 139.77),
    ]

    # Transfer Hubs
    hubs = [
        Node("transfer_sg_hub", 1.36, 103.99),
        Node("transfer_la_hub", 33.94, -118.40),
        Node("transfer_eu_hub", 51.50, 4.00),
    ]

    # Sample Nodes for Demo
    demo_nodes = [
        Node("PORT_A", 10.0, 10.0),
        Node("PORT_B", 20.0, 20.0),
        Node("PORT_D", 30.0, 30.0),
    ]

    for node in ports + airports + hubs + demo_nodes:
        graph.add_node(node)

    def add_bidirectional_edge(from_node: str, to_node: str, distance: float, base_time: float, transport_type: str):
        graph.add_edge(Edge(from_node, to_node, distance, base_time, transport_type))
        graph.add_edge(Edge(to_node, from_node, distance, base_time, transport_type))

    # Sea Routes
    add_bidirectional_edge("port_shanghai", "port_singapore", 2200, 120, "sea")
    add_bidirectional_edge("port_singapore", "port_rotterdam", 8300, 480, "sea")
    add_bidirectional_edge("port_shanghai", "port_los_angeles", 5800, 280, "sea")

    # Air Routes
    add_bidirectional_edge("airport_hong_kong", "airport_tokyo", 1800, 4, "air")
    add_bidirectional_edge("airport_tokyo", "airport_jfk_ny", 6700, 14, "air")
    add_bidirectional_edge("airport_jfk_ny", "airport_frankfurt", 3800, 8, "air")

    # Transfer Connections
    add_bidirectional_edge("port_singapore", "transfer_sg_hub", 20, 2, "sea")
    add_bidirectional_edge("transfer_sg_hub", "airport_hong_kong", 1600, 4, "air")
    
    add_bidirectional_edge("port_los_angeles", "transfer_la_hub", 30, 2, "sea")
    add_bidirectional_edge("transfer_la_hub", "airport_jfk_ny", 2400, 5, "air")

    add_bidirectional_edge("port_rotterdam", "transfer_eu_hub", 50, 4, "sea")
    add_bidirectional_edge("transfer_eu_hub", "airport_frankfurt", 350, 1, "air")

    # Sample Edges for Demo
    add_bidirectional_edge("PORT_A", "PORT_B", 1000, 50, "sea")
    add_bidirectional_edge("PORT_B", "PORT_D", 1000, 50, "sea")
    add_bidirectional_edge("PORT_A", "PORT_D", 2000, 150, "air")

    return graph
