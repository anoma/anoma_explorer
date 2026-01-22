ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(AnomaExplorer.Repo, :manual)

# Define Mox mocks
Mox.defmock(AnomaExplorer.HTTPClientMock, for: AnomaExplorer.HTTPClient)

# Mock for GraphQL HTTP client - uses the callbacks defined in the GraphQL module
Mox.defmock(AnomaExplorer.GraphQLHTTPClientMock, for: AnomaExplorer.Indexer.GraphQL)
