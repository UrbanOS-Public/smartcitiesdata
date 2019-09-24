defmodule Pipeline.MixProject do
  use Mix.Project

  def project do
    [
      app: :pipeline,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      test_paths: Mix.env() |> test_paths(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Pipeline.Application, []}
    ]
  end

  defp deps do
    [
      {:smart_city, github: "smartcitiesdata/smart_city", branch: "new_brook", override: true},
      {:elsa, "~> 0.9.0"},
      {:retry, "~> 0.13"},
      {:placebo, "~> 1.2", only: [:dev, :test, :integration]},
      {:smart_city_test, "~> 0.5", only: [:dev, :test, :integration]},
      {:divo, "~> 1.1", only: [:dev, :integration]},
      {:divo_kafka, "~> 0.1.5", only: [:dev, :integration]}
    ]
  end

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: []
end
