defmodule Andi.MixProject do
  use Mix.Project

  def project do
    [
      app: :andi,
      version: "1.0.0-static",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: Mix.env() |> test_paths(),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:brook, "~> 0.1.2"},
      {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
      # distillery breaks @ 2.1.0 due to elixir 1.9 support
      {:distillery, "2.0.14"},
      {:divo, "~> 1.1", only: [:dev, :integration]},
      {:divo_kafka, "~> 0.1.5", only: [:dev, :integration]},
      {:divo_redis, "~> 0.1.4", only: [:dev, :integration]},
      {:gettext, "~> 0.11"},
      {:husky, "~> 1.0", only: :dev, runtime: false},
      {:jason, "~> 1.1"},
      {:mix_test_watch, "~> 0.9", only: :dev, runtime: false},
      {:paddle, "~> 0.1"},
      {:phoenix, "~> 1.4"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_pubsub, "~> 1.1"},
      {:placebo, "~> 1.2", only: [:dev, :test, :integration]},
      {:plug_cowboy, "~> 2.0"},
      {:smart_city, "~> 2.7"},
      {:smart_city_registry, "~> 5.0"},
      {:smart_city_test, "~> 0.5", only: [:test, :integration]},
      {:sobelow, "~> 0.8", only: :dev},
      {:tesla, "~> 1.2", only: :integration},
      {:uuid, "~> 1.1"}
    ]
  end
end
