defmodule Reaper.MixProject do
  use Mix.Project

  def project do
    [
      app: :reaper,
      version: "3.0.0",
      elixir: "~> 1.14",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
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
      extra_applications: [:logger, :eex, :ftp],
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
      {:atomic_map, "~> 0.9"},
      {:brod, "~> 3.16", override: true},      
      {:brook_stream, "~> 1.0"},
      {:cachex, "~> 3.4"},
      {:castore, "~> 0.1"},
      {:cowlib, "== 2.12.1", override: true},
      {:ranch, "~> 1.8", override: true},
      {:dead_letter, in_umbrella: true},
      {:providers, in_umbrella: true},
      {:distillery, "~> 2.1"},
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0",
       [env: :prod, git: "https://github.com/ex-aws/ex_aws_s3", ref: "6b9fdac73b62dee14bffb939965742f2576f2a7b"]},
      {:elixir_uuid, "~> 1.2"},
      {:gen_stage, "~> 1.0", override: true},
      {:hackney, "~> 1.18"},
      {:horde, "~> 0.8"},
      {:httpoison, "~> 2.1"},
      {:poison, "~> 5.0", override: true},
      {:jason, "~> 1.1", override: true},
      {:jaxon, "~> 2.0"},
      {:libcluster, "~> 3.1"},
      {:libvault, "~> 0.2.3"},
      {:mint, "~> 1.2"},
      {:nimble_csv, "~> 1.2"},
      {:observer_cli, "~> 1.5"},
      {:properties, in_umbrella: true},
      {:plug_cowboy, "~> 2.6"},
      {:protobuf, "~> 0.12"},
      {:quantum, "~> 2.4"},
      {:redix, "~> 1.2"},
      {:retry, "~> 0.15"},
      {:sftp_ex, "~> 0.2"},
      {:saxy, "~> 1.5"},
      {:sweet_xml, "~> 0.6"},
      {:telemetry_event, in_umbrella: true},
      {:tesla, "~> 1.3"},
      {:timex, "~> 3.6"},
      # Test/Dev Dependencies
      {:tasks, in_umbrella: true, only: :dev},
      {:bypass, "~> 2.0", only: [:test, :integration]},
      {:checkov, "~> 1.0", only: [:test, :integration]},
      {:credo, "~> 1.7", only: [:dev, :test, :integration], runtime: false},
      {:dialyxir, "~> 1.3", only: :dev, runtime: false},
      {:divo, "~> 2.0", only: [:dev, :integration], override: true},
      {:divo_kafka, "~> 1.0", only: [:dev, :integration]},
      {:divo_redis, "~> 1.0", only: [:dev, :integration]},
      {:excoveralls, "~> 0.16.1", only: :test},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:mock, "~> 0.3", only: [:dev, :test, :integration], runtime: false},
      {:mox, "~> 1.0", only: [:dev, :test, :integration]},
      {:patiently, "~> 0.2", only: [:dev, :test, :integration], override: true},
      {:phoenix, "~> 1.4", only: :test},
      {:smart_city, "~> 5.4.0"},
      {:smart_city_test, "~> 2.4.0", only: [:test, :integration]},
      {:temp, "~> 0.4", only: [:test, :integration]},
      {:performance, in_umbrella: true, only: :integration},
      {:unzip, "~> 0.8"}
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]
end
