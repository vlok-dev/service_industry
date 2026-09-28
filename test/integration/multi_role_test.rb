require "test_helper"

class MultiRoleTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    # These users are looked up by email, so wipe any left by a previous test
    # to keep each example independent.
    User.where(email: [ "admin.multi@test.com", "plumber.multi@test.com", "super.multi@test.com" ]).destroy_all

    @admin = User.find_or_create_by!(email: "admin.multi@test.com") do |u|
      u.name = "Admin Multi"
      u.password = "password123"
      u.password_confirmation = "password123"
      u.role = :admin
    end

    @plumber = User.find_or_create_by!(email: "plumber.multi@test.com") do |u|
      u.name = "Plumber Multi"
      u.password = "password123"
      u.password_confirmation = "password123"
      u.role = :plumber
    end

    @super_admin = User.find_or_create_by!(email: "super.multi@test.com") do |u|
      u.name = "Super Multi"
      u.password = "password123"
      u.password_confirmation = "password123"
      u.role = :super_admin
    end
  end

  test "admin adds a second role to an existing person" do
    sign_in @admin
    person = @plumber.person

    post admin_users_path, params: {
      user: {
        person_id: person.id,
        role: "project_manager",
        email: "plumber.multi.pm@test.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_redirected_to admin_users_path
    assert_equal 2, person.profiles.reload.count, "expected the plumber to gain a second profile"
    assert_equal %w[plumber project_manager], person.profiles.order(:id).pluck(:role).sort
  end

  test "an admin can add a second role to themselves" do
    sign_in @admin

    post account_roles_path, params: {
      user: {
        role: "project_manager",
        email: "admin.multi.self@test.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_redirected_to dashboard_path
    assert_equal 2, @admin.person.profiles.reload.count
  end

  test "a plumber cannot add a role" do
    sign_in @plumber

    post account_roles_path, params: {
      user: {
        role: "project_manager",
        email: "plumber.multi.self@test.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_redirected_to dashboard_path
    assert_equal 1, @plumber.person.profiles.reload.count
    assert_not User.exists?(email: "plumber.multi.self@test.com")
  end

  test "super admin cannot add a role" do
    sign_in @super_admin

    post account_roles_path, params: {
      user: {
        role: "project_manager",
        email: "super.multi.self@test.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_redirected_to dashboard_path
    assert_equal 1, @super_admin.person.profiles.reload.count
    assert_not User.exists?(email: "super.multi.self@test.com")
  end

  test "the add a role button shows for admin but not for plumber or super admin" do
    [ [ @admin, true ], [ @plumber, false ], [ @super_admin, false ] ].each do |user, expected|
      sign_in user
      get dashboard_path
      assert_equal expected, css_select("a.sidebar-role-add-link").any?,
        "expected the add a role link presence to be #{expected} for #{user.role}"
      sign_out user
    end
  end

  test "the admin add role form carries person_id inside the form" do
    sign_in @admin

    get new_admin_user_path(person_id: @plumber.person.id)

    assert_response :success
    # The layout also renders a logout form, so look for the one that owns the
    # role field rather than simply the first form on the page.
    role_form = css_select("form").find { |f| f.css("select[name='user[role]']").any? }
    assert role_form, "expected the add role form on the page"

    hidden = role_form.css("input[name='user[person_id]']")
    assert_equal 1, hidden.length, "person_id hidden field must be inside the add role form"
    assert_equal @plumber.person.id.to_s, hidden.first["value"]
  end

  test "adding a second role does not leave a role-less profile behind" do
    sign_in @admin

    post account_roles_path, params: {
      user: { role: "super_admin", email: "nope@test.com",
              password: "password123", password_confirmation: "password123" }
    }

    assert_response :unprocessable_entity
    assert @admin.person.profiles.reload.all? { |p| p.role.present? },
      "no profile should be saved without a role"
  end

  test "a new role can have its own phone number" do
    sign_in @admin

    post account_roles_path, params: {
      user: { role: "project_manager", email: "pm.own.number@test.com",
              phone_number: "+27999887766",
              password: "password123", password_confirmation: "password123" }
    }

    assert_redirected_to dashboard_path
    added = @admin.person.profiles.reload.find_by(email: "pm.own.number@test.com")
    assert_equal "+27999887766", added.phone_number
  end

  test "a new role may reuse the phone number from the other profile" do
    @admin.update!(phone_number: "+27771234567")
    sign_in @admin

    post account_roles_path, params: {
      user: { role: "project_manager", email: "pm.shared.number@test.com",
              phone_number: "+27771234567",
              password: "password123", password_confirmation: "password123" }
    }

    assert_redirected_to dashboard_path
    added = @admin.person.profiles.reload.find_by(email: "pm.shared.number@test.com")
    assert_equal "+27771234567", added.phone_number
    assert_equal "+27771234567", @admin.reload.phone_number
  end

  test "a new role may omit the phone number and inherit the existing one" do
    @admin.update!(phone_number: "+27771234567")
    sign_in @admin

    post account_roles_path, params: {
      user: { role: "project_manager", email: "pm.no.number@test.com",
              phone_number: "", password: "password123", password_confirmation: "password123" }
    }

    assert_redirected_to dashboard_path
    added = @admin.person.profiles.reload.find_by(email: "pm.no.number@test.com")
    assert_equal "+27771234567", added.phone_number
  end

  test "an admin can give a new role its own phone number" do
    sign_in @admin
    person = @plumber.person

    post admin_users_path, params: {
      user: { person_id: person.id, role: "project_manager",
              email: "pm.admin.number@test.com", phone_number: "+27665544333",
              password: "password123", password_confirmation: "password123" }
    }

    assert_redirected_to admin_users_path
    added = person.profiles.reload.find_by(email: "pm.admin.number@test.com")
    assert_equal "+27665544333", added.phone_number
  end
end
