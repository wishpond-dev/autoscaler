selector = ENV['SELECTOR'] || raise("SELECTOR required")
resource = ENV['RESOURCE'] || "deployment"
name = ENV['NAME'] || "#{resource}/#{selector}"
max_pods = (ENV['MAX_PODS'] || '10').to_i
min_pods = (ENV['MIN_PODS'] || '1').to_i
strategy = ENV['STRATEGY'] || 'average_cpu'

# Get the list of pods
#
# TODO: Filter out any pods that aren't relevant
#
command = %(kubectl top pods -l #{selector} --no-headers > /tmp/pods)
`#{command}`

pods = `cat /tmp/pods | wc -l`.chomp.to_i
cpu = `awk '{s+=$2} END {print s}' /tmp/pods`.chomp.to_i
utilisation = cpu / pods
new_pods = pods
direction = 'none'

puts "name:#{name} selector:#{selector} cpu:#{cpu} pods:#{pods} utilisation:#{utilisation} strategy:#{strategy}"

case strategy
when 'average_cpu'
  scale_up = (ENV['SCALE_UP'] || '500').to_i
  scale_down = (ENV['SCALE_DOWN'] || '100').to_i
  factor = (ENV['FACTOR'] || '2').to_i

  if utilisation > scale_up
    new_pods = pods * factor
    new_pods = [new_pods, max_pods].min
    direction = 'up'
  elsif utilisation < scale_down
    new_pods = pods / factor
    new_pods = [new_pods, min_pods].max
    direction = 'down'
  end
when 'metric'
  current_value = %x(curl #{ENV['ENDPOINT']}).to_f
  desired_value = (ENV['TARGET'] || '1').to_f

  # Desired value can't be zero
  raise "TARGET can't be 0" if desired_value == '0'.to_f

  new_pods = (pods * (current_value / desired_value)).ceil

  if new_pods > pods
    new_pods = [new_pods, max_pods].min
    direction = 'up'
  elsif new_pods < pods
    new_pods = [new_pods, min_pods].max
    direction = 'down'
  end

  puts "current:#{current_value} desired:#{desired_value} new_pods:#{new_pods} direction:#{direction}"

else
  raise "Unknown strategy: #{strategy}"
end

if new_pods != pods
  puts "scaling #{direction}"
  command = %(kubectl scale --replicas #{new_pods} #{resource} -l #{selector})
  puts command
  puts %x(#{command})
  `curl -X POST https://katana.wishpond.com/notify/scale \
        --header "Content-Type: application/json" \
        --header "X-KATANA-TOKEN:#{ENV['KATANA_SECRET']}" \
        -d "{\"name\":\"#{name}\",\"selector\":\"#{selector}\",\"cpu\":\"#{cpu}\",\"pods\":\"#{pods}\",\"new_pods\":\"#{new_pods}\",\"utilisation\":\"#{utilisation}\",\"resource\":\"#{resource}\",\"direction\":\"#{direction}\"}"`
        #,\"scale_up\":\"$scale_up\",\"scale_down\":\"$scale_down\",\"factor\":\"$factor\"
end
