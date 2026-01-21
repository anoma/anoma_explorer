defmodule AnomaExplorerWeb.PageController do
  use AnomaExplorerWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
