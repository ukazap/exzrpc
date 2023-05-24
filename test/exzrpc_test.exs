defmodule Greeter do
  def hello(name), do: "Hello #{name}"
  def goodbye(name), do: "Goodbye #{name}"
end

defmodule Adder do
  def add(num1, num2), do: num1 + num2
end

defmodule ExZRPCTest do
  use ExUnit.Case
  doctest ExZRPC

  test "pipeline test" do
    # server-side
    function_list = [{Greeter, :hello, 1}, {Greeter, :goodbye, 1}, {Adder, :add, 2}]

    start_supervised!(
      {ExZRPC.Server, name: GreeterServer, host: "localhost", port: 5670, routes: function_list}
    )

    # client-side
    start_supervised!({ExZRPC.Client, name: GreeterRPC, host: "localhost", port: 5670})

    assert ^function_list = GreeterRPC |> ExZRPC.Client.routes()
    assert "Hello world" = GreeterRPC |> ExZRPC.Client.call(Greeter, :hello, ["world"])
    assert "Goodbye my love" = GreeterRPC |> ExZRPC.Client.call(Greeter, :goodbye, ["my love"])
    assert 5 = GreeterRPC |> ExZRPC.Client.call(Adder, :add, [2, 3])
    assert {:badrpc, :invalid_mfa} = GreeterRPC |> ExZRPC.Client.call(Greeter, :howdy, ["world"])
    assert {:badrpc, :invalid_mfa} = GreeterRPC |> ExZRPC.Client.call(Greeter, :hello, [])
  end
end
