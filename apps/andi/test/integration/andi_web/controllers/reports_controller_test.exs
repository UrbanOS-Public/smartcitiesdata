defmodule Andi.ReportsControllerTest do
  use ExUnit.Case
  use Andi.DataCase
  use Placebo
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.Schemas.User

  describe "download_report" do
    test "returns csv file when called", %{curator_conn: conn} do
      dataset1 = %Dataset{id: "12345"}
      user = %User{
        subject_id: UUID.uuid4(),
        email: "user1@fakemail.com",
        name: "user1",
        datasets: [
          dataset1
        ]
      }

      allow Andi.Repo.all(any()), seq: [[dataset1], [user]]
      result = get(conn, "/report")
      assert result.status == 200
      assert result.resp_body == "Dataset ID,Users\r\n12345,user1@fakemail.com\r\n"
    end

    test "filters users to their respective dataset ids", %{curator_conn: conn} do
      dataset1 = %Dataset{id: "12345"}
      dataset2 = %Dataset{id: "6789"}
      user1 = %User{
        subject_id: UUID.uuid4(),
        email: "user1@fakemail.com",
        name: "user1",
        datasets: [
          dataset1,
          dataset2
        ]
      }
      user2 = %User{
        subject_id: UUID.uuid4(),
        email: "user2@fakemail.com",
        name: "user2",
        datasets: [
          dataset1
        ]
      }

      allow Andi.Repo.all(any()), seq: [[dataset1, dataset2], [user1, user2]]
      result = get(conn, "/report")
      assert result.status == 200
      assert result.resp_body == "Dataset ID,Users\r\n12345,\"user1@fakemail.com, user2@fakemail.com\"\r\n6789,user1@fakemail.com\r\n"
    end
  end
end
