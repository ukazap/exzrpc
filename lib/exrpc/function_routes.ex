defmodule ExRPC.FunctionRoutes do
  @moduledoc """
  Function allowlist and routing table.

  Unlike `:rpc`, we don't transmit module and function names over the wire.
  Each function is assigned a unique integer ID, and the client sends the ID based on this routing table.

    # Instantiate a new routing table:
    iex> ExRPC.FunctionRoutes.create([])
    {:error, :empty_list}
    iex> {:ok, routes} = ExRPC.FunctionRoutes.create([{Greeter, :hello, 1}, {Greeter, :goodbye, 1}, {Adder, :add, 2}])
    {:ok, routes}
    # Route to ID and vice-versa:
    iex> ExRPC.FunctionRoutes.route_to_id(routes, {Greeter, :hello, 1})
    0
    iex> ExRPC.FunctionRoutes.route_to_id(routes, {Greeter, :goodbye, 1})
    1
    iex> ExRPC.FunctionRoutes.route_to_id(routes, {Adder, :add, 2})
    2
    iex> ExRPC.FunctionRoutes.route_to_id(routes, {Greeter, :howdy, 1})
    nil
    iex> ExRPC.FunctionRoutes.id_to_route(routes, 0)
    {Greeter, :hello, 1}
    iex> ExRPC.FunctionRoutes.id_to_route(routes, 1)
    {Greeter, :goodbye, 1}
    iex> ExRPC.FunctionRoutes.id_to_route(routes, 2)
    {Adder, :add, 2}
    iex> ExRPC.FunctionRoutes.id_to_route(routes, 3)
    nil
    # Convert route table to list (for transmitting to clients):
    iex> ExRPC.FunctionRoutes.to_list(routes)
    [{Greeter, :hello, 1}, {Greeter, :goodbye, 1}, {Adder, :add, 2}]
  """

  @type t :: {atom | :ets.tid(), atom | :ets.tid()}
  @type function_name() :: atom()
  @type id() :: integer()

  @spec create(list(mfa())) :: {:ok, t()} | {:error, atom()}
  def create([]), do: {:error, :empty_list}

  def create([{_, _, _} | _] = mfa_list) do
    mfa_list
    |> Enum.uniq()
    |> Enum.filter(fn route ->
      case route do
        {mod, fun, arity} ->
          is_atom(mod) && is_atom(fun) && is_integer(arity) && arity >= 0

        _ ->
          false
      end
    end)
    |> case do
      [] ->
        {:error, :invalid_list}

      mfas ->
        route2id = :ets.new(:route2id, [:set, :public, {:read_concurrency, true}])
        route2id_list = Enum.with_index(mfas)
        true = :ets.insert(route2id, route2id_list)

        id2route = :ets.new(:id2route, [:set, :public, {:read_concurrency, true}])
        id2mfa_list = Enum.with_index(mfas, fn route, id -> {id, route} end)
        true = :ets.insert(id2route, id2mfa_list)

        {:ok, {route2id, id2route}}
    end
  end

  @spec to_list(t()) :: [mfa()]
  def to_list({route2id, _}) do
    route2id
    |> :ets.tab2list()
    |> Enum.sort_by(fn {_, id} -> id end)
    |> Enum.map(fn {fun, _} -> fun end)
  end

  @spec route_to_id(t(), mfa()) :: id() | nil
  def route_to_id({route2id, _}, {module_name, function_name, arity}) do
    case :ets.lookup(route2id, {module_name, function_name, arity}) do
      [{_, id}] -> id
      [] -> nil
    end
  end

  @spec id_to_route(t(), id()) :: {module(), function_name(), arity()} | nil
  def id_to_route({_, id2route}, id) do
    case :ets.lookup(id2route, id) do
      [{_, {module_name, function_name, arity}}] -> {module_name, function_name, arity}
      [] -> nil
    end
  end
end
