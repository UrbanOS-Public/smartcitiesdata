defmodule E2E.MixProject do
  use Mix.Project

  def project do
    [
      app: :e2e,
      version: "0.1.16",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_paths: Mix.env() |> test_paths()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:alchemist, in_umbrella: true},
      {:andi, in_umbrella: true},
      {:cowlib, "== 2.9.1", override: true},
      {:raptor, in_umbrella: true},
      {:reaper, in_umbrella: true, only: [:integration]},
      {:valkyrie, in_umbrella: true},
      {:forklift, in_umbrella: true},
      {:estuary, in_umbrella: true, only: [:integration]},
      {:flair, in_umbrella: true},
      {:discovery_streams, in_umbrella: true},
      {:divo, "~> 1.3", only: [:dev, :test, :integration]},
      {:ranch, "~> 1.7.1", override: true},
      {:smart_city, "~> 5.4.0"},
      {:jason, "~> 1.2", override: true}
    ]
  end

  defp aliases do
    [
      verify: "format --check-formatted",
      "test.integration": "test.integration --include e2e"
    ]
  end

  defp test_paths(:integration), do: ["test"]
  defp test_paths(_), do: []
end
