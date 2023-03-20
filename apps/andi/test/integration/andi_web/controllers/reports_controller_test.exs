defmodule Andi.ReportsControllerTest do
  use ExUnit.Case
  use Andi.DataCase
  use Placebo
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Datasets.Technical
  alias Andi.InputSchemas.AccessGroup
  alias Andi.InputSchemas.Organization
  alias Andi.Schemas.User

  describe "download_report" do
    test "sets dataset users to public when dataset is not private", %{curator_conn: conn} do
      dataset1 = %Dataset{id: "12345", technical: %Technical{private: false}}

      allow Andi.Repo.all(any()), seq: [[dataset1]]
      result = get(conn, "/report")
      assert result.status == 200
      assert result.resp_body == "Dataset ID,Users\r\n12345,All (public)\r\n"
    end

    test "adds users to private dataset based on the dataset's org", %{curator_conn: conn} do
      dataset1 = %Dataset{id: "12345", technical: %Technical{private: true, orgId: "1122"}, access_groups: []}
      dataset2 = %Dataset{id: "6789", technical: %Technical{private: false}}
      user1 = %User{
        subject_id: UUID.uuid4(),
        email: "user1@fakemail.com",
        name: "user1",
      }
      user2 = %User{
        subject_id: UUID.uuid4(),
        email: "user2@fakemail.com",
        name: "user2",
      }
      org = %Organization{id: "1122", users: [user1, user2]}

      allow Andi.Repo.all(any()), seq: [[dataset1, dataset2], [org]]
      result = get(conn, "/report")
      assert result.status == 200
      assert result.resp_body == "Dataset ID,Users\r\n12345,\"user1@fakemail.com, user2@fakemail.com\"\r\n6789,All (public)\r\n"
    end
    test "adds users to private dataset based on the dataset's org and access groups", %{curator_conn: conn} do
      user1 = %User{
        subject_id: UUID.uuid4(),
        email: "user1@fakemail.com",
        name: "user1",
      }
      user2 = %User{
        subject_id: UUID.uuid4(),
        email: "user2@fakemail.com",
        name: "user2",
      }
      user3 = %User{
        subject_id: UUID.uuid4(),
        email: "user3@fakemail.com",
        name: "user3",
      }
      access_group1 = %AccessGroup{users: [user1]}
      access_group2 = %AccessGroup{users: [user2]}
      dataset1 = %Dataset{id: "12345", technical: %Technical{private: true, orgId: "1122"}, access_groups: [access_group1, access_group2]}
      dataset2 = %Dataset{id: "6789", technical: %Technical{private: false}}
      org = %Organization{id: "1122", users: [user3]}

      allow Andi.Repo.all(any()), seq: [[dataset1, dataset2], [org]]
      result = get(conn, "/report")
      assert result.status == 200
      assert result.resp_body == "Dataset ID,Users\r\n12345,\"user3@fakemail.com, user1@fakemail.com, user2@fakemail.com\"\r\n6789,All (public)\r\n"
    end
    test "filters duplicates", %{curator_conn: conn} do
      user1 = %User{
        subject_id: UUID.uuid4(),
        email: "user1@fakemail.com",
        name: "user1",
      }
      access_group1 = %AccessGroup{users: [user1]}
      access_group2 = %AccessGroup{users: [user1]}
      dataset1 = %Dataset{id: "12345", technical: %Technical{private: true, orgId: "1122"}, access_groups: [access_group1, access_group2]}
      dataset2 = %Dataset{id: "6789", technical: %Technical{private: false}}
      org = %Organization{id: "1122", users: [user1]}

      allow Andi.Repo.all(any()), seq: [[dataset1, dataset2], [org]]
      result = get(conn, "/report")
      assert result.status == 200
      assert result.resp_body == "Dataset ID,Users\r\n12345,user1@fakemail.com\r\n6789,All (public)\r\n"
    end
  end
end
