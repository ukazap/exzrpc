defmodule OXRPC do
  @moduledoc """
  Elixir RPC over ZeroMQ
  """

  @spec call(atom, atom, atom, list) :: {:badrpc, :nodedown | :noreply | any} | any
  def call(server, module, function, args) do
  end
end
