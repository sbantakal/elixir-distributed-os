defmodule TwitterTest do
  use ExUnit.Case
  doctest Twitter

  @tag tc: "1"
  test "Register User" do
    IO.puts "###################################################"
    IO.puts "Registering a 3 Users"

    :ets.new(:counter, [:set, :public, :named_table, read_concurrency: true])
    :ets.insert(:counter, {"total users", 0})

    {:ok, socket} = establishconnection()

    # users
    username0 = "sandy"
    username1 = "milind"
    username2 = "reddevil"

     #register user
    TwitterClient.registeruser(socket, username0)
    TwitterClient.registeruser(socket, username1)
    TwitterClient.registeruser(socket, username2)

    :ets.new(:packets, [:set, :public, :named_table, read_concurrency: true])

    fetchtotalusers(socket)
    :timer.sleep 1000
    listenonsocket(socket, :packets)

    [{_, totalusr}] = :ets.lookup(:counter, "total users")

    IO.puts totalusr
    assert totalusr == 3
    IO.puts "####################################################"
  end

  @tag tc: "2"
  test "Adding Subscribers" do
    IO.puts "###################################################"
    IO.puts "Creating a 3 Users & Adding subscribers to 1 user"

    :ets.new(:packets, [:set, :public, :named_table, read_concurrency: true])
    {:ok, socket} = establishconnection()

    :ets.new(:subscribers, [:set, :public, :named_table, read_concurrency: true])
    :ets.insert(:subscribers, {"total subs", 0})

    #user
    username0 = "sandy"
    username1 = "milind"
    username2 = "reddevil"

     #register user
    TwitterClient.registeruser(socket, username0)
    TwitterClient.registeruser(socket, username1)
    TwitterClient.registeruser(socket, username2)

    #subscribe
    TwitterClient.subscribe(socket, username0, username1)
    TwitterClient.subscribe(socket, username0, username2)

    getnoofsubscribers(socket, username0)
    :timer.sleep 1000
    listenonsocket(socket, :packets)

    [{_, totalsubs}] = :ets.lookup(:subscribers, "total subs")

    IO.puts totalsubs
    assert totalsubs == 2
    IO.puts "####################################################"
  end

  @tag tc: "3"
  test "Query Hastags" do
    IO.puts "###################################################"
    IO.puts "Creating a single user, sendinn multiple tweets with hashtags & evaluating the count"

    :ets.new(:packets, [:set, :public, :named_table, read_concurrency: true])
    {:ok, socket} = establishconnection()

    :ets.new(:hashtags, [:set, :public, :named_table, read_concurrency: true])
    :ets.insert(:hashtags, {"total hashs", 0})

    username="sandy"
    #register user
    TwitterClient.registeruser(socket,username)

    #send tweets
    tweet1 = "This is my #first #awesome tweet"
    TwitterClient.sendTweet(socket, tweet1, username)
    tweet2 = "Its an #awesome day today"
    TwitterClient.sendTweet(socket, tweet2, username)
    tweet3 = "DoS is #awesome ?"
    TwitterClient.sendTweet(socket, tweet3, username)

    gettotalhashtweets(socket, "#awesome")
    :timer.sleep 1000
    listenonsocket(socket, :packets)

    [{_, totalhashtweets}] = :ets.lookup(:hashtags, "total hashs")

    IO.puts totalhashtweets
    assert totalhashtweets == 3
    IO.puts "####################################################"
  end

  @tag tc: "4"
  test "Query Mentions" do
    IO.puts "###################################################"
    IO.puts "Creating a single user, sendinn multiple tweets with mentions & evaluating the count"

    :ets.new(:packets, [:set, :public, :named_table, read_concurrency: true])
    {:ok, socket} = establishconnection()

    :ets.new(:mentions, [:set, :public, :named_table, read_concurrency: true])
    :ets.insert(:mentions, {"total ments", 0})

    #user
    username0 = "sandy"
    username1 = "reddevil"

    #register user
    TwitterClient.registeruser(socket, username0)
    TwitterClient.registeruser(socket, username1)

    #send tweets
    tweet1 = "@reddevil how are you?"
    TwitterClient.sendTweet(socket, tweet1, username0)
    tweet2 = "@reddevil whats going on?"
    TwitterClient.sendTweet(socket, tweet2, username0)

    gettotalmentstweets(socket, "@reddevil")
    :timer.sleep 1000
    listenonsocket(socket, :packets)

    [{_, totalmentstweets}] = :ets.lookup(:mentions, "total ments")

    IO.puts totalmentstweets
    assert totalmentstweets == 2
    IO.puts "####################################################"
  end

  @tag tc: "5"
  test "Send Tweets" do
    IO.puts "###################################################"
    IO.puts "Creating a single user, sendinn multiple tweets with mentions & evaluating the count"

    :ets.new(:packets, [:set, :public, :named_table, read_concurrency: true])
    {:ok, socket} = establishconnection()

    :ets.new(:tweets, [:set, :public, :named_table, read_concurrency: true])
    :ets.insert(:tweets, {"total tweets", 0})

    username = "reddevil"
    #register user
    TwitterClient.registeruser(socket, username)

    #send tweets
    tweet1 = "This is my first tweet"
    TwitterClient.sendTweet(socket, tweet1, username)
    tweet2 = "This is my second tweet"
    TwitterClient.sendTweet(socket, tweet2, username)
    tweet3 = "This is my third tweet"
    TwitterClient.sendTweet(socket, tweet3, username)


    gettotaltweets(socket)
    :timer.sleep 1000
    listenonsocket(socket, :packets)

    [{_, totaltweets}] = :ets.lookup(:tweets, "total tweets")

    IO.puts totaltweets
    assert totaltweets == 3
    IO.puts "####################################################"
  end

  @tag tc: "6"
  test "User Log off" do
    IO.puts "###################################################"
    IO.puts "Registering a 3 Users & Logging of one user"

    :ets.new(:packets, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(:counter, [:set, :public, :named_table, read_concurrency: true])
    :ets.insert(:counter, {"total users", 0})

    {:ok, socket} = establishconnection()

    # users
    username0 = "sandy"
    username1 = "milind"
    username2 = "reddevil"

    #register user
    TwitterClient.registeruser(socket, username0)
    TwitterClient.registeruser(socket, username1)
    TwitterClient.registeruser(socket, username2)

    # logging of the user
    TwitterClient.performLogout(socket, username0)

    fetchtotalusers(socket)
    :timer.sleep 1000
    listenonsocket(socket, :packets)

    [{_, onlineusers}] = :ets.lookup(:counter, "total users")

    IO.puts onlineusers
    assert onlineusers == 2
    IO.puts "####################################################"
  end

  @tag tc: "7"
  test "User Log In" do
    IO.puts "###################################################"
    IO.puts "Registering a 3 Users & Logging of two users, then logging users back again"

    :ets.new(:packets, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(:counter, [:set, :public, :named_table, read_concurrency: true])
    :ets.insert(:counter, {"total users", 0})

    {:ok, socket} = establishconnection()

    # users
    username0 = "sandy"
    username1 = "milind"
    username2 = "reddevil"

    #register user
    TwitterClient.registeruser(socket, username0)
    TwitterClient.registeruser(socket, username1)
    TwitterClient.registeruser(socket, username2)

    # logging off the user
    TwitterClient.performLogout(socket, username0)
    TwitterClient.performLogout(socket, username1)

    # logging on the user
    TwitterClient.performLogin(socket, username0)
    TwitterClient.performLogin(socket, username1)

    fetchtotalusers(socket)
    :timer.sleep 1000
    listenonsocket(socket, :packets)

    [{_, onlineusers}] = :ets.lookup(:counter, "total users")

    IO.puts onlineusers
    assert onlineusers == 3
    IO.puts "####################################################"
  end



  defp establishconnection() do
    ip = {127,0,0,1}
    port = 8000
    :gen_tcp.connect(ip, port, [:binary, {:active, false},{:packet, 0}])
  end
  defp listenonsocket(socket, packetstable) do
    {status, response} = :gen_tcp.recv(socket, 0)
    if status == :ok do
      multdata = response |> String.split("}", trim: :true)
      for data <- multdata do
        #Logger.debug "Data to be decoded: #{inspect(data)}"
        incompletepackets = getpreviousdatapackets(packetstable)
        if incompletepackets != false do
          data = "#{incompletepackets}#{data}"
          # Logger.debug "Incomplete Packets found, merged data : #{data}"
        end
        try do
          data = Poison.decode!("#{data}}")
          username = data["username"]
          # Logger.debug "Data received @#{username} data: #{inspect(data)}"

          case data["function"] do
            "totalusers" ->
              inserttotalusers(data["noofusers"])
            "totalsubs" ->
              inserttotalssubs(data["noofsubs"])
            "totalhashtweets" ->
              inserttotalhashtweets(data["noofhashtweets"])
            "totalhmentstweets" ->
              inserttotalmentstweets(data["noofmentstweets"])
            "totaltweets" ->
              inserttotaltweets(data["nooftweets"])
            _ ->
              IO.puts " "
          end

        rescue
          Poison.SyntaxError ->
          insertpreviousdatapackets(data, packetstable)
        end
      end
    end
    # listenonsocket(socket, packetstable)
  end
  defp getpreviousdatapackets(table) do
    packet = :false
    if :ets.member(table, "previous packets") do
      packet = :ets.lookup_element(table, "previous packets", 2)
      :ets.delete(table,"previous packets")
    end
    packet
  end
  defp insertpreviousdatapackets(data, table \\ :packets) do
    :ets.insert(table, {"previous packets", data})
  end

  def sendrequest(server, data) do
    # IO.puts "#{inspect(data)}"
    request = Poison.encode!(data)
    :gen_tcp.send(server, request)
  end

  #### test case 1 ####
  def fetchtotalusers(server) do
    data = %{"function"=> "gettotalusers"}
    sendrequest(server, data)
  end
  def inserttotalusers(noofusers) do
    :ets.update_counter(:counter, "total users", {2, noofusers})
  end

  #### test case 2 ####
  def getnoofsubscribers(server, username) do
    data = %{"function"=> "getnoofsubscriber", "username" => username}
    sendrequest(server, data)
  end
  def inserttotalssubs(noofsubs) do
    :ets.update_counter(:subscribers, "total subs", {2, noofsubs})
  end

  #### test case 3 ####
  def gettotalhashtweets(server, hashtag) do
    data = %{"function"=> "gettotalhashtweets", "hashtag" => hashtag}
    sendrequest(server, data)
  end
  def inserttotalhashtweets(nooftweets) do
    :ets.update_counter(:hashtags, "total hashs", {2, nooftweets})
  end

  #### test case 4 ####
  def gettotalmentstweets(server, mention) do
    data = %{"function"=> "gettotalmenttweets", "mention" => mention}
    sendrequest(server, data)
  end
  def inserttotalmentstweets(noofmentions) do
    :ets.update_counter(:mentions, "total ments", {2, noofmentions})
  end

  #### test case 4 ####
  def gettotaltweets(server)do
    data = %{"function"=> "gettotaltweets"}
    sendrequest(server, data)
  end
  def inserttotaltweets(nooftweets) do
    :ets.update_counter(:tweets, "total tweets", {2, nooftweets})
  end
end
