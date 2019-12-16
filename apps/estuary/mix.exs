defmodule Estuary.MixProject do
  use Mix.Project

  def project do
    [
      app: :estuary,
      version: "0.1.1",
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
      test_paths: test_paths(Mix.env())
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Estuary.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.1", only: :dev, runtime: false},
      {:distillery, "~> 2.1"},
      {:divo, "~> 1.1", only: [:dev, :integration]},
      {:divo_kafka, "~> 0.1.5", only: [:dev, :integration]},
      {:elsa, "~> 0.10.0"},
      {:mock, "~> 0.3", only: [:test, :integration], runtime: false},
      {:placebo, "~> 1.2", only: [:dev, :test, :integration]},
      {:prestige, "~> 0.3"},
      {:smart_city_test, "~> 0.8", only: [:test, :integration]},
      {:yeet, "~> 1.0"}
    ]
  end

  defp aliases do
    [
      verify: ["format --check-formatted", "credo"]
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
