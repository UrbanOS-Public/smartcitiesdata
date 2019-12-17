defmodule Flair.MixProject do
  use Mix.Project

  def project do
    [
      app: :flair,
      version: "0.3.1",
      elixir: "~> 1.8",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      deps: deps(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: test_paths(Mix.env())
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Flair.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # App dependencies
      {:elsa, "~> 0.10.0"},
      {:flow, "~> 0.14"},
      {:gen_stage, "~> 0.14"},
      {:jason, "~> 1.1"},
      {:prestige, "~> 0.3"},
      {:retry, "~> 0.13.0"},

      {:statistics, "~> 0.6"},
      # Additional dependencies
      {:credo, "~> 1.1", only: :dev, runtime: false},
      {:excoveralls, "~> 0.11", only: [:dev]},
      {:ex_doc, "~> 0.21"},
      {:divo, "~> 1.1", only: [:dev, :integration]},
      {:divo_kafka, "~> 0.1", only: [:dev, :integration]},
      {:placebo, "~> 1.2", only: [:dev, :test, :integration]},
      {:faker, "~> 0.12", only: [:test, :integration], override: true},
      {:mox, "~> 0.5.1", only: [:dev, :test, :integration]},
      {:smart_city_test, "~> 0.8", only: [:test, :integration]},
      {:distillery, "~> 2.1"},
      {:pipeline, in_umbrella: true},
      {:tasks, in_umbrella: true, only: :dev}
    ]
  end

  defp aliases do
    [
      verify: ["format --check-formatted", "credo"]
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]
end
