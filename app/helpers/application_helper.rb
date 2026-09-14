module ApplicationHelper
  def sortable_header(title, column)
    current = params[:sort] == column
    direction = if current && params[:direction] == "desc"
      "asc"
    elsif current && params[:direction] == "asc"
      "desc"
    else
      "asc"
    end

    icon = if current
      params[:direction] == "desc" ? arrow_icon("down") : arrow_icon("up")
    else
      arrow_icon("unsorted")
    end

    link_to(
      safe_join([title, icon]),
      request.query_parameters.merge(sort: column, direction: direction),
      class: "sortable-header #{current ? "sorted" : ""}"
    )
  end

  private

  def arrow_icon(name)
    case name
    when "up"
      '<svg class="sort-icon sort-asc" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 4l-8 8h16z"/></svg>'.html_safe
    when "down"
      '<svg class="sort-icon sort-desc" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 20l8-8H4z"/></svg>'.html_safe
    else
      '<svg class="sort-icon sort-none" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M7 15l5 5 5-5zM7 9l5-5 5 5z"/></svg>'.html_safe
    end
  end

  def date_columns_display(date)
    return "—".html_safe unless date.present?
    date.strftime("%A %-d %b %Y").html_safe
  end
end
