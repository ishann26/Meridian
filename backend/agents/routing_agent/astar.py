import math
import heapq
from typing import List, Tuple, Optional, Dict
from models import Node, EdgeContext
from graph import Graph
from cost import compute_edge_cost

def heuristic(node_a: Node, node_b: Node) -> float:
    """Calculates straight-line (Euclidean) distance between two nodes."""
    dx = node_a.lat - node_b.lat
    dy = node_a.lng - node_b.lng
    return math.sqrt(dx * dx + dy * dy)

def find_path_astar(
    graph: Graph, 
    start_node_id: str, 
    end_node_id: str, 
    context: EdgeContext
) -> Optional[Tuple[List[str], float]]:
    """
    A* pathfinding algorithm implementation.
    Returns a tuple of (path, total_cost), or None if no path is found.
    """
    start_node = graph.nodes.get(start_node_id)
    end_node = graph.nodes.get(end_node_id)

    if not start_node or not end_node:
        raise ValueError("Start or end node not found in graph.")

    # open_set stores tuples of (f_score, count, node_id)
    # count is used to break ties and prevent comparing string node_ids
    open_set: List[Tuple[float, int, str]] = []
    counter = 0
    heapq.heappush(open_set, (0.0, counter, start_node_id))

    came_from: Dict[str, str] = {}
    
    g_score: Dict[str, float] = {start_node_id: 0.0}
    f_score: Dict[str, float] = {start_node_id: heuristic(start_node, end_node)}

    while open_set:
        current_f, _, current_id = heapq.heappop(open_set)

        # Reached the destination
        if current_id == end_node_id:
            path = [current_id]
            curr = current_id
            while curr in came_from:
                curr = came_from[curr]
                path.insert(0, curr)
            return (path, g_score[current_id])

        current_g = g_score.get(current_id, float('inf'))

        for edge in graph.get_neighbors(current_id):
            neighbor_id = edge.to_node
            neighbor_node = graph.nodes.get(neighbor_id)
            if not neighbor_node:
                continue

            tentative_g_score = current_g + compute_edge_cost(edge, context)
            neighbor_g = g_score.get(neighbor_id, float('inf'))

            # We found a shorter path to neighbor
            if tentative_g_score < neighbor_g:
                came_from[neighbor_id] = current_id
                g_score[neighbor_id] = tentative_g_score
                
                f = tentative_g_score + heuristic(neighbor_node, end_node)
                f_score[neighbor_id] = f
                
                counter += 1
                heapq.heappush(open_set, (f, counter, neighbor_id))

    return None
