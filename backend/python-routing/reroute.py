from models import RerouteInput, RerouteOutput
from graph import build_mock_graph
from astar import find_path_astar
from cost import compute_edge_cost

def reroute_shipment(input_data: RerouteInput) -> RerouteOutput:
    """
    Evaluates the current shipment route against dynamic context conditions
    and reroutes it if a faster path is found via A*.
    """
    graph = build_mock_graph()

    # Find the optimal new route
    astar_result = find_path_astar(
        graph, 
        input_data.current_node, 
        input_data.destination_node, 
        input_data.context
    )

    if not astar_result:
        raise ValueError(f"Unable to find path from {input_data.current_node} to {input_data.destination_node}")

    new_route, new_cost = astar_result

    # Calculate current route cost
    current_cost = 0.0
    for i in range(len(input_data.current_route) - 1):
        from_node = input_data.current_route[i]
        to_node = input_data.current_route[i + 1]
        
        edges_to_next = [e for e in graph.get_neighbors(from_node) if e.to_node == to_node]
        if not edges_to_next:
            raise ValueError(f"Current route is invalid: No edge between {from_node} and {to_node}")

        # Find the cheapest edge if multiple modes exist
        min_edge_cost = float('inf')
        for edge in edges_to_next:
            cost = compute_edge_cost(edge, input_data.context)
            if cost < min_edge_cost:
                min_edge_cost = cost
        
        current_cost += min_edge_cost

    # Compare and decide action
    if new_cost < current_cost:
        action = "REROUTED"
        final_route = new_route
        estimated_time = new_cost
    else:
        action = "UNCHANGED"
        final_route = input_data.current_route
        estimated_time = current_cost

    # Determine reason
    reason = None
    if input_data.context.weather_risk > 0.6:
        reason = "WEATHER"
    elif input_data.context.congestion > 0.6:
        reason = "CONGESTION"
    elif input_data.context.disruption_flag:
        reason = "DISRUPTION"

    return RerouteOutput(
        shipment_id=input_data.shipment_id,
        action=action,
        new_route=final_route,
        estimated_time=estimated_time,
        improvement=current_cost - new_cost,
        reason=reason
    )
