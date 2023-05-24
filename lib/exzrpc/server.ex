defmodule ExZRPC.Server do
  use GenServer
  require Logger

  def start_link(opts) do
    init_args = %{
      name: Keyword.fetch!(opts, :name) |> to_charlist(),
      host: Keyword.fetch!(opts, :host) |> to_charlist(),
      port: Keyword.fetch!(opts, :port)
    }

    GenServer.start_link(__MODULE__, init_args, Keyword.take(opts, [:name]))
  end

  @impl GenServer
  def init(%{host: host, port: port}) do
    with {:ok, _} <- Application.ensure_all_started(:chumak),
         {:ok, socket} <- :chumak.socket(:rep),
         true <- Process.link(socket),
         {:ok, _bind_pid} <- :chumak.bind(socket, :tcp, host, port) do
      {:ok, socket, {:continue, :recv_loop}}
    end
  end

  @impl GenServer
  def handle_continue(:recv_loop, socket) do
    {:ok, data} = :chumak.recv(socket)
    Logger.info("Received #{inspect(data)}")
    :timer.sleep(10_000)
    :chumak.send(socket, "Hello #{inspect(data)}")
    {:noreply, socket, {:continue, :recv_loop}}
  end
end
