defmodule FixtureHelper do
  @moduledoc false

  alias Reaper.Util
  alias Reaper.ReaperConfig

  def new_reaper_config(overrides) do
    struct(
      %ReaperConfig{},
      Util.deep_merge(
        %{
          cadence: "never",
          sourceUrl: "https://does-not-matter-url.com",
          sourceType: "remote",
          sourceFormat: "gtfs",
          partitioner: %{type: nil, query: nil},
          sourceQueryParams: %{},
          allow_duplicates: true
        },
        overrides
      )
    )
  end
end
