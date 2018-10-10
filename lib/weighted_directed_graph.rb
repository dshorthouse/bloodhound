# encoding: utf-8
require 'rgl/adjacency'
require 'rgl/dot'

module Bloodhound

  class WeightedDirectedGraph < RGL::DirectedAdjacencyGraph

    def initialize(edgelist_class = Set, *other_graphs)
      super
      @weights = {}
      @attributes = {}
    end

    # Create a graph from an array of [source, target] triples.
    def self.[] (*a)
      result = new
      0.step(a.size-2, 3) { |i| result.add_edge(a[i], a[i+1], a[i+2]) }
      result
    end

    def to_s
      # TODO Sort toplogically instead of by edge string.
      (edges.sort_by {|e| e.to_s} + 
       isolates.sort_by {|n| n.to_s}).map { |e| e.to_s }.join("\n")
    end

    # A set of all the unconnected vertices in the graph.
    def isolates
      edges.inject(Set.new(vertices)) { |iso, e| iso -= [e.source, e.target] }
    end

    # Add an edge between two verticies.
    #
    # [_u_] source vertex
    # [_v_] target vertex
    def add_edge(u, v, w)
      super(u,v)
      @weights[[u,v]] = w
    end

    def add_vertex_attributes(v, a)
      @attributes[v] = a
    end

    def vertex_attributes(v)
      @attributes[v] || {}
    end

    # Edge weight
    #
    # [_u_] source vertex
    # [_v_] target vertex
    def weight(u, v)
      @weights[[u,v]] || @weights[[v,u]]
    end

    # Remove the edge between two verticies.
    #
    # [_u_] source vertex
    # [_v_] target vertex
    def remove_edge(u, v)
      super
      @weights.delete([u,v])
    end

    # The class used for edges in this graph.
    def edge_class
      WeightedDirectedEdge
    end

    # Return the array of WeightedDirectedEdge objects of the graph.
    def edges
      result = []
      c = edge_class
      each_edge { |u,v| result << c.new(u, v, self) }
      result
    end

    # Create a dot file to depict the graph's vertices with decorated edges
    def write_to_dot_file(dotfile="graph")
      src = dotfile + ".dot"

      File.open(src, 'w') do |f|
        f << self.to_dot_graph.to_s << "\n"
      end
      src
    end

    def write_to_d3_file(d3file="d3")
      src = d3file + ".json"

      File.open(src, 'w') do |f|
        f << self.to_d3_graph.to_json
      end
      src
    end

    def to_d3_graph
      nodes = []
      each_vertex do |v|
        options = { 'name' => v.to_s }
        options.merge! vertex_attributes(v)
        nodes << options
      end
      links = edges.map{ |e| { 
        source: vertices.index(e.source),
        target: vertices.index(e.target) } }
      { nodes: nodes, edges: links }
    end

    # Create a dot file and png to depict the graph's vertices with decorated edges
    def write_to_graphic_file(fmt='png', dotfile="graph")
      src = dotfile + ".dot"
      dot = dotfile + "." + fmt

      File.open(src, 'w') do |f|
        f << self.to_dot_graph.to_s << "\n"
      end

      system("dot -T#{fmt} #{src} -o #{dot}")
      dot
    end

    def to_dot_graph(params = {})
      params[:name] ||= self.class.name.gsub(/:/, '_')
      fontsize       = params[:fontsize] ? params[:fontsize] : '8'
      graph          = RGL::DOT::Graph.new(params)
      edge_class     = RGL::DOT::Edge

      each_vertex do |v|
        name = v.to_s
        options = {
          name: name,
          fontsize: fontsize,
          label: name
        }
        options.merge! vertex_attributes(v)
        graph << RGL::DOT::Node.new(options)
      end

      each_edge do |u, v|
        graph << edge_class.new(
            from: u.to_s,
            to: v.to_s,
            fontsize: fontsize,
            label: weight(u,v)
        )
      end

      graph
    end

  end

  # A directed edge.
  class WeightedDirectedEdge < RGL::Edge::DirectedEdge
    
    # [_u_] source vertex
    # [_v_] target vertex
    # [_g_] the graph in which this edge appears
    def initialize(a, b, g)
      super(a,b)
      @graph = g
    end

    # The weight of this edge.
    def weight
      @graph.weight(source, target)
    end

     def to_s
       "(#{source}-#{weight}-#{target})"
     end
  end

end