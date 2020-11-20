defmodule AndiWeb.SubmitLiveView.ReviewSubmission do
  @moduledoc """
  LiveComponent reviewing submission
  """
  use Phoenix.LiveView
  require Logger

  def mount(_, %{"dataset" => dataset}, socket) do
    AndiWeb.Endpoint.subscribe("toggle-visibility")

    {:ok,
     assign(socket,
       visibility: "collapsed",
       validation_status: "collapsed",
       dataset_id: dataset.id
     )}
  end

  def render(assigns) do
    action =
      case assigns.visibility do
        "collapsed" -> "EDIT"
        "expanded" -> "MINIMIZE"
      end

    ~L"""
      <div id="review-submission" class="form-component">
        <div class="component-header" phx-click="toggle-component-visibility" phx-value-component="review_submission">
          <div class="section-number">
            <h3 class="component-number component-number--<%= @validation_status %>">4</h3>
            <div class="component-number-status--<%= @validation_status %>"></div>
          </div>
          <div class="component-title full-width">
            <h2 class="component-title-text component-title-text--<%= @visibility %> ">Review Your Submission</h2>
            <div class="component-title-action">
              <div class="component-title-action-text--<%= @visibility %>"><%= action %></div>
              <div class="component-title-icon--<%= @visibility %>"></div>
            </div>
          </div>
        </div>

        <div class="form-section">
          <div class="component-edit-section--<%= @visibility %>">
            <div class="review-form-header">
              <h4>Please ensure that there are no errors or omitted fields before submitting. Upon submission, the Data Curator will review your dataset for completeness, efficacy, and accuracy. You may check the status of your submission by returning to your submission portal homepage. If you have any questions, please contact the <a href="https://www.smartcolumbusos.com/contact-us" target="_blank">Data Curator</a></h4>
            </div>


        </div>
      </div>
    """
  end

  def handle_info(
        %{topic: "toggle-visibility", payload: %{expand: "review_submission", dataset_id: dataset_id}},
        %{assigns: %{dataset_id: dataset_id}} = socket
      ) do
    {:noreply, assign(socket, visibility: "expanded")}
  end

  def handle_info(%{topic: "toggle-visibility"}, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle-component-visibility", _, socket) do
    current_visibility = Map.get(socket.assigns, :visibility)

    new_visibility =
      case current_visibility do
        "expanded" -> "collapsed"
        "collapsed" -> "expanded"
      end

    {:noreply, assign(socket, visibility: new_visibility, validation_status: "valid")}
  end
end
