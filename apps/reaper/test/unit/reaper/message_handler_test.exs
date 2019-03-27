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
          cadence: dataset.technical.cadence,
          sourceUrl: dataset.technical.sourceUrl,
          sourceFormat: dataset.technical.sourceFormat,
          sourceType: dataset.technical.sourceType,
          queryParams: dataset.technical.queryParams
        })

      expect(ConfigServer.process_reaper_config(reaper_config), return: nil)

      MessageHandler.handle_dataset(dataset)
    end
  end
end
