defmodule Definition.MixProject do
  use Mix.Project

  def project do
    [
      app: :definition,
      version: "1.0.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_paths: test_paths(Mix.env()),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_json_schema, "~> 0.9"},
      {:jason, "~> 1.2"},
      {:mox, "~> 1.0", only: [:dev, :test, :integration]},
      {:checkov, "~> 1.0", only: [:dev, :test, :integration]},
      {:norm, "~> 0.13", only: [:dev, :test, :integration]},
      {:stream_data, "~> 0.6", only: [:dev, :test, :integration]},
      {:ok, in_umbrella: true},
      {:elixir_uuid, "~> 1.2"},
      
      {:result, "~> 1.1"}
    ]
  end

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]

  defp elixirc_paths(:test), do: ["lib", "test/unit/support"]
  defp elixirc_paths(:integration), do: ["lib", "test/integration/support"]
  defp elixirc_paths(_), do: ["lib"]
end