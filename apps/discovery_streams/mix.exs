defmodule CotaStreamingConsumer.Mixfile do
  use Mix.Project

  def project do
    [
      app: :cota_streaming_consumer,
      version: "0.0.1",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      mod: {CotaStreamingConsumer.Application, []},
      extra_applications: [:prometheus_plugs, :logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.3.2"},
      {:phoenix_pubsub, "~> 1.0"},
      {:phoenix_html, "~> 2.10"},
      {:phoenix_live_reload, "~> 1.0", only: :dev},
      {:prometheus_plugs, "~> 1.1.1"},
      {:cowboy, "~> 1.0"},
      {:mix_test_watch, "~> 0.6.0", only: :dev, runtime: false},
      {:streaming_metrics, path: "streaming_metrics"},
      {:mock, "~> 0.3.1", only: :test, runtime: false},
      {:kaffe, "~> 1.8"},
      {:httpoison, "~> 0.11.1"},
      {:sweet_xml, "~> 0.6"},
      {:cachex, "~> 3.0"},
      {:libcluster, "~> 3.0"},
      {:patiently, "~> 0.2.0", only: :test},
      {:credo, "~> 0.10", only: [:dev, :test], runtime: false},
      {:distillery, "~> 2.0"}
    ]
  end

  defp aliases do
    [
      lint: ["format", "credo"]
    ]
  end
end
