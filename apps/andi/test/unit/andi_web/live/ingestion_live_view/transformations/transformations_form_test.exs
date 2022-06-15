defmodule AndiWeb.IngestionLiveView.Transformations.TransformationFormTest do
  use ExUnit.Case
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Andi.InputSchemas.Ingestions.Transformation
  alias AndiWeb.IngestionLiveView.Transformations.TransformationForm

  @endpoint AndiWeb.Endpoint

  describe "Transformations form" do
    test "Shows errors for missing name field" do
      transformation_changeset = Transformation.changeset_for_draft(%{})
      assert {:ok, view, html} = render_transformation_form(transformation_changeset)

      form_update = %{
        "name" => "   "
      }

      element(view, "#transformation_form") |> render_change(form_update)

      assert element(view, "#name-error-msg") |> has_element?
    end
  end

  defp render_transformation_form(transformation_changeset) do
    live_isolated(build_conn(), TransformationForm, session: %{"transformation_changeset" => transformation_changeset})
  end
end
