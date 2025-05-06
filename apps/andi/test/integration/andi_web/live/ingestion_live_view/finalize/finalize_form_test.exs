defmodule AndiWeb.IngestionLiveView.FinalizeFormTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  import Checkov
  import Phoenix.LiveViewTest
  import SmartCity.Event, only: [ingestion_update: 0, dataset_update: 0]
  import SmartCity.TestHelper, only: [eventually: 1]
  import FlokiHelpers,
    only: [
      get_text: 2,
      get_attributes: 3,
      get_values: 2,
      find_elements: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Ingestions
  alias AndiWeb.Helpers.FormTools
  alias Andi.InputSchemas.InputConverter
  alias AndiWeb.InputSchemas.FinalizeFormSchema

  @endpoint AndiWeb.Endpoint
  @url_path "/ingestions/"

  @moduletag shared_data_connection: true
  @instance_name Andi.instance_name()

  describe "one-time ingestion" do
    setup %{conn: conn} do
      ingestion = create_ingestion_with_cadence("once")
      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)

      [
        view: view,
        html: html
      ]
    end

    test "shows the Immediate ingestion button selected", %{html: html} do
      refute Enum.empty?(get_attributes(html, "#finalize_form_cadence_once", "checked"))
    end

    test "does not show cron scheduler", %{html: html} do
      assert Enum.empty?(find_elements(html, ".finalize-form__scheduler--visible"))
      refute Enum.empty?(find_elements(html, ".finalize-form__scheduler--hidden"))
    end
  end

  describe "repeat ingestion" do
    setup %{conn: conn} do
      ingestion = create_ingestion_with_cadence("0 * * * * *")
      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)

      [
        view: view,
        html: html
      ]
    end

    test "shows the repeat ingestion button selected", %{html: html} do
      refute Enum.empty?(get_attributes(html, "#finalize_form_cadence_0__________", "checked"))
    end

    test "shows cron scheduler", %{html: html} do
      refute Enum.empty?(find_elements(html, ".finalize-form__scheduler--visible"))
      assert Enum.empty?(find_elements(html, ".finalize-form__scheduler--hidden"))

      assert "0 * * * * *" == get_crontab_from_html(html)
    end

    data_test "does not allow schedules more frequent than every 2 seconds", %{conn: conn} do
      ingestion = create_ingestion_with_cadence("#{second_value} * * * * *")
      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)

      refute Enum.empty?(find_elements(html, "#cadence-error-msg"))

      where(second_value: ["*", "*/1"])
    end

    data_test "marks #{cronstring} as invalid", %{conn: conn} do
      ingestion = create_ingestion_with_cadence(cronstring)

      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)

      refute Enum.empty?(find_elements(html, "#cadence-error-msg"))

      where([
        [:cronstring],
        [""],
        ["1 2 3 4"],
        ["1 nil 2 3 4 5"]
      ])
    end
  end

  describe "finalize form" do
    setup do
      ingestion = create_ingestion_with_cadence("1 1 1 * * *")
      [ingestion: ingestion]
    end

    data_test "quick schedule #{schedule}", %{conn: conn, ingestion: ingestion} do
      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)

      button = element(view, "#quick_schedule_#{schedule}")

      render_click(button)
      html = render(view)

      assert expected_crontab == get_crontab_from_html(html)
      assert Enum.empty?(find_elements(html, "#cadence-error-msg"))

      where([
        [:schedule, :expected_crontab],
        ["hourly", "0 0 * * * *"],
        ["daily", "0 0 0 * * *"],
        ["weekly", "0 0 0 * * 0"],
        ["monthly", "0 0 0 1 * *"],
        ["yearly", "0 0 0 1 1 *"]
      ])
    end

    test "set schedule manually", %{conn: conn, ingestion: ingestion} do
      assert {:ok, view, _} = live(conn, @url_path <> ingestion.id)

      form_data = %{"cadence" => ingestion.cadence}

      view
      |> form("#finalize_form", form_data: form_data)
      |> render_change()

      html = render(view)

      assert ingestion.cadence == get_crontab_from_html(html)
      assert Enum.empty?(find_elements(html, "#cadence-error-msg"))
    end

    test "handles five-character cronstrings", %{conn: conn} do
      ingestion = create_ingestion_with_cadence("4 2 7 * *")

      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)

      assert ingestion.cadence == get_crontab_from_html(html) |> String.trim_leading()
      assert Enum.empty?(find_elements(html, "#cadence-error-msg"))
    end

    test "handles cadence of never", %{conn: conn} do
      ingestion = create_ingestion_with_cadence("never")

      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      assert Enum.empty?(find_elements(html, "#cadence-error-msg"))
    end
  end

  test "required cadence field displays proper error message", %{conn: conn} do
    ingestion = create_ingestion_with_cadence("")

    assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)

    assert get_text(html, "#cadence-error-msg") == "Please enter a valid cadence."
  end

  defp create_ingestion_with_cadence(cadence) do
    dataset = TDG.create_dataset(%{})
    ingestion = TDG.create_ingestion(%{targetDatasets: [dataset.id], cadence: cadence})

    Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
    Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

    eventually(fn ->
      assert Ingestions.get(ingestion.id) != nil
    end)

    Ingestions.get(ingestion.id)
  end

  defp get_crontab_from_html(html) do
    html
    |> get_values(".finalize-form-schedule-input__field")
    |> Enum.join(" ")
  end
end
