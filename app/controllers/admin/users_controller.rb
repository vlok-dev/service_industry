module Admin
  class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin
    before_action :set_user, only: %i[ edit update destroy ]

    def index
      @search_query = params[:q].to_s.strip
      @people = Person.order(:name)

      if @search_query.present?
        sanitized = "%#{ActiveRecord::Base.sanitize_sql_like(@search_query)}%"
        matching_profiles = User.where(
          "LOWER(name) LIKE LOWER(:q) OR LOWER(COALESCE(email,'')) LIKE LOWER(:q) OR COALESCE(phone_number,'') LIKE :q",
          q: sanitized
        ).select(:person_id)

        @people = @people.where(
          "LOWER(people.name) LIKE LOWER(:q) OR COALESCE(people.phone_number,'') LIKE :q OR people.id IN (:matching_profiles)",
          q: sanitized, matching_profiles: matching_profiles
        )
      end
    end

    def new
      @user = User.new
      @person = Person.find_by(id: params[:person_id])

      if @person
        @user.person = @person
        @user.name = @person.name
        @user.phone_number = @person.phone_number
      end

      assign_available_roles
    end

    def create
      @user = build_profile

      if @user.save
        redirect_to admin_users_path, notice: success_notice_for(@user)
      else
        @person = @user.person
        assign_available_roles
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @person = @user.person
      assign_available_roles
    end

    def update
      update_params = user_params.except(:person_id)
      if update_params[:password].blank?
        update_params.delete(:password)
        update_params.delete(:password_confirmation)
      end

      if @user.update(update_params)
        redirect_to admin_users_path, notice: "User was successfully updated."
      else
        @person = @user.person
        assign_available_roles
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user == current_user
        redirect_to admin_users_path, alert: "You cannot delete your own account while logged in."
        return
      end

      if @user.jobs.exists?
        fallback = User.where.not(id: @user.id).where(role: [ :super_admin, :admin ]).first
        if fallback
          @user.jobs.update_all(user_id: fallback.id)
        else
          redirect_to admin_users_path, alert: "Cannot delete this user because they have created jobs and no other admin exists to reassign them to."
          return
        end
      end

      person = @user.person
      @user.destroy
      notice = "User was successfully deleted."

      if person && person.profiles.reload.empty?
        person.destroy
        notice = "User was successfully deleted, and the person had no remaining profiles."
      end

      redirect_to admin_users_path, notice: notice
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    # Someone cannot hold the same role twice, so once they have a profile we
    # stop offering the roles they already have.
    def assign_available_roles
      taken = @person&.profiles&.where.not(id: @user.id)&.filter_map(&:role) || []
      @taken_roles = taken
      @available_roles = User.roles.keys - taken.map(&:to_s)
    end

    # With a person_id this adds a second role to somebody who already exists,
    # which is a separate login with its own email and password. Without one it
    # creates a brand new person with their first profile.
    def build_profile
      attributes = user_params.except(:person_id)

      if user_params[:person_id].present?
        person = Person.find(user_params[:person_id])
        # The form hides the name when adding to somebody who already exists.
        attributes[:name] = person.name
        # The number stays editable and may repeat one the person already uses.
        attributes[:phone_number] = user_params[:phone_number].presence || person.phone_number
        person.profiles.new(attributes)
      else
        User.new(attributes)
      end
    end

    def success_notice_for(user)
      if user.person.multi_role?
        "Added a #{user.role.humanize} login for #{user.person.name}. They can now sign in with it to reach that dashboard."
      else
        "User was successfully created."
      end
    end

    def user_params
      params.require(:user).permit(:person_id, :name, :email, :role, :phone_number, :password, :password_confirmation)
    end

    def require_admin
      unless current_user.admin?
        redirect_to root_path, alert: "You are not authorized to access admin area."
      end
    end
  end
end
