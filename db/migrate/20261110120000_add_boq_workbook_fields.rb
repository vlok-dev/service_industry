class AddBoqWorkbookFields < ActiveRecord::Migration[8.1]
  def up
    create_boqs_table unless table_exists?(:boqs)
    create_boq_items_table unless table_exists?(:boq_items)

    add_column :boqs, :project_title, :string unless column_exists?(:boqs, :project_title)
    add_column :boqs, :sheet_name, :string unless column_exists?(:boqs, :sheet_name)
    add_column :boqs, :created_by_id, :integer unless column_exists?(:boqs, :created_by_id)
    add_column :boqs, :claim_1_label, :string unless column_exists?(:boqs, :claim_1_label)
    add_column :boqs, :claim_1_amount, :decimal, precision: 12, scale: 2 unless column_exists?(:boqs, :claim_1_amount)
    add_column :boqs, :claim_2_label, :string unless column_exists?(:boqs, :claim_2_label)
    add_column :boqs, :claim_2_amount, :decimal, precision: 12, scale: 2 unless column_exists?(:boqs, :claim_2_amount)
    add_column :boqs, :claim_3_label, :string unless column_exists?(:boqs, :claim_3_label)
    add_column :boqs, :claim_3_amount, :decimal, precision: 12, scale: 2 unless column_exists?(:boqs, :claim_3_amount)
    add_column :boqs, :claim_4_label, :string unless column_exists?(:boqs, :claim_4_label)

    add_column :boq_items, :row_type, :string, default: "item" unless column_exists?(:boq_items, :row_type)
    add_column :boq_items, :total_formula, :boolean, default: true unless column_exists?(:boq_items, :total_formula)
    add_column :boq_items, :position, :integer unless column_exists?(:boq_items, :position)

    change_column_null :boqs, :job_id, true
    add_index :boqs, :created_by_id unless index_exists?(:boqs, :created_by_id)
    add_index :boq_items, [ :boq_id, :position ] unless index_exists?(:boq_items, [ :boq_id, :position ])
  end

  def down
    remove_column :boqs, :project_title if column_exists?(:boqs, :project_title)
    remove_column :boqs, :sheet_name if column_exists?(:boqs, :sheet_name)
    remove_column :boqs, :created_by_id if column_exists?(:boqs, :created_by_id)
    remove_column :boqs, :claim_1_label if column_exists?(:boqs, :claim_1_label)
    remove_column :boqs, :claim_1_amount if column_exists?(:boqs, :claim_1_amount)
    remove_column :boqs, :claim_2_label if column_exists?(:boqs, :claim_2_label)
    remove_column :boqs, :claim_2_amount if column_exists?(:boqs, :claim_2_amount)
    remove_column :boqs, :claim_3_label if column_exists?(:boqs, :claim_3_label)
    remove_column :boqs, :claim_3_amount if column_exists?(:boqs, :claim_3_amount)
    remove_column :boqs, :claim_4_label if column_exists?(:boqs, :claim_4_label)
    remove_column :boq_items, :row_type if column_exists?(:boq_items, :row_type)
    remove_column :boq_items, :total_formula if column_exists?(:boq_items, :total_formula)
    remove_column :boq_items, :position if column_exists?(:boq_items, :position)
  end

  private

  def create_boqs_table
    create_table :boqs do |t|
      t.string :boq_number
      t.string :project_title
      t.string :sheet_name
      t.integer :job_id
      t.integer :created_by_id
      t.string :attention
      t.string :company
      t.string :email_address
      t.string :property
      t.string :subject
      t.integer :status
      t.decimal :subtotal
      t.decimal :total_including_vat
      t.decimal :vat_amount
      t.decimal :vat_rate
      t.string :claim_1_label
      t.decimal :claim_1_amount, precision: 12, scale: 2
      t.string :claim_2_label
      t.decimal :claim_2_amount, precision: 12, scale: 2
      t.string :claim_3_label
      t.decimal :claim_3_amount, precision: 12, scale: 2
      t.string :claim_4_label
      t.timestamps
    end
  end

  def create_boq_items_table
    create_table :boq_items do |t|
      t.references :boq, null: false, foreign_key: true
      t.string :row_type, default: "item"
      t.boolean :total_formula, default: true
      t.integer :position
      t.string :page
      t.string :item_code
      t.text :description
      t.string :unit
      t.decimal :bill_qty
      t.decimal :claimed_qty
      t.decimal :rate
      t.decimal :total
      t.timestamps
    end
  end
end
