defmodule DiscoveryStreams.Mixfile do
  use Mix.Project

  def project do
    [
      app: :discovery_streams,
      version: "3.0.14",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: test_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      mod: {DiscoveryStreams.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]

  defp deps do
    [
      {:annotated_retry, in_umbrella: true},
      {:brook, "== 0.4.9"},
      {:bypass, "~> 2.0", only: [:test, :integration]},
      {:cachex, "~> 3.4"},
      {:checkov, "~> 1.0", only: [:test, :integration]},
      {:cowlib, "== 2.9.1", override: true},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:definition_kafka, in_umbrella: true},
      {:divo_kafka, "~> 0.1.6", only: [:integration]},
      {:divo, "~> 1.3", only: [:dev, :integration]},
      {:divo_redis, "~> 0.1", only: [:integration]},
      {:elsa, "~> 0.12", override: true},
      {:ex_doc, "~> 0.19", only: [:test, :integration], runtime: false},
      {:httpoison, "~> 1.6"},
      {:initializer, in_umbrella: true},
      {:jason, "~> 1.2", override: true},
      {:kaffe, "~> 1.14"},
      {:libcluster, "~> 3.1"},
      {:management, in_umbrella: true},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:patiently, "~> 0.2", only: [:test, :integration], override: true},
      {:phoenix, "~> 1.4"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_html, "~> 2.14.1"},
      {:phoenix_live_reload, "~> 1.0", only: :dev},
      {:properties, in_umbrella: true},
      {:plug_cowboy, "~> 2.5"},
      {:placebo, "~> 2.0.0-rc2", only: [:dev, :test, :integration]},
      {:raptor_service, in_umbrella: true},
      {:redix, "~> 0.10.2"},
      {:sweet_xml, "~> 0.6"},
      {:smart_city, "~> 5.2.3"},
      {:smart_city_test, "~> 2.2.2", only: [:test, :integration]},
      {:streaming_metrics, "~>2.1"},
      {:telemetry_event, in_umbrella: true},
      {:temporary_env, "~> 2.0", only: [:test, :integration]},
      {:sobelow, "~> 0.8", only: :dev, runtime: false},
      {:distillery, "~> 2.1"},
      {:poison, "~> 3.1", override: true},
      {:tasks, in_umbrella: true, only: :dev},
      {:decimal, "~> 1.0"},
      {:tzdata, "~> 1.0"},
      {:web, in_umbrella: true},
      {:performance, in_umbrella: true, only: :integration}
    ]
  end

  defp aliases do
    [
      lint: ["format", "credo"]
    ]
  end
end
