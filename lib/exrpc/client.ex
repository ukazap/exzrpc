defmodule ExRPC.Client do
  @moduledoc false

  @behaviour NimblePool

  alias ExRPC.Codec
  alias ExRPC.FunctionRoutes

  @opts [
    packet: :raw,
    mode: :binary,
    active: false
  ]

  @timeout 30_000

  @type t :: pid() | atom()

  def start_link(opts) do
    {host, opts} = Keyword.pop!(opts, :host)
    {port, opts} = Keyword.pop!(opts, :port)
    opts = Keyword.put(opts, :worker, {__MODULE__, %{server: {to_charlist(host), port}}})
    NimblePool.start_link(opts)
  end

  @spec routes(t()) :: list()
  def routes(client_pool) do
    NimblePool.checkout!(client_pool, :checkout, fn _from, {_socket, routes} ->
      {FunctionRoutes.to_list(routes), :ok}
    end)
  end

  @spec call(t(), module(), atom(), list()) :: {:badrpc, atom} | {:badrpc, atom, binary} | any()
  def call(client_pool, m, f, a) when is_atom(m) and is_atom(f) and is_list(a) do
    NimblePool.checkout!(client_pool, :checkout, fn _from, {socket, routes} ->
      case FunctionRoutes.route_to_id(routes, {m, f, length(a)}) do
        nil ->
          {{:badrpc, :invalid_mfa}, :ok}

        route_id ->
          message = "!" <> :erlang.term_to_binary([route_id, a])
          :ok = :gen_tcp.send(socket, message)
          {:ok, bin} = :gen_tcp.recv(socket, 0)
          {wrap_response(bin), :ok}
      end
    end)
  end

  defp wrap_response(bin) do
    case Codec.decode(bin) do
      :decode_error -> {:badrpc, :invalid_response, bin}
      {:badrpc, reason} -> {:badrpc, reason}
      {:goodrpc, result} -> result
    end
  end

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: {__MODULE__, name: Keyword.fetch!(opts, :name)},
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @impl NimblePool
  def init_pool(%{server: {host, port}} = pool_state) do
    with {:ok, socket} <- create_socket(host, port),
         {:ok, mfa_list} <- fetch_mfa_list(socket),
         :ok <- :gen_tcp.close(socket),
         {:ok, routes} <- FunctionRoutes.create(mfa_list) do
      {:ok, Map.put(pool_state, :routes, routes)}
    else
      {:error, :econnrefused} ->
        {:stop, :econnrefused}

      {:error, :no_available_mfa} ->
        {:stop, :no_available_mfa}
    end
  end

  defp create_socket(host, port) do
    with {:ok, socket} <- :gen_tcp.connect(host, port, @opts, @timeout),
         :ok <- :gen_tcp.controlling_process(socket, self()) do
      {:ok, socket}
    else
      error -> error
    end
  end

  defp fetch_mfa_list(socket) do
    with :ok <- :gen_tcp.send(socket, Codec.encode(:list_routes)),
         {:ok, bin} = :gen_tcp.recv(socket, 0),
         {:goodrpc, [_ | _] = mfa_list} <- Codec.decode(bin) do
      {:ok, mfa_list}
    else
      {:goodrpc, []} -> {:error, :no_available_mfa}
    end
  end

  @impl NimblePool
  def init_worker(%{server: {host, port}} = pool_state) do
    {:ok, socket} = create_socket(host, port)
    {:ok, socket, pool_state}
  end

  @impl NimblePool
  def handle_checkout(:checkout, _from, socket, pool_state) do
    {:ok, {socket, pool_state.routes}, socket, pool_state}
  end

  @impl NimblePool
  def handle_checkin(:ok, _from, socket, pool_state) do
    {:ok, socket, pool_state}
  end
end
