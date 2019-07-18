defmodule Odo.MixProject do
  use Mix.Project

  def project do
    [
      app: :odo,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Odo.Application, []}
    ]
  end

  defp deps do
    [
      {:redix, "~> 0.9"},
      {:retry, "~> 0.13.0"},
      {:smart_city_registry, "~> 4.0"},
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0"},
      {:geomancer, git: "https://github.com/jdenen/geomancer.git"}
    ]
  end
end
