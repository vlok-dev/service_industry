module Account
  class RolesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin
    before_action :set_person

    def new
      @user = @person.profiles.new(name: @person.name, phone_number: current_user.phone_number)
      assign_available_roles
    end

    def create
      @user = @person.profiles.new(profile_attributes.merge(role: user_params[:role]))

      unless User.self_serviceable_roles.include?(user_params[:role].to_s)
        # Never reached save, so this error survives into the re-render.
        @user.errors.add(:role, "can only be granted by an admin")
        assign_available_roles
        return render :new, status: :unprocessable_entity
      end

      if @user.save
        redirect_to dashboard_path, notice: "Added a #{@user.role.humanize} login. Sign in with its email to reach that dashboard."
      else
        assign_available_roles
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      profile = @person.profiles.find(params[:id])

      if profile == current_user
        redirect_to new_account_role_path, alert: "You cannot remove the profile you are signed in with."
        return
      end

      if profile.assigned_jobs.exists?
        redirect_to new_account_role_path, alert: "That profile still has jobs assigned to it. Ask an admin to remove it instead."
        return
      end

      profile.destroy
      redirect_to dashboard_path, notice: "Removed the #{profile.role.humanize} profile."
    end

    private

    def set_person
      @person = current_user.person
    end

    # Strictly the admin profile. Super admin sits above admin and does not get
    # this button, so it is checked on its own rather than by inheritance.
    def require_admin
      return if current_user.admin?

      redirect_to dashboard_path, alert: "Only the admin profile can add a role."
    end

    # The new login inherits the person's name; only the role, email, password
    # and number are theirs to choose. The number is optional and may well be
    # the same one the person already uses for another role.
    def profile_attributes
      user_params.except(:person_id, :role).merge(
        name: @person.name,
        phone_number: user_params[:phone_number].presence || current_user.phone_number
      )
    end

    def assign_available_roles
      @taken_roles = current_user.person.profiles.filter_map(&:role)
      @available_roles = User.self_serviceable_roles - @taken_roles.map(&:to_s)
    end

    def user_params
      params.require(:user).permit(:role, :name, :email, :phone_number, :password, :password_confirmation)
    end
  end
end
