defmodule Valkyrie.MixProject do
  use Mix.Project

  def project do
    [
      app: :valkyrie,
      version: "1.6.1",
      elixir: "~> 1.8",
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
      mod: {Valkyrie.Application, []}
    ]
  end

  defp deps do
    [
      {:brook, "~> 0.4"},
      {:cachex, "~> 3.1"},
      {:checkov, "~> 1.0", only: [:test]},
      {:cowlib, "~> 2.8.0", override: true},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:distillery, "~> 2.1"},
      {:divo, "~> 1.1", only: [:dev, :test, :integration]},
      {:divo_kafka, "~> 0.1", only: [:integration]},
      {:divo_redis, "~> 0.1", only: [:integration]},
      {:excoveralls, "~> 0.11.1", only: :test},
      {:jason, "~> 1.2", override: true},
      {:httpoison, "~> 1.6"},
      {:libcluster, "~> 3.1"},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:observer_cli, "~> 1.4"},
      {:off_broadway_kafka, "~> 1.0.1"},
      {:placebo, "~> 2.0.0-rc2", only: [:dev, :test, :integration]},
      {:retry, "~> 0.13"},
      {:smart_city, "~> 3.0"},
      {:smart_city_test, "~> 0.8", only: [:test, :integration]},
      {:streaming_metrics, "~>2.1"},
      {:timex, "~> 3.6"},
      {:annotated_retry, in_umbrella: true},
      {:definition_kafka, in_umbrella: true},
      {:dlq, in_umbrella: true},
      {:initializer, in_umbrella: true},
      {:management, in_umbrella: true},
      {:properties, in_umbrella: true},
      {:tasks, in_umbrella: true, only: :dev},
      {:telemetry_event, in_umbrella: true},
      {:performance, in_umbrella: true, only: :integration},
      {:testing, in_umbrella: true, only: [:test, :integration]}
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
