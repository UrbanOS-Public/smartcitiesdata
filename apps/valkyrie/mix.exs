defmodule Valkyrie.MixProject do
  use Mix.Project

  def project do
    [
      app: :valkyrie,
      version: "0.2.3",
      elixir: "~> 1.9",
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
      {:cachex, "~> 3.1"},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:checkov, "~> 0.4.0", only: [:test]},
      {:ex_doc, "~> 0.19.3"},
      {:divo, "~> 1.1", only: [:dev, :test, :integration]},
      {:divo_kafka, "~> 0.1", only: [:integration]},
      {:divo_redis, "~> 0.1", only: [:integration]},
      {:jason, "~> 1.1"},
      {:mix_test_watch, "~> 0.9", only: :dev, runtime: false},
      {:placebo, "~> 1.2", only: [:dev, :test, :integration]},
      {:smart_city_registry, "~> 3.0"},
      {:smart_city_data, "~> 3.0"},
      {:smart_city_test, "~> 0.3", only: [:test, :integration]},
      {:yeet, "~> 1.0"},
      {:observer_cli, "~> 1.4"},
      {:benchee, "~> 1.0", only: [:integration]},
      {:husky, "~> 1.0", only: :dev, runtime: false},
      {:distillery, "~> 2.1"},
      # updating version breaks
      {:retry, "~> 0.11.2"},
      {:timex, "~> 3.6"},
      {:off_broadway_kafka, "~> 0.2.2"},
      {:excoveralls, "~> 0.11.1", only: :test}
    ]
  end

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]

  defp aliases do
    [
      lint: ["format", "credo"]
    ]
  end
end
