class PostsController < ApplicationController

  def index
    @posts = Post.all

    respond_to do |format|
      format.html # renders index.html.erb
      format.json { render json: @posts } # returns API JSON data
    end
  end

  def new
    @post = Post.new
  end

  def create
    @post = Post.new(post_params)

    if @post.save
      redirect_to posts_path
    else
      render :new
    end
  end

  private

  def post_params
    params.require(:post).permit(:title, :body, :author)
  end

end
