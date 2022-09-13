defmodule Pipeline.MixProject do
  use Mix.Project

  def project do
    [
      app: :pipeline,
      version: "0.1.12",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
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
      {:smart_city, "~> 5.2.6"},
      {:elsa, "~> 0.12", override: true},
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0",
       [
         env: :prod,
         git: "https://github.com/ex-aws/ex_aws_s3",
         ref: "6b9fdac73b62dee14bffb939965742f2576f2a7b"
       ]},
      {:configparser_ex, "~> 4.0"},
      {:ex_aws_sts, "~> 2.0"},
      {:retry, "~> 0.13"},
      {:prestige, "~> 2.0.0"},
      {:timex, "~> 3.6"},
      {:sweet_xml, "~> 0.6"},
      {:temp, "~> 0.4"},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:placebo, "~> 2.0.0-rc2", only: [:dev, :test, :integration]},
      {:smart_city_test, "~> 2.2.5", only: [:test, :integration]},
      {:divo, "~> 1.3", only: [:dev, :integration]},
      {:divo_kafka, "~> 0.1.5", only: [:dev, :integration]},
      {:telemetry_event, in_umbrella: true}
    ]
  end

  defp aliases do
    [verify: "format --check-formatted"]
  end

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]
end
