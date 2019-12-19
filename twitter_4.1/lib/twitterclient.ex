defmodule TwitterClient do
  use GenServer
  require Logger
  import IO.ANSI

  def start_link(socket, mode \\ :interactive, username \\ None, users \\ None, frequency \\ :medium, numoftweets \\ 0) do

    if mode == :interactive do
      # username = IO.gets "Enter username(without @ in begining) to signup: " |> String.trim()
      :ets.new(:packets, [:set, :public, :named_table, read_concurrency: true])
      spawn(fn  ->  listenonsocket(socket, :packets) end)
    end

    Logger.debug("@#{username}, Tweet Frequency =  #{frequency}")
    GenServer.start_link(__MODULE__, %{"username" => username, "mode"=> mode, "rt_prob"=> 10}, name: String.to_atom(username))
    TwitterClient.registeruser(socket, username)

    case mode do
      :interactive ->
        Logger.debug("Initiating Interactive Client")
        initInteractiveClient(socket, username)
      :simulate ->
        # add subcribers to the user @username
        performbulksubscription(socket, username, users)
        :timer.sleep 1000
        # Logger.debug("Initiating the Simulator")
        for _ <- 1..numoftweets do
          initTwitterSimulator(socket, username, frequency)
        end
        # initTwitterSimulator(socket, username, frequency)
      _ ->
        Logger.debug("Invalid value for Mode => #{mode}")
    end
  end

  defp initInteractiveClient(socket, username) do
    TwitterClient.waitfor(1000)
    Logger.info "User :"<>cyan()<>"@"<>yellow()<>"#{username}"<>reset()
    option = IO.gets "Options:\n1. Tweet\n2. Hashtag query\n3. Mention query\n4. Subscribe\n5. Unsubscribe\n6. Login\n7. Logout\nEnter your choice: "
    case String.trim(option) do
      "1" ->
        tweet = IO.gets "Enter tweet: "
        sendTweet(socket, tweet, username)
        # initInteractiveClient(socket, username)
      "2" ->
        hashtag = IO.gets "Enter hashtag to query for: "
        hashtagquery(socket, hashtag, username)
        # initInteractiveClient(socket, username)
      "3" ->
        mention = IO.gets "Enter the username(add @ in begining) to look for: "
        mentionquery(socket, mention, username)
        # initInteractiveClient(socket, username)
      "4" ->
        user = IO.gets "Enter the username you want to follow(without @ in begining): "
        subscribe(socket, user, username)
        # initInteractiveClient(socket, username)
      "5" ->
        user = IO.gets "Enter the username you want to unsubscribe(without @ in begining): "
        unsubscribe(socket, user, username)
        # initInteractiveClient(socket, username)
      "6" ->
        performLogin(socket, username)
        # initInteractiveClient(socket, username)
      "7" ->
        performLogout(socket, username)
      _ ->
        IO.puts "Invalid option. Please try again"
    end
    initInteractiveClient(socket, username)
  end

  defp initTwitterSimulator(server, username, frequency) do
    randTweet = generateRandomTweet(100)
    Logger.debug("@#{username} is tweeting #{randTweet}")
    sendTweet(server, randTweet, username)
    # Simulate Logout
    case frequency do
      :high ->
        :timer.sleep(200)
        simulateLogout(server, username, frequency)
      :medium ->
        :timer.sleep(400)
        simulateLogout(server, username, frequency)
      _ ->
        :timer.sleep(800)
        simulateLogout(server, username, frequency)
    end
    # initTwitterSimulator(server, username, frequency)
  end

  defp simulateLogout(server, username, frequency) do
    rand = :rand.uniform(10)
    # autologin => true
    if (frequency == :high and rand <= 3) do
      performLogout(server, username, true)
    else
      if (frequency == :medium and rand <= 5) do
        performLogout(server, username, true)
      else
        if rand <= 7 do
          performLogout(server, username, true)
        end
      end
    end
  end

  def init(status) do
    {:ok, status}
  end

  ######################
  ### Client Utility ###
  ######################
  def sendrequest(server, data) do
    request = Poison.encode!(data)
    :gen_tcp.send(server, request)
  end
  def sendTweet(server, tweet, username) do
    data = %{"function"=> "tweet", "username"=> username, "tweet"=> tweet}
    sendrequest(server, data)
  end
  def hashtagquery(server, hashtag, username) do
    data = %{"function"=> "hashtags", "username"=> username, "hashtag"=> hashtag}
    sendrequest(server, data)
  end
  def mentionquery(server, mention, username) do
    data = %{"function"=> "mentions", "mention"=> mention, "username"=> username}
    sendrequest(server, data)
  end
  def subscribe(server, users, username) do
    data = %{"function"=> "subscribe", "users"=> users, "username"=> username}
    sendrequest(server, data)
  end
  def unsubscribe(server, users, username) do
    data = %{"function"=> "unsubscribe", "users"=> users, "username"=> username}
    sendrequest(server, data)
  end
  def handle_cast({:signup, data}, status) do
    if data["status"] != "success" do
      Logger.info data["message"]
    end
    {:noreply, status}
  end
  def handle_cast({:mention, mentTweets}, status) do
    Logger.info(yellow()<>"Mention Tweet |>|"<>reset()<>"#{mentTweets}")
    {:noreply, status}
  end
  def handle_cast({:hashtag, hashTweets}, status) do
    Logger.info(blue()<>"Hash Tweet |>|"<>reset()<>" #{hashTweets}")
    {:noreply, status}
  end
  def handle_cast({:feed, feed}, status) do
    Logger.info(red()<>"Feed |>|"<>reset()<>" #{feed}")
    {:noreply, status}
  end
  def handle_cast({:tweet, username, sender, tweet, socket}, status) do
    Logger.info cyan()<>"@"<>yellow()<>"#{sender} |>| "<>blue()<>"#{tweet}"<>reset()
    mode = Map.get(status, "mode")
    if mode != :interactive and :rand.uniform(100) <= Map.get(status,"rt_prob") do
      Logger.debug "User @#{username} is retweeting"
      data = %{"function"=> "tweet", "username"=> username, "tweet"=> tweet}
      sendrequest(socket, data)
    end
    if mode == :interactive do
      input = IO.gets "Want to retweet(y/n)? " |> String.trim()
      if input == "y" do
        Logger.debug "User @#{username} is retweeting"
        data = %{"function"=> "tweet", "username"=> username, "tweet"=> tweet}
        sendrequest(socket, data)
      else
        data = %{"function"=> "tweet", "username"=> username, "tweet"=> " "}
        sendrequest(socket, data)
      end
    end
    {:noreply, status}
  end

  #####################
  ### User Function ###
  #####################
  def registeruser(server, username) do
    # Logger.debug("Logging passed username #{username}")
    data = %{"function"=> "signup", "username"=> username}
    sendrequest(server, data)
    Logger.debug("User @#{username} registered successfully")
  end
  defp performbulksubscription(server, username, users) do
    userlist = users |> Enum.chunk_every(50)
    for usr <- userlist do
      data = %{"function"=> "bulksubscription", "users"=> usr, "username"=> username}
      sendrequest(server, data)
      :timer.sleep 50
    end
  end
  def performLogout(server, username, autologin \\ false) do
    data = %{"function"=> "logout", "username"=> username}
    sendrequest(server, data)
    if autologin == true do
      sleep(username)
      performLogin(server, username)
    end
  end
  def performLogin(server, username) do
    data = %{"function"=> "login", "username"=> username}
    Logger.debug("User @#{username} is logging in")
    sendrequest(server, data)
  end
  defp getsubscribers(availablesub, subcount) do
    Enum.shuffle(availablesub) |> Enum.take(subcount) |> MapSet.new()
  end


  #####################
  ###   Utilities   ###
  #####################
  defp listenonsocket(socket, packetstable) do
    {status, response} = :gen_tcp.recv(socket, 0)
    if status == :ok do
      multdata = response |> String.split("}", trim: :true)
      for data <- multdata do
        #Logger.debug "Data to be decoded: #{inspect(data)}"
        incompletepackets = getpreviousdatapackets(packetstable)
        if incompletepackets != false do
          data = "#{incompletepackets}#{data}"
          Logger.debug "Incomplete Packets found, merged data : #{data}"
        end
        try do
          data = Poison.decode!("#{data}}")
          username = data["username"]
          Logger.debug "Data received @#{username} data: #{inspect(data)}"

          case data["function"] do
            "signup" -> GenServer.cast(nametoatom(username), {:signup, data})
            "tweet" -> GenServer.cast(nametoatom(username), {:tweet, username, data["sender"], data["tweet"], socket})
            "feed" -> GenServer.cast(nametoatom(username), {:feed, data["feed"]})
            "mention" -> GenServer.cast(nametoatom(username), {:mention, data["tweets"]})
            "hashtags" -> GenServer.cast(nametoatom(username), {:hashtag, data["tweets"]})
            _ -> Logger.error "unmatched clause for data: #{inspect(data)}"
          end

        rescue
          Poison.SyntaxError -> Logger.debug "Poison ERROR during decoding of data => #{data}"
          insertpreviousdatapackets(data, packetstable)
        end
      end
    end
    listenonsocket(socket, packetstable)
  end
  defp insertpreviousdatapackets(data, table \\ :packets) do
    :ets.insert(table, {"previous packets", data})
  end
  defp getpreviousdatapackets(table) do
    packet = :false
    if :ets.member(table, "previous packets") do
      packet = :ets.lookup_element(table, "previous packets", 2)
      :ets.delete(table,"previous packets")
    end
    packet
  end

  defp generateRandomString(length, commstr) do
    list = commstr |> String.split("", trim: true) |> Enum.shuffle
    1..length |> Enum.reduce([], fn(_, acc) -> [Enum.random(list) | acc] end) |> Enum.join("")
  end
  defp generateRandomTweet(length) do
    commstr="  abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789"
    generateRandomString(length, commstr)
  end
  defp generateRandomUsername(length \\ 10) do
    commstr="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    generateRandomString(length, commstr)
  end
  defp sleep(username) do
    sec = :rand.uniform(5000)
    Logger.debug "User @#{username} sleeping for #{sec} seconds"
    :timer.sleep sec
  end
  def nametoatom(username) do
    String.to_atom(username)
  end

  defp zipfconstant(users) do
    # c = (Sum(1/i))^-1 where i = 1,2,3....n
    users = for n <- 1..users, do: 1/n
    :math.pow(Enum.sum(users), -1)
  end
  defp zipfprob(constant, user, users) do
    # z=c/x where x = 1,2,3...n
    round((constant/user)*users)
  end
  def simulate(socket, user_count \\ 3, nooftweets \\ 1) do

    # generate random user names
    user_set = 1..user_count |> Enum.reduce(MapSet.new, fn(_, acc) -> MapSet.put(acc, generateRandomUsername()) end)

    constant = zipfconstant(user_count)
    Logger.debug "zipf constant: #{constant}"
    # Top 10%  & botton 10% of total
    high = round(:math.ceil(user_count * 0.1))
    low = user_count - high

    # table to keep track of incomplete packet and try to use it in next iteration (as data is a stream of packets)
    packet_table = :ets.new(:incomplete_packet, [:set, :public, read_concurrency: true])

    # listen on socket for incoming messages
    spawn fn -> listenonsocket(socket, packet_table) end

    for {username, pos} <- Enum.with_index(user_set) do

      # fetch online users other than the current user
      available_subscribers = MapSet.difference(user_set, MapSet.new([username]))

      #deciding on the number of subscribers for a particular user based on zipf law
      subscriber_count = zipfprob(constant, pos+1, user_count)

      Logger.debug "User @#{username}, No of subscribers = #{subscriber_count}"
      # pick random subscribers
      subscribers = getsubscribers(available_subscribers, subscriber_count)

      frequency = (if (pos + 1) <= high do
                    :high
                  else
                    if (pos + 1) > low do
                      :low
                    else
                      :medium
                    end
      end)

      spawn fn -> start_link(socket, :simulate, username, subscribers, frequency, nooftweets) end
    end
    # stay_alive()
  end
  def stay_alive()do
    :timer.sleep 10000
    stay_alive()
  end
  def waitfor(num)do
    :timer.sleep num
  end


  ### test ####
  def fetchtotalusers(server) do
    data = %{"function"=> "gettotalusers"}
    sendrequest(server, data)
  end

end
