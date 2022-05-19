defmodule DefinitionKafka.MixProject do
  use Mix.Project

  def project do
    [
      app: :definition_kafka,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_paths: test_paths(Mix.env()),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:annotated_retry, in_umbrella: true},
      {:dlq, in_umbrella: true},
      {:elsa, "~> 0.12", override: true},
      {:jason, "~> 1.2"},
      {:ok, in_umbrella: true},
      {:protocol_destination, in_umbrella: true},
      {:protocol_source, in_umbrella: true},
      {:telemetry, "~> 0.4.1"},
      {:json_serde, "~> 1.0"},
      {:credo, "~> 1.0", only: [:dev]},
      {:divo, "~> 1.3", only: [:dev, :integration]},
      {:divo_kafka, "~> 0.1.6", only: [:integration]},
      {:mox, "~> 1.0", only: [:test]},
      {:placebo, "~> 2.0.0-rc2", only: [:dev, :test]},
      {:testing, in_umbrella: true, only: [:test, :integration]}
    ]
  end

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
