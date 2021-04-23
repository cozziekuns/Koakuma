require 'net/http'
require 'nokogiri'
require 'json'

require 'sequel'

DB = Sequel.connect(ENV['DATABASE_URL'] || 'postgres://localhost/koakuma_test')

#==============================================================================
# ** Hanchan_Parser
#==============================================================================

class Hanchan_Parser

  #---------------------------------------------------------------------------
  # * Public Instance Variables
  #---------------------------------------------------------------------------

  attr_reader   :hanchan

  #---------------------------------------------------------------------------
  # * Constants
  #---------------------------------------------------------------------------

  PLAYER_SEAT_ARRAY = [:east_player, :south_player, :west_player, :north_player]

  #---------------------------------------------------------------------------
  # * Methods
  #---------------------------------------------------------------------------

  def initialize(log_url, timestamp)
    return unless DB[:hanchan].where(tenhou_log: log_url).first.nil?

    @hanchan = {
      log_url: log_url,
      time_start: timestamp
    }


    parse(get_log_body(log_url))
  end

  def parse(log_body)
    xml = Nokogiri::XML(log_body)
    xml.root.traverse { |node| parse_node(node) }
  end

  def parse_node(node)
    case node.name
    when 'UN'
      parse_un_node(node)
    when 'INIT'
      parse_init_node(node)
    when 'AGARI', 'RYUUKYOKU'
      parse_owari_node(node)
    end
  end

  def parse_un_node(node)
    return if not node.attributes['dan'] or not node.attributes['rate']

    dan_list = node.attributes['dan'].value.split(',').map { |s| s.to_i }
    rating_list = node.attributes['rate'].value.split(',').map { |s| s.to_i }

    [:east_player, :south_player, :west_player, :north_player].each.with_index { |sym, i|
      @hanchan[sym] ||= {}

      @hanchan[sym][:username] = URI.decode_www_form_component(node.attributes["n#{i}"].value)
      @hanchan[sym][:seat] = i
      
      @hanchan[sym][:dan] = dan_list[i]
      @hanchan[sym][:rating] = rating_list[i]
    }

    @hanchan[:hands] = []
  end

  def parse_init_node(node)
    seed = node.attributes['seed'].value.split(',').map { |s| s.to_i }
    scores = node.attributes['ten'].value.split(',').map { |s| s.to_i * 100 }

    hand = {
      round: seed[0],
      homba: seed[1],
      kyoutaku: seed[2],
      east_player_score: scores[0],
      south_player_score: scores[1],
      west_player_score: scores[2],
      north_player_score: scores[3],
    }

    @hanchan[:hands].push(hand)
  end

  def parse_owari_node(node)
    return if not node.attributes['owari']
    
    placements = []

    node.attributes['owari'].value.split(',').map { |s| s.to_i }.each.with_index { |score, i|
      next if i % 2 == 1

      sym = PLAYER_SEAT_ARRAY[i / 2]
      
      @hanchan[sym][:final_score] = score * 100
      placements.push(score) 
    }

    placements.sort!.reverse!

    PLAYER_SEAT_ARRAY.each { |sym|
      placement = placements.index(@hanchan[sym][:final_score] / 100)
      placements[placement] = nil
      
      @hanchan[sym][:placement] = placement
    }
  end

  def get_log_body(log_url)
    request_url = log_url.gsub("http") { "https" }
    request_url.gsub!("?log=") { "log/?" }

    uri = URI(request_url)

    begin
      retries ||= 0

      puts "Fetching Log Body: #{request_url}"

      Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http|
        return http.request(Net::HTTP::Get.new(uri)).body
      }
    rescue => e
      puts "Error during processing: #{$!}"

      retries += 1
      if (retries += 1) < 3
        puts "Retrying..."
        retry
      end

      puts "Execution failed after 3 retries. Exiting..."
      puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
      exit
    end
  end

  def commit
    return if @hanchan.nil?

    hanchan_id = DB[:hanchan].insert(
      time_start: @hanchan[:time_start],
      tenhou_log: @hanchan[:log_url],
    )

    player_ids = []
    
    PLAYER_SEAT_ARRAY.each { |sym|
      player = @hanchan[sym]
      
      player_id = DB[:players].insert(
        hanchan_id: hanchan_id,
        username: player[:username],
        seat: player[:seat],
        placement: player[:placement],
        final_score: player[:final_score],
        dan: player[:dan],
        rating: player[:rating],
      )

      player_ids.push(player_id)
    }

    DB[:hanchan].where(id: hanchan_id).update(
      east_player_id: player_ids[0],
      south_player_id: player_ids[1],
      west_player_id: player_ids[2],
      north_player_id: player_ids[3],
    )

    @hanchan[:hands].each { |hand|
      DB[:hands].insert(
        hanchan_id: hanchan_id,
        round: hand[:round],
        homba: hand[:homba],
        kyoutaku: hand[:kyoutaku],
        east_player_score: hand[:east_player_score],
        south_player_score: hand[:south_player_score],
        west_player_score: hand[:west_player_score],
        north_player_score: hand[:north_player_score],
      )
    }

    p "Inserted Hanchan ID: #{hanchan_id}, Log: #{@hanchan[:log_url]}"
  end

end

filename = ARGV[0]

File.open("#{filename}.json", 'r+') { |f|
  hanchan_list = JSON.parse(File.read(f))["list"]
  hanchan_list = hanchan_list[ARGV[1].to_i...-1] if ARGV[1]

  i = 0
  hanchan_list.each { |hanchan|
    break if i >= 1000

    parser = Hanchan_Parser.new(hanchan["log_url"], hanchan["timestamp"])
    parser.commit
    sleep(0.2)

    i += 1
  }
}
