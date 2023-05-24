defmodule TelefunTest do
  use ExUnit.Case
  doctest OXRPC

  test "greets the world" do
    assert OXRPC.hello() == :world
  end
end
