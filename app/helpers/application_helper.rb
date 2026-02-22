module ApplicationHelper
  def nav_link_to(label, path)
    classes = [ "nav-link" ]
    classes << "active" if nav_active?(path)
    link_to(label, path, class: classes.join(" "))
  end

  def status_label(value)
    value ? "RUNNING" : "STOPPED"
  end

  def human_bytes(bytes)
    value = bytes.to_i
    return "0 B" if value <= 0

    number_to_human_size(value, precision: 2, strip_insignificant_zeros: true)
  end

  def age_in_days_label(days)
    return "unknown age" if days.nil?
    return "built today" if days.zero?
    return "1 day old" if days == 1

    "#{days} days old"
  end

  def formatted_status_timestamp(timestamp)
    parsed = Time.zone.parse(timestamp.to_s)
    return timestamp if parsed.nil?

    parsed.strftime("%b %-d, %Y at %-I:%M %p %Z")
  rescue ArgumentError, TypeError
    timestamp
  end

  private

  def nav_active?(path)
    return current_page?(path) if path == root_path

    current_page?(path) || request.path.start_with?("#{path}/")
  end
end
