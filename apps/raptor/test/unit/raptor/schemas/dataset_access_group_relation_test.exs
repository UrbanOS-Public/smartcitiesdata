defmodule Raptor.Schemas.DatasetAccessGroupRelationTest do
  use RaptorWeb.ConnCase
  alias Raptor.Schemas.DatasetAccessGroupRelation

  test "convert from smrt event to Raptor dataset-access_group relation schema" do
    expected = %DatasetAccessGroupRelation{
      dataset_id: "dataset",
      access_group_id: "my_cool_group"
    }

    {:ok, actual_relation} =
      DatasetAccessGroupRelation.from_smrt_relation(%SmartCity.DatasetAccessGroupRelation{
        dataset_id: "dataset",
        access_group_id: "my_cool_group"
      })

    assert expected == actual_relation
  end
end
