defmodule AndiWeb.SubmissionUploadDataDictionaryTest do
  use ExUnit.Case
  use AndiWeb.Test.PublicAccessCase
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo
  import Checkov

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest

  import FlokiHelpers,
    only: [
      get_attributes: 3,
      get_value: 2,
      get_select: 2,
      get_all_select_options: 2,
      get_select_first_option: 2,
      get_text: 2,
      get_texts: 2,
      find_elements: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Dataset

  import SmartCity.TestHelper, only: [eventually: 1]

  @endpoint AndiWeb.Endpoint
  @url_path "/submissions/"

  describe "schema sample upload" do
    setup %{public_subject: public_subject} do
      {:ok, public_user} = Andi.Schemas.User.create_or_update(public_subject, %{email: "bob@example.com"})
      blank_dataset = %Dataset{id: UUID.uuid4(), technical: %{}, business: %{}}
      [blank_dataset: blank_dataset, public_user: public_user]
    end

    test "does not allow file uploads greater than 200MB", %{public_conn: conn, blank_dataset: blank_dataset, public_user: public_user} do
      {:ok, andi_dataset} = Datasets.update(blank_dataset)
      {:ok, _} = Datasets.update(andi_dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
      upload_data_dictionary_view = find_live_child(view, "upload_data_dictionary_form_editor")

      html = render_change(upload_data_dictionary_view, :file_upload, %{"fileSize" => 200_000_001})

      refute Enum.empty?(find_elements(html, "#datasetLink-error-msg"))
    end

    test "does not allow file types that arent csv or json", %{public_conn: conn, blank_dataset: blank_dataset, public_user: public_user} do
      {:ok, andi_dataset} = Datasets.update(blank_dataset)
      {:ok, _} = Datasets.update(andi_dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
      upload_data_dictionary_view = find_live_child(view, "upload_data_dictionary_form_editor")

      html = render_change(upload_data_dictionary_view, :file_upload, %{"fileSize" => 200, "fileType" => "text/plain"})

      refute Enum.empty?(find_elements(html, "#datasetLink-error-msg"))
    end

    test "json files are uploaded to s3", %{public_conn: conn, blank_dataset: blank_dataset, public_user: public_user} do
      {:ok, andi_dataset} = Datasets.update(blank_dataset)
      {:ok, _} = Datasets.update(andi_dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
      upload_data_dictionary_view = find_live_child(view, "upload_data_dictionary_form_editor")

      html =
        render_change(upload_data_dictionary_view, :file_upload, %{
          "fileType" => "application/json",
          "fileName" => "sample.json",
          "file" => "{\n\"hello\": \"world\"\n}"
        })

      eventually(fn ->
        assert {:ok, _} =
                 ExAws.S3.get_object("kdp-cloud-storage", "samples/#{andi_dataset.id}/sample.json")
                 |> ExAws.request()

        assert "sample.json" == get_text(html, ".sample-file-display")
      end)
    end

    test "csv files are uploaded to s3", %{public_conn: conn, blank_dataset: blank_dataset, public_user: public_user} do
      {:ok, andi_dataset} = Datasets.update(blank_dataset)
      {:ok, _} = Datasets.update(andi_dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
      upload_data_dictionary_view = find_live_child(view, "upload_data_dictionary_form_editor")

      html =
        render_change(upload_data_dictionary_view, :file_upload, %{
          "fileType" => "text/csv",
          "fileName" => "sample.csv",
          "file" => "John,Doe,120 jefferson st.,Riverside, NJ,8075"
        })

      eventually(fn ->
        assert {:ok, _} =
                 ExAws.S3.get_object("kdp-cloud-storage", "samples/#{andi_dataset.id}/sample.csv")
                 |> ExAws.request()

        assert "sample.csv" == get_text(html, ".sample-file-display")
      end)
    end
  end
end
