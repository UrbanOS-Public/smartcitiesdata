defmodule DeadLetter.MixProject do
  use Mix.Project

  def project do
    [
      app: :dead_letter,
      version: "2.0.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      elixir_paths: elixirc_paths(Mix.env()),
      test_paths: Mix.env() |> test_paths(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {DeadLetter.Application, []}
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:mock, "~> 0.3", only: [:dev, :test, :integration]},
      {:ex_doc, "~> 0.21", only: :dev},
      {:jason, "~> 1.2"},
      {:elsa_kafka, "~> 2.0"},
      {:divo, "~> 2.0", only: [:dev, :integration]},
      {:divo_kafka, "~> 1.0", only: [:integration]},
      {:assertions, "~> 0.14", only: [:test, :integration]},
      {:tasks, in_umbrella: true, only: :dev},
      {:telemetry_event, in_umbrella: true}
    ]
  end

  defp aliases do
    [verify: ["format --check-formatted", "credo"]]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]
end
