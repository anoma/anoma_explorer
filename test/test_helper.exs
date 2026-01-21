ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(AnomaExplorer.Repo, :manual)

# Define Mox mocks
Mox.defmock(AnomaExplorer.HTTPClientMock, for: AnomaExplorer.HTTPClient)
