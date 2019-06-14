defmodule Reaper.MixProject do
  use Mix.Project

  def project do
    [
      app: :reaper,
      version: "1.0.0-static",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      aliases: aliases(),
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
      extra_applications: [:logger, :eex],
      mod: {Reaper.Application, []}
    ]
  end

  defp aliases() do
    [
      test: "test --no-start"
    ]
  end

  defp deps do
    [
      {:cachex, "~> 3.1"},
      {:nimble_csv, "~> 0.6.0"},
      {:distillery, "~> 2.0"},
      {:horde, "~> 0.2.3"},
      {:horde_connector, "~> 0.1"},
      {:httpoison, "~> 1.5"},
      {:jason, "~>1.1"},
      {:kaffe, "~> 1.11"},
      {:libcluster, "~> 3.0"},
      {:libvault, "~> 0.2"},
      {:mint, "~> 0.2.1"},
      {:castore, "~> 0.1.2"},
      {:observer_cli, "~> 1.4"},
      {:plug_cowboy, "~> 2.0"},
      {:protobuf, "~> 0.6"},
      {:redix, "~> 0.9"},
      {:sftp_ex, "~> 0.2"},
      {:sweet_xml, "~> 0.6"},
      {:smart_city_data, "~> 2.1"},
      {:smart_city_registry, "~> 3.0"},
      {:tesla, "~> 1.2"},
      {:yeet, "~> 1.0"},
      # Test/Dev Dependencies
      {:bypass, "~> 1.0", only: [:test, :integration]},
      {:checkov, "~> 0.4", only: [:test, :integration]},
      {:credo, "~> 1.0", only: [:dev, :test, :integration], runtime: false},
      {:divo, "~> 1.1", only: [:dev, :integration], override: true},
      {:divo_kafka, "~> 0.1", only: [:dev, :integration]},
      {:divo_redis, "~> 0.1", only: [:dev, :integration]},
      {:excoveralls, "~> 0.10", only: :test},
      {:mix_test_watch, "~> 0.9", only: :dev, runtime: false},
      {:mock, "~> 0.3", only: [:test, :integration], runtime: false},
      {:patiently, "~> 0.2", only: [:dev, :test, :integration], override: true},
      {:phoenix, "~> 1.4", only: :test},
      {:placebo, "~> 1.2", only: [:test, :integration]},
      {:smart_city_test, "~> 0.2"}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: "https://github.com/SmartColumbusOS/reaper",
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
