module ApplicationHelper
  def message_graph(problem)
    create_percentage_table_for(problem.messages)
  end

  def generate_problem_ical(notices)
    RiCal.Calendar do |cal|
      notices.each_with_index do |notice, idx|
        cal.event do |event|
          event.summary     = "#{idx + 1} #{notice.message}"
          event.description = notice.url if notice.url
          event.dtstart     = notice.created_at.utc
          event.dtend       = notice.created_at.utc + 60.minutes
          event.organizer   = notice.server_environment && notice.server_environment["hostname"]
          event.location    = notice.project_root
          event.url         = app_problem_url(app_id: notice.problem.app.id, id: notice.problem)
        end
      end
    end.to_s
  end

  def user_agent_graph(problem)
    create_percentage_table_for(problem.user_agents)
  end

  def tenant_graph(problem)
    create_percentage_table_for(problem.hosts)
  end

  def create_percentage_table_for(collection)
    create_percentage_table_from_tallies(tally(collection))
  end

  def tally(collection)
    collection.values.inject({}) do |tallies, tally|
      tallies[tally['value']] = tally['count']
      tallies
    end
  end

  def create_percentage_table_from_tallies(tallies, options = {})
    total   = (options[:total] || total_from_tallies(tallies))
    percent = 100.0 / total.to_f
    rows    = tallies.map { |value, count| [(count.to_f * percent), value] }. \
      sort { |a, b| b[0] <=> a[0] }
    render "problems/tally_table", rows: rows
  end

  def head(collection)
    collection.first(head_size)
  end

  def tail(collection)
    collection.to_a[head_size..-1].to_a
  end

  def sparkline(times, start_time, num_buckets = 10)
    times = times.select { |time| time >= start_time }
    buckets = bucketize(times, start_time, Time.now.to_i, num_buckets)
    bars = buckets.map do |val|
      percent = (val * 100.0).round(2).to_s + "%"
      "<i style='height:#{percent}'></i>"
    end.join
    "<div class='spark'>#{bars}</div>".html_safe
  end

  def bucketize(values, min, max, num_buckets)
    get_min = ->(a, b) { a > b ? b : a }
    range = max - min
    buckets = Array.new(num_buckets, 0)
    values.each do |val|
      normalized = (val - min) / range.to_f

      # Use get_min() here because there will inevitably be one value == max
      # which means normalized = 1 and bucket[1 * num_buckets] doesn't exist
      bucket_index = get_min.call((normalized * num_buckets).floor, num_buckets - 1)
      buckets[bucket_index] += 1
    end
    max = buckets.max.to_f
    buckets.map { |count| count / max }
  end

  def issue_tracker_types
    ErrbitPlugin::Registry.issue_trackers.map do |_, object|
      IssueTrackerTypeDecorator.new(object)
    end
  end

private

  def total_from_tallies(tallies)
    tallies.values.sum
  end

  def head_size
    4
  end
end
