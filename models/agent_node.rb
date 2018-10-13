class AgentNode
  include Neo4j::ActiveNode
  has_many :both, :agent_nodes, rel_class: :AgentEdge

  property :agent_id, type: Integer
  property :given, type: String
  property :family, type: String
end