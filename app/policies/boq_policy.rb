class BoqPolicy < ApplicationPolicy
  def index?
    user.scheduler? || user.super_admin? || user.admin? || user.accountant? || user.project_manager?
  end

  def show?
    index?
  end

  def create?
    user.super_admin? || user.admin? || user.accountant? || user.scheduler?
  end

  def new?
    create?
  end

  def update?
    create?
  end

  def edit?
    update?
  end

  def destroy?
    user.super_admin? || user.admin?
  end

  def download?
    index?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      case user&.role
      when "super_admin", "admin", "accountant", "scheduler", "project_manager"
        scope.all
      else
        scope.none
      end
    end
  end
end
