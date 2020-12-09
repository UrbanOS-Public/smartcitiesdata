defmodule AndiWeb.SubmitLiveViewTest do
    use ExUnit.Case
    use AndiWeb.Test.PublicAccessCase
    use Andi.DataCase
    use AndiWeb.Test.AuthConnCase.IntegrationCase
    use Placebo
  
    import Checkov
  
    @moduletag shared_data_connection: true
  
    import Phoenix.LiveViewTest
    import SmartCity.Event, only: [dataset_update: 0, organization_update: 0]
    import SmartCity.TestHelper, only: [eventually: 1, eventually: 3]
  
    import FlokiHelpers,
      only: [
        get_attributes: 3,
        get_value: 2,
        get_values: 2,
        get_select: 2,
        get_text: 2,
        find_elements: 2
      ]
  
    alias SmartCity.TestDataGenerator, as: TDG
    alias Andi.InputSchemas.Datasets
    alias Andi.InputSchemas.Datasets.Dataset
    alias Andi.InputSchemas.Organizations
    alias Andi.InputSchemas.InputConverter
  
    @instance_name Andi.instance_name()
  
    @endpoint AndiWeb.Endpoint
    @url_path "/submissions/"
          
    setup %{public_subject: public_subject} do
        {:ok, public_user} = Andi.Schemas.User.create_or_update(public_subject, %{email: "bob@example.com"})
        blank_dataset = %Dataset{id: UUID.uuid4(), technical: %{}, business: %{}}
        [blank_dataset: blank_dataset, public_user: public_user]
    end

    describe "public user submits a new dataset" do
        test "user is presented with a disabled submit button", %{public_conn: conn, public_user: public_user} do
            dataset = Datasets.create(public_user)
            assert {:ok, view, html} = live(conn, "/submissions/" <> dataset.id)

            assert ["disabled"] = get_attributes(html, "#submit-button", "disabled") 
        end

        test "user completes all required sections and is able to submit dataset", %{public_conn: conn, public_user: public_user} do
            dataset = Datasets.create(public_user)
            assert {:ok, view, html} = live(conn, "/submissions/" <> dataset.id)

            metadata_view = find_live_child(view, "metadata_form_editor")
            data_dictionary_view = find_live_child(view, "data_dictionary_form_editor")
            dataset_link_view = find_live_child(view, "dataset_link_editor")

            render_change(metadata_view, :validate, %{"form_data" => %{
                "contactName" => "Joe Smith",
                "dataName" => "great_new_dataset",
                "dataTitle" => "Great new dataset",
                "description" => "really great description",
                "language" => "english",
                "sourceFormat" => "application/json",
              }})

            render_change(data_dictionary_view, :validate, %{"data_dictionary_form_schema" => %{
                "schema" => %{
                  "0" => %{
                    "bread_crumb" => "foo",
                    "dataset_id" => dataset.id,
                    "description" => "",
                    "id" => "f0cdd53a-cd5a-4741-a43d-7873d5f56773",
                    "name" => "foo",
                    "type" => "string"
                  }
                }
              }})

            render_change(dataset_link_view, :validate, %{"form_data" => %{"datasetLink" => "www.google.com"}})

            html = render(view)

            assert [] = get_attributes(html, "#submit-button", "disabled") 
        end
    end
end