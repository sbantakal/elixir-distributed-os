defmodule Main do
  [numNodes,topology,algorithm] =Enum.map(System.argv, (fn x -> x end))
  numNodes = String.to_integer(numNodes)
  NodeSupervisor.start_link(numNodes)
  Topology.organiseNodes(algorithm, topology, numNodes)
  IO.puts "*****************************************************************************"
  IO.puts "Number of Nodes : #{numNodes}"
  IO.puts "Topology : #{topology}"
  IO.puts "Algorithm : #{algorithm}"
  case algorithm do
    "gossip" -> NodeServer.initiateGossip(numNodes,System.os_time(:millisecond))
    "push-sum" -> NodeServer.startPushSum(numNodes,System.os_time(:millisecond))
    _ -> IO.puts "Invalid value of topology"
    System.halt(1)
  end
  Process.flag(:trap_exit, true)
end
