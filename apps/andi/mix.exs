defmodule Andi.MixProject do
  use Mix.Project

  def project do
    [
      app: :andi,
      version: "0.1.0",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
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

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:credo, "~> 0.10", only: [:dev, :test], runtime: false},
      {:distillery, "~> 2.0", runtime: false},
      {:kaffe, "~> 1.8"},
      {:placebo, "~> 1.2.1", only: [:test, :integration]},
      {:phoenix, "~> 1.4.0"},
      {:phoenix_pubsub, "~> 1.1"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:scos_ex, "~> 1.2.0", organization: "smartcolumbus_os"},
      {:mix_test_watch, "~> 0.9.0", only: :dev, runtime: false}
    ]
  end
end
