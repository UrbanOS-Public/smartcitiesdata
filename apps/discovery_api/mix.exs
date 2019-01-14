defmodule DiscoveryApi.Mixfile do
  use Mix.Project

  def project do
    [
      app: :discovery_api,
      compilers: [:phoenix, :gettext | Mix.compilers()],
      version: "0.0.1",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {DiscoveryApi.Application, []},
      extra_applications: [:logger, :runtime_tools, :corsica]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "src", "test/support"]
  defp elixirc_paths(_), do: ["lib", "src"]

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
      {:httpoison, "~> 0.11.1"},
      {:poison, "~> 3.1"},
      {:corsica, "~> 1.0"},
      {:cachex, "~> 3.0"},
      {:patiently, "~> 0.2.0"},
      {:placebo, "~> 1.2.0", only: [:dev, :test]},
      {:plug_cowboy, "~> 1.0"},
      {:prometheus_plugs, "~> 1.1.1"},
      {:prometheus_phoenix, "~>1.2.0"},
      {:csv, "~> 1.4.0"},
      {:streaming_metrics, path: "streaming_metrics"},
      {:riffed, git: "https://github.com/pinterest/riffed.git", tag: "1.0.0"},
      {:mix_test_watch, "~> 0.9.0", only: [:dev, :test]}
    ]
  end
end
