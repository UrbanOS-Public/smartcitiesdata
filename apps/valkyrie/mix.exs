defmodule Valkyrie.MixProject do
  use Mix.Project

  def project do
    [
      app: :valkyrie,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_paths: test_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Valkyrie.Application, []}
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:jason, "~> 1.1"},
      {:kaffe, "~> 1.0"},
      {:distillery, "~> 2.0"},
      {:divo, "~> 0.2.1", only: [:dev, :test, :integration], organization: "smartcolumbus_os"},
      {:mockaffe, "~> 0.1.1", only: [:dev, :test, :integration], organization: "smartcolumbus_os"},
      {:scos_ex, "~> 0.1.0", organization: "smartcolumbus_os"}
    ]
  end

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]

  defp aliases do
    [
      lint: ["format", "credo"],
      test: ["test"]
    ]
  end
end
