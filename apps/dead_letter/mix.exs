defmodule DeadLetter.MixProject do
  use Mix.Project

  def project do
    [
      app: :dead_letter,
      version: "1.1.2",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
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
      {:credo, "~> 1.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:placebo, "~> 2.0.0-rc2", only: [:dev, :test, :integration]},
      {:ex_doc, "~> 0.21", only: :dev},
      {:jason, "~> 1.2"},
      {:elsa, "~> 0.12"},
      {:divo, "~> 1.3", only: [:dev, :integration]},
      {:divo_kafka, "~> 0.1.5", only: [:integration]},
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
