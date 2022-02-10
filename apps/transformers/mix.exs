defmodule Transformers.MixProject do
  use Mix.Project

  def project do
    [
      app: :transformers,
      version: "0.1.0",
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
      {:mox, "~> 1.0", only: [:dev, :test, :integration]},
      {:smart_city, "~> 5.0.3"},
      {:smart_city_test, "~> 2.0.4", only: [:test, :integration]},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:timex, "~> 3.6"}
    ]
  end

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]
end
