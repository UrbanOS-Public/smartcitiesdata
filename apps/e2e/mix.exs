defmodule E2E.MixProject do
  use Mix.Project

  def project do
    [
      app: :e2e,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_paths: Mix.env() |> test_paths()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:andi, in_umbrella: true},
      {:forklift, in_umbrella: true},
      {:divo, "~> 1.1", only: [:dev, :test, :integration]}
    ]
  end

  defp test_paths(:integration), do: ["test"]
  defp test_paths(_), do: []
end
