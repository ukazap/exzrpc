defmodule ExRPC.Client do
  @moduledoc false

  @behaviour NimblePool

  require Logger

  alias ExRPC.Codec
  alias ExRPC.FunctionRoutes

  @opts [
    packet: :raw,
    mode: :binary,
    active: false
  ]

  @connect_timeout 10_000

  @type t :: pid() | atom()

  def start_link(opts) do
    {host, opts} = Keyword.pop!(opts, :host)
    {port, opts} = Keyword.pop!(opts, :port)
    {send_timeout, opts} = Keyword.pop(opts, :send_timeout, 10_000)

    opts =
      Keyword.put(opts, :worker, {__MODULE__, %{server: {to_charlist(host), port, send_timeout}}})

    NimblePool.start_link(opts)
  end

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: {__MODULE__, name: Keyword.fetch!(opts, :name)},
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  @spec routes(t()) :: list()
  def routes(client_pool) do
    NimblePool.checkout!(client_pool, :checkout, fn _from, {_socket, routes} ->
      {FunctionRoutes.to_list(routes), :ok}
    end)
  end

  @spec call(t(), module(), atom(), list(), integer() | atom()) ::
          {:badrpc, atom} | {:badrpc, atom, binary} | any()
  def call(client_pool, m, f, a, timeout \\ :infinity)
      when is_atom(m) and is_atom(f) and is_list(a) do
    NimblePool.checkout!(client_pool, :checkout, fn _from, {socket, routes} ->
      with socket when is_port(socket) <- socket,
           route_id when is_integer(route_id) <-
             FunctionRoutes.route_to_id(routes, {m, f, length(a)}),
           message <- "!" <> :erlang.term_to_binary([route_id, a]),
           :ok <- :gen_tcp.send(socket, message),
           {:ok, bin} <- :gen_tcp.recv(socket, 0, timeout) do
        {wrap_response(bin), :ok}
      else
        nil -> {{:badrpc, :invalid_mfa}, :ok}
        {:error, :closed} = error -> {{:badrpc, :disconnected}, error}
        {:error, :econnrefused} = error -> {{:badrpc, :disconnected}, error}
        {:error, :econnreset} = error -> {{:badrpc, :disconnected}, error}
        {:error, error} -> {{:badrpc, error}, :ok}
        {:badrpc, error} -> {{:badrpc, error}, :ok}
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

  @impl NimblePool
  def init_pool(%{server: {host, port, send_timeout}} = pool_state) do
    with {:ok, socket} <- create_socket(host, port, send_timeout),
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

  defp create_socket(host, port, send_timeout) do
    opts = Keyword.put(@opts, :send_timeout, send_timeout)

    with {:ok, socket} <- :gen_tcp.connect(host, port, opts, @connect_timeout),
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
  def init_worker(%{server: {host, port, send_timeout}} = pool_state) do
    parent = self()

    async_fn = fn ->
      with {:ok, socket} <- :gen_tcp.connect(host, port, @opts, @connect_timeout),
           :ok <- :gen_tcp.controlling_process(socket, parent) do
        socket
      end
    end

    {:async, async_fn, pool_state}
  end

  @impl NimblePool
  def handle_checkout(:checkout, _from, socket, pool_state) do
    {:ok, {socket, pool_state.routes}, socket, pool_state}
  end

  @impl NimblePool
  def handle_checkin(:ok, _from, socket, pool_state) do
    {:ok, socket, pool_state}
  end

  def handle_checkin({:error, reason}, _from, socket, pool_state) do
    Logger.error("removing from pool #{inspect(socket)}, #{inspect(reason)}")
    {:remove, reason, pool_state}
  end
end
