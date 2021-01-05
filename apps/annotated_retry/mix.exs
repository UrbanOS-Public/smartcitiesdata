defmodule AnnotatedRetry.MixProject do
  use Mix.Project

  def project do
    [
      app: :annotated_retry,
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
      {:retry, "~> 0.14.0"},
      {:credo, "~> 1.0", only: [:dev]}
    ]
  end
end
