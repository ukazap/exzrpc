defmodule ExRPC do
  @moduledoc "Elixir RPC without Erlang distribution"

  @spec routes(ExRPC.Client.t()) :: list()
  defdelegate routes(client_pool), to: ExRPC.Client

  @spec call(ExRPC.Client.t(), module(), atom(), list(), timeout()) ::
          {:badrpc, atom} | {:badrpc, atom, binary} | any()
  defdelegate call(client_pool, mod, fun, args, timeout \\ :infinity), to: ExRPC.Client
end
