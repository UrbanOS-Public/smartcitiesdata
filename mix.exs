defmodule Smartcitiesdata.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
      description: description()
    ]
  end

  defp deps, do:
    [
    {:decimal, "~> 1.5 or ~> 2.0", [env: :prod, hex: "decimal", repo: "hexpm", optional: false, override: true]},
    {:brod, "~> 3.16", override: true}
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
end
