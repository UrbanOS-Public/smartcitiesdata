defmodule AndiWeb.DatasetPageControllerTest do
  use AndiWeb.ConnCase

  import Andi, only: [instance_name: 0]
  import SmartCity.Event, only: [dataset_update: 0]
  import SmartCity.TestHelper, only: [eventually: 3]

  alias SmartCity.TestDataGenerator, as: TDG

  setup do
    Brook.Test.with_event(:andi, "__-nuke-__", fn ->
      instance_name()
      |> Brook.get_all!(:dataset)
      |> Enum.map(fn {key, _value} ->
        Brook.ViewState.delete(:dataset, key)
      end)
    end)

    :ok
  end

  describe "index" do
    test "displays list of all datasets", %{conn: conn} do
      dataset1 = TDG.create_dataset(%{})
      dataset2 = TDG.create_dataset(%{})

      Brook.Event.send(instance_name(), dataset_update(), :andi, dataset1)
      Brook.Event.send(instance_name(), dataset_update(), :andi, dataset2)

      eventually(
        fn ->
          response = get(conn, "/datasets")

          assert html_body = html_response(response, 200)

          assert html_body =~ dataset1.business.orgTitle
          assert html_body =~ dataset1.business.dataTitle
          assert html_body =~ dataset2.business.orgTitle
          assert html_body =~ dataset2.business.dataTitle
        end,
        200,
        10
      )
    end

    test "displays appropriate message when no datasets are returned", %{conn: conn} do
      response = get(conn, "/datasets")

      assert html_body = html_response(response, 200)

      assert html_body =~ "No Datasets Found"
    end
  end
end
