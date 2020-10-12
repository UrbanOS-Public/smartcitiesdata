defmodule Auth.MixProject do
  use Mix.Project

  def project do
    [
      app: :auth,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  def application do
    maybe_application(Mix.env())
  end

  defp deps do
    [
      {:bypass, "~> 1.0", only: [:test, :integration]},
      {:jason, "~> 1.2"},
      {:guardian, "~> 2.0"},
      {:httpoison, "~> 1.5"},
      {:memoize, "~> 1.2"},
      {:divo, "~> 1.1", only: [:dev, :test]},
      {:guardian_db, "~> 2.0.3"},
      {:ecto, "~> 3.3.4"},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, "~> 0.15.1"},
      {:placebo, "~> 2.0.0-rc2", only: [:dev, :test]},
      {:testing, in_umbrella: true, only: [:test]},
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp maybe_application(:test) do
    [
      mod: {Auth.Application, []},
      extra_applications: [:logger]
    ]
  end
  defp maybe_application(_) do
    [
      extra_applications: [:logger]
    ]
  end
end
