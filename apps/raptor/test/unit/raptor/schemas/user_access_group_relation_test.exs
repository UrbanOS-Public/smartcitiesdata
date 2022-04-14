defmodule Raptor.Schemas.UserAccessGroupRelationTest do
  use RaptorWeb.ConnCase
  alias Raptor.Schemas.UserAccessGroupRelation

  test "convert from smrt event to Raptor user-access_group relation schema" do
    expected = %UserAccessGroupRelation{user_id: "user", access_group_id: "my_cool_group"}

    {:ok, actual_relation} =
      UserAccessGroupRelation.from_smrt_relation(%SmartCity.UserAccessGroupRelation{
        subject_id: "user",
        access_group_id: "my_cool_group"
      })

    assert expected == actual_relation
  end
end
