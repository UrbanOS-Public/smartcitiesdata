defmodule Raptor.MixProject do
  use Mix.Project

  def project do
    [
      app: :raptor,
      compilers: [:phoenix] ++ Mix.compilers(),
      version: "2.0.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_paths: test_paths(Mix.env()),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases()
    ]
  end

  def application do
    [
      mod: {Raptor.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp deps do
    [
      {:brod, "~> 3.16", override: true},
      {:atomic_map, "~> 0.9"},
      {:brook_stream, "~> 1.0"},
      # {:cowlib, "== 2.12.1", override: true},
      {:divo, "~> 2.0", only: [:dev, :test, :integration]},
      {:phoenix, "~> 1.4"},
      {:phoenix_html, "~> 2.14"},
      {:phoenix_pubsub, "~> 2.0"},
      {:mock, "~> 0.3", only: [:dev, :test, :integration]},
      {:placebo, "~> 2.0.0-rc2", only: [:dev, :test, :integration]},
      {:plug_heartbeat, "~> 1.0"},
      {:properties, in_umbrella: true},
      {:redix, "~> 1.2"},
      {:smart_city, "~>  5.4.0"},
      {:smart_city_test, "~> 2.4.0", only: [:test, :integration]},
      {:tasks, in_umbrella: true, only: :dev},
      {:telemetry_event, in_umbrella: true},
      {:tesla, "~> 1.3"},
      {:ueberauth_auth0, "~> 2.1"},
      {:distillery, "~> 2.1"},
      {:httpoison, "~> 2.1"}
    ]
  end

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]

  defp elixirc_paths(:test), do: ["test/utils", "test/unit/support", "lib"]
  defp elixirc_paths(:integration), do: ["test/utils", "test/integration/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases() do
    [
      start: ["phx.server"]
    ]
  end
end
