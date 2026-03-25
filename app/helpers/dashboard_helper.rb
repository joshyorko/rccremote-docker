module DashboardHelper
  def dashboard_overview(status)
    {
      rcc_running: status.services.dig(:rccremote, :running),
      rcc_available: status.rcc.fetch(:available, false),
      rcc_mode: display_value(status.services.dig(:rccremote, :mode)),
      rcc_command: display_value(status.services.dig(:rccremote, :command)),
      rcc_origin: status.services.dig(:rccremote, :origin).presence,
      robots_count: status.statistics.fetch(:robots, 0),
      catalogs_count: status.statistics.fetch(:catalogs, 0),
      zips_count: status.statistics.fetch(:hololib_zips, 0),
      holotree_spaces: status.statistics.fetch(:holotree_spaces, 0),
      active_blueprints: status.statistics.fetch(:active_blueprints, 0),
      rcc_version: status.rcc.fetch(:version, "unknown"),
      catalog_total_bytes: status.rcc.fetch(:catalog_total_bytes, 0),
      newest_catalog_age_days: status.rcc[:newest_catalog_age_days],
      most_used_space: status.rcc[:most_used_space] || {},
      settings_profile: status.rcc[:settings_profile].presence || "default",
      settings_version: status.rcc[:settings_version].presence || "unknown",
      ssl_verify: status.rcc[:ssl_verify],
      diagnostics_hosts_count: status.rcc[:diagnostics_hosts_count].to_i,
      rcc_index_url: status.rcc[:rcc_index_url].presence,
      robots_path: display_value(status.paths[:robots]),
      hololib_zip_path: display_value(status.paths[:hololib_zip]),
      timestamp: formatted_status_timestamp(status.timestamp)
    }
  end

  def dashboard_resource_chips(overview)
    [
      { label: "#{overview[:robots_count]} workspace(s)", state_class: overview[:robots_count].positive? ? "ok" : "warning" },
      { label: "#{overview[:catalogs_count]} catalog snapshot(s)", state_class: overview[:catalogs_count].positive? ? "ok" : "warning" },
      { label: "#{overview[:zips_count]} import bundle(s)", state_class: overview[:zips_count].positive? ? "ok" : "warning" },
      { label: "#{overview[:holotree_spaces]} holotree space(s)", state_class: nil }
    ]
  end

  def dashboard_metrics(overview)
    [
      { label: "RCC remote", value: status_label(overview[:rcc_running]), hint: "Execution mode: #{overview[:rcc_mode]}", state_class: overview[:rcc_running] ? "ok" : "error" },
      { label: "Workspaces", value: overview[:robots_count], hint: overview[:robots_count].zero? ? "No workspaces yet" : "Ready for catalog builds", state_class: overview[:robots_count].zero? ? "warning" : "ok" },
      { label: "Catalogs", value: overview[:catalogs_count], hint: age_in_days_label(overview[:newest_catalog_age_days]), state_class: overview[:catalogs_count].zero? ? "warning" : "ok" },
      { label: "Holotree spaces", value: overview[:holotree_spaces], hint: "#{overview[:active_blueprints]} active blueprint(s)", state_class: overview[:holotree_spaces].zero? ? "warning" : "ok" },
      { label: "Catalog footprint", value: human_bytes(overview[:catalog_total_bytes]), hint: overview[:zips_count].zero? ? "No bundles uploaded" : "#{overview[:zips_count]} import bundle(s) available", state_class: overview[:catalog_total_bytes].to_i.positive? ? "ok" : "warning" },
      { label: "RCC version", value: overview[:rcc_version], hint: overview[:rcc_available] ? "Binary detected" : "Binary unavailable", state_class: overview[:rcc_available] ? "ok" : "error" },
      { label: "Config profile", value: overview[:settings_profile], hint: "settings #{overview[:settings_version]}", state_class: "ok" }
    ]
  end

  def dashboard_telemetry_rows(overview)
    [
      { label: "Execution mode", value: overview[:rcc_mode] },
      { label: "Most used space", value: display_value(overview.dig(:most_used_space, :id)) },
      { label: "Use count", value: "#{overview.dig(:most_used_space, :use_count) || 0} run(s)" },
      { label: "Last used", value: display_value(overview.dig(:most_used_space, :last_used)) },
      { label: "SSL verify", value: overview[:ssl_verify].nil? ? "unknown" : overview[:ssl_verify] ? "enabled" : "disabled" },
      { label: "Diagnostics hosts", value: overview[:diagnostics_hosts_count] }
    ]
  end

  def dashboard_checklist(overview)
    catalog_footprint = overview[:catalog_total_bytes].to_i.positive? ? "Catalog footprint is #{human_bytes(overview[:catalog_total_bytes])}." : "Catalog footprint is empty."

    [
      { state_class: overview[:rcc_running] ? "ok" : "error", message: "RCC remote process is #{overview[:rcc_running] ? "reachable" : "not reachable"}." },
      { state_class: overview[:rcc_available] ? "ok" : "error", message: "RCC binary is #{overview[:rcc_available] ? "available" : "missing"} for command execution." },
      { state_class: overview[:robots_count].positive? ? "ok" : "warning", message: overview[:robots_count].positive? ? "#{overview[:robots_count]} workspace definition(s) are present." : "No workspace definitions are present yet." },
      { state_class: overview[:catalogs_count].positive? ? "ok" : "warning", message: overview[:catalogs_count].positive? ? "#{overview[:catalogs_count]} catalog(s) are available." : "No catalogs available. Run a rebuild." },
      { state_class: overview[:holotree_spaces].positive? ? "ok" : "warning", message: overview[:holotree_spaces].positive? ? "#{overview[:holotree_spaces]} holotree space(s) are available." : "No holotree spaces currently available." },
      { state_class: overview[:catalog_total_bytes].to_i.positive? ? "ok" : "warning", message: catalog_footprint }
    ]
  end

  def dashboard_flow_steps(overview)
    [
      {
        title: "Stage workspaces",
        detail: overview[:robots_count].positive? ? "#{overview[:robots_count]} workspace(s) are ready for file review, YAML edits, or bundle staging." : "No workspace is staged yet. Create one before you rebuild catalogs.",
        href: robots_path,
        cta: "Open workspaces",
        state_class: overview[:robots_count].positive? ? "ok" : "warning"
      },
      {
        title: "Refresh catalogs",
        detail: overview[:catalogs_count].positive? ? "Current snapshot age: #{age_in_days_label(overview[:newest_catalog_age_days])}." : "No catalog snapshot is loaded. Rebuild after workspace changes land.",
        href: catalogs_path(anchor: "rebuild-catalogs"),
        cta: "Review catalogs",
        state_class: overview[:catalogs_count].positive? ? "ok" : "warning"
      },
      {
        title: "Import bundles",
        detail: overview[:zips_count].positive? ? "#{overview[:zips_count]} bundle(s) are waiting in the intake lane." : "No bundles are queued. Upload one when you need to hydrate the remote.",
        href: hololib_zips_path(anchor: "upload-bundle"),
        cta: "Open imports",
        state_class: overview[:zips_count].positive? ? "ok" : "warning"
      }
    ]
  end
end
