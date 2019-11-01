defmodule AndiWeb.DatasetPageControllerTest do
  use AndiWeb.ConnCase

  import Andi, only: [instance_name: 0]
  import SmartCity.Event, only: [dataset_update: 0]

  alias SmartCity.TestDataGenerator, as: TDG

  setup do
    Brook.Test.clear_view_state(instance_name(), :dataset)

    :ok
  end

  describe "index" do
    test "displays list of all datasets", %{conn: conn} do
      dataset1 = TDG.create_dataset(%{})
      dataset2 = TDG.create_dataset(%{})

      Brook.Event.send(instance_name(), dataset_update(), :andi, dataset1)
      Brook.Event.send(instance_name(), dataset_update(), :andi, dataset2)

      response = get(conn, "/datasets")

      assert html_body = html_response(response, 200)

      assert html_body =~ dataset1.business.orgTitle
      assert html_body =~ dataset1.business.dataTitle
      assert html_body =~ dataset2.business.orgTitle
      assert html_body =~ dataset2.business.dataTitle
    end

    test "displays appropriate message when no datasets are returned", %{conn: conn} do
      response = get(conn, "/datasets")

      assert html_body = html_response(response, 200)

      assert html_body =~ "No Datasets Found"
    end
  end
end
