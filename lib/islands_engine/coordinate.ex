defmodule IslandsEngine.Coordinate do
  # Since we have aliased the Coordinate module, we can now refer
  # to coordinate structs as %Coordinate{} instead of
  # %IslandsEngine.Coordinate{}
  alias __MODULE__

  # have to define @enforce_keys before defstruct or else
  # it will not have an effect
  @enforce_keys [:row, :col]
  defstruct [:row, :col]

  @board_range 1..10

  def new(row, col) when row in @board_range and col in @board_range do
    {:ok, %Coordinate{row: row, col: col}}
  end

  def new(_row, _col), do: {:error, :invalid_coordinate}
end
