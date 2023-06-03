defmodule ExZRPC.Client do
  @behaviour NimblePool
  alias ExZRPC.Codec
  alias ExZRPC.FunctionRoutes

  @spec routes(atom()) :: list()
  def routes(pool) do
    NimblePool.checkout!(pool, :checkout, fn _from, {_socket, routes} ->
      {FunctionRoutes.to_list(routes), :ok}
    end)
  end

  @spec call(atom(), atom(), atom(), list()) :: any()
  def call(pool, m, f, a) when is_atom(m) and is_atom(f) and is_list(a) do
    NimblePool.checkout!(pool, :checkout, fn _from, {socket, routes} ->
      case FunctionRoutes.route_to_id(routes, {m, f, length(a)}) do
        nil ->
          {{:badrpc, :invalid_mfa}, :ok}

        route_id ->
          message = "!" <> :erlang.term_to_binary([route_id, a])
          :ok = :chumak.send(socket, message)
          {:ok, bin} = :chumak.recv(socket)

          case Codec.decode(bin) do
            :decode_error ->
              {{:badrpc, :invalid_response, bin}, :ok}

            {:badrpc, reason} ->
              {{:badrpc, reason}, :ok}

            {:goodrpc, result} ->
              {result, :ok}
          end
      end
    end)
  end

  def start_link(opts) do
    {host, opts} = Keyword.pop!(opts, :host)
    {port, opts} = Keyword.pop!(opts, :port)
    opts = Keyword.put(opts, :worker, {__MODULE__, %{server: {to_charlist(host), port}}})
    NimblePool.start_link(opts)
  end

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: {__MODULE__, name: Keyword.fetch!(opts, :name)},
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @impl NimblePool
  def init_pool(pool_state) do
    Application.ensure_all_started(:chumak)

    routes = FunctionRoutes.new()
    pool_state = Map.put(pool_state, :routes, routes)

    {:ok, pool_state}
  end

  @impl NimblePool
  def init_worker(%{server: server, routes: routes} = pool_state) do
    {:ok, socket} = create_socket()

    if FunctionRoutes.empty?(routes) do
      {:ok, peer} = connect_socket(socket, server)
      :ok = :chumak.send(socket, Codec.encode(:list_routes))
      {:ok, bin} = :chumak.recv(socket)
      {:goodrpc, route_list} = Codec.decode(bin)
      FunctionRoutes.register_functions!(routes, route_list)
      {:ok, {socket, peer}, pool_state}
    else
      {:ok, {socket, nil}, pool_state}
    end
  end

  @impl NimblePool
  def handle_checkout(:checkout, _from, {socket, nil}, pool_state) do
    {:ok, peer} = connect_socket(socket, pool_state.server)
    {:ok, {socket, pool_state.routes}, {socket, peer}, pool_state}
  end

  def handle_checkout(:checkout, _from, {socket, peer}, pool_state) do
    {:ok, {socket, pool_state.routes}, {socket, peer}, pool_state}
  end

  @impl NimblePool
  def handle_checkin(:ok, _from, {socket, peer}, pool_state) do
    {:ok, {socket, peer}, pool_state}
  end

  defp create_socket() do
    {:ok, socket} = :chumak.socket(:req)
    Process.link(socket)
    {:ok, socket}
  end

  defp connect_socket(socket, {host, port}) do
    {:ok, peer} = :chumak.connect(socket, :tcp, host, port)
    Process.link(peer)
    {:ok, peer}
  end
end
