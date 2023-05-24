defmodule ExZRPC.Client do
  @behaviour NimblePool

  @spec send(atom(), binary()) :: any()
  def send(pool, message) do
    NimblePool.checkout!(pool, :checkout, fn _from, socket ->
      :ok = :chumak.send(socket, message)
      reply = :chumak.recv(socket)
      {reply, :ok}
    end)
  end

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    host = Keyword.fetch!(opts, :host) |> to_charlist()
    port = Keyword.fetch!(opts, :port)

    Supervisor.child_spec(
      {NimblePool, worker: {__MODULE__, {host, port}}, name: Keyword.fetch!(opts, :name)},
      restart: :permanent
    )
  end

  @impl NimblePool
  def init_worker(pool_state) do
    Application.ensure_all_started(:chumak)
    {:ok, socket} = :chumak.socket(:req)
    Process.link(socket)
    {:ok, {socket, nil}, pool_state}
  end

  @impl NimblePool
  def handle_checkout(:checkout, _from, {socket, nil}, {host, port} = pool_state) do
    {:ok, peer} = :chumak.connect(socket, :tcp, host, port)
    Process.link(peer)
    {:ok, socket, {socket, peer}, pool_state}
  end

  def handle_checkout(:checkout, _from, {socket, peer}, pool_state) do
    {:ok, socket, {socket, peer}, pool_state}
  end

  @impl NimblePool
  def handle_checkin(:ok, _from, {socket, peer}, pool_state) do
    {:ok, {socket, peer}, pool_state}
  end
end
