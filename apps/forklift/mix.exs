defmodule Forklift.MixProject do
  use Mix.Project

  def project do
    [
      app: :forklift,
      version: "0.4.8",
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
      {:smart_city_data, "~> 2.1"},
      {:smart_city_registry, "~> 3.3"},
      {:smart_city_test, "~> 0.2", only: [:test, :integration]},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:jason, "~> 1.1"},
      {:kaffe, "~> 1.13"},
      {:brod, "~> 3.7", override: true},
      {:divo, "~> 1.0", only: [:dev, :test, :integration]},
      {:patiently, "~> 0.2", only: [:dev, :test, :integration]},
      {:prestige, "~> 0.3.0"},
      {:mix_test_watch, "~> 0.9", only: :dev, runtime: false},
      {:placebo, "~> 1.2", only: [:dev, :test, :integration]},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev], runtime: false},
      {:redix, "~> 0.10"},
      {:faker, "~> 0.12", only: [:dev, :test, :integration]},
      {:yeet, "~> 1.0"},
      {:ex_doc, "~> 0.19"},
      {:observer_cli, "~> 1.4"},
      {:retry, "~> 0.12"},
      {:elsa, "~> 0.1"},
      {:benchee, "~> 1.0", only: [:integration]},
      {:husky, "~> 1.0", only: :dev, runtime: false},
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
