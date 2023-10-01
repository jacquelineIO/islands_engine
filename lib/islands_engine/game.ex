defmodule IslandsEngine.Game do
  use GenServer

  alias IslandsEngine.{Board, Coordinate, Guesses, Island, Rules}

  # There's direct mapping between GenServer module functions and callbaks.
  # - Calling GenServer.start_link/3 always triggers GenServer.init/1.
  # - Calling GenServer.call/3 always triggers GenServer.handle_call/3.
  # - Calling GenServer.cast/2 always triggers GenServer.handle_cast/2.
  #
  # not for production but can debug state by calling
  # state_data = :sys.get_state(game)
  # state_data = :sys.replace_state(game, fn data ->
  #   %{state_data | rules: %Rules{state: :player1_turn}}
  #   end)

  @players [:player1, :player2]

  def init(name) do
    player1 = %{name: name, board: Board.new(), guesses: Guesses.new()}
    player2 = %{name: nil, board: Board.new(), guesses: Guesses.new()}

    {:ok, %{player1: player1, player2: player2, rules: %Rules{}}}
  end

  def handle_call(:demo_call, _from, state) do
    # indicates that we are replying, is the reply, is the new state that we want to keep/store
    {:reply, state, state}
  end

  def handle_call({:add_player, name}, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, :add_player) do
      state_data
      |> update_player2_name(name)
      |> update_rules(rules)
      |> reply_success(:ok)
    else
      :error -> {:reply, :error, state_data}
      {:error_rule_check, %{state: rules, action: action}} -> {:reply, "failed rule check, current state: #{inspect(rules)} tried action #{inspect(action)}", state_data}

    end
  end

  def handle_call({:position_island, player, key, row, col}, _from, state_data) do
    board = player_board(state_data, player)

    with {:ok, rules} <- Rules.check(state_data.rules, {:position_islands, player}),
         {:ok, coordinate} <- Coordinate.new(row, col),
         {:ok, island} <- Island.new(key, coordinate),
         %{} = board <- Board.position_island(board, key, island) do
      state_data
      |> update_board(player, board)
      |> update_rules(rules)
      |> reply_success(:ok)
    else
      :error -> {:reply, :error, state_data}
      {:error, :invalid_coordinate} -> {:reply, {:error, :invalid_coordinate}, state_data}
      {:error, :invalid_island_type} -> {:reply, {:error, :invalid_island_type}, state_data}
      {:error, :overlapping_island} -> {:reply, {:error, :overlapping_island}, state_data}
      {:error_rule_check, %{state: rules, action: action}} -> {:reply, "failed rule check, current state: #{inspect(rules)} tried action #{inspect(action)}", state_data}

    end
  end

  def handle_call({:set_islands, player}, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, {:set_islands, player}),
         %{} = board <- player_board(state_data, player),
         true <- Board.all_islands_positioned?(board) do
      state_data
      |> update_rules(rules)
      |> reply_success(:ok)
    else
      :error -> {:reply, :error, state_data}
      false -> {:reply, {:error, :not_all_islands_positioned}, state_data}
      {:error_rule_check, %{state: rules, action: action}} -> {:reply, "failed rule check, current state: #{inspect(rules)} tried action #{inspect(action)}", state_data}
      error -> {:reply, {:error, inspect(error)}, state_data}
    end
  end

  def handle_call({:guess_coordinate, player, row, col}, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, {:guess_coordinate, player}),
         {:ok, coordinate} <- Coordinate.new(row, col),
         opponent_player <- opponent(player),
         %{} = opponent_board <- player_board(state_data, opponent_player),
         {hit_or_miss, forested_island, win_status, opponent_board} <-
           Board.guess(opponent_board, coordinate),
         {:ok, rules} <- Rules.check(rules, {:win_check, win_status}) do
      state_data
      |> update_board(opponent_player, opponent_board)
      |> update_guesses(player, hit_or_miss, coordinate)
      |> update_rules(rules)
      |> reply_success({hit_or_miss, forested_island, win_status})
    else
      :error -> {:reply, :error, state_data}
      {:error, :invalid_coordinate} -> {:reply, {:error, :invalid_coordinate}, state_data}
      {:error_rule_check, %{state: rules, action: action}} -> {:reply, "failed rule check, current state: #{inspect(rules)} tried action #{inspect(action)}", state_data}
    end
  end

  def update_player2_name(state_data, name) do
    put_in(state_data.player2.name, name)
  end

  @spec update_rules(%{:rules => any, optional(any) => any}, any) :: %{
          :rules => any,
          optional(any) => any
        }
  def update_rules(state_data, rules) do
    %{state_data | rules: rules}
  end

  def update_guesses(state_data, player, hit_or_miss, coordinate) do
    update_in(state_data[player].guesses, fn guesses ->
      Guesses.add(guesses, hit_or_miss, coordinate)
    end)
  end

  def reply_success(state_data, reply) do
    {:reply, reply, state_data}
  end

  def handle_info(:first, state) do
    IO.puts("This message had been handled by handle_info/2, matching on :first.")
    {:noreply, state}
  end

  def handle_cast({:demo_cast, new_value}, state) do
    {:noreply, Map.put(state, :test, new_value)}
  end

  # CLIENT CODE

  def start_link(name) when is_binary(name) do
    GenServer.start_link(__MODULE__, name, name: via_tuple(name))
  end

  # def start_link(name) when is_binary(name) do
  #   GenServer.start_link(__MODULE__, name, [])
  # end

  def via_tuple(name), do: {:via, Registry, {Registry.Game, name}}

  def add_player(game, name) when is_binary(name) do
    GenServer.call(game, {:add_player, name})
  end

  def position_island(game, player, key, row, col) when player in @players do
    GenServer.call(game, {:position_island, player, key, row, col})
  end

  defp player_board(state_data, player), do: Map.get(state_data, player).board

  defp update_board(state_data, player, board) do
    Map.update!(state_data, player, fn player -> %{player | board: board} end)
  end

  def set_islands(game, player) when player in @players do
    GenServer.call(game, {:set_islands, player})
  end

  def guess_coordinate(game, player, row, col) when player in @players do
    GenServer.call(game, {:guess_coordinate, player, row, col})
  end

  defp opponent(:player1), do: :player2
  defp opponent(:player2), do: :player1



  def demo_call(game) do
    GenServer.call(game, :demo_call)
  end

  def demo_cast(game, new_value) do
    GenServer.cast(game, {:demo_cast, new_value})
  end
end
