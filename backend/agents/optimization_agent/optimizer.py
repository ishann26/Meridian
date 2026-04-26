import math
from typing import List, Dict, Any, Tuple

from ortools.constraint_solver import routing_enums_pb2
from ortools.constraint_solver import pywrapcp

from utils import haversine_distance


def calculate_travel_time_minutes(distance_km: float, speed_kmh: float = 60.0) -> int:
    """Calculate travel time in minutes given distance in km and speed in km/h."""
    if speed_kmh <= 0:
        return 0
    hours = distance_km / speed_kmh
    return int(round(hours * 60))


def extract_locations(input_data: Dict[str, Any]) -> List[Dict[str, float]]:
    """Extract all locations (origin + stops) from input data."""
    locations = [input_data['origin']]
    for stop in input_data.get('stops', []):
        locations.append(stop['location'])
    return locations


def extract_demands(input_data: Dict[str, Any]) -> List[int]:
    """Extract demands for all locations. Origin has 0 demand."""
    demands = [0]  # Depot has 0 demand
    for stop in input_data.get('stops', []):
        demands.append(stop.get('demand_kg', 0))
    return demands


def extract_time_windows(input_data: Dict[str, Any], max_time: int) -> List[Tuple[int, int]]:
    """Extract time windows for all locations."""
    time_windows = [(0, max_time)]  # Origin time window
    for stop in input_data.get('stops', []):
        tw = stop.get('time_window')
        if tw and len(tw) == 2:
            time_windows.append((tw[0], tw[1]))
        else:
            time_windows.append((0, max_time))
    return time_windows


def build_matrices(locations: List[Dict[str, float]]) -> Tuple[List[List[int]], List[List[int]]]:
    """Build distance matrix (in meters) and time matrix (in minutes)."""
    num_locations = len(locations)
    distance_matrix = []
    time_matrix = []
    
    for i in range(num_locations):
        dist_row = []
        time_row = []
        for j in range(num_locations):
            if i == j:
                dist_row.append(0)
                time_row.append(0)
                continue
                
            dist_km = haversine_distance(
                locations[i]['latitude'], locations[i]['longitude'],
                locations[j]['latitude'], locations[j]['longitude']
            )
            # OR-Tools requires integer weights
            dist_row.append(int(round(dist_km * 1000)))  # distance in meters
            time_row.append(calculate_travel_time_minutes(dist_km)) # time in minutes
            
        distance_matrix.append(dist_row)
        time_matrix.append(time_row)
        
    return distance_matrix, time_matrix


def create_data_model(input_data: Dict[str, Any]) -> Dict[str, Any]:
    """Creates the data structure needed for the OR-Tools routing model."""
    data = {}
    
    locations = extract_locations(input_data)
    data['distance_matrix'], data['time_matrix'] = build_matrices(locations)
    data['demands'] = extract_demands(input_data)
    
    vehicle = input_data.get('vehicle', {})
    max_driving_minutes = vehicle.get('max_driving_minutes', 1440) # default 24 hours
    
    data['time_windows'] = extract_time_windows(input_data, max_driving_minutes)
    data['vehicle_capacities'] = [vehicle.get('capacity_kg', 0)]
    data['max_driving_minutes'] = max_driving_minutes
    data['num_vehicles'] = 1
    data['depot'] = 0
    
    return data


def setup_capacity_dimension(manager, routing, data):
    """Sets up the capacity constraint dimension."""
    def demand_callback(from_index):
        from_node = manager.IndexToNode(from_index)
        return data['demands'][from_node]

    demand_callback_index = routing.RegisterUnaryTransitCallback(demand_callback)
    routing.AddDimensionWithVehicleCapacity(
        demand_callback_index,
        0,  # null capacity slack
        data['vehicle_capacities'],  # vehicle maximum capacities
        True,  # start cumul to zero
        'Capacity'
    )


def setup_time_dimension(manager, routing, data):
    """Sets up the time constraint dimension with time windows."""
    def time_callback(from_index, to_index):
        from_node = manager.IndexToNode(from_index)
        to_node = manager.IndexToNode(to_index)
        return data['time_matrix'][from_node][to_node]

    time_callback_index = routing.RegisterTransitCallback(time_callback)
    
    # Add Time dimension.
    routing.AddDimension(
        time_callback_index,
        1440,  # allow waiting time (e.g. up to 24 hours)
        data['max_driving_minutes'],  # maximum time per vehicle
        False,  # Don't force start cumul to zero
        'Time'
    )
    
    time_dimension = routing.GetDimensionOrDie('Time')
    
    # Add time window constraints for each location except depot.
    for location_idx, time_window in enumerate(data['time_windows']):
        if location_idx == data['depot']:
            continue
        index = manager.NodeToIndex(location_idx)
        time_dimension.CumulVar(index).SetRange(time_window[0], time_window[1])
        
    # Add time window constraints for each vehicle start node.
    depot_idx = data['depot']
    for vehicle_id in range(data['num_vehicles']):
        index = routing.Start(vehicle_id)
        time_dimension.CumulVar(index).SetRange(
            data['time_windows'][depot_idx][0],
            data['time_windows'][depot_idx][1]
        )

    # Instantiate route start and end times to produce feasible times.
    for i in range(data['num_vehicles']):
        routing.AddVariableMinimizedByFinalizer(time_dimension.CumulVar(routing.Start(i)))
        routing.AddVariableMinimizedByFinalizer(time_dimension.CumulVar(routing.End(i)))


def format_solution(manager, routing, solution, input_data, data) -> Dict[str, Any]:
    """Formats the final solution into the required JSON/Dict format."""
    stops = input_data.get('stops', [])
    time_dimension = routing.GetDimensionOrDie('Time')
    
    route_names = ["Origin"]
    total_distance_meters = 0
    
    index = routing.Start(0)
    
    while not routing.IsEnd(index):
        previous_index = index
        index = solution.Value(routing.NextVar(index))
        
        # Accumulate distance
        total_distance_meters += routing.GetArcCostForVehicle(previous_index, index, 0)
        
        # Find stop name
        node_index = manager.IndexToNode(index)
        if not routing.IsEnd(index):
            route_names.append(stops[node_index - 1]['name'])
            
    route_names.append("Origin")
    
    # Get total time from the end node
    end_index = routing.End(0)
    total_time_minutes = solution.Min(time_dimension.CumulVar(end_index))
    
    return {
        "route": route_names,
        "total_distance": total_distance_meters / 1000.0,  # convert back to km
        "total_time": total_time_minutes
    }


def optimize_route(input_data: Dict[str, Any]) -> Dict[str, Any]:
    """Main function to solve the CVRP with time windows."""
    # 1. Create data model
    data = create_data_model(input_data)

    # 2. Create Routing Index Manager & Routing Model
    manager = pywrapcp.RoutingIndexManager(
        len(data['distance_matrix']),
        data['num_vehicles'],
        data['depot']
    )
    routing = pywrapcp.RoutingModel(manager)

    # 3. Define arc costs (distance in meters)
    def distance_callback(from_index, to_index):
        from_node = manager.IndexToNode(from_index)
        to_node = manager.IndexToNode(to_index)
        return data['distance_matrix'][from_node][to_node]

    transit_callback_index = routing.RegisterTransitCallback(distance_callback)
    routing.SetArcCostEvaluatorOfAllVehicles(transit_callback_index)

    # 4. Add Constraints (Capacity and Time Windows)
    setup_capacity_dimension(manager, routing, data)
    setup_time_dimension(manager, routing, data)

    # 5. Set search parameters
    search_parameters = pywrapcp.DefaultRoutingSearchParameters()
    search_parameters.first_solution_strategy = (
        routing_enums_pb2.FirstSolutionStrategy.PATH_CHEAPEST_ARC)
    search_parameters.local_search_metaheuristic = (
        routing_enums_pb2.LocalSearchMetaheuristic.GUIDED_LOCAL_SEARCH)
    search_parameters.time_limit.FromSeconds(5)

    # 6. Solve
    solution = routing.SolveWithParameters(search_parameters)

    # 7. Output formatted result
    if solution:
        return format_solution(manager, routing, solution, input_data, data)
    else:
        return {"error": "No solution found meeting all constraints."}
