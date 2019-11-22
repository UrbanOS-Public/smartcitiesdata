defmodule DiscoveryApi.Mixfile do
  use Mix.Project

  def project do
    [
      app: :discovery_api,
      compilers: [:phoenix, :gettext | Mix.compilers()],
      version: "1.0.0-static",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_paths: test_paths(Mix.env()),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases()
    ]
  end

  def application do
    [
      mod: {DiscoveryApi.Application, []},
      extra_applications: [:logger, :runtime_tools, :corsica, :prestige, :ecto]
    ]
  end

  defp deps do
    [
      {:assertions, "~> 0.14.1", only: [:test, :integration], runtime: false},
      {:ex_aws, "~> 2.1"},
      # This commit allows us to stream files off of S3 through memory. Release pending.
      {
        :ex_aws_s3,
        "~> 2.0",
        git: "https://github.com/ex-aws/ex_aws_s3", ref: "6b9fdac73b62dee14bffb939965742f2576f2a7b"
      },
      {:ibrowse, "~> 4.4"},
      {:libvault, "~> 0.2"},
      {:sweet_xml, "~> 0.6"},
      {:paddle, "~> 0.1"},
      {:brook, "~> 0.4"},
      {:bypass, "~> 1.0", only: [:test, :integration]},
      {:cachex, "~> 3.0"},
      {:corsica, "~> 1.0"},
      {:cowboy, "~> 1.0"},
      {:csv, "~> 2.3"},
      {:credo, "~> 1.1", only: [:dev, :test, :integration], runtime: false},
      {:checkov, "~> 0.5", only: [:test, :integration]},
      {:divo, "~> 1.1"},
      {:ex_json_schema, "~> 0.7", only: [:test, :integration]},
      {:ecto_sql, "~> 3.0"},
      {:guardian, "~> 2.0"},
      {:gettext, "~> 0.17"},
      {:httpoison, "~> 1.5"},
      {:faker, "~> 0.13"},
      {:jason, "~> 1.1"},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:patiently, "~> 0.2"},
      {:phoenix, "~> 1.4"},
      {:phoenix_pubsub, "~> 1.0"},
      {:nanoid, "~> 2.0"},
      {:placebo, "~> 1.2.2", only: [:dev, :test]},
      {:plug_cowboy, "~> 1.0"},
      {:postgrex, "~> 0.15.1"},
      {:prestige, github: "smartcitiesdata/prestige", branch: "master"},
      {:prometheus_plugs, "~> 1.1"},
      {:prometheus_phoenix, "~>1.3"},
      {:quantum, "~>2.3"},
      {:redix, "~> 0.10"},
      {:streaming_metrics, "~> 2.2"},
      {:smart_city, "~> 3.0", override: true},
      {:smart_city_registry, "~> 5.0"},
      {:smart_city_test, "~> 0.7", only: [:test, :integration]},
      {:temporary_env, "~> 2.0", only: :test, runtime: false},
      {:timex, "~> 3.0"},
      {:sobelow, "~> 0.8.0", only: :dev},
      {:dialyxir, "~> 0.5.1", only: :dev, runtime: false},
      # updating version breaks
      {:distillery, "2.0.14"},
      # distillery breaks @ 2.1.0 due to elixir 1.9 support
      {:poison, "3.1.0"}
      # poison breaks @ 4.0.1 due to encode_to_iotdata missing from 4.0
    ]
  end

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]

  defp elixirc_paths(:test), do: ["test/utils", "test/unit/support", "lib"]
  defp elixirc_paths(:integration), do: ["test/utils", "test/integration/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases() do
    [
      start: ["ecto.create --quiet", "ecto.migrate", "phx.server"]
    ]
  end
end
