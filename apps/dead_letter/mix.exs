defmodule Yeet.MixProject do
  use Mix.Project

  def project do
    [
      app: :yeet,
      version: "0.2.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      source_url: "https://www.github.com/SmartColumbusOS"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 0.10", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.19", only: :dev},
      {:jason, "~> 1.1"}
    ]
  end

  defp description do
    "Generates standard messages for Dead Letter Queue"
  end

  defp package do
    [
      organization: "smartcolumbus_os",
      licenses: ["AllRightsReserved"],
      links: %{"GitHub" => "https://www.github.com/SmartColumbusOS/yeet"}
    ]
  end
end
