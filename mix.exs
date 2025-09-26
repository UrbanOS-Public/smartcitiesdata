defmodule Smartcitiesdata.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "1.0.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
      description: description(),
      releases: releases()
    ]
  end

  defp deps,
    do: [
      {:decimal, "~> 1.5 or ~> 2.0",
       [env: :prod, hex: "decimal", repo: "hexpm", optional: false, override: true]},
      {:brod, "~> 3.16.5", override: true},
      {:kafka_protocol, "4.1.0", override: true},
      {:nimble_csv, "~> 1.2.0", override: true},
      {:elixir_uuid, "~> 1.2", override: true},
      {:norm, "~> 0.8", override: true},
      
    ]

  defp aliases do
    [
      test: "cmd mix test --color",
      "test.e2e": "cmd --app e2e mix test.integration --color --include e2e",
      sobelow_andi:
        "cmd --app andi mix sobelow -i Config.HTTPS,Config.CSWH,Config.Secrets,Config.HSTS --skip --compact --exit low",
      sobelow_discovery_api:
        "cmd --app discovery_api mix sobelow -i Config.HTTPS,Config.Secrets --skip --compact --exit low"
    ]
  end

  defp description, do: "A data ingestion and processing platform for the next generation."

  defp docs() do
    [
      main: "readme",
      source_url: "https://github.com/UrbanOS-Public/smartcitiesdata.git",
      extras: [
        "README.md",
        "apps/andi/README.md",
        "apps/reaper/README.md",
        "apps/valkyrie/README.md",
        "apps/estuary/README.md",
        "apps/discovery_streams/README.md",
        "apps/forklift/README.md",
        "apps/flair/README.md"
      ]
    ]
  end

  defp releases do
    [
      forklift: [
        include_executables_for: [:unix],
        applications: [forklift: :permanent, runtime_tools: :permanent],
        steps: [:assemble, :tar]
      ],
      valkyrie: [
        include_executables_for: [:unix],
        applications: [valkyrie: :permanent, runtime_tools: :permanent],
        steps: [:assemble, :tar]
      ],
      raptor: [
        include_executables_for: [:unix],
        applications: [raptor: :permanent, runtime_tools: :permanent],
        steps: [:assemble, :tar]
      ]
    ]
  end
end