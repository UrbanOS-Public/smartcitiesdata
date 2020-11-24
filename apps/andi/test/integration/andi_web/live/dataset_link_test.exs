defmodule AndiWeb.DatasetLinkTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use AndiWeb.Test.PublicAccessCase
  use Placebo

  import Checkov

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest

  import FlokiHelpers,
    only: [
      get_text: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.InputConverter

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets/"

  describe "create new dataset" do
    setup %{curator_subject: curator_subject, public_subject: public_subject} do
      {:ok, public_user} = Andi.Schemas.User.create_or_update(public_subject, %{email: "bob@example.com"})
      blank_dataset = %Dataset{id: UUID.uuid4(), technical: %{}, business: %{}}
      [blank_dataset: blank_dataset, public_user: public_user]
    end

    data_test "required #{field} field displays proper error message", %{public_conn: conn, public_user: public_user} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      {:ok, dataset} = Datasets.update(dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      dataset_link_view = find_live_child(view, "dataset_link_editor")

      html = render_change(dataset_link_view, :validate, %{"form_data" => form_data})

      assert get_text(html, "##{field}-error-msg") == expected_error_message

      where([
        [:field, :form_data, :expected_error_message],
        [:datasetLink, %{"datasetLink" => ""}, "Please enter a valid dataset link."]
      ])
    end
  end
end
