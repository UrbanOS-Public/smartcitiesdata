defmodule Forklift.MixProject do
  use Mix.Project

  def project do
    [
      app: :forklift,
      version: "0.4.6",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: test_paths(Mix.env())
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :kaffe],
      mod: {Forklift.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:smart_city_data, "~> 2.1.5"},
      {:smart_city_registry, "~> 2.6"},
      {:smart_city_test, "~> 0.2.0", only: [:test, :integration]},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:jason, "~> 1.1"},
      {:kaffe, "~> 1.13"},
      {:brod, "~> 3.7", override: true},
      {:divo, "~> 1.0", only: [:dev, :test, :integration]},
      {:patiently, "~> 0.2.0", only: [:dev, :test, :integration]},
      {:prestige, "~> 0.3.0"},
      {:mix_test_watch, "~> 0.9.0", only: :dev, runtime: false},
      {:placebo, "~> 1.2.1", only: [:dev, :test, :integration]},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev], runtime: false},
      {:redix, "~> 0.9.3"},
      {:faker, "~> 0.12", only: [:dev, :test, :integration]},
      {:distillery, "~> 2.0"},
      {:yeet, "~> 1.0"},
      {:ex_doc, "~> 0.19"},
      {:observer_cli, "~> 1.4"},
      {:retry, "~> 0.11.2"},
      {:benchee, "~> 1.0", only: [:integration]}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: "https://www.github.com/smartcolumbusos/forklift",
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
