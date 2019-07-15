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
      {:castore, "~> 0.1"},
      {:distillery, "2.0.14"},
      {:elsa, "~> 0.4"},
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0"},
      {:gen_stage, "~> 0.14"},
      {:horde_connector, "~> 0.1"},
      {:httpoison, "~> 1.5"},
      {:poison, "~> 3.0"},
      {:jason, "~> 1.1"},
      {:libcluster, "~> 3.0"},
      {:libvault, "~> 0.2"},
      {:mint, "~> 0.2"},
      {:nimble_csv, "~> 0.6.0"},
      {:observer_cli, "~> 1.4"},
      {:plug_cowboy, "~> 2.0"},
      {:protobuf, "~> 0.6"},
      {:redix, "~> 0.9"},
      {:retry, "~> 0.11"},
      {:sftp_ex, "~> 0.2"},
      {:smart_city_data, "~> 2.1"},
      {:smart_city_registry, "~> 4.0"},
      {:sweet_xml, "~> 0.6"},
      {:tesla, "~> 1.2"},
      {:yeet, "~> 1.0"},
      # Test/Dev Dependencies
      {:benchee, "~> 1.0", only: [:integration]},
      {:bypass, "~> 1.0", only: [:test, :integration]},
      {:checkov, "~> 0.4", only: [:test, :integration]},
      {:credo, "~> 1.0", only: [:dev, :test, :integration], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev]},
      {:divo, "~> 1.1", only: [:dev, :integration], override: true},
      {:divo_kafka, "~> 0.1", only: [:dev, :integration]},
      {:divo_redis, "~> 0.1", only: [:dev, :integration]},
      {:excoveralls, "~> 0.10", only: :test},
      {:husky, "~> 1.0", only: [:dev, :test, :integration], runtime: false},
      {:mix_test_watch, "~> 0.9", only: :dev, runtime: false},
      {:mock, "~> 0.3", only: [:test, :integration], runtime: false},
      {:patiently, "~> 0.2", only: [:dev, :test, :integration], override: true},
      {:phoenix, "~> 1.4", only: :test},
      {:placebo, "~> 1.2", only: [:test, :integration]},
      {:smart_city_test, "~> 0.3", only: [:test, :integration]},
      {:temp, "~> 0.4", only: [:test, :integration]}
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
