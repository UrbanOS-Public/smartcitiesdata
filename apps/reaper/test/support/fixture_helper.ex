defmodule FixtureHelper do
  @moduledoc false

  alias Reaper.Util

  def new_dataset(overrides) do
    {:ok, dataset} =
      Dataset.new(
        Util.deep_merge(
          %{
            business: %{},
            operational: %{
              cadence: 100_000,
              sourceUrl: "https://does-not-matter-url.com",
              sourceFormat: "gtfs",
              status: "created",
              queryParams: %{
                apiKey: "whatever"
              },
              transformations: ["a_transform"],
              version: "1",
              headers: %{
                Authorization: "Basic xdasdgdasgdsgd"
              },
              organization: "Whatever"
            }
          },
          overrides
        )
      )

    dataset
  end
end
