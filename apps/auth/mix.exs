defmodule Auth.MixProject do
  use Mix.Project

  def project do
    [
      app: :auth,
      version: "0.1.3",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: test_paths(Mix.env()),
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
      {:cowlib, "== 2.9.1", override: true},
      {:jason, "~> 1.2"},
      {:guardian, "~> 2.0"},
      {:guardian_db, "~> 2.0.3"},
      {:httpoison, "~> 1.5"},
      {:memoize, "~> 1.2"},
      {:ecto, "== 3.9.0", override: true},
      {:ecto_sql, "== 3.6.2", override: true},
      {:plug, "~> 1.10"},
      {:postgrex, "~> 0.15.1"},
      {:ranch, "~> 1.7.1", override: true},
      {:bypass, "~> 2.0", only: [:test, :integration]},
      {:divo, "~> 1.3", only: [:dev, :integration]},
      {:divo_postgres, "~> 0.2", only: [:dev, :integration]},
      {:placebo, "~> 2.0.0-rc2", only: [:dev, :test]},
      {:testing, in_umbrella: true, only: [:test, :integration]}
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]
end
