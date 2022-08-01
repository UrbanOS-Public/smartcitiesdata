defmodule Definition.MixProject do
  use Mix.Project

  def project do
    [
      app: :definition,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      test_paths: test_paths(Mix.env()),
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
      {:ok, in_umbrella: true},
      {:norm, "0.10.4"},
      {:jason, "~> 1.1"},
      {:elixir_uuid, "~> 1.1"},

      # Def/Test Dependencies
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false},
      # {:placebo, "~> 2.0.0-rc.2", only: [:dev, :test]},
      {:placebo, path: "../../../Placebo"}, 
      {:stream_data, "~> 0.4.0", only: [:dev, :test]},
      {:checkov, "~> 1.0", only: [:test]},
      {:credo, "~> 1.3", only: [:dev]}
    ]
  end

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]
end
