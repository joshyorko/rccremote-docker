module ApplicationHelper
  def nav_link_to(label, path)
    classes = [ "nav-link" ]
    classes << "active" if current_page?(path)
    link_to(label, path, class: classes.join(" "))
  end

  def status_label(value)
    value ? "RUNNING" : "STOPPED"
  end
end
