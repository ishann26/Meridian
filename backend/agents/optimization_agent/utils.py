import math
from typing import List, Dict, Any

def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate the great circle distance in kilometers between two points on the earth."""
    R = 6371.0  # Earth radius in kilometers
    
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    
    a = (math.sin(dlat / 2)**2 + 
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    
    return R * c

def build_distance_matrix(origin: Dict[str, float], stops: List[Dict[str, Any]]) -> List[List[float]]:
    """
    Build a 2D distance matrix in km.
    origin is index 0, followed by each stop.
    """
    locations = [origin]
    for stop in stops:
        locations.append(stop['location'])
        
    num_locations = len(locations)
    distance_matrix = []
    
    for i in range(num_locations):
        row = []
        for j in range(num_locations):
            if i == j:
                row.append(0.0)
            else:
                dist = haversine_distance(
                    locations[i]['latitude'], locations[i]['longitude'],
                    locations[j]['latitude'], locations[j]['longitude']
                )
                row.append(dist)
        distance_matrix.append(row)
        
    return distance_matrix
