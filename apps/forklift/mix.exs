defmodule Forklift.MixProject do
  use Mix.Project

  def project do
    [
      app: :forklift,
      version: "1.0.0-static",
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
      extra_applications: [:logger],
      mod: {Forklift.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:benchee, "~> 1.0", only: [:integration]},
      {:brod, "~> 3.7", override: true},
      {:brook, "~> 0.3.0"},
      {:checkov, "~> 0.4"},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev], runtime: false},
      {:divo, "~> 1.0", only: [:dev, :test, :integration]},
      {:elsa, "~> 0.1"},
      {:ex_doc, "~> 0.19"},
      {:husky, "~> 1.0", only: :dev, runtime: false},
      {:jason, "~> 1.1"},
      {:libcluster, "~> 3.0"},
      {:mix_test_watch, "~> 0.9", only: :dev, runtime: false},
      {:observer_cli, "~> 1.4"},
      {:placebo, "~> 1.2", only: [:dev, :test, :integration]},
      {:plug_cowboy, "~> 2.0"},
      {:prestige, "~> 0.3.0"},
      {:prometheus_plugs, "~> 1.1"},
      {:quantum, "~>2.3"},
      {:redix, "~> 0.10"},
      {:retry, "~> 0.12"},
      {:smart_city, "~> 2.8.0"},
      {:smart_city_test, "~> 0.5.0"},
      {:streaming_metrics, "~> 2.1"},
      {:timex, "~> 3.0"},
      {:yeet, "~> 1.0"},
      # updating version breaks
      {:distillery, "2.0.14"}
      # distillery breaks @ 2.1.0 due to elixir 1.9 support
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
