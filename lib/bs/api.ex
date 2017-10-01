defmodule Bs.Api do
  alias Bs.Api.Response
  alias Bs.Move
  alias Bs.Snake
  alias Bs.World
  alias BsWeb.GameForm
  alias BsWeb.SnakeForm
  alias Ecto.Changeset

  require Logger

  @start_timeout Application.get_env(:bs, :start_timeout)

  @callback load(%SnakeForm{}, %GameForm{}) :: Response.t
  @callback move(%Snake{}, %World{}) :: Response.t
  @callback request_move(%Snake{}, %World{}) :: HTTPoison.Response.t

  def load(url, data, request \\ &HTTPoison.post/4)

  def load(%{url: url}, data, request) do
    load url, data, request
  end

  def load(url, data, request)
  when is_binary(url)
  do
    request_url = url <> "/start"
    data = Poison.encode!(data)

    response = request_url
    |> request.(data, ["content-type": "application/json"], [recv_timeout: @start_timeout])
    |> Response.new(as: %{})

    response = put_in(response.url, url)

    update_in(response.parsed_response, fn
      {:ok, map} ->
      (
        {:ok, map}
      )
      error ->
      (
        log_error(url, error, response)
        error
      )
    end)

    response = update_in(response.parsed_response, fn
      {:ok, snake} ->
      (
        snake = put_in(snake["url"], url)
        {:ok, snake}
      )
      error ->
      (
        log_error(request_url, error, response)
        error
      )
    end)

    response = update_in response.parsed_response, fn
      {:ok, map} ->
        cast_load(map)
      response ->
        response
    end

    do_log(response)
  end

  def do_log(response) do
    with {:error, e} <- response.raw_response,
      do: Logger.debug("[#{response.url}] #{inspect(e)}")

    with {:error, e} <- response.parsed_response,
      do: Logger.debug("[#{response.url}] #{inspect(e)}")

    response
  end

  def cast_load(map) do
    data = %Snake{}
    types = %{
      color: :string,
      head_type: :string,
      head_url: :string,
      name: :string,
      secondary_color: :string,
      tail_type: :string,
      taunt: :string,
      url: :string,
    }

    changeset = {data, types}
    |> Changeset.cast(map, Map.keys(types))
    |> Changeset.validate_required([:name])
    |> Changeset.validate_inclusion(:head_type, Bs.SnakeHeads.list())
    |> Changeset.validate_inclusion(:tail_type, Bs.SnakeTails.list())

    if changeset.valid? do
      {:ok, Changeset.apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end


  @doc """
  Get the move for a single snake.

  POST /move
  """
  @spec move(%Snake{}, %World{}) :: Response.t
  def move(%{url: url, id: id}, world, request \\ &HTTPoison.post/4) do
    data = Poison.encode!(world, me: id)
    url = (url <> "/move")

    response = url
    |> request.(data, ["content-type": "application/json"], [])
    |> Response.new(as: %{})

    response = put_in(response.url, url)

    update_in(response.parsed_response, fn
      {:ok, map} ->
      (
        {:ok, map}
      )
      error ->
      (
        log_error(url, error, response)
        error
      )
    end)

    response = update_in response.parsed_response, fn
      {:ok, map} ->
        cast_move(map)
      response ->
        response
    end

    do_log(response)
  end

  def cast_move(map) do
    data = %Move{}
    types = %{move: :string, taunt: :string}

    changeset = {data, types}
    |> Changeset.cast(map, Map.keys(types))
    |> Changeset.validate_required([:move])
    |> Changeset.validate_inclusion(:move, ~w(up down left right))

    if changeset.valid? do
      {:ok, Changeset.apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end

  def request_move(target, data, opts \\ [])

  def request_move(url, data, options)
  when is_binary(url)
  and is_binary(data) do
    Logger.info("POST #{url}")

    {time, value} = :timer.tc(HTTPoison, :post,
      [url, data, ["content-type": "application/json"], options])

    Logger.info("Response from POST #{url} in #{div(time, 1000)}ms")

    value
  end

  def request_move(%Snake{} = snake, %World{} = world, options) do
    request_move(
      Bs.URL.move_url(snake.url),
      Poison.encode!(world, me: snake.id),
      options
    )
  end

  defp log_error(url, error, response) do
    http_response = inspect(response.raw_response, color: false, pretty: true)
    ("""
    Could not process API response for #{url}:

    Poison JSON Parsing Error:
    #{inspect error}

    HTTPoison HTTP Response:
    #{http_response}
    """)
    |> Logger.debug
  end
end

defmodule Bs.URL do
  def move_url(base), do: base <> "/move"
  def start_url(base), do: base <> "/start"
end
