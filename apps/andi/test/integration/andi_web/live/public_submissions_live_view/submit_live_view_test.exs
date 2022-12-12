defmodule AndiWeb.SubmitLiveViewTest do
  use ExUnit.Case
  use AndiWeb.Test.PublicAccessCase
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest

  import FlokiHelpers,
    only: [
      get_attributes: 3
    ]

  import SmartCity.TestHelper, only: [eventually: 1]

  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Dataset

  @endpoint AndiWeb.Endpoint
  @url_path "/submissions/"

  setup %{public_subject: public_subject} do
    {:ok, public_user} = Andi.Schemas.User.create_or_update(public_subject, %{email: "bob@example.com", name: "bob"})
    blank_dataset = %Dataset{id: UUID.uuid4(), technical: %{}, business: %{}}
    [blank_dataset: blank_dataset, public_user: public_user]
  end

  describe "public user submits a new dataset" do
    test "user is presented with a disabled submit button", %{public_conn: conn, public_user: public_user} do
      dataset = Datasets.create(public_user)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert ["disabled"] = get_attributes(html, "#submit-button", "disabled")
    end

    test "submit button is disabled if all sections arent completed", %{
      public_conn: conn,
      blank_dataset: blank_dataset,
      public_user: public_user
    } do
      {:ok, andi_dataset} = Datasets.update(blank_dataset)
      {:ok, _} = Datasets.update(andi_dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)

      assert ["disabled"] = get_attributes(html, "#submit-button", "disabled")
    end

    test "submit button is enabled if all required sections are completed", %{
      public_conn: conn,
      blank_dataset: blank_dataset,
      public_user: public_user
    } do
      blank_dataset = Map.put(blank_dataset, :datasetLink, "samples/#{blank_dataset.id}/sample.json")
      {:ok, andi_dataset} = Datasets.update(blank_dataset)
      {:ok, _} = Datasets.update(andi_dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)

      metadata_view = find_live_child(view, "metadata_form_editor")
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      render_change(metadata_view, :validate, %{
        "form_data" => %{
          "contactName" => "Joe Smith",
          "dataName" => "great_new_dataset",
          "dataTitle" => "Great new dataset",
          "description" => "really great description",
          "language" => "english",
          "sourceFormat" => "application/json"
        }
      })

      render_change(data_dictionary_view, :validate, %{
        "data_dictionary_form_schema" => %{
          "schema" => %{
            "0" => %{
              "bread_crumb" => "foo",
              "dataset_id" => andi_dataset.id,
              "description" => "",
              "id" => "f0cdd53a-cd5a-4741-a43d-7873d5f56773",
              "name" => "foo",
              "type" => "string"
            }
          }
        }
      })

      html = render(view)

      assert [] = get_attributes(html, "#submit-button", "disabled")
    end

    test "dataset submission status is updated to submitted upon completion", %{
      public_conn: conn,
      blank_dataset: blank_dataset,
      public_user: public_user
    } do
      blank_dataset = Map.put(blank_dataset, :datasetLink, "samples/#{blank_dataset.id}/sample.json")
      {:ok, andi_dataset} = Datasets.update(blank_dataset)
      {:ok, _} = Datasets.update(andi_dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)

      metadata_view = find_live_child(view, "metadata_form_editor")
      data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")

      render_change(metadata_view, :validate, %{
        "form_data" => %{
          "contactName" => "Joe Smith",
          "dataName" => "great_new_dataset",
          "dataTitle" => "Great new dataset",
          "description" => "really great description",
          "language" => "english",
          "sourceFormat" => "application/json"
        }
      })

      render_change(data_dictionary_view, :validate, %{
        "data_dictionary_form_schema" => %{
          "schema" => %{
            "0" => %{
              "bread_crumb" => "foo",
              "dataset_id" => andi_dataset.id,
              "description" => "",
              "id" => "f0cdd53a-cd5a-4741-a43d-7873d5f56773",
              "name" => "foo",
              "type" => "string"
            }
          }
        }
      })

      html = render(view)

      assert [] = get_attributes(html, "#submit-button", "disabled")

      element(view, "#submit-button") |> render_click()

      eventually(fn ->
        assert Datasets.get(andi_dataset.id) |> Map.get(:submission_status) == :submitted
      end)
    end
  end
end
