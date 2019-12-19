defmodule Main do
  [numUser,numtweet] =Enum.map(System.argv, (fn x -> x end))
  numUser = String.to_integer(numUser)
  numtweet = String.to_integer(numtweet)

  Simulator.main([numUser,numtweet])
end
