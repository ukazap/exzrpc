defmodule ExRPC.Server.Handler do
  @moduledoc false

  use ThousandIsland.Handler

  alias ExRPC.Codec
  alias ExRPC.FunctionRoutes

  @impl ThousandIsland.Handler
  def handle_data(data, socket, %{routes: routes} = state) do
    reply =
      data
      |> Codec.decode()
      |> process(routes)
      |> Codec.encode()

    ThousandIsland.Socket.send(socket, reply)
    {:continue, state}
  end

  defp process(:list_routes, routes) do
    {:goodrpc, FunctionRoutes.to_list(routes)}
  end

  defp process([route_id, args], routes) when is_list(args) do
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

  defp process(_, _) do
    {:badrpc, :invalid_request}
  end
end
