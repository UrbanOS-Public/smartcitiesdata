defmodule Testing.MixProject do
  use Mix.Project

  def project do
    [
      app: :testing,
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
      {:cowlib, "== 2.12.1", override: true},
      {:protocol_source, in_umbrella: true},
      {:protocol_destination, in_umbrella: true},
      {:protocol_decoder, in_umbrella: true},
      {:credo, "~> 1.7", only: [:dev]}
    ]
  end
end
