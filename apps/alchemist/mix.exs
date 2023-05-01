defmodule Alchemist.MixProject do
  use Mix.Project

  def project do
    [
      app: :alchemist,
      version: "0.2.33",
      elixir: "~> 1.10",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_paths: test_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Alchemist.Application, []}
    ]
  end

  defp deps do
    [
      {:brook, "== 0.4.9"},
      {:cachex, "~> 3.4"},
      {:checkov, "~> 1.0", only: [:test]},
      {:cowlib, "== 2.9.1", override: true},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dead_letter, in_umbrella: true},
      {:distillery, "~> 2.1"},
      {:divo, "~> 1.3", only: [:dev, :test, :integration]},
      {:divo_kafka, "~> 0.1", only: [:integration]},
      {:divo_redis, "~> 0.1", only: [:integration]},
      {:elixir_uuid, "~> 1.2"},
      {:excoveralls, "~> 0.11.1", only: :test},
      {:tasks, in_umbrella: true, only: :dev},
      {:jason, "~> 1.2", override: true},
      {:httpoison, "~> 1.6"},
      {:libcluster, "~> 3.1"},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:observer_cli, "~> 1.4"},
      {:off_broadway_kafka, "~> 1.0.1"},
      {:placebo, "~> 2.0.0-rc2", only: [:dev, :test, :integration]},
      {:properties, in_umbrella: true},
      {:retry, "~> 0.13"},
      {:smart_city, "~> 5.4.0"},
      {:smart_city_test, "~> 2.4.0", only: [:test, :integration]},
      {:telemetry_event, in_umbrella: true},
      {:timex, "~> 3.6"},
      {:transformers, in_umbrella: true},
      {:performance, in_umbrella: true, only: :integration}
    ]
  end

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]

  defp aliases do
    [
      lint: ["format", "credo"],
      verify: ["format --check-formatted", "credo"]
    ]
  end
end
