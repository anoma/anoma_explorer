defmodule AnomaExplorer.HTTPClient.FinchClient do
  @moduledoc """
  HTTP client implementation using Finch.
  """

  @behaviour AnomaExplorer.HTTPClient

  @impl true
  def post(url, body, headers \\ []) do
    headers = [{"content-type", "application/json"} | headers]
    json_body = Jason.encode!(body)

    request = Finch.build(:post, url, headers, json_body)

    case Finch.request(request, AnomaExplorer.Finch, receive_timeout: 30_000) do
      {:ok, %Finch.Response{status: status, body: response_body}} when status in 200..299 ->
        case Jason.decode(response_body) do
          {:ok, decoded} -> {:ok, decoded}
          {:error, _} -> {:error, :invalid_json}
        end

      {:ok, %Finch.Response{status: status, body: response_body}} ->
        {:error, {:http_error, status, response_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
