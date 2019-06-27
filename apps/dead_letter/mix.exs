defmodule Yeet.MixProject do
  use Mix.Project

  def project do
    [
      app: :yeet,
      version: "1.0.3",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
      source_url: "https://www.github.com/smartcitiesdata/yeet"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev]},
      {:placebo, "~> 1.2", only: [:dev, :test, :integration]},
      {:ex_doc, "~> 0.19", only: :dev},
      {:jason, "~> 1.1"},
      {:brod, "~> 3.7"},
      {:husky, "~> 1.0", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Generates standard messages for Dead Letter Queue"
  end

  defp package do
    [
      maintainers: ["smartcitiesdata"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://www.github.com/smartcitiesdata/yeet"}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: "https://www.github.com/smartcitiesdata/yeet",
      extras: [
        "README.md"
      ]
    ]
  end
end
