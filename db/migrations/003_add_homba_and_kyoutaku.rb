require 'sequel'

Sequel.migration do

  up do 
    alter_table(:hands) do
      add_column :homba, Integer
      add_column :kyoutaku, Integer
    end
  end

  down do
    alter_table(:hands) do
      drop_column :homba
      drop_column :kyoutaku
    end
  end

end
