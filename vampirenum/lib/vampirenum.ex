defmodule Vampirenum do
  use Application

  def start(_type,_args) do
    {first,""} = Integer.parse(Enum.at(System.argv(),0))
    {last,""} = Integer.parse(Enum.at(System.argv(),1))

    # Initiating the Supervisor to create workers
    {:ok,supid}=VSupervisor.start_link(first,last)

    # Fetching the process id of the workers and using the same to print out the vampire numbers
    workers = Supervisor.which_children(supid)
    for w <- workers, do: Enum.each(VGenServer.get_vampire_nos(elem(w,1)),fn x -> IO.puts x end)

    #return
    {:ok, supid}
  end
end
