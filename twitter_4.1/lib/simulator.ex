require Logger
defmodule Simulator do
  def main(args) do
    [numofusrs, numtweet] = args
    port = 8000

    #simulator mode
    ip = parse_address("127.0.0.1")

    # simulating active clients
    {:ok, socket} = establishconnection(ip, port)
    Logger.debug("Connected to Twitter Server")
    TwitterClient.simulate(socket, numofusrs, numtweet)

    holdconnection()
  end

  defp parse_address(str) do
    [a, b, c, d] = String.split(str, ".")
    {String.to_integer(a), String.to_integer(b), String.to_integer(c), String.to_integer(d)}
  end

  defp establishconnection(ip, port) do
    :gen_tcp.connect(ip, port, [:binary, {:active, false},{:packet, 0}])
  end

  defp holdconnection() do
    :timer.sleep 90000
    # holdconnection()
  end

end
