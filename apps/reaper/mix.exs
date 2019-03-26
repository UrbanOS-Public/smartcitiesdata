defmodule Reaper.MixProject do
  use Mix.Project

  def project do
    [
      app: :reaper,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: test_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        format: :test,
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
      {:csv, "~> 2.1"},
      {:distillery, "~> 2.0"},
      {:horde, "~> 0.2.3"},
      {:horde_connector, "~> 0.1", organization: "smartcolumbus_os"},
      {:httpoison, "~> 0.11.1"},
      {:jason, "~>1.1"},
      {:kaffe, "~> 1.9.1"},
      {:libcluster, "~> 3.0"},
      {:plug_cowboy, "~> 2.0"},
      {:protobuf, "~> 0.5.3"},
      {:redix, "~> 0.9.2"},
      {:sweet_xml, "~> 0.6"},
      {:smart_city_registry, "~> 2.3", organization: "smartcolumbus_os"},
      {:smart_city_data, "~> 2.0", organization: "smartcolumbus_os"},
      # Test/Dev Dependencies
      {:mix_test_watch, "~> 0.9.0", only: :dev, runtime: false},
      {:credo, "~> 0.10", only: [:dev, :test, :integration], runtime: false},
      {:divo, "~> 1.0", only: [:dev, :test, :integration], organization: "smartcolumbus_os"},
      {:mock, "~> 0.3.1", only: [:test, :integration], runtime: false},
      {:patiently, "~> 0.2.0", only: [:dev, :test, :integration]},
      {:placebo, "~> 1.2.1", only: [:test, :integration]},
      {:bypass, "~> 1.0", only: [:test, :integration]},
      {:excoveralls, "~> 0.9", only: :test},
      {:phoenix, "~> 1.4.2", only: :test}
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]
end
