defmodule Reaper.MixProject do
  use Mix.Project

  def project do
    [
      app: :reaper,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: test_paths(Mix.env()),
      preferred_cli_env: [format: :test]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Reaper.Application, []}
    ]
  end

  defp aliases do
    [
      test: "test --no-start",
      "test.integration": ["docker.start", "test --no-start", "docker.stop"]
    ]
  end

  defp deps do
    [
      {:cachex, "~> 3.1"},
      {:checkov, "~> 0.4.0"},
      {:credo, "~> 0.10", only: [:dev, :test, :integration], runtime: false},
      {:csv, "~> 2.1"},
      {:distillery, "~> 2.0"},
      {:horde, "~> 0.2.0"},
      {:horde_connector, path: "./horde_connector"},
      {:httpoison, "~> 0.11.1"},
      {:jason, "~>1.1"},
      {:kaffe, "~> 1.9.1"},
      {:libcluster, "~> 3.0"},
      {:mock, "~> 0.3.1", only: [:test, :integration], runtime: false},
      {:patiently, "~> 0.2", only: [:test, :integration]},
      {:placebo, "~> 1.2.1", only: [:test, :integration]},
      {:plug_cowboy, "~> 2.0"},
      {:protobuf, "~> 0.5.3"},
      {:sweet_xml, "~> 0.6"},
      {:typed_struct, "~> 0.1.4"}
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]
end
