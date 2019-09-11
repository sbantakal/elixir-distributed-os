#  code using only handle call function
# defmodule VGenServer do
#   use GenServer

#   def start_link(numrange) do
#     GenServer.start_link(__MODULE__,numrange)
#   end

#   def init(numrange) do
#     {:ok,numrange}
#   end

#   def get_vampire_nos(pid) do
#     GenServer.call(pid,:get_vampire_nos)
#   end

#   def handle_call(:get_vampire_nos,_from,state) do
#     state_len=length(state)-1
#     first_elem=Enum.at(state,0)
#     last_elem=Enum.at(state,state_len)
#     {:reply,vmp_range(first_elem,last_elem),state}
#   end

#   # Vampire Number Functions
#   def vmp_range(first, last) do
#     Enum.filter(Enum.map(first..last, fn x -> vf(x) end), & &1)
#   end

#   def find_fangs(_, _, _, fangs, first, last) when first==last, do: fangs

#   def find_fangs(n, half, sorted, fangs, first, last) when first<last do
#     if(rem(n, first) == 0 &&
#       digit_count(first) == half && digit_count(div(n,first)) == half  &&
#       Enum.sort(String.codepoints("#{first}#{div(n,first)}")) == sorted) do
#         find_fangs(n,half,sorted,fangs <> " #{first} #{div(n,first)}", first+1, last)
#     else
#       find_fangs(n,half,sorted,fangs, first+1, last)
#     end
#   end

#   def vf n do
#     if rem(digit_count(n), 2) == 0 do
#       half = div(digit_count(n), 2)
#       sorted = Enum.sort(String.codepoints("#{n}"))
#       initial = trunc(n / :math.pow(10, div(digit_count(n), 2)))
#       last = round(:math.sqrt(n))
#       fangs = find_fangs(n, half, sorted, "", initial, last)
#       if byte_size(fangs) > 0 do
#         "#{n}" <> fangs
#       end
#     end
#   end

#   defp digit_count(no), do: length(to_charlist(no))

# end

# code using both handle call and handle cast
defmodule VGenServer do
  use GenServer

  def start_link(numrange) do
    {:ok, pid} = GenServer.start_link(__MODULE__,numrange)
    findvmps(pid, numrange)
    {:ok, pid}
  end

  def init(numrange) do
    {:ok,numrange}
  end

  def get_vampire_nos(pid) do
    GenServer.call(pid,:get_vampire_nos,:infinity)
  end

  def handle_call(:get_vampire_nos,_from,state) do
    {:reply,state,state}
  end

  def findvmps(pid, range) do
    GenServer.cast(pid,{:find_vmps, range})
  end

  def handle_cast({:find_vmps, range}, _numrange) do
    result = vmp_range(range)
    {:noreply, result}
  end

  # Vampire Number Functions
  def vmp_range(range) do
    Enum.filter(Enum.map(range, fn x -> vf(x) end), & &1)
  end

  def find_fangs(_, _, _, fangs, first, last) when first==last, do: fangs

  def find_fangs(n, half, sorted, fangs, first, last) when first<last do
    if(rem(n, first) == 0 &&
      digit_count(first) == half && digit_count(div(n,first)) == half  &&
      Enum.sort(String.codepoints("#{first}#{div(n,first)}")) == sorted) do
        find_fangs(n,half,sorted,fangs <> " #{first} #{div(n,first)}", first+1, last)
    else
      find_fangs(n,half,sorted,fangs, first+1, last)
    end
  end

  def vf n do
    if rem(digit_count(n), 2) == 0 do
      half = div(digit_count(n), 2)
      sorted = Enum.sort(String.codepoints("#{n}"))
      initial = trunc(n / :math.pow(10, div(digit_count(n), 2)))
      last = round(:math.sqrt(n))
      fangs = find_fangs(n, half, sorted, "", initial, last)
      if byte_size(fangs) > 0 do
        "#{n}" <> fangs
      end
    end
  end

  defp digit_count(no), do: length(to_charlist(no))

end
