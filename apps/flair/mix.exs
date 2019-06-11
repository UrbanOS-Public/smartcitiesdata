defmodule Flair.MixProject do
  use Mix.Project

  def project do
    [
      app: :flair,
      version: "1.0.0-static",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      deps: deps(),
      aliases: aliases(),
      test_paths: test_paths(Mix.env())
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Flair.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.10"},
      {:ex_doc, "~> 0.19.3"},
      {:distillery, "~> 2.0"},
      {:divo, "~> 1.1", only: [:dev, :integration]},
      {:divo_kafka, "~> 0.1", only: [:dev, :integration]},
      {:divo_redis, "~> 0.1", only: [:dev, :integration]},
      {:flow, "~> 0.14"},
      {:gen_stage, "~> 0.14"},
      {:jason, "~> 1.1"},
      {:kafka_ex, "~> 0.9"},
      {:kaffe, "~> 1.14.1", only: [:test, :integration]},
      {:placebo, "~> 1.2", only: [:dev, :test, :integration]},
      {:faker, "~> 0.12.0"},
      {:prestige, "~> 0.3.2"},
      {:smart_city, "~> 2.1"},
      {:smart_city_data, "~> 2.1"},
      {:smart_city_registry, "~> 2.6"},
      {:smart_city_test, "~> 0.2.7", only: [:test, :integration]},
      {:statistics, "~> 0.6"},
      {:yeet, "~> 1.0"}
    ]
  end

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]

  defp aliases do
    [
      lint: ["format", "credo"],
      test: ["test --no-start"]
    ]
  end
end
