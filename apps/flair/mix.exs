defmodule Flair.MixProject do
  use Mix.Project

  def project do
    [
      app: :flair,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_paths: test_paths(Mix.env())
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Flair.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:flow, "~> 0.14"},
      {:gen_stage, "~> 0.14"},
      {:kafka_ex, "~> 0.9"},
      {:jason, "~> 1.1"},
      {:statistics, "~> 0.6"},
      {:scos_ex, "~> 0.4.1", organization: "smartcolumbus_os"},
      {:prestige, "~> 0.2.0", organization: "smartcolumbus_os"},
      {:distillery, "~> 2.0"},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:divo, "~> 0.2.1", only: [:dev, :test, :integration], organization: "smartcolumbus_os"},
      {:mockaffe, "~> 0.1.1",
       only: [:dev, :test, :integration], organization: "smartcolumbus_os"},
      {:placebo, "~> 1.2", only: :integration}
    ]
  end

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]

  defp aliases do
    [
      lint: ["format", "credo"],
      test: ["test --no-start"]
    ]
  end
end
