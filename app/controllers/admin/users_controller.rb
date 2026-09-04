module Admin
  class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin
    before_action :set_user, only: %i[ edit update destroy ]

    def index
      @search_query = params[:q].to_s.strip
      @users = User.all.order(:role, :name)
      if @search_query.present?
        sanitized = "%#{ActiveRecord::Base.sanitize_sql_like(@search_query)}%"
        @users = @users.where("name ILIKE :q OR email ILIKE :q OR phone_number ILIKE :q", q: sanitized)
      end
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)

      if @user.save
        redirect_to admin_users_path, notice: "User was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

  def update
    update_params = user_params
    if update_params[:password].blank?
      update_params.delete(:password)
      update_params.delete(:password_confirmation)
    end

    if @user.update(update_params)
      redirect_to admin_users_path, notice: "User was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

    def destroy
      if @user == current_user
        redirect_to admin_users_path, alert: "You cannot delete your own account while logged in."
        return
      end

      if @user.jobs.exists?
        fallback = User.where.not(id: @user.id).where(role: [:super_admin, :admin]).first
        if fallback
          @user.jobs.update_all(user_id: fallback.id)
        else
          redirect_to admin_users_path, alert: "Cannot delete this user because they have created jobs and no other admin exists to reassign them to."
          return
        end
      end

      @user.destroy
      redirect_to admin_users_path, notice: "User was successfully deleted."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:name, :email, :role, :phone_number, :password, :password_confirmation)
    end

    def require_admin
      unless current_user.admin? || current_user.super_admin?
        redirect_to root_path, alert: "You are not authorized to access admin area."
      end
    end
  end
end