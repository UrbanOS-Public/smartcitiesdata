defmodule FixtureHelper do
  @moduledoc false

  alias Reaper.Util
  alias Reaper.ReaperConfig

  def new_reaper_config(overrides) do
    struct(
      %ReaperConfig{},
      Util.deep_merge(
        %{
          cadence: 100_000,
          sourceUrl: "https://does-not-matter-url.com",
          sourceFormat: "gtfs",
          partitioner: %{type: nil, query: nil},
          queryParams: %{}
        },
        overrides
      )
    )
  end
end
