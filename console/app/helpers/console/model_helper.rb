module Console::ModelHelper

  def cartridge_info(cartridge, application)
    case
    when cartridge.jenkins_client?
      [
        link_to('See Jenkins Build jobs', application.build_job_url, :title => 'Jenkins is currently running builds for your application'),
        link_to('(configure)', application_building_path(application), :title => 'Remove or change your Jenkins configuration'),
      ].join(' ').html_safe
    when cartridge.haproxy_balancer?
      link_to "See HAProxy status page", application.scale_status_url
    when cartridge.database?
      name, _ = cartridge.data(:database_name)
      if name
        user, _ = cartridge.data(:username)
        password, _ = cartridge.data(:password)
        content_tag(:span,
          if user && password
            (@info_id ||= 0)
            link_id = "db_link_#{@info_id += 1}"
            span_id = "db_link_#{@info_id += 1}"
            "Database: <strong>#{h name}</strong> (user <strong>#{h user}</strong>, <a href=\"javascript:;\" id=\"#{link_id}\" data-unhide=\"##{span_id}\" data-hide-parent=\"##{link_id}\">show password</a><span id=\"#{span_id}\" class=\"hidden\">password <strong>#{h password}</strong></span>)".html_safe
          else
            "Database: <strong>#{name}</strong>"
          end
        )
      end
    else
      url, name = cartridge.data(:connection_url)
      if url
        link_to name, url, :target => '_blank'
      end
    end
  end

  def gear_group_state(states)
    css_class = if states.all? {|s| s == :started}
        'state_started'
      elsif states.none? {|s| s == :started}
        'state_stopped'
      end

    content_tag(:span, gear_group_states(states), :class => css_class)
  end

  def gear_group_count(gears)
    types = gears.inject({}){ |h,g| h[g.gear_profile.to_s] ||= 0; h[g.gear_profile.to_s] += 1; h }
    return 'None' if types.empty?
    types.keys.sort.map do |k|
      "#{types[k]} #{k.humanize.downcase}"
    end.to_sentence
  end

  def web_cartridge_scale_title(cartridge)
    if cartridge.current_scale == cartridge.scales_from
      'Your web cartridge is running on the minimum amount of gears and will scale up if needed'
    elsif cartridge.current_scale == cartridge.scales_to
      'Your web cartridge is running on the maximum amount of gears and cannot scale up any further'
    else
      'Your web cartridge is running multiple copies to handle increased web traffic'
    end
  end

  def web_cartridge_scale_label(cartridge)
    suffix = case
      when cartridge.scales_from == cartridge.scales_to
      when cartridge.current_scale == cartridge.scales_from
        " (max #{cartridge.scales_to})"
      when cartridge.current_scale == cartridge.scales_to
        " (min #{cartridge.scales_from})"
      else
        " (min #{cartridge.scales_to}, max #{cartridge.scales_to})"
      end
    "Routing to #{pluralize(cartridge.current_scale, 'web gear')}#{suffix}"
  end

  def application_gear_count(application)
    return 'None' if application.gear_count == 0
    "#{application.gear_count} #{application.gear_profile.to_s.humanize.downcase}"
  end

  def cartridge_gear_group_count(group)
    return 'None' if group.gears.empty?
    "#{group.gears.length} #{group.gear_profile.to_s.humanize.downcase}"
  end

  def gear_group_count_title(total_gears)
    "OpenShift runs each cartridge inside one or more gears on a server and is allocated a fixed portion of CPU time and memory use."
  end

  def cartridge_storage(cart)
    storage_string(cart.total_storage)
  end

  def scaled_cartridge_storage(cart)
    storage_string(cart.total_storage, cart.current_scale)
  end

  def storage_string(quota,multiplier = 0)
    parts = []
    if multiplier > 1
      parts << "#{multiplier} x"
    end
    parts << "%s GB" % quota
    parts.join(' ').strip
  end

  def scaling_max(*args)
    args.unshift(1)
    args.select{ |i| i != nil && i != -1 }.max
  end
  def scaling_min(*args)
    args.unshift(1)
    args.select{ |i| i != nil && i != -1 }.min
  end

  def scale_range(from, to, max, max_choices)
    limit = to == -1 ? max : to
    return if limit > max_choices
    (from .. limit).map{ |i| [i.to_s, i] }
  end
  def scale_from_options(obj, max, max_choices=20)
    if range = scale_range(obj.supported_scales_from, obj.supported_scales_to, max, max_choices)
      {:as => :select, :collection => range, :include_blank => false}
    else
      {:as => :string}
    end
  end
  def scale_to_options(obj, max, max_choices=20)
    if range = scale_range(obj.supported_scales_from, obj.supported_scales_to, max, max_choices)
      range << ['All available', -1] if obj.supported_scales_to == -1
      {:as => :select, :collection => range, :include_blank => false}
    else
      {:as => :string, :hint => 'Use -1 to scale to your current account limits'}
    end
  end

  def storage_options(min,max)
    {:as => :select, :collection => (min..max), :include_blank => false}
  end

  def scale_options
    [['No scaling',false],['Scale with web traffic',true]]
  end

  def can_scale_application_type(type, capabilities)
    type.scalable?
  end

  def cannot_scale_title(type, capabilities)
    unless can_scale_application_type(type, capabilities)
      "This application shares filesystem resources and can't be scaled."
    end
  end

  def warn_may_not_scale(type, capabilities)
    if type.may_not_scale?
      "This application may require additional work to scale. Please see the application's documentation for more information."
    end
  end

  def gear_increase_indicator(cartridges, scales, gear_type, existing, capabilities)
    range = scales ? gear_estimate_for_scaled_app(cartridges) : (existing ? 0..0 : 1..1)
    min = range.begin
    max = range.end
    increasing = (min > 0 || max > 0)

    cost, title = 
      if gear_increase_cost(min, capabilities)
        [true, "This will add #{pluralize(min, 'gear')} to your account and will result in additional charges."]
      elsif gear_increase_cost(max, capabilities)
        [true, "This will add at least #{pluralize(min, 'gear')} to your account and may result in additional charges."]
      elsif !increasing
        [false, "No gears will be added to your account."]
      else
        [false, "This will add #{pluralize(min, 'gear')} to your account."]
      end
    if cartridges_premium(cartridges)
      cost = true
      title = "#{title} Additional charges may be accrued for premium cartridges."
    end
    if increasing && gear_types_with_cost.include?(gear_type)
      cost = true
      title = "#{title} The selected gear type will have additional hourly charges."
    end

    content_tag(:span, 
      [
        (if max == Float::INFINITY
          "+#{min}-?"
        elsif max != min
          "+#{min}-#{max}"
        else
          "+#{min}"
        end),
        "<span data-icon=\"\ue014\" aria-hidden=\"true\"> </span>",
        ("<span class=\"label label-premium\">$</span>" if cost),
      ].compact.join(' ').html_safe, 
      :class => 'indicator-gear-increase',
      :title => title,
    )
  end

  def cartridges_premium(cartridges)
    false
  end
  def gear_increase_cost(count, capabilities)
    false
  end
  def gear_types_with_cost
    []
  end
  def gear_estimate_for_scaled_app(cartridges)
    min = 0
    max = 0
    if cartridges.present?
      cartridges.each_pair do |_, carts|
        any = false
        all = true
        carts.each do |cart| 
          if cart.service? || cart.web_framework?
            any = true
          else
            all = false
            break if any
          end
        end
        max += 1 if any
        min += 1 if all
      end
    else
      min = 1
      max = Float::INFINITY
    end
    Range.new(min,max)
  end

  def user_currency_symbol
    "$"
  end

  def usage_rate_indicator
    content_tag :span, user_currency_symbol, :class => "label label-premium", :title => 'May include additional usage fees at certain levels, see plan for details.'
  end

  def in_groups_by_tag(ary, tags)
    groups = {}
    other = ary.reject do |t|
      tags.any? do |tag|
        (groups[tag] ||= []) << t if t.tags.include?(tag)
      end
    end
    groups = tags.map do |tag|
      types = groups[tag]
      if types
        if types.length < 2
          other.concat(types)
          nil
        else
          [tag, types]
        end
      end
    end.compact
    [groups, other]
  end

  def common_tags_for(ary)
    ary.length < 2 ? [] : ary.inject(nil){ |tags, a| tags ? (a.tags & tags) : a.tags } || []
  end
end
