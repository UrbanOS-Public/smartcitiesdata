defmodule Andi.ReportsControllerTest do
  use ExUnit.Case
  use Andi.DataCase
  use Placebo
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Datasets.Business
  alias Andi.InputSchemas.Datasets.Technical
  alias Andi.InputSchemas.AccessGroup
  alias Andi.InputSchemas.Organization
  alias Andi.Schemas.User

  describe "download_report" do
    test "sets dataset users to public when dataset is not private", %{curator_conn: conn} do
      dataset1 = %Dataset{
        id: "12345",
        business: %Business{dataTitle: "Example", orgTitle: "Test", keywords: ["keyword1", "keyword2"]},
        technical: %Technical{private: false, systemName: "Test__Example"}
      }

      allow Andi.Repo.all(any()), seq: [[dataset1]]
      result = get(conn, "/report")
      assert result.status == 200

      assert result.resp_body ==
               "Dataset ID,Dataset Title,Organization,System Name,Users,Tags,Access Level\r\n12345,Example,Test,Test__Example,All (public),Public,keyword1,keyword2\r\n"
    end

    test "adds users to private dataset based on the dataset's org", %{curator_conn: conn} do
      dataset1 = %Dataset{
        id: "12345",
        business: %Business{dataTitle: "Example", orgTitle: "Test", keywords: ["keyword1", "keyword2"]},
        technical: %Technical{private: true, orgId: "1122", systemName: "Test__Example"},
        access_groups: []
      }

      dataset2 = %Dataset{
        id: "6789",
        business: %Business{dataTitle: "Example2", orgTitle: "Test2", keywords: ["keyword2", "keyword3"]},
        technical: %Technical{private: false, systemName: "Test2__Example2"}
      }

      user1 = %User{
        subject_id: UUID.uuid4(),
        email: "user1@fakemail.com",
        name: "user1"
      }

      user2 = %User{
        subject_id: UUID.uuid4(),
        email: "user2@fakemail.com",
        name: "user2"
      }

      org = %Organization{id: "1122", users: [user1, user2]}

      allow Andi.Repo.all(any()), seq: [[dataset1, dataset2], [org]]
      result = get(conn, "/report")
      assert result.status == 200

      assert result.resp_body ==
               "Dataset ID,Dataset Title,Organization,System Name,Users,Tags,Access Level\r\n12345,Example,Test,Test__Example,\"user1@fakemail.com, user2@fakemail.com,Public,keyword1, keyword2\"\r\n6789,Example2,Test2,Test2__Example2,All (public),Public,keyword2, keyword3\r\n"
    end

    test "adds users to private dataset based on the dataset's org and access groups", %{curator_conn: conn} do
      user1 = %User{
        subject_id: UUID.uuid4(),
        email: "user1@fakemail.com",
        name: "user1"
      }

      user2 = %User{
        subject_id: UUID.uuid4(),
        email: "user2@fakemail.com",
        name: "user2"
      }

      user3 = %User{
        subject_id: UUID.uuid4(),
        email: "user3@fakemail.com",
        name: "user3"
      }

      access_group1 = %AccessGroup{users: [user1]}
      access_group2 = %AccessGroup{users: [user2]}

      dataset1 = %Dataset{
        id: "12345",
        business: %Business{dataTitle: "Example", orgTitle: "Test", keywords: ["keyword1", "keyword2"]},
        technical: %Technical{private: true, orgId: "1122", systemName: "Test__Example"},
        access_groups: [access_group1, access_group2]
      }

      dataset2 = %Dataset{
        id: "6789",
        business: %Business{dataTitle: "Example2", orgTitle: "Test2"},
        technical: %Technical{private: false, systemName: "Test2__Example2"}
      }

      org = %Organization{id: "1122", users: [user3]}

      allow Andi.Repo.all(any()), seq: [[dataset1, dataset2], [org]]
      result = get(conn, "/report")
      assert result.status == 200

      assert result.resp_body ==
               "Dataset ID,Dataset Title,Organization,System Name,Users,Tags,Access Level\r\n12345,Example,Test,Test__Example,\"user1@fakemail.com, user2@fakemail.com, user3@fakemail.com,Private,keyword1, keyword2\"\r\n6789,Example2,Test2,Test2__Example2,All (public),Public,keyword1, keyword2\r\n"
    end

    test "filters duplicates", %{curator_conn: conn} do
      user1 = %User{
        subject_id: UUID.uuid4(),
        email: "user1@fakemail.com",
        name: "user1"
      }

      access_group1 = %AccessGroup{users: [user1]}
      access_group2 = %AccessGroup{users: [user1]}

      dataset1 = %Dataset{
        id: "12345",
        business: %Business{dataTitle: "Example", orgTitle: "Test", keywords: ["keyword1", "keyword2"]},
        technical: %Technical{private: true, orgId: "1122", systemName: "Test__Example"},
        access_groups: [access_group1, access_group2]
      }

      dataset2 = %Dataset{
        id: "6789",
        business: %Business{dataTitle: "Example2", orgTitle: "Test2", keywords: ["keyword2", "keyword3"]},
        technical: %Technical{private: false, systemName: "Test2__Example2"}
      }

      org = %Organization{id: "1122", users: [user1]}

      allow Andi.Repo.all(any()), seq: [[dataset1, dataset2], [org]]
      result = get(conn, "/report")
      assert result.status == 200

      assert result.resp_body ==
               "Dataset ID,Dataset Title,Organization,System Name,Users,Tags,Access Level\r\n12345,Example,Test,Test__Example,user1@fakemail.com,Private,keyword1, keyword2\r\n6789,Example2,Test2,Test2__Example2,All (public),Public,keyword1, keyword2\r\n"
    end
  end
end
