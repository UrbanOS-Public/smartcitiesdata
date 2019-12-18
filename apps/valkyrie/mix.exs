defmodule Valkyrie.MixProject do
  use Mix.Project

  def project do
    [
      app: :valkyrie,
      version: "0.2.3",
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
      {:benchee, "~> 1.0", only: [:integration]},
      {:brook, "~> 0.4"},
      {:cachex, "~> 3.1"},
      {:checkov, "~> 0.4.0", only: [:test]},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:distillery, "~> 2.1"},
      {:divo, "~> 1.1", only: [:dev, :test, :integration]},
      {:divo_kafka, "~> 0.1", only: [:integration]},
      {:divo_redis, "~> 0.1", only: [:integration]},
      {:excoveralls, "~> 0.11.1", only: :test},
      {:tasks, in_umbrella: true, only: :dev},
      {:jason, "~> 1.1"},
      {:libcluster, "~> 3.1"},
      {:mix_test_watch, "~> 0.9", only: :dev, runtime: false},
      {:observer_cli, "~> 1.4"},
      {:off_broadway_kafka, "~> 0.4.0"},
      {:placebo, "~> 1.2", only: [:dev, :test, :integration]},
      {:retry, "~> 0.13"},
      {:smart_city, "~> 3.11"},
      {:smart_city_test, "~> 0.8", only: [:test, :integration]},
      {:timex, "~> 3.6"},
      {:yeet, "~> 1.0"}
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
