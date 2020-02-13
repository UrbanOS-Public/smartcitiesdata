defmodule Forklift.MixProject do
  use Mix.Project

  def project do
    [
      app: :forklift,
      version: "0.11.0",
      elixir: "~> 1.8",
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
      {:benchee, "~> 1.0", only: [:integration]},
      {:brod, "~> 3.8", override: true},
      {:brook, "~> 0.4.0"},
      {:checkov, "~> 0.4"},
      {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
      {:dead_letter, in_umbrella: true},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:divo, "~> 1.1", only: [:dev, :test, :integration]},
      {:elsa, "~> 0.10.0"},
      {:ex_doc, "~> 0.21"},
      {:jason, "~> 1.1"},
      {:libcluster, "~> 3.1"},
      {:libvault, "~> 0.2"},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:observer_cli, "~> 1.5"},
      {:placebo, "~> 1.2", only: [:dev, :test, :integration]},
      {:plug_cowboy, "~> 2.1"},
      {:prestige, "~> 1.0"},
      {:prometheus_plugs, "~> 1.1"},
      {:quantum, "~>2.3"},
      {:redix, "~> 0.10"},
      {:retry, "~> 0.13"},
      {:smart_city, "~> 3.0"},
      {:smart_city_test, "~> 0.7"},
      {:streaming_metrics, "~> 2.2"},
      {:timex, "~> 3.6"},
      {:distillery, "~> 2.1"},
      {:tasks, in_umbrella: true, only: :dev},
      {:pipeline, in_umbrella: true},
      {:mox, "~> 0.5.1", only: [:dev, :test, :integration]}
    ]
  end

  defp aliases do
    [verify: ["format --check-formatted", "credo"]]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]
end
