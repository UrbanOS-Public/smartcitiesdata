defmodule Andi.MixProject do
  use Mix.Project

  def project do
    [
      app: :andi,
      version: "0.5.0",
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
      aliases: aliases()
    ]
  end

  def application do
    [
      mod: {Andi.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]

  defp deps do
    [
      {:brook, "~> 0.4.0"},
      {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
      {:checkov, "~> 0.4.0", only: [:test]},
      {:divo, "~> 1.1", only: [:dev, :integration]},
      {:divo_kafka, "~> 0.1.5", only: [:dev, :integration]},
      {:divo_redis, "~> 0.1.4", only: [:dev, :integration]},
      {:floki, "~> 0.23", only: [:dev, :test, :integration]},
      {:gettext, "~> 0.17"},
      {:jason, "~> 1.1"},
      {:mix_test_watch, "~> 0.9", only: :dev, runtime: false},
      {:paddle, "~> 0.1"},
      {:sobelow, "~> 0.8", only: :dev},
      {:phoenix, "~> 1.4"},
      {:phoenix_live_view, "~>0.4"},
      {:phoenix_html, "~> 2.13"},
      {:phoenix_live_reload, "~> 1.2", only: [:dev, :integration]},
      {:phoenix_pubsub, "~> 1.1"},
      {:placebo, "~> 1.2", only: [:dev, :test, :integration]},
      {:plug_cowboy, "~> 2.1"},
      {:simply_validate, ">= 0.2.0"},
      {:smart_city, "~> 3.0", override: true},
      {:smart_city_registry, "~> 5.0"},
      {:smart_city_test, "~> 0.7", only: [:test, :integration]},
      {:tesla, "~> 1.3", only: :integration},
      {:timex, "~> 3.6"},
      {:uuid, "~> 1.1"},
      {:distillery, "~> 2.1"},
      {:tasks, in_umbrella: true, only: :dev}
    ]
  end

  defp aliases do
    [verify: ["format --check-formatted", "credo", "sobelow -i Config.HTTPS --skip --compact --exit low"]]
  end
end
