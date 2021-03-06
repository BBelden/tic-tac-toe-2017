defmodule TicTacToe.Worker do
  use GenServer

  ##
  # Important stuff, DON'T CHANGE
  ##
  def start_link(opts \\ []) do
    {:ok, _pid} = GenServer.start_link(__MODULE__, [], opts)
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
      time_remaining: get_value(:time_remaining),
      winner: get_value(:winner),
      tie: get_value(:tie)
    }
  end

  def init_board() do
    put_value(:team, :x)
    set_timer()
    put_value(:board, %{
      0 => nil, 1 => nil, 2 => nil,
      3 => nil, 4 => nil, 5 => nil,
      6 => nil, 7 => nil, 8 => nil
    })
    put_value(:votes, %{
      0 => 0, 1 => 0, 2 => 0,
      3 => 0, 4 => 0, 5 => 0,
      6 => 0, 7 => 0, 8 => 0
    })
    put_value(:winner, false)
    put_value(:tie, false)
  end

  def init(_) do
    init_board()
    :timer.apply_interval(:timer.seconds(1), TicTacToe.Worker, :timer_tick, [])
    {:ok, []}
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
  # team: something something Tom did this
  # .... belongs to user... he told me so
  def apply_vote(team, vote_idx) do
    board = get_value(:board)
    # Team?
    if team == get_value(:team) do
       board_value = Map.get(board, vote_idx)
       if board_value == nil do
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
    put_value(:time_remaining, 15)
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
    gb = get_value(:board)
    Enum.reduce_while(@win_conditions, false, fn(item, _) ->
      winner = variant_has_winner?(gb, item)
      if winner do
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

  def game_over() do
    set_timer()
    TicTacToe.GameChannel.tick(15)
    :timer.sleep(15000)
    init_board()
  end

  def is_game_over() do
    board = get_value(:board)
    winner = check_win()
    cond do
      !Enum.any?(board, fn({_k,v}) -> v == nil end) ->
        ## board is full but no winner: draw
        put_value(:tie, true)
        game_over()
      winner ->
        ## winner!
        put_value(:winner, winner)
        game_over()
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
