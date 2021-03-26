require 'sequel'

Sequel.migration do

  up do
    create_table(:players) do
      primary_key :id
      
      String :username
      
      Integer :seat
      Integer :placement
      Integer :final_score
    end

    create_table(:hanchan) do
      primary_key :id
      foreign_key :east_player_id, :players
      foreign_key :south_player_id, :players
      foreign_key :west_player_id, :players
      foreign_key :north_player_id, :players
      
      Time :time_start, index: true
      String :tenhou_log
    end

    alter_table(:players) do
      add_foreign_key :hanchan_id, :hanchan
    end

    create_table(:hands) do
      primary_key :id
      foreign_key :hanchan_id, :hanchan

      Integer :round

      Integer :east_player_score
      Integer :south_player_score
      Integer :west_player_score
      Integer :north_player_score
    end
  end

  down do
    drop_table(:hands)
    drop_table(:players)
    drop_table(:hanchan)
  end
end
