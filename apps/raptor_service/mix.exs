defmodule RaptorService.MixProject do
  use Mix.Project

  def project do
    [
      app: :raptor_service,
      version: "0.1.5",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_paths: ["test/unit"]
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
      {:credo, "~> 1.3", only: [:dev]},
      {:httpoison, "~> 1.5"},
      {:jason, "~> 1.2", override: true},
      {:placebo, "~> 2.0.0-rc2", only: [:dev, :test, :integration]},
      {:properties, in_umbrella: true}
    ]
  end
end
