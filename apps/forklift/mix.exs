defmodule Forklift.MixProject do
  use Mix.Project

  def project do
    [
      app: :forklift,
      version: "1.0.0",
      elixir: "~> 1.14",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: test_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Forklift.Application, []}
    ]
  end

  defp deps do
    [
      {:brod, "~> 3.16", override: true},
      {:brook_stream, "~> 1.0"},
      {:checkov, "~> 1.0"},
      {:cowlib, "== 2.12.1", override: true},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dead_letter, in_umbrella: true},
      {:dialyxir, "~> 1.3", only: :dev, runtime: false},
      {:divo, "~> 2.0", only: [:dev, :test, :integration]},
      {:elsa_kafka, "~> 2.0"},
      {:elixir_uuid, "~> 1.2"},
      {:ex_doc, "~> 0.21"},
      {:hackney, "~> 1.18"},
      {:jason, "~> 1.2", override: true},
      {:libcluster, "~> 3.1"},
      {:libvault, "~> 0.2"},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:mock, "~> 0.3", only: [:dev, :test, :integration]},
      {:observer_cli, "~> 1.5"},
      {:poison, "~> 5.0", override: true},
      {:prestige, "~> 3.0.0"},
      {:properties, in_umbrella: true},
      {:quantum, "~> 2.4"},
      {:redix, "~> 1.2"},
      {:retry, "~> 0.15"},
      {:smart_city, "~> 5.4.0 "},
      {:smart_city_test, "~> 2.4.0"},
      {:timex, "~> 3.6"},
      {:distillery, "~> 2.1"},
      {:tasks, in_umbrella: true, only: :dev},
      {:telemetry_event, in_umbrella: true},
      {:pipeline, in_umbrella: true},
      {:httpoison, "~> 2.1"},
      {:mox, "~> 1.0", only: [:dev, :test, :integration]},
      {:performance, in_umbrella: true, only: :integration}
    ]
  end

  defp aliases do
    %{
      :"test.compaction" => ["test.integration --only compaction:true --no-start"],
      :"test.performance" => ["test.integration --only performance:true"],
      :verify => ["format --check-formatted", "credo"]
    }
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]
end
