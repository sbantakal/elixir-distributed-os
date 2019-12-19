defmodule NodeSupervisor do
  use Supervisor

  def start_link(numNodes) do
    Supervisor.start_link(__MODULE__, numNodes)
  end

  def init(numNodes) do
    child_nodes = Enum.map(1..numNodes, fn n -> worker(NodeServer, [n], [id: n, restart: :temporary]) end)
    supervise(child_nodes, strategy: :one_for_one)
  end

end
