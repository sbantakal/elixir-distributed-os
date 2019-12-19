require Logger
defmodule Twitter do
  def main(args) do
    {_, clargs, _} = OptionParser.parse(args)
    mode = Enum.at(clargs, 0)
    port = 8000
    case mode do
      "server" ->
        Logger.debug("Starting Twitter Server")
        TwitterServer.start_link(port)
       "client" ->
        ip = parse_address(Enum.at(clargs, 1))
        username = Enum.at(clargs, 2)
        {:ok, socket} = establishconnection(ip, port)
        TwitterClient.start_link(socket, :interactive, username)
        Logger.debug("Connecting client to Twitter Server")
    end
  end
  defp parse_address(str) do
    [a, b, c, d] = String.split(str, ".")
    {String.to_integer(a), String.to_integer(b), String.to_integer(c), String.to_integer(d)}
  end
  defp establishconnection(ip, port) do
    :gen_tcp.connect(ip, port, [:binary, {:active, false},{:packet, 0}])
  end
end

# require Logger
# defmodule Twitter do
#   def main(args) do
#     {_, clargs, _} = OptionParser.parse(args)
#     mode = Enum.at(clargs, 0)
#     port = 8000
#     case mode do
#       "server" ->
#         Logger.debug("Starting Twitter Server")
#         TwitterServer.start_link(port)

#        "client" ->
#         ip = parse_address(Enum.at(clargs, 1))
#         username = Enum.at(clargs, 2)
#         {:ok, socket} = establishconnection(ip, port)
#         TwitterClient.start_link(socket, :interactive, username)
#         Logger.debug("Connecting client to Twitter Server")

#         "simulator" ->
#           #simulator mode
#           ip = parse_address(Enum.at(clargs, 1))
#           numofusrs = Enum.at(clargs, 2) |> String.to_integer()
#           activeusrs = (if Enum.at(clargs, 3) do
#             Enum.at(clargs, 3) |> String.to_integer()
#           else
#             2
#           end
#           )
#           # simulating active clients
#           for _ <- 1..activeusrs do
#             {:ok, socket} = establishconnection(ip, port)
#             Logger.debug("Connected to Twitter Server")
#             TwitterClient.simulate(socket, numofusrs)
#           end
#           holdconnection()
#     end
#   end
#   defp parse_address(str) do
#     [a, b, c, d] = String.split(str, ".")
#     {String.to_integer(a), String.to_integer(b), String.to_integer(c), String.to_integer(d)}
#   end
#   defp establishconnection(ip, port) do
#     :gen_tcp.connect(ip, port, [:binary, {:active, false},{:packet, 0}])
#   end
#   defp holdconnection() do
#     :timer.sleep 10000
#     holdconnection()
#   end
# end


