defmodule DiscoveryApi.Mixfile do
  use Mix.Project

  def project do
    [
      app: :discovery_api,
      compilers: [:phoenix, :gettext | Mix.compilers()],
      version: "0.0.1",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: test_paths(Mix.env())
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {DiscoveryApi.Application, []},
      extra_applications: [:logger, :runtime_tools, :corsica, :prestige]
    ]
  end

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.3.3"},
      {:phoenix_pubsub, "~> 1.0"},
      {:gettext, "~> 0.11"},
      {:cowboy, "~> 1.0"},
      {:distillery, "~> 2.0"},
      {:httpoison, "~> 1.5"},
      {:poison, "~> 3.1"},
      {:corsica, "~> 1.0"},
      {:cachex, "~> 3.0"},
      {:patiently, "~> 0.2.0"},
      {:placebo, "~> 1.2.1", only: [:dev, :test]},
      {:plug_cowboy, "~> 1.0"},
      {:prometheus_plugs, "~> 1.1.1"},
      {:prometheus_phoenix, "~>1.2.0"},
      {:csv, "~> 1.4.0"},
      {:streaming_metrics, path: "streaming_metrics"},
      {:prestige, path: "prestige"},
      {:mix_test_watch, "~> 0.9.0", only: :dev, runtime: false},
      {:jason, "~> 1.1"},
      {:kaffe, "~> 1.9"},
      {:redix, "~> 0.9.2"},
      {:faker, "~> 0.12", only: [:test, :integration]}
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/unit/support", "test/utils"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]

  defp aliases do
    [
      test: ["test"],
      "test.integration": ["docker.start", "test", "scos.application.stop", "docker.stop"]
    ]
  end
end
