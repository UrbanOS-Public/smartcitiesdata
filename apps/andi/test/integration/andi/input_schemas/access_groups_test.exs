defmodule Andi.InputSchemas.AccessGroupsTest do
  use ExUnit.Case
  use Andi.DataCase

  @moduletag shared_data_connection: true

  alias Andi.InputSchemas.AccessGroup
  alias Andi.InputSchemas.AccessGroups
  alias SmartCity.TestDataGenerator, as: TDG

  import SmartCity.TestHelper, only: [eventually: 1]

  describe "get/1" do
    test "returns a saved access group by id" do
      uuid = UUID.uuid4()
      {:ok, access_group} = SmartCity.AccessGroup.new(%{name: "Smrt Access Group", id: uuid})

      access_group
      |> AccessGroup.changeset()
      |> AccessGroups.save()

      assert %{
               name: "Smrt Access Group",
               id: ^uuid,
               description: nil
             } = AccessGroups.get(access_group.id)
    end
  end

  describe "get_all/0" do
    test "gets all access groups in the system" do
      uuid1 = UUID.uuid4()
      {:ok, access_group1} = SmartCity.AccessGroup.new(%{name: "Smrt Access Group1", id: uuid1})

      uuid2 = UUID.uuid4()
      {:ok, access_group2} = SmartCity.AccessGroup.new(%{name: "Smrt Access Group2", id: uuid2})

      andi_access_groups =
        Enum.map([access_group1, access_group2], fn access_group ->
          {:ok, andi_access_group} =
            access_group
            |> AccessGroup.changeset()
            |> AccessGroups.save()

          andi_access_group
        end)

      assert Enum.at(andi_access_groups, 0) in AccessGroups.get_all()
      assert Enum.at(andi_access_groups, 1) in AccessGroups.get_all()
    end
  end

  describe "create/0" do
    test "a new access group is created with an id and a name" do
      new_org = AccessGroups.create()
      id = new_org.id
      date = Date.utc_today()
      name = "New Access Group - #{date}"

      eventually(fn ->
        assert %{id: ^id, name: ^name} = AccessGroups.get(id)
      end)
    end
  end

  describe "delete/1" do
    test "an access group can be successfully deleted" do
      new_access_group = AccessGroups.create()
      id = new_access_group.id

      eventually(fn ->
        assert %{id: ^id} = AccessGroups.get(id)
      end)

      AccessGroups.delete(id)

      eventually(fn ->
        assert nil == AccessGroups.get(id)
      end)

    end
  end
end
