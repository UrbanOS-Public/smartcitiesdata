defmodule Andi.MixProject do
  use Mix.Project

  def project do
    [
      app: :andi,
      version: "0.1.0",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: Mix.env() |> test_paths(),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Andi.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]

  defp deps do
    [
      {:credo, "~> 0.10", only: [:dev, :test], runtime: false},
      {:distillery, "~> 2.0", runtime: false},
      {:placebo, "~> 1.2", only: [:dev, :test, :integration]},
      {:phoenix, "~> 1.4"},
      {:phoenix_pubsub, "~> 1.1"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.1"},
      {:plug_cowboy, "~> 2.0"},
      {:mix_test_watch, "~> 0.9", only: :dev, runtime: false},
      {:smart_city_registry, "~> 2.6", organization: "smartcolumbus_os"},
      {:divo, "~> 1.1", only: [:dev, :integration], organization: "smartcolumbus_os"},
      {:paddle, "~> 0.1"},
      {:tesla, "~> 1.2", only: :integration},
      {:uuid, "~> 1.1"},
      {:smart_city_test, "~> 0.2", organization: "smartcolumbus_os", only: [:test, :integration]}
    ]
  end
end
