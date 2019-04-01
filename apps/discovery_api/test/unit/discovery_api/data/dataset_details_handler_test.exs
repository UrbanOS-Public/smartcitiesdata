defmodule DiscoveryApi.Data.DatasetDetailsHandlerTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.{Dataset, DatasetDetailsHandler}
  alias SmartCity.TestDataGenerator, as: TDG

  test "maps a SmartCity.Dataset to a API Dataset" do
    event = TDG.create_dataset(%{})

    expected = %Dataset{
      id: event.id,
      title: event.business.dataTitle,
      systemName: event.technical.systemName,
      keywords: event.business.keywords,
      organization: event.business.orgTitle,
      orgId: event.technical.orgId,
      modified: event.business.modifiedDate,
      description: event.business.description,
      fileTypes: ["CSV"],
      sourceUrl: event.technical.sourceUrl,
      sourceType: event.technical.sourceType
    }

    allow Dataset.save(any()), return: {:ok, "OK"}

    DatasetDetailsHandler.process_dataset_details_event(event)

    assert_called Dataset.save(expected)
  end
end
