defmodule DeadLetter.MixProject do
  use Mix.Project

  def project do
    [
      app: :dead_letter,
      version: "1.0.7",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      elixir_paths: elixirc_paths(Mix.env()),
      test_paths: Mix.env() |> test_paths(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev]},
      {:placebo, "~> 1.2", only: [:dev, :test, :integration]},
      {:ex_doc, "~> 0.21", only: :dev},
      {:jason, "~> 1.1"},
      {:elsa, "~> 0.9.0"},
      {:divo, "~> 1.1", only: [:dev, :integration]},
      {:divo_kafka, "~> 0.1.5", only: [:integration]},
      {:assertions, "~> 0.14", only: [:test, :integration]},
      {:tasks, in_umbrella: true, only: :dev}
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]

  defp description do
    "Generates standard messages for Dead Letter Queue"
  end

  defp package do
    [
      maintainers: ["smartcitiesdata"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://www.github.com/smartcitiesdata/smartcitiesdata/tree/master/apps/dead_letter"}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: "https://www.github.com/smartcitiesdata/smartcitiesdata/tree/master/apps/dead_letter",
      extras: [
        "README.md"
      ]
    ]
  end
end
