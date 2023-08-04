defmodule Raptor.MixProject do
  use Mix.Project

  def project do
    [
      app: :raptor,
      compilers: [:phoenix] ++ Mix.compilers(),
      version: "1.3.1",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
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
      {:atomic_map, "~> 0.9"},
      {:brook, "== 0.4.9"},
      {:cowlib, "== 2.9.1", override: true},
      {:divo, "~> 1.3", only: [:dev, :test, :integration]},
      {:phoenix, "~> 1.4"},
      {:phoenix_html, "~> 2.14.1"},
      {:phoenix_pubsub, "~> 2.0"},
      {:placebo, "~> 2.0.0-rc2", only: [:dev, :test, :integration]},
      {:plug_heartbeat, "~> 0.2.0"},
      {:properties, in_umbrella: true},
      {:redix, "~> 0.10"},
      {:smart_city, "~> 5.4.6"},
      {:smart_city_test, "~> 2.4.0", only: [:test, :integration]},
      {:tasks, in_umbrella: true, only: :dev},
      {:telemetry_event, in_umbrella: true},
      {:tesla, "~> 1.3"},
      {:ueberauth_auth0, "~> 0.8.1"},
      {:distillery, "~> 2.1"},
      {:httpoison, "~> 1.5"}
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
