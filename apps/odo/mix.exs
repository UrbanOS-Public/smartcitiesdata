defmodule Odo.MixProject do
  use Mix.Project

  def project do
    [
      app: :odo,
      version: "1.0.0",
      elixir: "~> 1.10",
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
      {:ex_aws_s3, "~> 2.0",
       [env: :prod, git: "https://github.com/ex-aws/ex_aws_s3", ref: "6b9fdac73b62dee14bffb939965742f2576f2a7b"]},
      {:geomancer, "~> 0.1.0"},
      {:hackney, "~> 1.17"},
      {:jason, "~> 1.2"},
      {:libvault, "~> 0.2"},
      {:poison, "~> 3.1", override: true},
      {:properties, in_umbrella: true},
      {:redix, "~> 0.10"},
      {:retry, "~> 0.14.0"},
      {:smart_city, "~> 5.0.4"},
      {:streaming_metrics, "~> 2.2.0"},
      {:sweet_xml, "~> 0.6"},
      {:tasks, in_umbrella: true, only: :dev},
      {:tesla, "~> 1.3"},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:placebo, "~> 2.0.0-rc2", only: [:test, :integration]},
      {:smart_city_test, "~> 2.0.5", only: [:test, :integration]},
      {:temp, "~> 0.4", only: [:test, :integration]},
      {:telemetry_event, in_umbrella: true}
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]
end
