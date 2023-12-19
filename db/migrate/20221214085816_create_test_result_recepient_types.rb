class CreateTestResultRecepientTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :test_result_recepient_types do |t|

      t.timestamps
    end
  end
end
