defmodule AndiWeb.IngestionLiveView.MetadataModel do
  @moduledoc false

  import Phoenix.LiveView, only: [assign: 2]

  defstruct name: "",
            sourceFormat: "",
            targetDataset: "",
            topLevelSelector: ""

  @type t :: %__MODULE__{
               name: String.t(),
               sourceFormat: String.t(),
               targetDataset: String.t(),
               topLevelSelector: String.t(),
             }

  @spec merge_to_socket(t, Phoenix.Socket) :: t
  def merge_to_socket(ingestionModel, socket) do
    assign(socket, ingestion_model: ingestionModel)
  end
end