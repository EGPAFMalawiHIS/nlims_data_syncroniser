class CreateSites < ActiveRecord::Migration[5.2]
  def change
    create_table :sites do |t|
	t.string :name
    	t.string :district
    	t.float  :x
    	t.float  :y
    	t.string :region
    	t.string :description
    	t.boolean :enabled
        t.boolean :sync_status
        t.string :site_code
        t.string :application_port
        t.string :host_address
      t.timestamps
    end
  end
end
