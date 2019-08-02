defmodule Valkyrie.MixProject do
  use Mix.Project

  def project do
    [
      app: :valkyrie,
      version: "1.0.0-static",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Valkyrie.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.1"},
      {:kaffe, "~> 1.0"},
      {:distillery, "~> 2.0"}
    ]
  end
end
