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
      {:jason, "~> 1.1"},
      {:kaffe, "~> 1.0"},
      {:distillery, "~> 2.0"},
      {:divo, "~> 1.1", only: [:dev, :test, :integration], organization: "smartcolumbus_os"},
      {:divo_kafka, "~> 0.1.0", only: [:dev, :test, :integration], organization: "smartcolumbus_os"},
      {:mockaffe, "~> 0.1.1", only: [:dev, :test, :integration], organization: "smartcolumbus_os"},
      {:placebo, "~> 1.2", only: [:dev, :test]},
      {:smart_city_data, "~> 2.1", organization: "smartcolumbus_os"},
      {:smart_city_registry, "~> 2.6", organization: "smartcolumbus_os"},
      {:smart_city_test, "~> 0.2.0", organization: "smartcolumbus_os", only: [:test, :integration]},
      {:yeet, "~> 0.3.0", organization: "smartcolumbus_os"}
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
