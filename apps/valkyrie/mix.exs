defmodule Valkyrie.MixProject do
  use Mix.Project

  def project do
    [
      app: :valkyrie,
      version: "0.1.2",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_paths: test_paths(Mix.env())
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
      {:ex_doc, "~> 0.19.3"},
      {:distillery, "~> 2.0"},
      {:divo, "~> 1.1", only: [:dev, :test, :integration]},
      {:divo_kafka, "~> 0.1", only: [:integration]},
      {:divo_redis, "~> 0.1", only: [:integration]},
      {:jason, "~> 1.1"},
      {:kaffe, "~> 1.0"},
      {:mix_test_watch, "~> 0.9.0", only: :dev, runtime: false},
      {:placebo, "~> 1.2", only: [:dev, :test]},
      {:smart_city_data, "~> 2.1"},
      {:smart_city_registry, "~> 2.6"},
      {:smart_city_test, "~> 0.2.0", only: [:test, :integration]},
      {:yeet, "~> 1.0"},
      {:observer_cli, "~> 1.4"}
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
