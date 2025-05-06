defmodule Pipeline.MixProject do
  use Mix.Project

  def project do
    [
      app: :pipeline,
      version: "1.0.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      test_paths: Mix.env() |> test_paths(),
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Pipeline.Application, []}
    ]
  end

  defp deps do
    [
      {:elsa_kafka, "~> 2.0", override: true},
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0",
       [
         env: :prod,
         git: "https://github.com/ex-aws/ex_aws_s3",
         ref: "6b9fdac73b62dee14bffb939965742f2576f2a7b"
       ]},
      {:configparser_ex, "~> 4.0"},
      {:ex_aws_sts, "~> 2.0"},
      {:retry, "~> 0.15"},
      {:placebo, "~> 2.0.0-rc2", only: [:dev, :test, :integration]},
      {:prestige, "~> 3.0"},
      {:timex, "~> 3.6"},
      {:sweet_xml, "~> 0.6"},
      {:temp, "~> 0.4"},
      {:dialyxir, "~> 1.3", only: :dev, runtime: false},
      {:mock, "~> 0.3", only: [:dev, :test, :integration]},
      {:smart_city, "~> 5.4.0"},
      {:smart_city_test, "~> 2.4.0", only: [:test, :integration]},
      {:divo, "~> 2.0", only: [:dev, :integration]},
      {:divo_kafka, "~> 1.0", only: [:dev, :integration]},
      {:telemetry_event, in_umbrella: true}
    ]
  end

  defp aliases do
    [verify: "format --check-formatted"]
  end

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]
end
