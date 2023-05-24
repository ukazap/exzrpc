defmodule TelefunTest do
  use ExUnit.Case
  doctest ExZRPC

  test "greets the world" do
    assert ExZRPC.hello() == :world
  end
end
