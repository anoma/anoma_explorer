defmodule AnomaExplorer.HTTPClient do
  @moduledoc """
  Behaviour for HTTP client implementations.

  Used to enable mocking in tests.
  """

  @type response :: {:ok, map()} | {:error, term()}

  @callback post(url :: String.t(), body :: map(), headers :: keyword()) :: response()
end
