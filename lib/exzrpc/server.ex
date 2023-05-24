defmodule ExZRPC.Server do
  use GenServer
  alias ExZRPC.Codec
  alias ExZRPC.FunctionRoutes

  def start_link(opts) do
    init_args = %{
      host: Keyword.fetch!(opts, :host) |> to_charlist(),
      port: Keyword.fetch!(opts, :port),
      routes: Keyword.fetch!(opts, :routes)
    }

    GenServer.start_link(__MODULE__, init_args, Keyword.take(opts, [:name]))
  end

  @impl GenServer
  def init(%{host: host, port: port, routes: route_list}) do
    {:ok, _} = Application.ensure_all_started(:chumak)
    {:ok, socket} = :chumak.socket(:rep)
    true = Process.link(socket)
    {:ok, _bind_pid} = :chumak.bind(socket, :tcp, host, port)

    routes = FunctionRoutes.new()
    FunctionRoutes.register_functions!(routes, route_list)

    {:ok, {socket, routes}, {:continue, :recv_loop}}
  end

  @impl GenServer
  def handle_continue(:recv_loop, {socket, routes} = state) do
    {:ok, data} = :chumak.recv(socket)

    reply =
      data
      |> Codec.decode()
      |> handle_message(routes)
      |> Codec.encode()

    :chumak.send(socket, reply)

    {:noreply, state, {:continue, :recv_loop}}
  end

  defp handle_message(:list_routes, routes) do
    {:goodrpc, FunctionRoutes.to_list(routes)}
  end

  defp handle_message([route_id, args], routes) when is_list(args) do
    arity = length(args)

    case FunctionRoutes.id_to_route(routes, route_id) do
      {mod, fun, ^arity} ->
        try do
          result = apply(mod, fun, args)
          {:goodrpc, result}
        rescue
          exception -> {:badrpc, exception}
        catch
          thrown -> {:badrpc, thrown}
        end

      _ ->
        {:badrpc, :invalid_mfa}
    end
  end

  defp handle_message(_, _) do
    {:badrpc, :invalid_request}
  end
end
