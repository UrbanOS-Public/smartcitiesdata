defmodule ProtocolSource.MixProject do
  use Mix.Project

  def project do
    [
      app: :protocol_source,
      version: "0.1.0",
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
      {:definition_deadletter, in_umbrella: true},
      {:definition_dictionary, in_umbrella: true},
      {:ok, in_umbrella: true},
      {:credo, "~> 1.0", only: [:dev]}
    ]
  end
end
