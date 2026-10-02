class MakeJobIdNullableInQuotes < ActiveRecord::Migration[8.1]
  def change
    change_column_null :quotes, :job_id, true
  end
end
