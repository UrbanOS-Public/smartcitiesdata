defmodule Reaper.MessageHandlerTest do
  use ExUnit.Case
  use Placebo

  alias Reaper.{ConfigServer, MessageHandler}
  alias SmartCity.TestDataGenerator, as: TDG

  describe "handle_dataset" do
    test "does send the registry message on if it's valid" do
      dataset = TDG.create_dataset(%{id: "cool"})

      reaper_config =
        FixtureHelper.new_reaper_config(%{
          dataset_id: dataset.id,
          dataName: dataset.technical.dataName,
          orgName: dataset.technical.orgName,
          cadence: dataset.technical.cadence,
          sourceFormat: dataset.technical.sourceFormat,
          sourceUrl: dataset.technical.sourceUrl,
          authUrl: dataset.technical.authUrl,
          sourceType: dataset.technical.sourceType,
          partitioner: dataset.technical.partitioner,
          sourceQueryParams: dataset.technical.sourceQueryParams,
          sourceHeaders: dataset.technical.sourceHeaders,
          authHeaders: dataset.technical.authHeaders,
          schema: dataset.technical.schema
        })

      expect(ConfigServer.process_reaper_config(reaper_config), return: nil)

      MessageHandler.handle_dataset(dataset)
    end
  end
end
