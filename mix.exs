defmodule Smartcitiesdata.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    []
  end

  defp aliases do
    [
      test: "cmd mix test --color",
      "test.e2e": "cmd --app e2e mix test.integration --seed 0 --color",
      sobelow: "cmd --app andi mix sobelow -i Config.HTTPS --skip --compact --exit low"
    ]
  end
end
