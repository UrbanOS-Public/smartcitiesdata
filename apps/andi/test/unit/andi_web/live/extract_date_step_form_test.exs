defmodule AndiWeb.ExtractDateFormTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Phoenix.ConnTest
  use Placebo
  alias Andi.Schemas.User

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2, get_values: 2]

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets/"
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
      date_extract_step = %{
        type: "date",
        context: %{
          destination: "bob_field",
          deltaTimeUnit: "Year",
          deltaTimeValue: 5,
          format: "frankly this is invalid"
        }
      }

      dataset = DatasetHelpers.create_dataset(%{technical: %{extractSteps: [date_extract_step]}})

      extract_step_id =
        dataset
        |> get_in([:technical, :extractSteps])
        |> hd()
        |> Map.get(:id)

      allow(Andi.InputSchemas.Datasets.get(dataset.id), return: dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_steps_form_view = find_child(view, "extract_step_form_editor")
      extract_date_step_form_view = find_child(extract_steps_form_view, extract_step_id)

      form_data = %{"format" => "frankly this is invalid too"}
      html = render_change(extract_date_step_form_view, "validate", %{"form_data" => form_data})

      error_text = get_text(html, "#format-error-msg")
      assert error_text != ""
    end

    test "shows No Datasets when there are no rows to show", %{conn: conn} do
      allow(Andi.Repo.all(any()), return: [])
      DatasetHelpers.replace_all_datasets_in_repo([])

      assert {:ok, view, html} = live(conn, @url_path)

      assert get_text(html, ".datasets-index__title") =~ "All Datasets"
      assert get_text(html, ".datasets-index__table") =~ "No Datasets"
    end
  end
end
