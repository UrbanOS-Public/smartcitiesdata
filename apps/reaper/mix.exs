defmodule Reaper.MixProject do
  use Mix.Project

  def project do
    [
      app: :reaper,
      version: "0.15.3",
      elixir: "~> 1.8",
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
      {:brook, "~> 0.4.0"},
      {:cachex, "~> 3.2"},
      {:castore, "~> 0.1"},
      {:dead_letter, in_umbrella: true},
      {:distillery, "~> 2.1"},
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0",
       [env: :prod, git: "https://github.com/ex-aws/ex_aws_s3", ref: "6b9fdac73b62dee14bffb939965742f2576f2a7b"]},
      {:gen_stage, "~> 0.14"},
      {:horde, "~> 0.7.0"},
      {:httpoison, "~> 1.6"},
      {:poison, "~> 3.1", override: true},
      {:jason, "~> 1.1"},
      {:jaxon, "~> 1.0"},
      {:libcluster, "~> 3.1"},
      {:libvault, "~> 0.2"},
      {:mint, "~> 0.4"},
      {:nimble_csv, "~> 0.6.0"},
      {:observer_cli, "~> 1.5"},
      {:plug_cowboy, "~> 2.1"},
      {:protobuf, "~> 0.6"},
      {:quantum, "~> 2.3"},
      {:redix, "~> 0.10"},
      {:retry, "~> 0.13"},
      {:sftp_ex, "~> 0.2"},
      {:smart_city, "~> 3.0"},
      {:saxy, "~> 0.10"},
      {:sweet_xml, "~> 0.6"},
      {:tesla, "~> 1.3"},
      {:timex, "~> 3.6"},
      # Test/Dev Dependencies
      {:benchee, "~> 1.0", only: :integration},
      {:tasks, in_umbrella: true, only: :dev},
      {:bypass, "~> 1.0", only: [:test, :integration]},
      {:checkov, "~> 0.4", only: [:test, :integration]},
      {:credo, "~> 1.1", only: [:dev, :test, :integration], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:divo, "~> 1.1", only: [:dev, :integration], override: true},
      {:divo_kafka, "~> 0.1", only: [:dev, :integration]},
      {:divo_redis, "~> 0.1", only: [:dev, :integration]},
      {:excoveralls, "~> 0.11", only: :test},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:mock, "~> 0.3", only: [:test, :integration], runtime: false},
      {:patiently, "~> 0.2", only: [:dev, :test, :integration], override: true},
      {:phoenix, "~> 1.4", only: :test},
      {:placebo, "~> 1.2", only: [:test, :integration]},
      {:smart_city_test, "~> 0.8", only: [:test, :integration]},
      {:temp, "~> 0.4", only: [:test, :integration]}
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]
end
