defmodule Schemas.DatasetTest do
  use RaptorWeb.ConnCase
  alias Raptor.Schemas.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  test "convert from dataset event to Raptor dataset schema", %{conn: conn} do
    expected = %Dataset{
      dataset_id: "cool_data",
      system_name: "awesome__cool_data",
      org_id: "awesome"
    }

    dataset =
      TDG.create_dataset(%{
        id: "cool_data",
        technical: %{systemName: "awesome__cool_data", orgId: "awesome"}
      })

    {:ok, actualDataset} = Dataset.from_event(dataset)

    assert expected == actualDataset
  end
end
