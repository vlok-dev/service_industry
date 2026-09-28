class CreatePeopleAndAddPersonToUsers < ActiveRecord::Migration[8.1]
  def up
    create_table :people do |t|
      t.string :name, null: false
      t.string :phone_number
      t.timestamps
    end

    add_reference :users, :person, null: true, foreign_key: true, index: true

    backfill_people

    change_column_null :users, :person_id, false

    # A person may hold several roles, but only once per role.
    add_index :users, [ :person_id, :role ], unique: true, name: "index_users_on_person_id_and_role"
  end

  def down
    remove_index :users, name: "index_users_on_person_id_and_role"
    remove_reference :users, :person, foreign_key: true
    drop_table :people
  end

  private

  # Every existing user becomes their own person so no account is orphaned.
  def backfill_people
    say_with_time "Backfilling a person for each existing user" do
      now = quote(Time.current.utc)

      select_all("SELECT id, name, phone_number FROM users WHERE person_id IS NULL").each do |row|
        person_id = insert(<<~SQL.squish)
          INSERT INTO people (name, phone_number, created_at, updated_at)
          VALUES (#{quote(row["name"] || "Unknown")}, #{quote(row["phone_number"])}, #{now}, #{now})
        SQL
        execute "UPDATE users SET person_id = #{person_id.to_i} WHERE id = #{row["id"].to_i}"
      end
    end
  end
end
