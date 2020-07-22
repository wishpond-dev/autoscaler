class Autoscaler
  POD_DATA_FILE = '/tmp/pods'

  class << self
    def run
      new.run
    end
  end

  def run
    log "name:#{name} selector:#{selector} cpu:#{cpu} pods:#{pods} utilisation:#{utilisation} strategy:#{strategy}"

    if new_pods != pods
      log "scaling #{direction}"
      log %x(kubectl scale --replicas #{new_pods} #{resource} -l #{selector})
      `curl -X POST https://katana.wishpond.com/notify/scale \
            --header "Content-Type: application/json" \
            --header "X-KATANA-TOKEN:#{ENV['KATANA_SECRET']}" \
            -d "{\"name\":\"#{name}\",\"selector\":\"#{selector}\",\"cpu\":\"#{cpu}\",\"pods\":\"#{pods}\",\"new_pods\":\"#{new_pods}\",\"utilisation\":\"#{utilisation}\",\"resource\":\"#{resource}\",\"direction\":\"#{direction}\"}"`
    else
      log "no change"
    end
  end

  def log(message)
    puts "#{Time.now} #{message}"
  end

  def pods
    get_current_state!
    @pods ||= `cat #{POD_DATA_FILE} | wc -l`.chomp.to_i
  end

  def cpu
    get_current_state!
    @cpu ||= `awk '{s+=$2} END {print s}' #{POD_DATA_FILE}`.chomp.to_i
  end

  def utilisation
    @utilisation ||= cpu / pods
  end

  def get_current_state!
    return if @state_acquired
    @state_acquired = true
    `kubectl top pods -l #{selector} --no-headers > #{POD_DATA_FILE}`
  end

  def strategy
    @strategy ||= ENV['STRATEGY'] || 'average_cpu'
  end

  def min_pods
    @min_pods ||= (ENV['MIN_PODS'] || '1').to_i
  end

  def max_pods
    @max_pods ||= (ENV['MAX_PODS'] || '10').to_i
  end

  def name
    @name ||= ENV['NAME'] || "#{resource}/#{selector}"
  end

  def resource
    @resource ||= ENV['RESOURCE'] || "deployment"
  end

  def selector
    @selector ||= ENV['SELECTOR'] || raise("SELECTOR required")
  end

  def new_pods
    @new_pods ||= [[desired_pods, min_pods].max, max_pods].min
  end

  def direction
    @direction =
      if new_pods > pods
        'up'
      elsif new_pods < pods
        'down'
      else
        ''
      end
  end

  def desired_pods
    @desired_pods ||=
      case strategy
      when 'average_cpu'
        new_pods_by_average_cpu
      when 'metric'
        new_pods_by_metric
      else
        raise "Unknown strategy: #{strategy}"
      end
  end

  def new_pods_by_average_cpu
    scale_up = (ENV['SCALE_UP'] || '500').to_i
    scale_down = (ENV['SCALE_DOWN'] || '100').to_i
    factor = (ENV['FACTOR'] || '2').to_i

    if utilisation > scale_up
      pods * factor
    elsif utilisation < scale_down
      pods / factor
    end
  end

  def new_pods_by_metric
    current_value = %x(curl -s #{ENV['ENDPOINT']}).to_f
    desired_value = (ENV['TARGET'] || '1').to_f

    # Desired value can't be zero
    raise "TARGET can't be 0" if desired_value == '0'.to_f

    (pods * (current_value / desired_value)).ceil
  end
end

Autoscaler.run
