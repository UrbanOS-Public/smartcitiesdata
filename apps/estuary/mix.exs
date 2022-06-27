defmodule Estuary.MixProject do
  use Mix.Project

  def project do
    [
      app: :estuary,
      version: "0.11.14",
      elixir: "~> 1.10",
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
      {:credo, "~> 1.0", only: [:dev], runtime: false},
      {:dead_letter, in_umbrella: true},
      {:distillery, "~> 2.1"},
      {:elsa, "~> 0.12"},
      {:floki, "~> 0.23", only: [:dev, :test, :integration]},
      {:jason, "~> 1.2"},
      {:mox, "~> 1.0", only: [:dev, :test, :integration]},
      {:phoenix, "~> 1.4"},
      {:phoenix_html, "~> 2.14.1"},
      {:phoenix_live_reload, "~> 1.2", only: [:dev, :integration]},
      {:phoenix_live_view, "~>0.4"},
      {:phoenix_pubsub, "~> 2.0"},
      {:pipeline, in_umbrella: true},
      {:placebo, "~> 2.0.0-rc2", only: [:dev, :test, :integration]},
      {:plug_cowboy, "~> 2.5"},
      {:plug_heartbeat, "~> 0.2.0"},
      {:prestige, "~> 1.0"},
      {:properties, in_umbrella: true},
      {:smart_city_test, "~> 2.2.3", only: [:test, :integration]},
      {:sobelow, "~> 0.8", only: :dev},
      {:quantum, "~>2.4"},
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
      source_url: "https://www.github.com/UrbanOS-Public/smartcitiesdata",
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
