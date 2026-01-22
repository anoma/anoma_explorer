defmodule AnomaExplorer.Repo.Migrations.SyncContractAddressesWithIndexer do
  use Ecto.Migration

  @moduledoc """
  Syncs contract addresses with indexer/config.yaml.

  Removes networks that are no longer being indexed:
  - base-sepolia
  - base-mainnet
  - optimism-mainnet

  Keeps only the networks actually configured in the indexer:
  - eth-mainnet (chain 1)
  - eth-sepolia (chain 11155111)
  - arb-mainnet (chain 42150)
  """

  def up do
    # Remove contract addresses for networks no longer being indexed
    execute """
    DELETE FROM contract_addresses
    WHERE network IN ('base-sepolia', 'base-mainnet', 'optimism-mainnet')
    """
  end

  def down do
    # Re-create the removed addresses (using the Protocol Adapter protocol)
    execute """
    INSERT INTO contract_addresses (protocol_id, category, version, network, address, active, inserted_at, updated_at)
    SELECT
      p.id,
      'protocol_adapter',
      'v1.0',
      network,
      '0x212f275c6dd4829cd84abdf767b0df4a9cb9ef60',
      true,
      NOW(),
      NOW()
    FROM protocols p
    CROSS JOIN (VALUES
      ('base-sepolia'),
      ('base-mainnet'),
      ('optimism-mainnet')
    ) AS networks(network)
    WHERE p.name = 'Protocol Adapter'
    ON CONFLICT (protocol_id, category, version, network) DO NOTHING
    """
  end
end
