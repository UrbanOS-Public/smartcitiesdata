defmodule Management.MixProject do
  use Mix.Project

  def project do
    [
      app: :management,
      version: "0.1.4",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
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
      {:brook, "~> 0.4.9"},
      {:credo, "~> 1.3", only: [:dev]}
    ]
  end
end
