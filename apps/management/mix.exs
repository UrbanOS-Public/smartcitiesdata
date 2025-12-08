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
      extra_applications: [:logger, :pg]
    ]
  end

  defp deps do
    [
      {:brook_stream,
       git: "https://github.com/UrbanOS-Public/brook_stream.git",
       branch: "20251205-v1.0.0-handle-already-started"},
      {:credo, "~> 1.7", only: [:dev]}
    ]
  end
end
