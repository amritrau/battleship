defmodule Util do
  def cartesian([]), do: []
  def cartesian(x), do: cartesian(Enum.reverse(x), []) |> Enum.to_list()
  defp cartesian([], elems), do: [elems]

  defp cartesian([h | tail], elems) do
    Stream.flat_map(h, fn x -> cartesian(tail, [x | elems]) end)
  end

  def has_duplicates?(list) do
    list
    |> Enum.reduce_while(%MapSet{}, fn x, acc ->
      if MapSet.member?(acc, x),
        do: {:halt, false},
        else: {:cont, MapSet.put(acc, x)}
    end)
    |> is_boolean()
  end

  def time(func) do
    {t, res} = func |> :timer.tc()
    {t |> Kernel./(1_000_000), res}
  end
end

defmodule Ship do
  @enforce_keys [:name, :size]
  defstruct [:name, :size]
end

defmodule Board do
  @boardsize 5
  def boardsize, do: @boardsize

  def in_bounds?(x), do: 0 <= x and x < @boardsize
  def in_bounds?(x, y), do: in_bounds?(x) and in_bounds?(y)

  def get_footprint(pos, size, ori) when ori == :horizontal do
    {x, y} = pos
    MapSet.new(for i <- 0..(size - 1), do: {x + i, y})
  end
  def get_footprint(pos, size, ori) when ori == :vertical do
    {x, y} = pos
    MapSet.new(for i <- 0..(size - 1), do: {x, y + i})
  end

  def place_ship(ship) do
    for i <- 0..(@boardsize - ship.size), j <- 0..(@boardsize - 1) do
      h = get_footprint({i, j}, ship.size, :horizontal)
      v = get_footprint({j, i}, ship.size, :vertical)
      [h, v]
    end
  end

  def hit?(board, pos) do
    MapSet.member?(board, pos)
  end

  def select_target(configs, history) do
    [{target, _} | _] =
      configs
      |> Enum.map(&MapSet.to_list/1)
      |> List.flatten()
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_, v} -> -v end)
      |> Enum.reject(fn {x, _} -> MapSet.member?(history, x) end)
    target
  end

  def game_over(board, history) do
    board |> MapSet.subset?(history)
  end

  def shoot(configs, board, history \\ MapSet.new()) do
    target = select_target(configs, history)

    selector =
      if Board.hit?(board, target) do
        &Enum.filter/2
      else
        &Enum.reject/2
      end

    result =
      if Board.hit?(board, target) do
        :hit
      else
        :miss
      end

    {target, result, configs |> selector.(fn x -> Board.hit?(x, target) end),
     history |> MapSet.put(target)}
  end
end

defmodule Battleship do
  @ships %{
    patrol: %Ship{name: "Patrol Boat", size: 2},
    submarine: %Ship{name: "Submarine", size: 3},
    destroyer: %Ship{name: "Destroyer", size: 3},
    battleship: %Ship{name: "Battleship", size: 4},
    carrier: %Ship{name: "Carrier", size: 5}
  }
  def ships, do: @ships

  def get_configs do
    total_footprint = Enum.sum(for {_, x} <- Battleship.ships(), do: x.size)

    Enum.map(@ships, fn {_, ship} -> Board.place_ship(ship) end)
    |> Enum.map(&List.flatten/1)
    |> Util.cartesian()
    |> Enum.map(fn x -> Enum.reduce(x, &MapSet.union/2) end)
    |> Enum.filter(fn x -> MapSet.size(x) == total_footprint end)
  end

  def main do
    {t, configs} = Util.time(&Battleship.get_configs/0)
    time = :erlang.float_to_binary(t, decimals: 3)
    IO.puts("#{length(configs)} configurations (#{time}s)")

    board = configs |> Enum.random()
    turns = 1..(Board.boardsize * Board.boardsize)

    Enum.reduce_while(turns, {1, configs, MapSet.new}, fn _, acc ->
      {i, cfgs, history} = acc
      {target, result, cfgs, history} = Board.shoot(cfgs, board, history)
      IO.inspect {target, result}
      acc = {i + 1, cfgs, history}
      if !Board.game_over(board, history) do
        {:cont, acc}
      else
        IO.puts "game over; #{i} turns taken"
        {:halt, acc}
      end
    end)
  end
end

ExUnit.start()

defmodule BattleshipTest do
  use ExUnit.Case

  test "all ships are placed in bounds" do
    Enum.each(Battleship.ships(), fn {_, ship} ->
      xy =
        ship
        |> Board.place_ship()
        |> List.flatten()
        |> Enum.map(&MapSet.to_list/1)
        |> List.flatten()
      assert Enum.all?(Enum.map(xy, fn {x, y} -> Board.in_bounds?(x, y) end))
    end)
  end
end

Battleship.main