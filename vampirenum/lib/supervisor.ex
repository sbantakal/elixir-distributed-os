defmodule VSupervisor do
  use Supervisor

  def start_link(first,last) do
    Supervisor.start_link(__MODULE__, [first,last])
  end

  def init([first,last]) do
    #complete range of numbers
    range = first..last
    numlist=Enum.to_list(range)

    #number of cores in the machine
    cores = :erlang.system_info(:schedulers_online)
    IO.puts "Number of System Cores : #{cores}"
    IO.puts "************************************************************"
    # determine the chunk by value
    chunks=ceil(length(numlist)/cores)
    IO.puts "Chunk size set to  : #{chunks}"
    IO.puts "************************************************************"
    IO.puts "The num of workers : #{cores}"
    IO.puts "************************************************************"

    # list of lists to be passed to workers
    list_of_list = Enum.chunk_every(numlist,chunks,chunks,[])

    #defining childs/workers
    children = Enum.map(list_of_list, fn list ->
      worker(VGenServer, [list], [id: list, restart: :temporary])
    end)

    supervise(children, strategy: :one_for_one)
  end
end
