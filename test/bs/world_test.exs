defmodule Bs.WorldTest do
  alias Bs.{Point, Snake, World}
  use Bs.Case, async: true
  use Property
  use Point
  import Point

  setup context do
    world = %World{max_food: 4, height: 10, width: 10, game_id: 0}
    Map.put(context, :world, world)
  end

  describe "World.dec_health_points/2" do
    setup %{world: context_world, dec_health_points: dec} do
      world = %{context_world | dec_health_points: dec}
      snake = build(:snake, health_points: 50)

      [snake: _, world: world] =
        with_snake_in_world(snake: snake, world: world, length: 1)

      world = World.dec_health_points(world)

      [snake] = world.snakes

      {:ok, snake: snake, world: world}
    end

    @tag dec_health_points: 1
    test "reduces snake health points by 1 (default)", %{snake: snake} do
      assert snake.health_points == 49
    end

    @tag dec_health_points: 2
    test "reduces snake health points by 2", %{snake: snake} do
      assert snake.health_points == 48
    end
  end

  describe "World.grow_snakes/1" do
    setup do
      world = build(:world)
      snake = build(:snake, health_points: 50)

      [snake: snake, world: world] =
        with_snake_in_world(snake: snake, world: world, length: 1)

      world = with_food_on_snake(world: world, snake: snake)
      world = World.grow_snakes(world)
      [snake] = world.snakes

      {:ok, snake: snake, world: world}
    end

    test "resets the health_points of snakes that are eating this turn", %{
      snake: snake
    } do
      assert snake.health_points == 100
    end

    test "increases snake length", %{snake: snake} do
      assert length(snake.coords) == 2
    end
  end

  describe "World.rand_unoccupied_space/1" do
    property "in the bounds of the board, on an unoccupied space" do
      forall(world(), fn w ->
        {:ok, point} = World.rand_unoccupied_space(w)

        coords = Enum.flat_map(w.snakes, & &1.coords)

        point not in w.food and point not in coords and point.x in World.cols(w) and
          point.y in World.rows(w)
      end)
    end

    test "does the thing" do
      food =
        for x <- 0..90,
            y <- 0..90,
            do: p(x, y)

      world = build(:world, snakes: [], width: 100, height: 100, food: food)

      assert {:ok, v} = World.rand_unoccupied_space(world)
      assert MapSet.member?(MapSet.new(food), v) == false
    end

    test "returns an error if there is no space" do
      world = build(:world, width: 1, height: 1, food: [p(0, 0)])
      assert {:error, :empty_error} == World.rand_unoccupied_space(world)
    end
  end

  describe "World.stock_food/1" do
    test "sets food on the board, up to a max", %{world: world} do
      world = World.stock_food(world)
      assert length(world.food) == 4
    end

    test "does nothing if there is no space" do
      world = build(:world, width: 1, height: 1, food: [p(0, 0)])
      assert World.stock_food(world) == world
    end

    test "sets no food if set to 0", %{world: world} do
      world = put_in(world.max_food, 0)
      world = World.stock_food(world)
      assert length(world.food) == 0
    end

    test "adds to existing stocks", %{world: world} do
      food = %Point{y: 5, x: 5}
      world = put_in(world.food, [food])
      world = put_in(world.max_food, 2)

      world = World.stock_food(world)

      assert [
               %Point{},
               ^food
             ] = world.food
    end
  end

  describe "World.clean_up_dead/1 head to head collision" do
    test "kills same length snakes" do
      big_snake = build(:snake, id: :big, coords: line(p(0, 0), p(0, 1), 3))
      small_snake = build(:snake, id: :small, coords: line(p(0, 0), p(1, 0), 3))

      world =
        build(:world, width: 100, height: 100, snakes: [big_snake, small_snake])

      world = World.clean_up_dead(world)

      assert world.snakes == []
      assert small_snake in world.dead_snakes
      assert big_snake in world.dead_snakes
      assert 2 == length(world.dead_snakes)
    end

    test "kills the smaller snake" do
      big_snake = build(:snake, id: :big, coords: line(p(0, 0), p(0, 1), 10))
      small_snake = build(:snake, id: :small, coords: line(p(0, 0), p(1, 0), 3))

      world =
        build(:world, width: 100, height: 100, snakes: [big_snake, small_snake])

      world = World.clean_up_dead(world)

      assert world.snakes == [big_snake]
      assert world.dead_snakes == [small_snake]
    end
  end

  describe "World.clean_up_dead/1" do
    test "removes snakes that died in body collisions", %{world: world} do
      snake = %Snake{coords: [%Point{y: 5, x: 5}, %Point{y: 5, x: 5}]}
      world = put_in(world.snakes, [snake])

      world = World.clean_up_dead(world)
      assert world.snakes == []
      assert world.dead_snakes == [snake]
    end

    test "removes any snakes that die this turn", %{world: world} do
      snake = %Snake{coords: [%Point{y: 10, x: 10}]}
      world = put_in(world.snakes, [snake])

      world = World.clean_up_dead(world)
      assert world.snakes == []
      assert world.dead_snakes == [snake]
    end

    @dead_snake %Snake{name: "dead"}
    @snake %Snake{name: "live", coords: [p(-1, 0)]}
    @world %World{turn: 10, snakes: [@snake], dead_snakes: [@dead_snake]}
    test "adds dead snakes to a list of deaths with the turn they died on" do
      world = World.clean_up_dead(@world)
      assert world.dead_snakes == [@dead_snake, @snake]
      assert world.snakes == []

      assert world.deaths == [%World.DeathEvent{turn: 10, snake: @snake}]
    end
  end

  test "#find_snake" do
    snake = build(:snake)
    world = build(:world, snakes: [snake])
    assert snake == World.find_snake(world, snake.id)

    world = build(:world, snakes: [])
    assert nil == World.find_snake(world, snake.id)
  end
end
