defmodule AndiWeb.ExtractDateFormTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  alias SmartCity.TestDataGenerator, as: TDG
  use Placebo
  alias Andi.Schemas.User
  alias IngestionHelpers

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [find_elements: 2, get_text: 2]

  @endpoint AndiWeb.Endpoint
  @url_path "/ingestions/"
  @user UserHelpers.create_user()

  setup do
    allow(Andi.Repo.get_by(Andi.Schemas.User, any()), return: @user)
    allow(User.get_all(), return: [@user])
    allow(User.get_by_subject_id(any()), return: @user)
    []
  end

  setup %{auth_conn_case: auth_conn_case} do
    auth_conn_case.disable_revocation_list.()
    :ok
  end

  describe "date extract step form" do
    setup do
      allow(Andi.Repo.all(any()), return: [])

      :ok
    end

    test "displays error for invalid formats", %{conn: conn} do
      %{ingestion: ingestion} =
        IngestionHelpers.create_with_date_extract_step(%{
          destination: "bob_field",
          deltaTimeUnit: "Year",
          deltaTimeValue: 5,
          format: "frankly this is invalid"
        })
        |> IngestionHelpers.mock_repo_get()

      extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)

      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      extract_steps_form_view = find_live_child(view, "extract_step_form_editor")
      es_form = element(extract_steps_form_view, "#step-#{extract_step_id} form")

      form_data = %{"format" => "frankly this is invalid too"}
      html = render_change(es_form, %{"form_data" => form_data})

      error_text = get_text(html, "#format-error-msg")
      assert error_text != ""
    end

    test "displays example output with offsets when changeset is valid", %{conn: conn} do
      %{ingestion: ingestion} = IngestionHelpers.create_with_date_extract_step(%{}) |> IngestionHelpers.mock_repo_get()
      extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)

      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      extract_steps_form_view = find_live_child(view, "extract_step_form_editor")
      es_form = element(extract_steps_form_view, "#step-#{extract_step_id} form")

      form_data = %{"destination" => "dest", "deltaTimeValue" => 1, "deltaTimeUnit" => "days", "format" => "{YYYY}"}

      html = render_change(es_form, %{"form_data" => form_data})

      refute Enum.empty?(find_elements(html, ".example-output"))
    end

    test "displays example output when changeset is valid", %{conn: conn} do
      %{ingestion: ingestion} = IngestionHelpers.create_with_date_extract_step(%{}) |> IngestionHelpers.mock_repo_get()
      extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)

      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      extract_steps_form_view = find_live_child(view, "extract_step_form_editor")
      es_form = element(extract_steps_form_view, "#step-#{extract_step_id} form")

      form_data = %{"destination" => "dest", "deltaTimeUnit" => "", "format" => "{YYYY}"}

      html = render_change(es_form, %{"form_data" => form_data})

      refute Enum.empty?(find_elements(html, ".example-output"))
    end

    test "removes example output when changeset is invalid", %{conn: conn} do
      %{ingestion: ingestion} = IngestionHelpers.create_with_date_extract_step(%{}) |> IngestionHelpers.mock_repo_get()
      extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)

      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      extract_steps_form_view = find_live_child(view, "extract_step_form_editor")
      es_form = element(extract_steps_form_view, "#step-#{extract_step_id} form")

      form_data = %{"destination" => "dest", "deltaTimeValue" => 1, "deltaTimeUnit" => "days", "format" => "{YYYY}"}
      html = render_change(es_form, %{"form_data" => form_data})

      refute Enum.empty?(find_elements(html, ".example-output"))

      form_data = %{"destination" => "", "deltaTimeValue" => 1, "deltaTimeUnit" => "days", "format" => "{YYYY}"}
      html = render_change(es_form, %{"form_data" => form_data})

      assert Enum.empty?(find_elements(html, ".example-output"))
    end
  end
end
