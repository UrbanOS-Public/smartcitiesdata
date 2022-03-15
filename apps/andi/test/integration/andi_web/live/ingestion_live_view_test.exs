defmodule AndiWeb.IngestionLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true

  import Placebo
  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1]

  import FlokiHelpers,
    only: [
      find_elements: 2,
      get_texts: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.InputSchemas.Ingestion
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Ingestions

  @instance_name Andi.instance_name()

  @url_path "/ingestions"

  describe "public user access" do
    test "public users cannot view or edit ingestions", %{public_conn: conn} do
      assert {:error,
              {
                :redirect,
                %{
                  to: "/auth/auth0?prompt=login&error_message=Unauthorized"
                }
              }} = live(conn, @url_path)
    end
  end

  describe "curator users access" do
    test "curators can view all the ingestions", %{curator_conn: conn} do
      assert {:ok, view, html} = live(conn, @url_path)
    end

    test "all ingestions are shown", %{curator_conn: conn} do
      {:ok, dataset_a} = TDG.create_dataset(business: %{dataTitle: "dataset_a"}) |> Datasets.update()
      {:ok, dataset_b} = TDG.create_dataset(business: %{dataTitle: "datset_b"}) |> Datasets.update()

      ingestion_a = TDG.create_ingestion(%{targetDataset: dataset_a.id, name: "ingestion_a"}) |> Ingestions.update()
      ingestion_b = TDG.create_ingestion(%{targetDataset: dataset_b.id, name: "ingestion_b"}) |> Ingestions.update()

      {:ok, _view, html} = live(conn, @url_path)

      dataset_rows = find_elements(html, ".ingestions-table__tr")

      assert Enum.count(dataset_rows) >= 2
    end

    test "edit button links to the ingestion edit page", %{curator_conn: conn} do
      ingestion = Ingestions.create()

      {:ok, view, _html} = live(conn, @url_path)

      edit_ingestion_button = element(view, ".btn", "Edit")

      render_click(edit_ingestion_button)
      assert_redirected(view, "/ingestions/#{ingestion.id}")
    end
  end
end
