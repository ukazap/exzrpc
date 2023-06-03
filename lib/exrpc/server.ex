defmodule ExRPC.Server do
  @moduledoc false

  use Supervisor

  alias ExRPC.FunctionRoutes
  alias ExRPC.Server.Handler

  def start_link(opts) do
    init_arg = %{
      port: Keyword.fetch!(opts, :port),
      mfa_list: Keyword.fetch!(opts, :routes)
    }

    Supervisor.start_link(__MODULE__, init_arg, name: opts[:name])
  end

  @impl Supervisor
  def init(init_arg) do
    routes =
      case FunctionRoutes.create(init_arg[:mfa_list]) do
        {:ok, routes} -> routes
        {:error, _} -> raise "invalid or empty list of routes"
      end

    children = [
      {ThousandIsland,
       port: init_arg[:port], handler_module: Handler, handler_options: %{routes: routes}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
