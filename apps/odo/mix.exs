defmodule Odo.MixProject do
  use Mix.Project

  def project do
    [
      app: :odo,
      version: "0.2.0",
      elixir: "~> 1.8",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: test_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Odo.Application, []}
    ]
  end

  defp deps do
    [
      {:brook, "~> 0.4.0"},
      {:credo, "~> 1.0", only: :dev, runtime: false},
      {:distillery, "~> 2.1"},
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0"},
      {:geomancer, "~> 0.1.0"},
      {:hackney, "~> 1.15"},
      {:jason, "~> 1.1"},
      {:libvault, "~> 0.2"},
      {:plug_cowboy, "~> 2.1"},
      {:poison, "~> 3.1", override: true},
      {:prometheus_plugs, "~> 1.1"},
      {:redix, "~> 0.10"},
      {:retry, "~> 0.13.0"},
      {:smart_city, "~> 3.5"},
      {:streaming_metrics, "~> 2.2.0"},
      {:sweet_xml, "~> 0.6"},
      {:tasks, in_umbrella: true, only: :dev},
      {:tesla, "~> 1.3"},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:divo, "~> 1.1", only: [:dev, :integration], override: true},
      {:divo_redis, "~> 0.1", only: :integration},
      {:divo_kafka, "~> 0.1", only: :integration},
      {:placebo, "~> 1.2", only: [:test, :integration]},
      {:smart_city_test, "~> 0.8", only: [:test, :integration]},
      {:temp, "~> 0.4", only: [:test, :integration]}
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(_), do: ["test/unit"]
end
