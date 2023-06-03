defmodule ExZRPC.MixProject do
  use Mix.Project

  def project do
    [
      app: :exzrpc,
      description: "Elixir RPC over ZeroMQ",
      package: package(),
      version: "0.1.1",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def package do
    [
      maintainers: ["Ukaza Perdana"],
      licenses: ["MIT"],
      links: %{GitHub: "https://github.com/ukazap/exzrpc"}
    ]
  end

  defp deps do
    [
      {:chumak, "~> 1.4"},
      {:credo, "~> 1.7", only: :dev},
      {:nimble_pool, "~> 1.0"}
    ]
  end
end
