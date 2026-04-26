from models import Edge, EdgeContext

def compute_edge_cost(edge: Edge, context: EdgeContext) -> float:
    """
    Computes the dynamic cost of traversing an edge given current context.
    Base cost is base_time.
    Air transport is highly affected by weather.
    Sea transport is highly affected by congestion.
    Disruptions add a flat heavy penalty.
    """
    cost = edge.base_time

    if edge.transport_type == "air":
        cost += context.weather_risk * 70.0
        cost += context.congestion * 20.0
    elif edge.transport_type == "sea":
        cost += context.weather_risk * 30.0
        cost += context.congestion * 60.0

    if context.disruption_flag:
        cost += 200.0

    return float(cost)
