defmodule Estuary.MixProject do
  use Mix.Project

  def project do
    [
      app: :estuary,
      version: "0.7.0",
      elixir: "~> 1.8",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: test_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {Estuary.Application, []}
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.1", only: [:dev], runtime: false},
      {:dead_letter, in_umbrella: true},
      {:distillery, "~> 2.1"},
      {:divo, "~> 1.1", only: [:dev, :integration]},
      {:divo_kafka, "~> 0.1.5", only: [:dev, :integration]},
      {:elsa, "~> 0.12"},
      {:floki, "~> 0.23", only: [:dev, :test, :integration]},
      {:jason, "~> 1.1"},
      {:mox, "~> 0.5.1", only: [:dev, :test, :integration]},
      {:phoenix, "~> 1.4"},
      # temporary lock to a version that includes `inputs_for` that can wrap a `live_component` - see https://github.com/phoenixframework/phoenix_html/issues/291
      {:phoenix_html,
       github: "phoenixframework/phoenix_html",
       ref: "9034602e10be566f8c96e49f991521568c8e3d24",
       override: true},
      {:phoenix_live_reload, "~> 1.2", only: [:dev, :integration]},
      {:phoenix_live_view, "~>0.4"},
      {:phoenix_pubsub, "~> 1.1"},
      {:pipeline, in_umbrella: true},
      {:placebo, "~> 1.2", only: [:dev, :test, :integration]},
      {:plug_cowboy, "~> 2.1"},
      {:plug_heartbeat, "~> 0.2.0"},
      {:prestige, "~> 1.0"},
      {:smart_city_test, "~> 0.8", only: [:test, :integration]},
      {:sobelow, "~> 0.8", only: :dev},
      {:quantum, "~>2.3"},
      {:timex, "~> 3.6"}
    ]
  end

  defp aliases do
    [
      verify: [
        "format --check-formatted",
        "credo",
        "sobelow -i Config.HTTPS --skip --compact --exit low"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: "https://www.github.com/smartcitiesdata/smartcitiesdata",
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
