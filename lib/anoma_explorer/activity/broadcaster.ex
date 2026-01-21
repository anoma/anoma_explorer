defmodule AnomaExplorer.Activity.Broadcaster do
  @moduledoc """
  Broadcasts activity updates via PubSub for realtime LiveView updates.
  """

  alias Phoenix.PubSub

  @pubsub AnomaExplorer.PubSub

  @doc """
  Broadcasts a new activity to all subscribers.
  """
  def broadcast_new_activity(activity) do
    # Broadcast to network-specific topic
    topic = "contract:#{activity.network}:#{activity.contract_address}"
    PubSub.broadcast(@pubsub, topic, {:new_activity, activity})

    # Also broadcast to general topic
    PubSub.broadcast(@pubsub, "activities:new", {:new_activity, activity})
  end

  @doc """
  Broadcasts multiple new activities.
  """
  def broadcast_new_activities(activities) when is_list(activities) do
    Enum.each(activities, &broadcast_new_activity/1)
  end

  @doc """
  Subscribe to activity updates for a specific network/contract.
  """
  def subscribe(network, contract_address) do
    topic = "contract:#{network}:#{contract_address}"
    PubSub.subscribe(@pubsub, topic)
  end

  @doc """
  Subscribe to all activity updates.
  """
  def subscribe_all do
    PubSub.subscribe(@pubsub, "activities:new")
  end
end
