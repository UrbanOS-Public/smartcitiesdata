defmodule DiscoveryStreams.Mixfile do
  use Mix.Project

  def project do
    [
      app: :discovery_streams,
      version: "2.0.3",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      aliases: aliases(),
      test_paths: test_paths(Mix.env())
    ]
  end

  def application do
    [
      mod: {DiscoveryStreams.Application, []},
      extra_applications: [:prometheus_plugs, :prometheus_phoenix, :logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]

  defp deps do
    [
      {:cachex, "~> 3.0"},
      {:checkov, "~> 0.4.0", only: :test},
      {:credo, "~> 0.10", only: [:dev, :test], runtime: false},
      {:distillery, "~> 2.0"},
      {:divo_kafka, "~> 0.1"},
      {:divo, "~> 1.1"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:httpoison, "~> 1.5"},
      {:kaffe, "~> 1.12.0"},
      {:libcluster, "~> 3.0"},
      {:mix_test_watch, "~> 0.6.0", only: :dev, runtime: false},
      {:patiently, "~> 0.2", only: [:test, :integration], override: true},
      {:phoenix, "~> 1.3.2"},
      {:phoenix_pubsub, "~> 1.0"},
      {:phoenix_html, "~> 2.10"},
      {:phoenix_live_reload, "~> 1.0", only: :dev},
      {:prometheus_phoenix, "~> 1.2.0"},
      {:prometheus_plugs, "~> 1.1.1"},
      {:plug_cowboy, "~> 1.0"},
      {:placebo, "~> 1.2", only: [:dev, :test, :integration]},
      {:sweet_xml, "~> 0.6"},
      {:streaming_metrics, "~>2.1"},
      {:temporary_env, "~> 2.0", only: [:test, :integration]},
      {:sobelow, "~> 0.8.0"}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: "https://github.com/smartcitiesdata/discovery-streams",
      extras: [
        "README.md"
      ]
    ]
  end

  defp package do
    [
      maintainers: ["smartcitiesdata"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/smartcitiesdata/discovery-streams"}
    ]
  end

  defp aliases do
    [
      lint: ["format", "credo"]
    ]
  end
end
