# ExZRPC

Elixir RPC over ZeroMQ.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `exzrpc` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:exzrpc, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/exzrpc>.

## ToDo

- [x] Function allowlist/routing
- [x] Simple REQ-REP sockets (single thread) implementation
- [ ] Load-balanced implementation
- [ ] Benchmark vs gRPC vs HTTP JSON API vs `:rpc.call/4` (Erlang distribution)
- [ ] Usage documentation
- [ ] Design documentation
- [ ] Publish to Hex.pm
