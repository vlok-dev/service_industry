class AddClaim4AmountToBoq < ActiveRecord::Migration[8.1]
  def up
    add_column :boqs, :claim_4_amount, :decimal, precision: 12, scale: 2 unless column_exists?(:boqs, :claim_4_amount)
  end

  def down
    remove_column :boqs, :claim_4_amount if column_exists?(:boqs, :claim_4_amount)
  end
end