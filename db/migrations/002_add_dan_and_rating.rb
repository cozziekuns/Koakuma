require 'sequel'

Sequel.migration do

  up do 
    alter_table(:players) do
      add_column :dan, Integer
      add_column :rating, Integer
    end
  end

  down do
    alter_table(:players) do
      drop_column :dan
      drop_column :rating
    end
  end

end
