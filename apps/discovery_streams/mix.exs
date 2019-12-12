defmodule DiscoveryStreams.Mixfile do
  use Mix.Project

  def project do
    [
      app: :discovery_streams,
      version: "2.2.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: test_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
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
      {:brook, "~> 0.4.0"},
      {:cachex, "~> 3.0"},
      {:checkov, "~> 0.4", only: :test},
      {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
      {:divo_kafka, "~> 0.1.5", only: [:integration]},
      {:divo, "~> 1.1", only: [:dev, :integration]},
      {:divo_redis, "~> 0.1", only: [:integration]},
      {:elsa, "~> 0.10.0", override: true},
      {:ex_doc, "~> 0.19", only: [:test, :integration], runtime: false},
      {:httpoison, "~> 1.6"},
      {:kaffe, "~> 1.14"},
      {:libcluster, "~> 3.1"},
      {:mix_test_watch, "~> 0.6", only: :dev, runtime: false},
      {:patiently, "~> 0.2", only: [:test, :integration], override: true},
      {:phoenix, "~> 1.4"},
      {:phoenix_pubsub, "~> 1.0"},
      {:phoenix_html, "~> 2.10"},
      {:phoenix_live_reload, "~> 1.0", only: :dev},
      {:prometheus_phoenix, "~> 1.2"},
      {:prometheus_plugs, "~> 1.1"},
      {:plug_cowboy, "~> 2.1"},
      {:placebo, "~> 1.2", only: [:dev, :test, :integration]},
      {:redix, "~> 0.10.2"},
      {:sweet_xml, "~> 0.6"},
      {:smart_city, "~> 3.0"},
      {:smart_city_test, "~> 0.8", only: [:test, :integration]},
      {:streaming_metrics, "~>2.1"},
      {:temporary_env, "~> 2.0", only: [:test, :integration]},
      {:sobelow, "~> 0.8", only: :dev, runtime: false},
      {:distillery, "~> 2.1"},
      # poison breaks @ 4.0.1 due to encode_to_iotdata missing from 4.0
      # {:poison, "~> 4.0"},
      {:poison, "~> 3.1", override: true}
    ]
  end

  defp aliases do
    [
      lint: ["format", "credo"]
    ]
  end
end
