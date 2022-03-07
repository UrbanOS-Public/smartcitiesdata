defmodule Transformers.MixProject do
  use Mix.Project

  def project do
    [
      app: :transformers,
      version: "0.2.3",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      test_paths: Mix.env() |> test_paths(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:checkov, "~> 1.0", only: [:test]},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:divo, "~> 1.1", only: [:dev, :test, :integration]},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:mox, "~> 1.0", only: [:dev, :test, :integration]},
      {:placebo, "~> 2.0.0-rc2", only: [:dev, :test, :integration]},
      {:smart_city, "~> 5.0.5"},
      {:smart_city_test, "~> 2.1.0", only: [:test, :integration]},
      {:timex, "~> 3.6"}
    ]
  end

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]
end
