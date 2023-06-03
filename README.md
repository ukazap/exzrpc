# ExRPC

Elixir RPC without Erlang distribution.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `exrpc` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:exrpc, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/exrpc>.

## ToDo

- [x] Function allowlist/routing
- [ ] Benchmark vs gRPC vs HTTP JSON API vs `:rpc.call/4` (Erlang distribution)
- [ ] Usage documentation
- [ ] Design documentation
- [ ] Publish to Hex.pm
