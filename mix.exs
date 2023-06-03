defmodule ExRPC.MixProject do
  use Mix.Project

  def project do
    [
      app: :exrpc,
      description: "Elixir RPC over ZeroMQ",
      package: package(),
      version: "0.1.1",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
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
      links: %{GitHub: "https://github.com/ukazap/exrpc"}
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:nimble_pool, "~> 1.0"},
      {:plug_crypto, "~> 1.2"},
      {:sobelow, "~> 0.12", only: [:dev, :test], runtime: false},
      {:thousand_island, "~> 0.6.7"}
    ]
  end

  defp aliases do
    [
      check: ["format --check-formatted", "credo --strict", "sobelow"]
    ]
  end
end
