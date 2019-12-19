defmodule TwitterServer do
  import IO.ANSI
  use GenServer
  require Logger

  def start_link(portNum) do
    Logger.debug("Configuring TwitterServer listen on port: #{portNum}")
    {:ok, listensocket} = :gen_tcp.listen(portNum, [:binary,{:packet, 0},{:ip, {0,0,0,0}},{:active, false},{:reuseaddr, true}])
    Logger.debug("Connection established")

    Logger.debug("Initializing application tables")
    TwitterServer.initializetables()

    GenServer.start_link(__MODULE__, listensocket, name: :TwitterServer)
    spawn(fn -> printstats() end)
    listenonsocket(listensocket)
  end
  def init(port) do
    {:ok, port}
  end
  def initializetables() do
    #####
    :ets.new(:users, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(:hashtags, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(:mentions, [:set, :public, :named_table, read_concurrency: true])
    ### Metrics Tables ####
    :ets.new(:counter, [:set, :public, :named_table, read_concurrency: true])
    :ets.insert(:counter, {"total tweets", 0})
    :ets.insert(:counter, {"total users", 0})
    :ets.insert(:counter, {"online users", 0})
    :ets.insert(:counter, {"offline users", 0})
  end

  def listenonsocket(socket) do
    # Logger.debug("Twitter Server")
    {:ok, connection} = :gen_tcp.accept(socket)

    packets = :ets.new(:packets, [:set, :public, read_concurrency: true])
    spawn(fn  -> serveconnection(connection, packets) end)

    # listen for other connections
    listenonsocket(socket)
  end
  defp serveconnection(connection, packets) do
    {status, request} = :gen_tcp.recv(connection,0)
    Logger.debug("Request: #{inspect(request)}")
    if status === :ok do
      multdata = request |> String.split("}", trim: :true)
      for data <- multdata do

        incompletepacketdata = getpreviousdatapackets(packets)
        if incompletepacketdata != false do
          data = "#{incompletepacketdata}#{data}"
        end

        try do
          data = Poison.decode!("#{data}}")
          Logger.debug("data received in user #{inspect(connection)} request, data => #{inspect(data)}")

          case Map.get(data, "function") do
            "signup" -> GenServer.cast(:TwitterServer, {:signup, data["username"],connection})
            "login"  -> GenServer.cast(:TwitterServer, {:login, data["username"],connection})
            "logout" -> GenServer.cast(:TwitterServer, {:logout, data["username"]})
            "hashtags"  -> GenServer.cast(:TwitterServer, {:hashtag, String.trim(data["hashtag"]), data["username"],connection})
            "mentions"  -> GenServer.cast(:TwitterServer, {:mentions, String.trim(data["mention"]), data["username"],connection})
            "tweet" -> GenServer.cast(:TwitterServer, {:tweet, data["username"], data["tweet"]})
            "subscribe"  -> GenServer.cast(:TwitterServer, {:subscribe, String.trim(data["username"]),data["users"]})
            "unsubscribe"  -> GenServer.cast(:TwitterServer, {:login, String.trim(data["username"]),data["users"]})
            "bulksubscription" -> GenServer.cast(:TwitterServer, {:bulksubscription, data["username"], data["users"]})
            "gettotalusers" -> GenServer.cast(:TwitterServer, {:totaluser, connection})
            "getnoofsubscriber" -> GenServer.cast(:TwitterServer, {:totalsubs, data["username"], connection})
            "gettotalhashtweets" -> GenServer.cast(:TwitterServer, {:totalhashtweets,  data["hashtag"], connection})
            "gettotalmenttweets" -> GenServer.cast(:TwitterServer, {:totalmentstweets,  data["mention"], connection})
            "gettotaltweets" -> GenServer.cast(:TwitterServer, {:totaltweets, connection})
            _ -> Logger.error "No matching clause found for the data => #{inspect(data)}"
          end

        rescue
          Poison.SyntaxError -> Logger.debug("Poison Error occurred while decoding data => #{data}")
          inserttotable(packets, {"previous packets", data})
        end
      end
    end
    serveconnection(connection, packets)
  end
  defp getpreviousdatapackets(table) do
    packet = :false
    if :ets.member(table, "previous packets") do
      packet = :ets.lookup_element(table, "previous packets", 2)
      :ets.delete(table,"previous packets")
    end
    packet
  end

  ###############
  #### TEST #####
  ###############
  ## case 1 ###
  def handle_cast({:totaluser, client}, status) do
    totalusers = :ets.lookup_element(:counter, "online users", 2)
    Logger.debug "total users #{inspect(totalusers)}"
    data = %{"function"=> "totalusers", "noofusers" => totalusers }
    sendresponse(client, data)
    {:noreply, status}
  end
  ## case 2 ###
  def handle_cast({:totalsubs, username, client}, status) do
    subsList = getuserfield(username, "followers") |> MapSet.to_list()
    totalsubs = length(subsList)
    Logger.debug "total subscribers #{inspect(totalsubs)}"
    data = %{"function"=> "totalsubs", "noofsubs" => totalsubs }
    sendresponse(client, data)
    {:noreply, status}
  end
  ## case 3 ###
  def handle_cast({:totalhashtweets, hashtag, client}, status) do
    hashtweets = retrivehashtagtweets(hashtag) |> MapSet.to_list()
    totalhashtweets = length(hashtweets)
    data = %{"function"=> "totalhashtweets", "noofhashtweets" => totalhashtweets }
    sendresponse(client, data)
    {:noreply, status}
  end
  ## case 4 ###
  def handle_cast({:totalmentstweets,  mention, client}, status) do
    mentweets = retrivementiontweets(mention) |> MapSet.to_list()
    totalmentstweet = length(mentweets)
    data = %{"function"=> "totalhmentstweets", "noofmentstweets" => totalmentstweet }
    sendresponse(client, data)
    {:noreply, status}
  end
  ## case 5 ###
  def handle_cast({:totaltweets, client}, status) do
    totaltweets = :ets.lookup_element(:counter, "total tweets", 2)
    Logger.debug "total users #{inspect(totaltweets)}"
    data = %{"function"=> "totaltweets", "nooftweets" => totaltweets }
    sendresponse(client, data)
    {:noreply, status}
  end
  ###############
  #### TEST #####
  ###############


  ##### New User Sign-Up! #####
  def handle_cast({:signup, username, client}, status) do
    # check if user exists
    user = getuserdetails(username)

    # if user is found
    if user === :false do
      Logger.debug("Creating new account for user #{username}")
      # add new user to the user table
      inserttotable(:users, {username, :online, %MapSet{}, :queue.new, client})

      # increment total user and online user count
      updatecounter(1, "total users")
      updatecounter(1, "online users")
      Logger.info cyan()<>"@"<>yellow()<>"#{username}"<>reset()<>" has been registered successfully"
    else
      Logger.debug("Username exists, responding with try again messsage!")
      sendresponse(client, %{"status" => :error, "message" => "username already alloted, try something else!", "function" => "signup", "username" => username})
    end

    # ## display content of table , comment/remove later
    # allusers =  :ets.tab2list(:users)
    # Logger.info("All Registered users => #{inspect(allusers)}")

    {:noreply, status}
  end

  ##### User Login #####
  def handle_cast({:login, username, client}, status) do
    if userexists?(username) do
      # update user state to online, increment online users by 1 and decrement offline users by 1
      updateuserfield(username, "status", :online)
      updatecounter(1, "online users")

      if getcountervalue("offline users") > 0 do
        updatecounter(-1, "offline users")
      end

      has_feeds = userfeedexist?(username)
      Logger.debug("User has feed? #{inspect(has_feeds)}")

      if userfeedexist?(username) do
        Logger.debug("#{username} has feeds")
        # spawn(fn -> sendfeedtouser(username, client) end)
        sendfeedtouser(username, client)
      end
      Logger.debug("User #{username} logged in successfully")
    end

    # ## display content of table , comment/remove later
    # allusers =  :ets.tab2list(:users)
    # Logger.info("All Registered users => #{inspect(allusers)}")

    {:noreply, status}
  end

  ##### User Logout #####
  def handle_cast({:logout, username}, status) do
    if userexists?(username) do
      # update user state to offline, increment offline users by 1 and decrement online users by 1
      updateuserfield(username, "status", :offline)
      updatecounter(-1, "online users")
      updatecounter(1, "offline users")
    end
    Logger.debug("User @#{username} logged out successfully")
    {:noreply, status}
  end

  #### hashtags/mentions ####
  def handle_cast({:hashtag, hashtag, username, client}, status) do
    Logger.debug(" Tweets containing the #{hashtag}")
    spawn(fn  -> sendhashtags(username, hashtag, client)  end)
    {:noreply, status}
  end
  def handle_cast({:mentions, mention, username, client}, status) do
    Logger.debug(" Tweets containing the #{mention}")
    spawn(fn  -> sendmentions(username, mention, client)  end)
    {:noreply, status}
  end

  #### tweet ####
  def handle_cast({:tweet, username, tweet}, status) do
    # increment the counter for total number of tweets
    updatecounter(1, "total tweets")

    # ## display content of table , comment/remove later
    # allcounter =  :ets.tab2list(:counter)
    # Logger.debug("All Counters => #{inspect(allcounter)}")

    # extract hashtag from tweet (if any) and add to hashtag table
    Logger.debug("Extracting hashtags from tweet #{inspect(tweet)}")
    tweetcomponents = SocialParser.extract(tweet,[:hashtags,:mentions])
    Logger.debug("Tweet components #{inspect(tweetcomponents)}")
    if Map.has_key?(tweetcomponents, :hashtags) do
      allhashtags = Map.get(tweetcomponents, :hashtags)
      # Logger.debug("inspect(#{allhashtags})")
      for hashtag <- allhashtags do
        Logger.debug("adding the tweet #{hashtag} to hashtags table")
        addtohashtagslist(hashtag, tweet)
      end
    end

    #extract mention from tweet, add to mention table and send tweets to users mentioned in the tweet
    Logger.debug("Extracting mentions from tweet #{inspect(tweet)}")
    if Map.has_key?(tweetcomponents, :mentions) do
      mentioned = Map.get(tweetcomponents, :mentions)
      for user <- mentioned do
        Logger.debug("adding the tweet to mentions table")
        addtomentionslist(user, tweet)

        Logger.debug("Extracting mentioned username to relay the tweet to the user")
        mentioneduser = String.split(user, ["@", "+"], trim: true) |> List.first
        sendtweet(mentioneduser, username, tweet)
      end
    end

    #share the tweet to all the subscribers
    subscribers = getuserfield(username, "followers")
    for subs <- subscribers do
      sendtweet(subs, username, tweet)
    end

    {:noreply, status}
  end

  def handle_cast({:subscribe, username, follow}, status) do
    subto = String.trim(follow)
    # addsubscribers(username, subto)
    addsubscribers(subto, username)

 	  # # display content of table , comment/remove later
    # allusers =  :ets.tab2list(:users)
    # Logger.info("All Registered users => #{inspect(allusers)}")

    {:noreply, status}
  end
  def handle_cast({:unsubscribe, username, follow}, status) do
    unsubto = String.trim(follow)
    # unsubscriber(username, unsubto)
    unsubscriber(unsubto, username)
    {:noreply, status}
  end
  def handle_cast({:bulksubscription, username, newfollowers}, status) do
    Logger.debug("Adding new subscribers to user #{username}")
    addbulkusersubs(username, newfollowers)
    {:noreply, status}
  end

  #####################
  ### SERVER UTILIY ###
  #####################
  defp sendresponse(client, data) do
    response = Poison.encode!(data)
    :gen_tcp.send(client, response)
  end

  defp sendtweet(sendto, sender, tweet) do
    # fetching receiver details
    port = getuserfield(sendto, "port")
    state = getuserfield(sendto, "status")

    # if user is online send tweet
    if state == :online do
      Logger.debug("Sending tweet to #{sendto}")
      sendresponse(port,%{"function"=> "tweet", "sender"=> sender, "tweet"=> tweet, "username"=> sendto})
    else
      Logger.debug("Receiver #{sendto} is offline, adding tweet to his feeds")
      addtouserfeed(sendto, tweet)
    end
  end

  defp sendfeedtouser(username, client) do
    userfeeds = getuserfield(username, "feeds")
    # Logger.info("User Feeds#{inspect(userfeeds)}")
    alluserfeeds = :queue.to_list(userfeeds)
    # Logger.info("User Feeds#{inspect(alluserfeeds)}")

    for feed <- alluserfeeds do
      data = %{"function"=> "feed", "feed" => feed, "username"=> username}
      sendresponse(client, data)
      :timer.sleep 50
    end
    # delete all feeds in queue
    updateuserfield(username, "feeds", :queue.new)
  end

  ####################################
  #### Tables / Counter Functions ####
  ####################################
  defp inserttotable(table, tuple) do
    :ets.insert(table, tuple)
  end
  defp updatecounter(value, field) do
    # increment value = 1, decrement value = -1
    :ets.update_counter(:counter, field, value)
  end
  defp getcountervalue(whichcounter) do
    :ets.lookup_element(:counter, whichcounter, 2)
  end
  defp printstats(period \\ 10000, last_tweet_count \\ 0) do
    :timer.sleep period
    total_tweets = :ets.lookup_element(:counter, "total tweets", 2)
    tweet_per_sec = (total_tweets - last_tweet_count) / (10000 / 1000)
    total_users = :ets.lookup_element(:counter, "total users", 2)
    online_users = :ets.lookup_element(:counter, "online users", 2)
    offline_users = :ets.lookup_element(:counter, "offline users", 2)
    Logger.info white_background()<>"\n\t"<>red()<>"Twitter Server Stats"<>reset()<>yellow()<>"\n\tTotal Tweets => #{total_tweets}\n\tTweets(per sec) => #{tweet_per_sec}\n\tTotal Users => #{total_users}\n\tOnline Users => #{online_users}\n\tOffline Users => #{offline_users}"<>reset()
    printstats(period, total_tweets)
  end
  ###################
  #### User Data ####
  ###################
  def userexists?(username) do
    :ets.member(:users, username)
  end
  defp getuserdetails(username) do
    userlist = :ets.lookup(:users, username)
    if userlist == [] do
      false
    else
      List.first(userlist)
    end
  end
  defp updateuserstatus(username, position, updatedvalue) do
    :ets.update_element(:users, username, {position, updatedvalue})
  end
  defp updateuserfield(username, field, newvalue) do
    case field do
      "feeds" -> updateuserstatus(username, 4, newvalue)
      "followers" -> updateuserstatus(username, 3, newvalue)
      "status" -> updateuserstatus(username, 2, newvalue)
      _ -> Logger.debug("Invalid filed option passed to updateuserfield #{field}")
    end
  end
  defp getuserfield(username, field) do
    case field do
       "port" -> getuserdetails(username) |> elem(4)
       "feeds"-> getuserdetails(username) |> elem(3)
       "followers" -> getuserdetails(username) |> elem(2)
       "status" -> getuserdetails(username) |> elem(1)
        _ -> Logger.debug("Invalid filed option passed to getuserfield #{field}")
    end
  end
  defp userfeedexist?(username) do
    # :queue.is_empty(getuserfield(username, "feeds"))
    queuelist = :queue.to_list(getuserfield(username, "feeds"))
    if length(queuelist) == 0 do
      false
    else
      true
    end
  end
  defp addsubscribers(username, subscriber) do
    updatedSubs = getuserfield(username, "followers") |> MapSet.put(subscriber)
    updateuserfield(username, "followers", updatedSubs)
  end
  defp unsubscriber(username, follower) do
    updatedSubs = getuserfield(username, "followers") |> MapSet.delete(follower)
    updateuserfield(username, "followers", updatedSubs)
  end
  defp addbulkusersubs(username, followers) do
    currSubs = getuserfield(username, "followers")
    updatedSubs = MapSet.union(currSubs, MapSet.new(followers))
    updateuserfield(username, "followers", updatedSubs)
  end

  ################################
  #### HashTag / Mention Data ####
  ################################
  defp hashtagexists?(hashtag) do
    # :ets.member(:hashtags, hashtag)
    if :ets.lookup(:hashtags, hashtag) == [] do
      false
    else
      true
    end
  end
  defp retrivehashtagtweets(hashtag) do
    Logger.debug("Looking for hash tweet #{hashtag}")
    found = hashtagexists?(hashtag)
    if found do
      :ets.lookup_element(:hashtags, hashtag, 2)
    else
      MapSet.new()
    end
  end
  defp sendhashtags(username, hashtag, client) do
    hashtweets = retrivehashtagtweets(hashtag) |> MapSet.to_list()
    Logger.debug ("Retrieved hastags : #{inspect(hashtweets)}")
    for tweets <- hashtweets do
      data = %{"function"=> "hashtags", "tweets" => tweets, "username"=> username}
      Logger.debug("sending response #{inspect(data)} to client #{inspect(client)}")
      sendresponse(client, data)
      :timer.sleep 50
    end
  end
  defp mentionexists?(mention) do
    :ets.member(:mentions, mention)
  end
  defp retrivementiontweets(mention) do
    if mentionexists?(mention) do
      :ets.lookup_element(:mentions, mention, 2)
    else
      MapSet.new()
    end
  end
  defp sendmentions(username, mention, client) do
    mentweets = retrivementiontweets(mention) |> MapSet.to_list() |> Enum.chunk_every(5)
    Logger.debug " All #{mention} tweets #{inspect(mentweets)}"
    for tweets <- mentweets do
      data = %{"function"=> "mention", "tweets" => tweets, "username"=> username}
      sendresponse(client, data)
      :timer.sleep 50
    end
  end
  defp addtohashtagslist(hashtag, tweet) do
    hashtags = :ets.lookup(:hashtags, hashtag)
    if hashtags == [] do
      tweetMap = MapSet.new |> MapSet.put(tweet)
      inserttotable(:hashtags, {hashtag, tweetMap})
    else
      updtweetMap = hashtags |> List.first |> elem(1) |> MapSet.put(tweet)
      inserttotable(:hashtags, {hashtag,updtweetMap})
    end

    # ## display content of table , comment/remove later
    # allhashs =  :ets.tab2list(:hashtags)
    # Logger.debug("All Hashtags => #{inspect(allhashs)}")
  end
  defp addtomentionslist(mention, tweet) do
    mentions = :ets.lookup(:mentions, mention)
    if mentions == [] do
      mentMap = MapSet.new |> MapSet.put(tweet)
      inserttotable(:mentions, {mention, mentMap})
    else
      udpmentMap = mentions |> List.first |> elem(1) |> MapSet.put(tweet)
      inserttotable(:mentions, {mention, udpmentMap})
    end

    # ## display content of table , comment/remove later
    # allments =  :ets.tab2list(:mentions)
    # Logger.debug("All Mentions => #{inspect(allments)}")

  end

  ###################
  #### Feed Data ####
  ###################
  defp enqueue(queue, value) do
    if :queue.member(value, queue) do
        queue
    else
        :queue.in(value, queue)
    end
  end
  defp addtouserfeed(username, tweet) do
    feed = getuserfield(username, "feeds")
    Logger.debug("Adding tweet => #{tweet} to users feed")
    feed = enqueue(feed, tweet)
    queueaslist = :queue.to_list(feed)
    Logger.debug("@#{username}'s Queue => #{inspect(queueaslist)}")
    updateuserfield(username, "feeds", feed)

    # ## display content of table , comment/remove later
    # allusers =  :ets.tab2list(:users)
    # Logger.debug("All Registered users => #{inspect(allusers)}")

  end

end
