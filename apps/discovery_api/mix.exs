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
      {:cachex, "~> 3.0"},
      {:corsica, "~> 1.0"},
      {:cowboy, "~> 1.0"},
      {:csv, "~> 1.4.0"},
      {:credo, "~> 0.10", only: [:dev, :test, :integration], runtime: false},
      {:distillery, "~> 2.0"},
      {:divo, "~> 0.2.1", only: [:dev, :test, :integration], organization: "smartcolumbus_os"},
      {:gettext, "~> 0.11"},
      {:httpoison, "~> 1.5"},
      {:jason, "~> 1.1"},
      {:kaffe, "~> 1.9"},
      {:faker, "~> 0.12", only: [:test, :integration]},
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
      {:redix, "~> 0.9.2"},
      {:streaming_metrics, path: "streaming_metrics"},
      {:scos_ex, "~> 0.4.2", organization: "smartcolumbus_os"}
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/unit/support", "test/utils"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]
end
