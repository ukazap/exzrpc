defmodule Greeter do
  def hello(name), do: "Hello #{name}"
  def goodbye(name), do: "Goodbye #{name}"
end

defmodule Adder do
  def add(num1, num2), do: num1 + num2
end

defmodule Timer do
  def sleep(ms) do
    :timer.sleep(ms)
  end
end

defmodule ExRPCTest do
  use ExUnit.Case
  doctest ExRPC

  describe "pipeline" do
    test "should work" do
      # server-side
      function_list = [{Greeter, :hello, 1}, {Greeter, :goodbye, 1}, {Adder, :add, 2}]
      start_supervised!({ExRPC.Server, name: RPC.Server, port: 5670, routes: function_list})

      # client-side
      start_supervised!({ExRPC.Client, name: RPC.Client, host: "localhost", port: 5670})
      assert ^function_list = ExRPC.routes(RPC.Client)
      assert "Hello world" = ExRPC.call(RPC.Client, Greeter, :hello, ["world"])
      assert "Goodbye my love" = ExRPC.call(RPC.Client, Greeter, :goodbye, ["my love"])
      assert 5 = ExRPC.call(RPC.Client, Adder, :add, [2, 3])
      assert {:badrpc, :invalid_mfa} = ExRPC.call(RPC.Client, Greeter, :howdy, ["world"])
      assert {:badrpc, :invalid_mfa} = ExRPC.call(RPC.Client, Greeter, :hello, [])
    end

    test "call too long should return timeout" do
      # server-side
      function_list = [{Timer, :sleep, 1}]
      start_supervised!({ExRPC.Server, name: RPC.Server, port: 5670, routes: function_list})

      # client-side
      start_supervised!(
        {ExRPC.Client, name: RPC.Client, host: "localhost", port: 5670, send_timeout: 1}
      )

      receive_timeout_ms = 1
      {:badrpc, :timeout} = ExRPC.call(RPC.Client, Timer, :sleep, [350], receive_timeout_ms)
    end

    test "call when server down should raise conn refused" do
      # server-side
      function_list = [{Greeter, :hello, 1}]
      start_supervised!({ExRPC.Server, name: RPC.Server, port: 5670, routes: function_list})

      # client-side
      start_supervised!({ExRPC.Client, name: RPC.Client, host: "localhost", port: 5670})

      # stop server
      stop_supervised!(ExRPC.Server)

      {:badrpc, :closed} = ExRPC.call(RPC.Client, Greeter, :hello, ["world"])

      # TODO add test case when server start again
    end
  end
end
