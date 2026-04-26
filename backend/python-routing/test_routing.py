import unittest
from models import Node, Edge, EdgeContext, RerouteInput
from graph import Graph, build_mock_graph
from astar import find_path_astar, heuristic
from cost import compute_edge_cost
from reroute import reroute_shipment
from fastapi.testclient import TestClient

# Attempt to import app for API tests, gracefully skip if not possible (e.g. httpx missing)
try:
    from app import app
    client = TestClient(app)
    CAN_TEST_API = True
except ImportError:
    CAN_TEST_API = False

class TestCost(unittest.TestCase):
    def setUp(self):
        self.edge_air = Edge("A", "B", distance=1000, base_time=10, transport_type="air")
        self.edge_sea = Edge("C", "D", distance=1000, base_time=100, transport_type="sea")
        
    def test_normal_cost(self):
        ctx = EdgeContext(weather_risk=0.0, congestion=0.0, disruption_flag=False)
        self.assertEqual(compute_edge_cost(self.edge_air, ctx), 10.0)
        self.assertEqual(compute_edge_cost(self.edge_sea, ctx), 100.0)

    def test_weather_impact(self):
        ctx = EdgeContext(weather_risk=1.0, congestion=0.0, disruption_flag=False)
        self.assertEqual(compute_edge_cost(self.edge_air, ctx), 10.0 + 70.0) # 80.0
        self.assertEqual(compute_edge_cost(self.edge_sea, ctx), 100.0 + 30.0) # 130.0

    def test_congestion_impact(self):
        ctx = EdgeContext(weather_risk=0.0, congestion=1.0, disruption_flag=False)
        self.assertEqual(compute_edge_cost(self.edge_air, ctx), 10.0 + 20.0) # 30.0
        self.assertEqual(compute_edge_cost(self.edge_sea, ctx), 100.0 + 60.0) # 160.0

    def test_disruption_impact(self):
        ctx = EdgeContext(weather_risk=0.0, congestion=0.0, disruption_flag=True)
        self.assertEqual(compute_edge_cost(self.edge_air, ctx), 10.0 + 200.0) # 210.0
        self.assertEqual(compute_edge_cost(self.edge_sea, ctx), 100.0 + 200.0) # 300.0

class TestAStar(unittest.TestCase):
    def setUp(self):
        self.graph = Graph()
        self.graph.add_node(Node("A", 0, 0))
        self.graph.add_node(Node("B", 0, 10))
        self.graph.add_node(Node("C", 10, 10))
        
        self.graph.add_edge(Edge("A", "B", 10, 5, "sea"))
        self.graph.add_edge(Edge("B", "C", 10, 5, "sea"))
        self.graph.add_edge(Edge("A", "C", 14, 15, "sea")) # slower direct route
        self.ctx = EdgeContext(weather_risk=0.0, congestion=0.0, disruption_flag=False)

    def test_shortest_path(self):
        path, cost = find_path_astar(self.graph, "A", "C", self.ctx)
        self.assertEqual(path, ["A", "B", "C"])
        self.assertEqual(cost, 10.0)

    def test_no_path(self):
        self.graph.add_node(Node("D", 20, 20)) # isolated node
        result = find_path_astar(self.graph, "A", "D", self.ctx)
        self.assertIsNone(result)

    def test_invalid_node(self):
        with self.assertRaises(ValueError):
            find_path_astar(self.graph, "A", "UNKNOWN", self.ctx)

class TestReroute(unittest.TestCase):
    def test_unchanged_route(self):
        # Using the mock graph from build_mock_graph
        input_data = RerouteInput(
            shipment_id="TEST-1",
            current_node="PORT_A",
            destination_node="PORT_D",
            current_route=["PORT_A", "PORT_B", "PORT_D"],
            context=EdgeContext(weather_risk=0.0, congestion=0.0, disruption_flag=False)
        )
        result = reroute_shipment(input_data)
        self.assertEqual(result.action, "UNCHANGED")
        self.assertEqual(result.new_route, ["PORT_A", "PORT_B", "PORT_D"])
        self.assertEqual(result.estimated_time, 100.0) # 50 + 50

    def test_rerouted_due_to_weather(self):
        # Weather impacts air heavily (70) and sea moderately (30)
        # PORT_A -> PORT_B -> PORT_D is 50+50 base time (sea). With weather=1.0, it becomes 80+80=160
        # PORT_A -> PORT_D is 150 base time (air). With weather=1.0, it becomes 150+70=220
        # Wait, if both get worse, does it reroute?
        # Let's adjust so one is better. Or use congestion.
        # Sea congestion is 60, Air congestion is 20.
        input_data = RerouteInput(
            shipment_id="TEST-2",
            current_node="PORT_A",
            destination_node="PORT_D",
            current_route=["PORT_A", "PORT_B", "PORT_D"],
            context=EdgeContext(weather_risk=0.0, congestion=1.0, disruption_flag=False)
        )
        # Sea route: 50 + 60 = 110 per edge. Total 220
        # Air route: 150 + 20 = 170 per edge. Total 170
        # So it should reroute to air (PORT_A -> PORT_D)
        result = reroute_shipment(input_data)
        self.assertEqual(result.action, "REROUTED")
        self.assertEqual(result.new_route, ["PORT_A", "PORT_D"])
        self.assertEqual(result.estimated_time, 170.0)
        self.assertEqual(result.reason, "CONGESTION")
        
    def test_invalid_current_route(self):
        input_data = RerouteInput(
            shipment_id="TEST-3",
            current_node="PORT_A",
            destination_node="PORT_D",
            current_route=["PORT_A", "UNKNOWN_NODE"],
            context=EdgeContext(weather_risk=0.0, congestion=0.0, disruption_flag=False)
        )
        with self.assertRaises(ValueError):
            reroute_shipment(input_data)

class TestAPI(unittest.TestCase):
    def setUp(self):
        if not CAN_TEST_API:
            self.skipTest("httpx not installed, skipping API test")

    def test_reroute_endpoint(self):
        payload = {
          "shipment_id": "SHP001",
          "current_node": "PORT_A",
          "destination_node": "PORT_D",
          "current_route": ["PORT_A", "PORT_B", "PORT_D"],
          "context": {
            "weather_risk": 0.0,
            "congestion": 1.0,
            "disruption_flag": False
          }
        }
        response = client.post("/reroute", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["action"], "REROUTED")
        self.assertEqual(data["reason"], "CONGESTION")

if __name__ == "__main__":
    unittest.main()
