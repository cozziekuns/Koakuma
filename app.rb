require 'sequel'
require 'sinatra'

DAN_TO_STRING = [
  "七段",
  "八段",
  "九段",
  "十段",
  "天鳳",
]

DB = Sequel.connect(ENV['DATABASE_URL'] || 'postgres://localhost/koakuma_test')

def get_score_range(score, tolerance)
  return (score - tolerance)..(score + tolerance)
end

get '/' do
  @hanchan_count = DB[:hanchan].count
  
  haml :index
end

post '/list_hanchan' do
  score_sym = [:east_score, :south_score, :west_score, :north_score]
  
  # Re-order the scores so that they line up with the original seat placements.
  round = params[:round].to_i - 1
  ordered_scores = 0.upto(3).map { |i| params[score_sym[((i - round) + 4) % 4]].to_i }
  
  hands = DB[:hands].where(
    round: round,
    east_player_score: get_score_range(ordered_scores[0], params[:error].to_i),
    south_player_score: get_score_range(ordered_scores[1], params[:error].to_i),
    west_player_score: get_score_range(ordered_scores[2], params[:error].to_i),
    north_player_score: get_score_range(ordered_scores[3], params[:error].to_i),
  ).distinct(:hanchan_id)
    
  hanchan_ids = hands.map(:hanchan_id)

  return "No Results Found." if hanchan_ids.empty?

  @total_count = hanchan_ids.length

  placements = DB[:players].where(
    hanchan_id: hanchan_ids
  ).select_hash_groups(:seat, :placement)

  @avg_placements = 0.upto(3).map { |i| 
    "%0.2f" % ((1.0 * placements[(i + round) % 4].sum + @total_count) / @total_count)
  }

  # Replace this with the current page
  paginated_hanchan_ids = hanchan_ids[0...20]

  paginated_hanchan = DB[:hanchan].where(id: paginated_hanchan_ids).as_hash(:id)

  players_by_hanchan = DB[:players].where(
    hanchan_id: paginated_hanchan_ids
  ).to_hash_groups(:hanchan_id)

  paginated_hands = hands.where(
    hanchan_id: paginated_hanchan_ids
  ).to_hash_groups(:hanchan_id)

  @results = []
    
  paginated_hanchan_ids.each { |id|
    player_sym = [:east_player, :south_player, :west_player, :north_player]
    
    curr_hanchan = paginated_hanchan[id]
    curr_players = players_by_hanchan[id]
    curr_hand = paginated_hands[id]

    blob = {}

    blob[:log_url] = curr_hanchan[:tenhou_log]
    blob[:timestamp] = curr_hanchan[:time_start]

    0.upto(3).each { |i|
      blob[player_sym[i]] = curr_players[i]

      blob[player_sym[i]][:dan] = DAN_TO_STRING[blob[player_sym[i]][:dan] - 16]
      blob[player_sym[i]][:curr_score] = curr_hand[0][(player_sym[(i + round) % 4].to_s + "_score").to_sym]
    }

    @results.push(blob)
  }
  
  haml :list_hanchan
end
