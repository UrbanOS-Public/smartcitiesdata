defmodule Andi.MixProject do
  use Mix.Project

  def project do
    [
      app: :andi,
      version: "0.59.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: Mix.env() |> test_paths(),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: "Dataset curation interface for Datastillery"
    ]
  end

  def application do
    [
      mod: {Andi.Application, []},
      extra_applications: [:logger, :runtime_tools, :phoenix_ecto]
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]

  defp deps do
    [
      {:accessible, "~> 0.2.1"},
      {:atomic_map, "~> 0.9"},
      {:auth, in_umbrella: true},
      {:brook, "~> 0.4.0"},
      {:bypass, "~> 2.0", only: [:test, :integration]},
      {:checkov, "~> 1.0", only: [:test, :integration]},
      {:cowlib, "~> 2.8", override: true},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:crontab, "~> 1.1"},
      {:distillery, "~> 2.1"},
      {:divo, "~> 1.1", only: [:dev, :integration]},
      {:divo_kafka, "~> 0.1.5", only: [:dev, :integration]},
      {:divo_postgres, "~> 0.2", only: [:dev, :integration]},
      {:divo_redis, "~> 0.1.4", only: [:dev, :integration]},
      {:ecto, "~> 3.3"},
      {:ecto_sql, "~> 3.0"},
      {:elixir_uuid, "~> 1.2"},
      {:floki, "~> 0.23", only: [:dev, :test, :integration]},
      {:gettext, "~> 0.17"},
      {:guardian, "~> 2.0"},
      {:guardian_db, "~> 2.0.3"},
      {:httpoison, "~> 1.5"},
      {:jason, "~> 1.2"},
      {:jaxon, "~> 1.0"},
      {:libvault, "~> 0.2"},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:phoenix, "~> 1.4"},
      {:phoenix_ecto, "~> 4.0"},
      {:phoenix_html, "~> 2.14.1"},
      {:phoenix_live_reload, "~> 1.2", only: [:dev, :integration]},
      {:phoenix_live_view, "~>0.14"},
      {:phoenix_pubsub, "~> 2.0"},
      {:placebo, "~> 2.0.0-rc2", only: [:dev, :test, :integration]},
      {:plug_cowboy, "~> 2.1"},
      {:postgrex, "~> 0.15.1"},
      {:prestige, "~> 1.0"},
      {:properties, in_umbrella: true},
      {:quantum, "~> 2.4"},
      {:ranch, "~> 1.7.1", override: true},
      {:simply_validate, ">= 0.2.0"},
      {:smart_city, "~> 3.0"},
      {:smart_city_test, "~> 0.10.1", only: [:test, :integration]},
      {:sobelow, "~> 0.8", only: :dev},
      {:ssl_verify_fun, "~> 1.1"},
      {:tasks, in_umbrella: true, only: :dev},
      {:telemetry_event, in_umbrella: true},
      {:tesla, "~> 1.3"},
      {:timex, "~> 3.6"},
      {:tzdata, "~> 1.0"},
      {:ueberauth_auth0, "~> 0.8.1"},
      {:x509, "~> 0.8.1", only: [:dev, :integration]},
      {:web, in_umbrella: true}
    ]
  end

  defp aliases do
    [
      verify: ["format --check-formatted", "credo", "sobelow -i Config.HTTPS --skip --compact --exit low"],
      start:
        ensure_generated_certs([
          "ecto.create --quiet",
          "ecto.migrate",
          "phx.server"
        ]),
      "test.integration":
        ensure_generated_certs([
          "test.integration"
        ])
    ]
  end

  defp ensure_generated_certs(tasks) do
    if File.exists?("priv/cert/selfsigned.pem") do
      tasks
    else
      ["x509.gen.selfsigned localhost 127.0.0.1.xip.io" | tasks]
    end
  end
end
