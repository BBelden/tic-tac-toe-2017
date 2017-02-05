defmodule TicTacToe.Worker do
  use GenServer

  ##
  # Important stuff, DON'T CHANGE
  ##
  put_value(:test_time,5)
  def start_link(opts \\ []) do
    {:ok, pid} = GenServer.start_link(__MODULE__, [], opts)
  end

  def get_value(key) do
    ConCache.get(:game_state, key)
  end

  def put_value(key, value) do
    ConCache.put(:game_state, key, value)
  end

  def get_cache() do
    %{
      team: get_value(:team),
      board: Map.values(get_value(:board)),
      votes: Map.values(get_value(:votes)),
      time_remaining: get_value(:time_remaining)
    }
  end

  def init_board() do
    #put_value(:teamPlayer, Enum.random([:o, :x]))
    put_value(:team, Enum.random([:o, :x]))
    set_timer()
    put_value(:board, %{
      0 => nil, 1 => nil, 2 => nil,
      3 => nil, 4 => nil, 5 => nil,
      6 => nil, 7 => nil, 8 => nil
    })
    put_value(:votes, %{
      0 => 0, 1 => 0, 2 => 555555,
      3 => 0, 4 => 0, 5 => 0,
      6 => 0, 7 => 0, 8 => 0
    })
    ConCache.put(:game_state, :team, :o)
    put_value(:board_full,false)
    put_value(:winner,false)
  end

  def init(state) do
    init_board()
    #IO.inspect Map.to_list(get_value(:board))
    :timer.apply_interval(:timer.seconds(1), TicTacToe.Worker, :timer_tick, [])
    {:ok, state}
  end
  ##
  # End important stuff
  ##

  ##
  # Timer
  ##
  def timer_tick() do
    prev = get_value(:time_remaining)
    case prev do
      prev when prev in 1..15 ->
        TicTacToe.GameChannel.tick(prev-1)
        put_value(:time_remaining, prev-1)
      0 ->
        turn_over()
    end
  end
  ##
  # End timer
  ##

  ##
  # Vote tallying stuff
  ##
  def apply_vote(team, vote_idx) do
    board = get_value(:board)
    current_turn = get_value(:team)
    # Team?
    IO.inspect(%{voting_team: current_turn, my_team: team, my_choice: vote_idx})
    if team == get_value(:team) do
       board_value = Map.get(board, vote_idx)
       if board_value == nil do
         IO.puts "Hey! Apply Vote If Is Working"
          # ...add vote
          votes = get_value(:votes)
          votes_value = Map.get(votes, vote_idx)
          new_votes = Map.put(votes, vote_idx, votes_value + 1)
          put_value(:votes, new_votes)
       end
    end
  end


  ##
  # End vote tallying stuff
  ##

  ##
  #  end of turn stuff
  ##
  def set_timer() do
    put_value(:time_remaining, get_value(:test_time))
  end

  @win_conditions [
    [0, 1, 2], # 0
    [3, 4, 5], # 1
    [6, 7, 8], # 2
    [0, 3, 6], # 3
    [1, 4, 7], # 4
    [2, 5, 8], # 5
    [0, 4, 8], # 6
    [2, 4, 6]  # 7
  ]

  def pluck_spaces(board, indices) do
    Enum.map(indices, fn(x) -> Map.get(board, x) end)
  end

  def variant_has_winner?(board, indices) do
    case pluck_spaces(board, indices) do
      [:x, :x, :x] ->
        :x
      [:o, :o, :o] ->
        :o
      _ ->
        false
    end
  end

  def check_win() do
    IO.puts "checking if there's a winner"
    gb = get_value(:board)
    Enum.reduce_while(@win_conditions, false, fn(item, _) ->
      winner = variant_has_winner?(gb, item)
      IO.inspect(winner)
      if winner do
        IO.puts "FINAL WINNER!!!"
        IO.inspect(winner)
        put_value(:winner, winner)
        {:halt, winner}
      else
        {:cont, false}
      end
    end)
  end

  def update_board() do
    board = get_value(:board)
    highest = get_value(:votes)
      |> Enum.sort(fn({_, lhs}, {_, rhs}) ->
          lhs >= rhs
        end)
      |> List.first
    if elem(highest,1) != 0 do
      board = if get_value(:team) == :x do
        Map.put(board,elem(highest,0),:x)
      else
        Map.put(board,elem(highest,0),:o)
      end
      put_value(:board,board)
    end
  end

  def reset_votes() do
    put_value(:votes, %{
      0 => 0, 1 => 0, 2 => 0,
      3 => 0, 4 => 0, 5 => 0,
      6 => 0, 7 => 0, 8 => 0
    })
  end

  def change_team() do
    if get_value(:team) == :x do
      put_value(:team, :o)
    else
      put_value(:team, :x)
    end
  end

  def is_game_over() do
    board = get_value(:board)
    check_win()
    cond do
      !Enum.any?(board, fn({k,v}) -> v == nil end) ->
        ## board full
        ## TODO game tie output?
        init_board()
        #get_value(:winner) != nil ->
      get_value(:winner) ->
        ## winner!
        ## TODO game winner output?
        init_board()
      true ->
        true
    end
  end

  def turn_over() do
    update_board()
    reset_votes()
    change_team()
    is_game_over()
    set_timer()
  end

  ##
  #  end end of turn stuff
  ##
end
