# AnomaExplorer IEx Helpers
# Load with: iex -S mix or iex -S mix phx.server

alias AnomaExplorer.Repo
alias AnomaExplorer.Config

# Import Ecto.Query for interactive queries
import Ecto.Query

IO.puts("\n=== AnomaExplorer IEx Helpers ===\n")

defmodule H do
  @moduledoc """
  Helper functions for IEx exploration.

  Available functions:
  - caddr/0       - Get configured contract address
  - nets/0        - Get configured networks
  - supported/0   - List all supported networks
  - rpc_url/1     - Get RPC URL for a network
  """

  @doc "Get the configured contract address (from env)"
  def caddr do
    case System.get_env("CONTRACT_ADDRESS") do
      nil -> {:error, "CONTRACT_ADDRESS not set"}
      addr -> AnomaExplorer.Config.validate_contract_address(addr)
    end
  end

  @doc "Get the configured networks (from env)"
  def nets do
    case System.get_env("ALCHEMY_NETWORKS") do
      nil -> {:error, "ALCHEMY_NETWORKS not set"}
      networks -> AnomaExplorer.Config.parse_networks(networks)
    end
  end

  @doc "List all supported Alchemy networks"
  def supported do
    AnomaExplorer.Config.supported_networks()
  end

  @doc "Get RPC URL for a network (requires ALCHEMY_API_KEY)"
  def rpc_url(network) do
    case System.get_env("ALCHEMY_API_KEY") do
      nil -> {:error, "ALCHEMY_API_KEY not set"}
      key -> AnomaExplorer.Config.network_rpc_url(network, key)
    end
  end

  @doc "Print helper usage"
  def help do
    IO.puts("""

    AnomaExplorer IEx Helpers
    ========================

    Configuration:
      H.caddr()       - Get configured contract address
      H.nets()        - Get configured networks
      H.supported()   - List all supported Alchemy networks
      H.rpc_url(net)  - Get RPC URL for a network

    Environment variables needed:
      CONTRACT_ADDRESS    - Ethereum address to track
      ALCHEMY_API_KEY     - Your Alchemy API key
      ALCHEMY_NETWORKS    - Comma-separated networks (e.g., "eth-mainnet,polygon-mainnet")

    Example:
      export CONTRACT_ADDRESS=0x742d35cc6634c0532925a3b844bc9e7595f0ab12
      export ALCHEMY_API_KEY=your_key_here
      export ALCHEMY_NETWORKS=eth-mainnet,polygon-mainnet
    """)
  end
end

IO.puts("Type H.help() for available helper functions\n")
