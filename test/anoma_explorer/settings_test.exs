defmodule AnomaExplorer.SettingsTest do
  @moduledoc """
  Tests for the Settings context.
  """
  use AnomaExplorer.DataCase, async: true

  alias AnomaExplorer.Settings

  describe "get_envio_url/0" do
    test "returns nil when not configured" do
      Application.delete_env(:anoma_explorer, :envio_graphql_url)
      assert Settings.get_envio_url() == nil
    end

    test "returns value from application config" do
      Application.put_env(:anoma_explorer, :envio_graphql_url, "https://test.envio.dev/graphql")

      assert Settings.get_envio_url() == "https://test.envio.dev/graphql"

      Application.delete_env(:anoma_explorer, :envio_graphql_url)
    end
  end

  describe "get_app_setting/1 and set_app_setting/3" do
    test "get_app_setting returns nil when not set" do
      assert Settings.get_app_setting("nonexistent_key") == nil
    end

    test "set_app_setting creates and retrieves setting" do
      assert {:ok, setting} = Settings.set_app_setting("test_key", "test_value", "A test setting")
      assert setting.key == "test_key"
      assert setting.value == "test_value"
      assert setting.description == "A test setting"

      assert Settings.get_app_setting("test_key") == "test_value"
    end

    test "set_app_setting updates existing setting" do
      Settings.set_app_setting("test_key", "initial", "Initial description")
      assert Settings.get_app_setting("test_key") == "initial"

      Settings.set_app_setting("test_key", "updated", "Updated description")
      assert Settings.get_app_setting("test_key") == "updated"
    end
  end

  describe "delete_app_setting/1" do
    test "deletes existing setting" do
      Settings.set_app_setting("test_setting", "value", "description")

      assert {:ok, _} = Settings.delete_app_setting("test_setting")
      assert Settings.get_app_setting("test_setting") == nil
    end

    test "returns error when not exists" do
      # Ensure it doesn't exist
      Settings.delete_app_setting("nonexistent_setting")

      assert {:error, :not_found} = Settings.delete_app_setting("nonexistent_setting")
    end
  end
end
