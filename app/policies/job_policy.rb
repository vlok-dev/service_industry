class JobPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    record_owner_or_admin? || assigned_plumber? || reporter? || user.scheduler?
  end

  def create?
    user.super_admin? || user.admin?
  end

  def new?
    create?
  end

  def update?
    record_owner_or_admin? || assigned_plumber?
  end

  def edit?
    update?
  end

  def destroy?
    user.super_admin? || user.admin?
  end

  def schedule?
    user.scheduler?
  end

  def bulk_whatsapp?
    user.scheduler?
  end

  private

  def record_owner_or_admin?
    user.super_admin? || user.admin? || record.user_id == user.id
  end

  def assigned_plumber?
    record.assigned_to_id == user.id
  end

  def reporter?
    user.reporter?
  end

  class Scope < Scope
    def resolve
      case user.role
      when "super_admin", "admin"
        scope.all
      when "scheduler"
        scope.all
      when "reporter"
        scope.all
      when "plumber"
        scope.where(assigned_to: user)
      else
        scope.none
      end
    end
  end
end