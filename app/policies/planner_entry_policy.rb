class PlannerEntryPolicy < ApplicationPolicy
  def index?
    user.super_admin? || user.admin? || user.scheduler? || user.accountant?
  end

  def show?
    index?
  end

  def new?
    create?
  end

  def create?
    user.super_admin? || user.admin? || user.scheduler?
  end

  def edit?
    update?
  end

  def update?
    user.super_admin? || user.admin? || user.scheduler?
  end

  def destroy?
    user.super_admin? || user.admin?
  end

  def upcoming?
    index?
  end

  def past?
    index?
  end

  class Scope < Scope
    def resolve
      if user.super_admin? || user.admin? || user.scheduler? || user.accountant?
        scope.all
      elsif user.reporter?
        scope.where("assigned_to_id IS NULL OR assigned_to_id = ?", user.id)
      else
        scope.none
      end
    end
  end
end