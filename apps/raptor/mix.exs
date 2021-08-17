defmodule Raptor.MixProject do
  use Mix.Project

  def project do
    [
      app: :raptor,
      compilers: [:phoenix, :gettext | Mix.compilers()],
      version: "0.1.0",
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

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Raptor.Application, []},
      extra_applications: [:logger, :runtime_tools, :corsica, :prestige, :ecto]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:atomic_map, "~> 0.9"},
      {:assertions, "~> 0.14.1", only: [:test, :integration], runtime: false},
      {:auth, in_umbrella: true},
      {:ex_aws, "~> 2.1"},
      {:ibrowse, "~> 4.4"},
      {:libvault, "~> 0.2"},
      {:sweet_xml, "~> 0.6"},
      {:brook, "~> 0.4"},
      {:bypass, "~> 2.0", only: [:test, :integration]},
      {:cachex, "~> 3.0"},
      {:corsica, "~> 1.0"},
      {:cowboy, "~> 2.7"},
      {:cowlib, "~> 2.8", override: true},
      {:csv, "~> 2.3"},
      {:credo, "~> 1.0", only: [:dev, :test, :integration], runtime: false},
      {:checkov, "~> 1.0", only: [:test, :integration]},
      {:divo, "~> 1.1", only: [:dev, :test, :integration]},
      {:ex_json_schema, "~> 0.7", only: [:test, :integration]},
      {:ecto_sql, "~> 3.0"},
      {:elastix, "~> 0.8.0"},
      {:guardian, "~> 2.0"},
      {:guardian_db, "~> 2.0.3"},
      {:gettext, "~> 0.17"},
      {:hackney, "~> 1.17"},
      {:httpoison, "~> 1.5"},
      {:faker, "~> 0.13"},
      {:jason, "~> 1.2"},
      {:mime, "~> 1.3", override: true},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:patiently, "~> 0.2"},
      {:phoenix, "~> 1.4"},
      {:phoenix_html, "~> 2.14.1"},
      {:phoenix_pubsub, "~> 2.0"},
      {:nanoid, "~> 2.0"},
      {:placebo, "~> 2.0.0-rc2", only: [:dev, :test, :integration]},
      {:plug_heartbeat, "~> 0.2.0"},
      {:postgrex, "~> 0.15.1"},
      {:prestige, "~> 1.0"},
      {:properties, in_umbrella: true},
      {:quantum, "~>2.4"},
      {:ranch, "~> 1.7.1", override: true},
      {:redix, "~> 0.10"},
      {:streaming_metrics, "~> 2.2"},
      {:smart_city, "~> 3.0"},
      {:smart_city_test, "~> 0.10.1", only: [:test, :integration]},
      {:telemetry_event, in_umbrella: true},
      {:temporary_env, "~> 2.0", only: :test, runtime: false},
      {:timex, "~> 3.0"},
      {:sobelow, "~> 0.8", only: :dev},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:distillery, "~> 2.1"},
      {:tasks, in_umbrella: true, only: :dev},
      {:web, in_umbrella: true}
    ]
  end

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]

  defp elixirc_paths(:test), do: ["test/utils", "test/unit/support", "lib"]
  defp elixirc_paths(:integration), do: ["test/utils", "test/integration/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases() do
    [
      start: ["ecto.create --quiet", "ecto.migrate", "phx.server"]
    ]
  end
end
