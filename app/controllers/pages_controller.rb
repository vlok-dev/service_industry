class PagesController < ApplicationController
  def offline
    render layout: false
  end

  def manifest
    render layout: false
  end
end