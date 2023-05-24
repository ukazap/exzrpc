defmodule ExZRPC.FunctionRoutes do
  @moduledoc """
  Function allowlist and routing table.

  Unlike `:rpc`, we don't transmit module and function names over the wire.
  Each function is assigned a unique integer ID, and the client sends the ID based on this routing table.

  ## Example

    iex> function_list = [{Greeter, :hello, 1}, {Greeter, :goodbye, 1}, {Adder, :add, 2}]
    iex> routes = ExZRPC.FunctionRoutes.new()
    iex> ExZRPC.FunctionRoutes.register_functions!(routes, function_list)
    iex> ExZRPC.FunctionRoutes.route_to_id(routes, {Greeter, :hello, 1})
    0
    iex> ExZRPC.FunctionRoutes.route_to_id(routes, {Greeter, :goodbye, 1})
    1
    iex> ExZRPC.FunctionRoutes.route_to_id(routes, {Adder, :add, 2})
    2
    iex> ExZRPC.FunctionRoutes.route_to_id(routes, {Greeter, :howdy, 1})
    nil
    iex> ExZRPC.FunctionRoutes.id_to_route(routes, 0)
    {Greeter, :hello, 1}
    iex> ExZRPC.FunctionRoutes.id_to_route(routes, 1)
    {Greeter, :goodbye, 1}
    iex> ExZRPC.FunctionRoutes.id_to_route(routes, 2)
    {Adder, :add, 2}
    iex> ExZRPC.FunctionRoutes.id_to_route(routes, 3)
    nil
    iex> ExZRPC.FunctionRoutes.to_list(routes)
    [{Greeter, :hello, 1}, {Greeter, :goodbye, 1}, {Adder, :add, 2}]
  """

  @type t :: {atom | :ets.tid(), atom | :ets.tid()}
  @type function_name() :: atom()
  @type id() :: integer()

  @spec new() :: t()
  def new do
    {
      :ets.new(:route2id, [:set, :public, {:read_concurrency, true}]),
      :ets.new(:id2route, [:set, :public, {:read_concurrency, true}])
    }
  end

  @spec register_functions!(t(), [mfa()]) :: :ok
  def register_functions!({route2id, id2route}, route_list) do
    route_list =
      route_list
      |> Enum.uniq()
      |> Enum.filter(fn route ->
        case route do
          {mod, fun, arity} ->
            is_atom(mod) && is_atom(fun) && is_integer(arity) && arity >= 0
          _ -> false
        end
      end)

    if !Enum.empty?(route_list) do
      route2id_list = Enum.with_index(route_list)
      id2route_list = Enum.with_index(route_list, fn route, id -> {id, route} end)
      true = :ets.delete_all_objects(route2id)
      true = :ets.delete_all_objects(id2route)
      true = :ets.insert(route2id, route2id_list)
      true = :ets.insert(id2route, id2route_list)
    end

    :ok
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

  @spec id_to_route(t(), id()) :: {module(), function_name()} | nil
  def id_to_route({_, id2route}, id) do
    case :ets.lookup(id2route, id) do
      [{_, {module_name, function_name, arity}}] -> {module_name, function_name, arity}
      [] -> nil
    end
  end
end
