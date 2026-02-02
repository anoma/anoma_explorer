defmodule AnomaExplorer.MixProject do
  use Mix.Project

  def project do
    [
      app: :anoma_explorer,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],
      dialyzer: [
        plt_add_apps: [:ex_unit],
        plt_local_path: "priv/plts/project.plt",
        plt_core_path: "priv/plts/core.plt"
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {AnomaExplorer.Application, []},
      extra_applications: [:logger, :runtime_tools, :inets, :ssl]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Override decimal to get OTP 28 compatible version
      {:decimal, github: "ericmj/decimal", override: true},
      {:phoenix, "~> 1.8.3"},
      {:phoenix_ecto, "~> 4.7.0"},
      {:ecto_sql, "~> 3.13.4"},
      {:postgrex, "~> 0.22.0"},
      {:phoenix_html, "~> 4.3.0"},
      {:phoenix_live_reload, "~> 1.6.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.20"},
      {:floki, "~> 0.38.0", only: :test},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.4.1", runtime: Mix.env() == :dev},
      {:ex_heroicons, "~> 3.1.0"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.5",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.1.0"},
      {:telemetry_poller, "~> 1.3.0"},
      {:gettext, "~> 0.26 or ~> 1.0"},
      {:jason, "~> 1.4"},
      # WebSocket client for GraphQL subscriptions
      {:websockex, "~> 0.4.3"},
      # HTTP server
      {:plug_cowboy, "~> 2.7"},
      # Testing
      {:mox, "~> 1.2", only: :test},
      {:tidewave, "~> 0.5.4", only: :dev},
      # Code quality
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind anoma_explorer", "esbuild anoma_explorer"],
      "assets.deploy": [
        "tailwind anoma_explorer --minify",
        "esbuild anoma_explorer --minify",
        "phx.digest"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
