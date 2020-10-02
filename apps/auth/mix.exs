defmodule Auth.MixProject do
  use Mix.Project

  def project do
    [
      app: :auth,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:bypass, "~> 1.0", only: [:test, :integration]},
      {:jason, "~> 1.2"},
      {:guardian, "~> 2.0"},
      {:httpoison, "~> 1.5"},
      {:memoize, "~> 1.2"},
      {:placebo, "~> 2.0.0-rc2", only: [:test]},
    ]
  end
end
