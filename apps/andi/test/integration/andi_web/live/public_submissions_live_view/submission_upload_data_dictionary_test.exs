defmodule AndiWeb.SubmissionUploadDataDictionaryTest do
  use ExUnit.Case
  use AndiWeb.Test.PublicAccessCase
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import Phoenix.ChannelTest

  import FlokiHelpers, only: [get_text: 2, find_elements: 2]

  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Dataset

  import SmartCity.TestHelper, only: [eventually: 1]

  @endpoint AndiWeb.Endpoint
  @url_path "/submissions/"

  describe "schema sample upload" do
    setup %{public_subject: public_subject} do
      {:ok, public_user} = Andi.Schemas.User.create_or_update(public_subject, %{email: "bob@example.com", name: "bob"})
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
                 ExAws.S3.get_object("trino-hive-storage", "samples/#{andi_dataset.id}/sample.json")
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
          "file" => "name,last,addr,city,state,zip\nJohn,Doe,120 jefferson st.,Riverside, NJ,8075"
        })

      eventually(fn ->
        assert {:ok, _} =
                 ExAws.S3.get_object("trino-hive-storage", "samples/#{andi_dataset.id}/sample.csv")
                 |> ExAws.request()

        assert "sample.csv" == get_text(html, ".sample-file-display")
      end)
    end

    test "tsv files are uploaded to s3", %{public_conn: conn, blank_dataset: blank_dataset, public_user: public_user} do
      {:ok, andi_dataset} = Datasets.update(blank_dataset)
      {:ok, _} = Datasets.update(andi_dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
      upload_data_dictionary_view = find_live_child(view, "upload_data_dictionary_form_editor")

      html =
        render_change(upload_data_dictionary_view, :file_upload, %{
          "fileType" => "text/plain",
          "fileName" => "sample.tsv",
          "file" => "first_name \t last_name \t age\nJohn \t Doe \t 34"
        })

      eventually(fn ->
        assert {:ok, _} =
                 ExAws.S3.get_object("trino-hive-storage", "samples/#{andi_dataset.id}/sample.tsv")
                 |> ExAws.request()

        assert "sample.tsv" == get_text(html, ".sample-file-display")
      end)
    end

    test "populates data dictionary for valid json files", %{public_conn: conn, blank_dataset: blank_dataset, public_user: public_user} do
      {:ok, andi_dataset} = Datasets.update(blank_dataset)
      {:ok, _} = Datasets.update(andi_dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
      upload_data_dictionary_view = find_live_child(view, "upload_data_dictionary_form_editor")

      json_sample = [%{first_name: "joey", last_name: "bob", age: 12}] |> Jason.encode!()

      render_change(upload_data_dictionary_view, :file_upload, %{
        "fileType" => "application/json",
        "fileName" => "sample.json",
        "file" => json_sample
      })

      expected_schema = [
        %{name: "age", type: "integer"},
        %{name: "first_name", type: "string"},
        %{name: "last_name", type: "string"}
      ]

      eventually(fn ->
        updated_dataset = Datasets.get(andi_dataset.id)

        generated_schema =
          updated_dataset.technical.schema
          |> Enum.map(fn item -> %{type: item.type, name: item.name} end)

        assert(generated_schema == expected_schema)
      end)
    end

    test "populates data dictionary for valid csv files", %{public_conn: conn, blank_dataset: blank_dataset, public_user: public_user} do
      {:ok, andi_dataset} = Datasets.update(blank_dataset)
      {:ok, _} = Datasets.update(andi_dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
      upload_data_dictionary_view = find_live_child(view, "upload_data_dictionary_form_editor")

      render_change(upload_data_dictionary_view, :file_upload, %{
        "fileType" => "text/csv",
        "fileName" => "sample.csv",
        "file" => "first_name,last_name,age\nJohn,Doe,34"
      })

      expected_schema = [
        %{name: "first_name", type: "string"},
        %{name: "last_name", type: "string"},
        %{name: "age", type: "integer"}
      ]

      eventually(fn ->
        updated_dataset = Datasets.get(andi_dataset.id)

        generated_schema =
          updated_dataset.technical.schema
          |> Enum.map(fn item -> %{type: item.type, name: item.name} end)

        assert(generated_schema == expected_schema)
      end)
    end

    test "populates data dictionary for valid tsv files", %{public_conn: conn, blank_dataset: blank_dataset, public_user: public_user} do
      {:ok, andi_dataset} = Datasets.update(blank_dataset)
      {:ok, _} = Datasets.update(andi_dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
      upload_data_dictionary_view = find_live_child(view, "upload_data_dictionary_form_editor")

      render_change(upload_data_dictionary_view, :file_upload, %{
        "fileType" => "text/plain",
        "fileName" => "sample.tsv",
        "file" => "first_name \t last_name \t age\nJohn \t Doe \t 34"
      })

      expected_schema = [
        %{name: "first_name", type: "string"},
        %{name: "last_name", type: "string"},
        %{name: "age", type: "integer"}
      ]

      eventually(fn ->
        updated_dataset = Datasets.get(andi_dataset.id)

        generated_schema =
          updated_dataset.technical.schema
          |> Enum.map(fn item -> %{type: item.type, name: item.name} end)

        assert(generated_schema == expected_schema)
      end)
    end

    test "does not populate data dictionary for failed sample upload", %{
      public_conn: conn,
      blank_dataset: blank_dataset,
      public_user: public_user
    } do
      {:ok, andi_dataset} = Datasets.update(blank_dataset)
      {:ok, _} = Datasets.update(andi_dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
      upload_data_dictionary_view = find_live_child(view, "upload_data_dictionary_form_editor")

      json_sample = [%{field1: "blah", field2: "blah blah"}] |> Jason.encode!()

      file_payload = %{
        "fileType" => "invalid",
        "fileName" => "sample.csv",
        "file" => json_sample
      }

      render_change(upload_data_dictionary_view, :file_upload, file_payload)

      updated_dataset = Datasets.get(andi_dataset.id)
      generated_schema = updated_dataset.technical.schema

      assert generated_schema == []
      refute_broadcast("populate_data_dictionary", file_payload)
    end

    test "logs sample upload to postgres on success", %{
      public_conn: conn,
      blank_dataset: blank_dataset,
      public_user: public_user
    } do
      {:ok, andi_dataset} = Datasets.update(blank_dataset)
      {:ok, _} = Datasets.update(andi_dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
      upload_data_dictionary_view = find_live_child(view, "upload_data_dictionary_form_editor")

      json_sample = [%{field1: "blah", field2: "blah blah"}] |> Jason.encode!()

      file_payload = %{
        "fileType" => "application/json",
        "fileName" => "sample.csv",
        "file" => json_sample
      }

      render_change(upload_data_dictionary_view, :file_upload, file_payload)

      download_log = Andi.Repo.get_by(Andi.Schemas.DatasetUpload, dataset_id: andi_dataset.id)

      assert download_log != nil

      associated_user = Andi.Repo.get(Andi.Schemas.User, download_log.user_uploading)

      assert download_log.dataset_id == andi_dataset.id
      assert associated_user.email == "bob@example.com"
      assert associated_user.name == "bob"
      assert download_log.upload_success
    end

    test "logs sample upload to postgres on failure", %{
      public_conn: conn,
      blank_dataset: blank_dataset,
      public_user: public_user
    } do
      {:ok, andi_dataset} = Datasets.update(blank_dataset)
      {:ok, _} = Datasets.update(andi_dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
      upload_data_dictionary_view = find_live_child(view, "upload_data_dictionary_form_editor")

      json_sample = [%{field1: "blah", field2: "blah blah"}] |> Jason.encode!()

      file_payload = %{
        "fileType" => "invalid",
        "fileName" => "sample.csv",
        "file" => json_sample
      }

      render_change(upload_data_dictionary_view, :file_upload, file_payload)

      download_log = Andi.Repo.get_by(Andi.Schemas.DatasetUpload, dataset_id: andi_dataset.id)

      assert download_log != nil

      associated_user = Andi.Repo.get(Andi.Schemas.User, download_log.user_uploading)

      assert download_log.dataset_id == andi_dataset.id
      assert associated_user.email == "bob@example.com"
      assert associated_user.name == "bob"
      refute download_log.upload_success
    end
  end
end
