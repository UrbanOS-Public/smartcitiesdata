defmodule AndiWeb.EditLiveView.FinalizeFormTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo
  import Checkov

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1]

  import FlokiHelpers,
    only: [
      get_text: 2,
      get_attributes: 3,
      get_values: 2,
      find_elements: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias AndiWeb.Helpers.FormTools
  alias Andi.InputSchemas.InputConverter
  alias AndiWeb.InputSchemas.FinalizeFormSchema

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets/"

  describe "one-time ingestion" do
    setup %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          technical: %{
            cadence: "once"
          }
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      [
        view: view,
        html: html
      ]
    end

    test "shows the Immediate ingestion button selected", %{html: html} do
      refute Enum.empty?(get_attributes(html, "#form_data_cadence_once", "checked"))
    end

    test "does not show cron scheduler", %{html: html} do
      assert Enum.empty?(find_elements(html, ".finalize-form__scheduler--visible"))
      refute Enum.empty?(find_elements(html, ".finalize-form__scheduler--hidden"))
    end
  end

  describe "never ingestion" do
    setup %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          technical: %{
            cadence: "never"
          }
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      [
        view: view,
        html: html
      ]
    end

    test "shows the Never ingestion button selected", %{html: html} do
      refute Enum.empty?(get_attributes(html, "#form_data_cadence_never", "checked"))
    end

    test "does not show cron scheduler", %{html: html} do
      assert Enum.empty?(find_elements(html, ".finalize-form__scheduler--visible"))
      refute Enum.empty?(find_elements(html, ".finalize-form__scheduler--hidden"))
    end
  end

  describe "repeat ingestion" do
    setup %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          technical: %{
            cadence: "0 * * * * *"
          }
        })

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      [
        view: view,
        html: html
      ]
    end

    test "shows the repeat ingestion button selected", %{html: html} do
      refute Enum.empty?(get_attributes(html, "#form_data_cadence_0__________", "checked"))
    end

    test "shows cron scheduler", %{html: html} do
      refute Enum.empty?(find_elements(html, ".finalize-form__scheduler--visible"))
      assert Enum.empty?(find_elements(html, ".finalize-form__scheduler--hidden"))

      assert "0 * * * * *" == get_crontab_from_html(html)
    end

    data_test "does not allow schedules more frequent than every 10 seconds", %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          technical: %{
            cadence: "*/#{second_interval} * * * * *"
          }
        })

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, _} = live(conn, @url_path <> dataset.id)
      finalize_view = find_live_child(view, "finalize_form_editor")

      form_data = FormTools.form_data_from_andi_dataset(dataset)
      html = render_change(finalize_view, :validate, %{"form_data" => form_data})

      refute Enum.empty?(find_elements(html, "#cadence-error-msg"))

      where(second_interval: ["1", "2", "3", "4", "5", "6", "7", "8", "9"])
    end

    data_test "marks #{cronstring} as invalid", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      finalize_view = find_live_child(view, "finalize_form_editor")

      form_data = %{"cadence" => cronstring}
      html = render_change(finalize_view, :validate, %{"form_data" => form_data})

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
      dataset = TDG.create_dataset(%{technical: %{cadence: "1 1 1 * * *"}})

      {:ok, andi_dataset} = Datasets.update(dataset)
      [dataset: andi_dataset]
    end

    data_test "quick schedule #{schedule}", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      finalize_view = find_live_child(view, "finalize_form_editor")

      render_click(finalize_view, "quick_schedule", %{"schedule" => schedule})
      html = render(finalize_view)

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

    test "set schedule manually", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      finalize_view = find_live_child(view, "finalize_form_editor")

      form_data = %{"cadence" => dataset.technical.cadence}
      html = render_change(finalize_view, :validate, %{"form_data" => form_data})

      assert dataset.technical.cadence == get_crontab_from_html(html)
      assert Enum.empty?(find_elements(html, "#cadence-error-msg"))
    end

    test "handles five-character cronstrings", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{cadence: "4 2 7 * *"}})
      {:ok, _} = Datasets.update(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      finalize_view = find_live_child(view, "finalize_form_editor")

      form_data = %{"cadence" => dataset.technical.cadence}
      render_change(finalize_view, :validate, %{"form_data" => form_data})
      html = render(view)

      assert dataset.technical.cadence == get_crontab_from_html(html) |> String.trim_leading()
      assert Enum.empty?(find_elements(html, "#cadence-error-msg"))
    end

    test "handles cadence of never", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{cadence: "never"}})
      {:ok, _} = Datasets.update(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert Enum.empty?(find_elements(html, "#cadence-error-msg"))
    end
  end

  test "required cadence field displays proper error message", %{conn: conn} do
    smrt_dataset = TDG.create_dataset(%{})

    {:ok, dataset} =
      InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
      |> Datasets.save()

    assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    finalize_view = find_live_child(view, "finalize_form_editor")

    form_data = %{"cadence" => ""}
    html = render_change(finalize_view, :validate, %{"form_data" => form_data})

    assert get_text(html, "#cadence-error-msg") == "Please enter a valid cadence."
  end

  defp get_crontab_from_html(html) do
    html
    |> get_values(".finalize-form-schedule-input__field")
    |> Enum.join(" ")
  end
end
