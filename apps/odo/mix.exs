defmodule Odo.MixProject do
  use Mix.Project

  def project do
    [
      app: :odo,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: test_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Odo.Application, []}
    ]
  end

  defp deps do
    [
      {:brook, git: "https://github.com/bbalser/brook.git", ref: "188122343ed59158ae8e6667ffecb346a2f6d5c1"},
      {:distillery, "2.0.14"},
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0"},
      {:geomancer, git: "https://github.com/jdenen/geomancer.git"},
      {:hackney, "~> 1.15"},
      {:poison, "~> 3.0"},
      {:redix, "~> 0.9"},
      {:retry, "~> 0.11.0"},
      {:smart_city, path: "../smart_city", override: true},
      {:smart_city_registry, "~> 4.0"},
      {:sweet_xml, "~> 0.6"},
      # Test/Dev Dependencies
      {:dialyxir, "~> 0.5", only: [:dev]},
      {:divo, "~> 1.1", only: [:dev, :integration], override: true},
      {:divo_redis, "~> 0.1", only: [:dev, :integration]},
      {:divo_kafka, "~> 0.1.5", only: [:dev, :integration]},
      {:smart_city_test, "~> 0.3", only: [:test, :integration]},
      {:temp, "~> 0.4", only: [:test, :integration]}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: "https://github.com/SmartColumbusOS/odo",
      extras: [
        "README.md"
      ]
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]
end
