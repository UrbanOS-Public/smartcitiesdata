defmodule FixtureHelper do
  @moduledoc false

  alias Reaper.Util
  alias SCOS.RegistryMessage
  alias Reaper.ReaperConfig

  def new_registry_message(overrides) do
    {:ok, registry_message} =
      RegistryMessage.new(
        Util.deep_merge(
          %{
            business: %{
              dataTitle: "Stuff",
              description: "crap",
              modifiedDate: "something",
              orgTitle: "SCOS",
              contactName: "Jalson",
              contactEmail: "something@email.com",
              license: "MIT"
            },
            technical: %{
              dataName: "name",
              cadence: 100_000,
              sourceUrl: "https://does-not-matter-url.com",
              sourceFormat: "gtfs",
              # status: "created",
              queryParams: %{},
              transformations: ["a_transform"],
              # version: "1",
              headers: %{
                Authorization: "Basic xdasdgdasgdsgd"
              },
              systemName: "scos",
              stream: "IDK",
              orgName: "Whatever"
            }
          },
          overrides
        )
      )

    registry_message
  end

  def new_reaper_config(overrides) do
    struct(
      %ReaperConfig{},
      Util.deep_merge(
        %{
          cadence: 100_000,
          sourceUrl: "https://does-not-matter-url.com",
          sourceFormat: "gtfs",
          queryParams: %{}
        },
        overrides
      )
    )
  end
end
