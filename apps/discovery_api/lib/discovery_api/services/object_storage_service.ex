defmodule DiscoveryApi.Services.ObjectStorageService do
  @moduledoc """
  Provides access to files stored in object storage, such as S3, Google Cloud Storage or Azure Storage
  """

  def download_file_as_stream(path, possible_extensions) do
    case Enum.find(possible_extensions, &extension_available_for_file?(path, &1)) do
      nil ->
        {:error, "not found"}

      available_extension ->
        data_stream =
          bucket_name()
          |> ExAws.S3.download_file(
            get_file_key(path, available_extension),
            "dataset"
          )
          |> ExAws.stream!(region: region())

        {:ok, data_stream, available_extension}
    end
  end

  defp extension_available_for_file?(path, extension) do
    bucket_name()
    |> ExAws.S3.list_objects(prefix: get_file_key(path, extension))
    |> ExAws.request!()
    |> Map.get(:body)
    |> Map.get(:contents)
    |> length() > 0
  end

  defp get_file_key(path, extension) do
    "#{path}.#{extension}"
  end

  defp bucket_name() do
    Application.get_env(:discovery_api, :hosted_bucket)
  end

  defp region() do
    Application.get_env(:discovery_api, :hosted_region)
  end
end
