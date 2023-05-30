defmodule Management.MixProject do
  use Mix.Project

  def project do
    [
      app: :management,
      version: "1.0.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
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
      {:brook_stream, "~> 1.0"},
      {:credo, "~> 1.7", only: [:dev]}
    ]
  end
end
