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
      {:brook, "~> 0.1.2"},
      {:credo, "~> 1.1.4"},
      {:distillery, "2.0.14"},
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0"},
      {:geomancer, "~> 0.1.0"},
      {:hackney, "~> 1.15"},
      {:jason, "~> 1.1"},
      {:libvault, "~> 0.2"},
      {:plug_cowboy, "~> 2.0"},
      {:poison, "~> 3.0"},
      {:prometheus_plugs, "~> 1.1"},
      {:redix, "~> 0.9"},
      {:retry, "~> 0.13.0"},
      {:smart_city, "~> 2.7", override: true},
      {:smart_city_registry, "~> 5.0"},
      {:streaming_metrics, "~> 2.2.0"},
      {:sweet_xml, "~> 0.6"},
      {:tesla, "~> 1.2"},
      # Test/Dev Dependencies
      {:dialyxir, "~> 0.5", only: [:dev]},
      {:divo, "~> 1.1", only: [:dev, :integration], override: true},
      {:divo_redis, "~> 0.1", only: :integration},
      {:divo_kafka, "~> 0.1", only: :integration},
      {:placebo, "~> 1.2", only: [:test]},
      {:smart_city_test, "~> 0.5", only: [:test, :integration]},
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
