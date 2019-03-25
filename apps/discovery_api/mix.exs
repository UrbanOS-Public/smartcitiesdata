defmodule DiscoveryApi.Mixfile do
  use Mix.Project

  def project do
    [
      app: :discovery_api,
      compilers: [:phoenix, :gettext | Mix.compilers()],
      version: "0.0.1",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: test_paths(Mix.env())
    ]
  end

  def application do
    [
      mod: {DiscoveryApi.Application, []},
      extra_applications: [:logger, :runtime_tools, :corsica, :prestige]
    ]
  end

  defp deps do
    [
      {:cachex, "~> 3.0"},
      {:corsica, "~> 1.0"},
      {:cowboy, "~> 1.0"},
      {:csv, "~> 1.4.0"},
      {:credo, "~> 0.10", only: [:dev, :test, :integration], runtime: false},
      {:checkov, "~> 0.4.0"},
      {:distillery, "~> 2.0"},
      {:divo, "~> 1.0.1", only: [:dev, :integration], organization: "smartcolumbus_os"},
      {:gettext, "~> 0.11"},
      {:httpoison, "~> 1.5"},
      {:faker, "~> 0.12.0"},
      {:jason, "~> 1.1"},
      {:mix_test_watch, "~> 0.9.0", only: :dev, runtime: false},
      {:patiently, "~> 0.2.0"},
      {:phoenix, "~> 1.3.3"},
      {:phoenix_pubsub, "~> 1.0"},
      {:placebo, "~> 1.2.1", only: [:dev, :test]},
      {:plug_cowboy, "~> 1.0"},
      {:poison, "~> 3.1"},
      {:prestige, "~> 0.2.0", organization: "smartcolumbus_os"},
      {:prometheus_plugs, "~> 1.1.1"},
      {:prometheus_phoenix, "~>1.2.0"},
      {:redix, "~> 0.9.3"},
      {:streaming_metrics, path: "streaming_metrics"},
      {:smart_city_registry, "~> 2.2.0", organization: "smartcolumbus_os"},
      {:ex_json_schema, "~> 0.5.7", only: [:test, :integration]}
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/unit/support", "test/utils"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]
end
