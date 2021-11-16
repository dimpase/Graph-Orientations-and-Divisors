"""Implements some basic methods useful with divisors and orientations,
as well as an algorithm for producing a theta characteristic.
"""

import itertools
from sage.graphs.graph import Graph
from sage.graphs.generic_graph import GenericGraph
from sage.graphs.digraph import DiGraph
from sage.sandpiles.sandpile import Sandpile
from sage.sandpiles.sandpile import SandpileDivisor
from sage.misc.functional import is_odd

"""Sandpile methods"""

def n_torsion(S, n):
    """Return a list of the n-torsion elements (including 0) of Pic^0."""
    return [D for D in S.jacobian_representatives() if
    (2 * D).is_linearly_equivalent(S.zero_div())]


"""SandpileDivisor methods"""


def hodge_star(div):
    """Perform the divisorial equivalent of flipping all
    edges in an orientation (including biorienting <-> unorienting).
    """
    return div.sandpile().canonical_divisor() - div


def div_pos(div, divisor_format=True):
    """Return the positive part of a divisor, or if divisor_format is False,
    a list of all positive entries (with multiplicity) in the
    divisor.
    """
    if divisor_format:
        return SandpileDivisor(div.sandpile(),
                               {v: max(0, div[v]) for v in div.keys()})
    output_list = []
    for v in div.keys():
        if div[v] > 0:
            output_list.extend([v] * int(div[v]))
    return output_list


""" DiGraph methods """


def reachable_from_vertex(G, q):
    """Return the set of vertices reachable by oriented paths from q,
    a vertex in a DiGraph.
    """
    return reachable_from_vertices(G, {q})


def reachable_from_vertices(G, X):
    """Return the set of vertices reachable by oriented paths from X,
    a collection of vertices in a DiGraph.
    """
    V = set(X)
    to_add = G.edge_boundary(V)
    while len(to_add) != 0:
        V = V.union({e[1] for e in to_add})
        to_add = G.edge_boundary(V)
    return V


def make_paths(G, origin, target=None):
    """Flip oriented cuts til either every vertex is accessible by an
    oriented path from q, or, if a target vertex is selected, until
    the target is accessible.
    """
    vertex_set = set(G.vertices())
    reachable = G.reachable_from_vertex(origin)
    new_orientation = G.copy()
    while (target not in reachable) and not reachable == vertex_set:
        v_complement = vertex_set - reachable
        new_orientation.reverse_edges(
            new_orientation.edge_boundary(v_complement),
            multiedges=G.allows_multiple_edges())
        reachable = G.reachable_from_vertex(origin)
    return new_orientation


def cycle_basis(G, output="edge"):
    """Implement SageMath's cycle_basis method for DiGraphs. Only returns edge
    formatted cycles."""
    assert output == "edge", "Only returns edge formatted cycles."
    result = []
    cycles = Graph(G).cycle_basis("edge")
    for C in cycles:
        edges = G.edge_signs(C)
        new_cycle = []
        for e in edges:
            if edges[e] == 1:
                new_cycle.append(e)
            else:
                new_cycle.append((e[1], e[0], e[2]))
        result.append(new_cycle)
    return result


def edge_signs(G, L):
    """Accept a collection of edges.
    Create a dict with keys the edges e in L:
    - assign 1 if e is in G
    - assign -1 if the opposite direction of e is in G
    - assign nothing otherwise
    Checks with multiplicity.
    """
    return collections_edge_signs(G.edges(), L)


"""GenericGraph methods"""


def induces_connected_subgraph(G, vertices):
    """Return whether a set of vertices determines a connected induced
    subgraph. Treats the empty graph as not connected.
    """
    if len(vertices) == 0:
        return False
    return G.subgraph(vertices).is_connected()


def eulerian_bipartition(G):
    """Return a set of vertices V of a graph G,
    such that G[V] and G[V^c] are eulerian.
    We have V = V(G) iff the graph has purely even degrees.
    """
    if G.has_multiple_edges():
        preprocess_G = Graph([G.vertices(), []])
        for (v, w) in itertools.combinations(G.vertices(), 2):
            if is_odd(len(G.edge_boundary([v], [w], labels=False))):
                preprocess_G.add_edge(v, w)
        result = _eulerian_bipartition_recur(preprocess_G, ([], []))
    else:
        result = _eulerian_bipartition_recur(G, ([], []))
    return result[0]


def _eulerian_bipartition_recur(G, partition):
    for v in G.vertices():
        if is_odd(G.degree(v)):
            smallG = G.copy()
            smallG.delete_vertex(v)
            neighbs = G.neighbors(v)
            for vertex_pair in itertools.combinations(neighbs, 2):
                if G.has_edge(vertex_pair[0], vertex_pair[1]):
                    smallG.delete_edge(vertex_pair[0], vertex_pair[1])
                else:
                    smallG.add_edge(vertex_pair[0], vertex_pair[1])
            partition = _eulerian_bipartition_recur(smallG, partition)
            if is_odd(len(set(partition[0]).intersection(G.neighbors(v)))):
                partition[1].extend([v])
            else:
                partition[0].extend([v])
            return partition
    return (G.vertices(), [])


def vertex_complement(G, V):
    """Return, as a set, the complement of a collection of vertices."""
    return set(G.vertices()) - set(V)


def cycle_intersection_graph(G, show=False):
    """Accept a graph G.
    Return a graph C which has one vertex for each of the cycles, and an edge
    between them iff the cycles intersect.
    Will exhibit undesired behaviour with loop edges or when edge labels are
    not hashable."""
    return cycle_graph_from_basis(G.cycle_basis("edge"), show)


"""Functions"""


def collections_edge_signs(L1, L2):
    """Accept two collections of edges.
    Create a dict with keys the edges e in L2:
    - assign 1 if e is in L1
    - assign -1 if the opposite direction of e is in L1
    - assign nothing otherwise
    Checks with multiplicity.
    """
    L1 = list(L1)
    L2 = list(L2)
    result = {}
    for e in L2:
        if e in L1:
            result.update({e: 1})
            L1.remove(e)
        else:
            if (e[1], e[0], e[2]) in L1:
                result.update({e: -1})
                L1.remove((e[1], e[0], e[2]))
    return result


def cycle_graph_from_basis(cycle_basis, show=False):
    """Accept a cycle basis for a graph. The basis must be formatted
    with edges.
    Return a graph C which has one vertex for each of the cycles, and an edge
    between them iff the cycles intersect.
    Will exhibit undesired behaviour with loop edges or when edge labels are
    not hashable.
    """
    preformat = []
    for C in cycle_basis:
        preformat.append(tuple(edges_to_unordered_representation(C)))
    result = graphs.IntersectionGraph(preformat)
    if show:
        result.show(vertex_labels=False, edge_labels=False)
    return result


def edges_to_unordered_representation(it):
    """Accept a collection of edges. Replace each 3-tuple (v1, v2, label)
    with (frozenset{v1, v2}, label) and return a list of the results.
    Will exhibit undesired behaviour with loop edges.
    """
    return [(frozenset({t[0],t[1]}), t[2]) for t in it]


Sandpile.n_torsion = n_torsion
SandpileDivisor.hodge_star = hodge_star
SandpileDivisor.div_pos = div_pos
DiGraph.reachable_from_vertex = reachable_from_vertex
DiGraph.reachable_from_vertices = reachable_from_vertices
DiGraph.make_paths = make_paths
DiGraph.cycle_basis = cycle_basis
DiGraph.edge_signs = edge_signs
GenericGraph.eulerian_bipartition = eulerian_bipartition
GenericGraph.vertex_complement = vertex_complement
GenericGraph.cycle_intersection_graph = cycle_intersection_graph
