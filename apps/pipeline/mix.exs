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
      deps: deps(),
      aliases: aliases()
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
      {:smart_city, "~> 3.0", override: true},
      {:elsa, "~> 0.10.0"},
      {:retry, "~> 0.13"},
      {:prestige, "~> 0.3"},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:placebo, "~> 1.2", only: [:dev, :test, :integration]},
      {:smart_city_test, "~> 0.8", only: [:test, :integration]},
      {:divo, "~> 1.1", only: [:dev, :integration]},
      {:divo_kafka, "~> 0.1.5", only: [:dev, :integration]}
    ]
  end

  defp aliases do
    [verify: "format --check-formatted"]
  end

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]
end
