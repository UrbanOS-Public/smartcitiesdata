defmodule Raptor.Schemas.DatasetTest do
  use RaptorWeb.ConnCase
  alias Raptor.Schemas.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  test "convert from dataset event to Raptor dataset schema" do
    expected = %Dataset{
      dataset_id: "cool_data",
      system_name: "awesome__cool_data",
      org_id: "awesome",
      is_private: true
    }

    dataset =
      TDG.create_dataset(%{
        id: "cool_data",
        technical: %{systemName: "awesome__cool_data", orgId: "awesome", private: true}
      })

    {:ok, actualDataset} = Dataset.from_event(dataset)

    assert expected == actualDataset
  end
end
