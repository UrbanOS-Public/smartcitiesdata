defmodule DiscoveryStreams.Mixfile do
  use Mix.Project

  def project do
    [
      app: :discovery_streams,
      version: "4.0.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
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
      {:brook_stream, "~> 1.0"},
      {:bypass, "~> 2.0", only: [:test, :integration]},
      {:cachex, "~> 3.4"},
      {:checkov, "~> 1.0", only: [:test, :integration]},
      # {:cowlib, "== 2.12.1", override: true},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:definition_kafka, in_umbrella: true},
      {:divo_kafka, "~> 1.0", only: [:integration]},
      {:divo, "~> 2.0", only: [:dev, :integration]},
      {:divo_redis, "~> 1.0", only: [:integration]},
      {:elsa_kafka, "~> 2.0", override: true},
      {:ex_doc, "~> 0.19", only: [:test, :integration], runtime: false},
      {:httpoison, "~> 2.1"},
      {:initializer, in_umbrella: true},
      {:jason, "~> 1.2", override: true},
      {:kaffe, "~> 1.22"},
      {:libcluster, "~> 3.1"},
      {:management, in_umbrella: true},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:mock, "~> 0.3", only: [:dev, :test, :integration]},
      {:patiently, "~> 0.2", only: [:test, :integration], override: true},
      {:phoenix, "~> 1.4"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_html, "~> 2.14"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:properties, in_umbrella: true},
      {:placebo, "~> 2.0.0-rc2", only: [:dev, :test, :integration]},
      {:plug_cowboy, "~> 2.6"},
      {:raptor_service, in_umbrella: true},
      {:redix, "~> 1.2"},
      {:sweet_xml, "~> 0.6"},
      {:smart_city, "~> 5.4.0"},
      {:smart_city_test, "~> 2.4.0", only: [:test, :integration]},
      {:telemetry_event, in_umbrella: true},
      {:temporary_env, "~> 2.0", only: [:test, :integration]},
      {:sobelow, "~> 0.8", only: :dev, runtime: false},
      {:distillery, "~> 2.1"},
      {:poison, "~> 5.0", override: true},
      {:tasks, in_umbrella: true, only: :dev},
      {:decimal, "~> 2.0"},
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
