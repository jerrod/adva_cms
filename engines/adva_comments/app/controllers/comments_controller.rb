class CommentsController < BaseController

  # TODO apparently it is not possible to use protect_from_forgery with
  # page cached forms? is that correct? as protect_from_forgery seems to
  # validate the form token against the session and ideally when all pages
  # and assets are cached there is no session at all this seems to make sense.
  #
  # Rails docs say: "done by embedding a token based on the session ... in all
  # forms and Ajax requests generated by Rails and then verifying the authenticity
  # of that token in the controller"
  # http://api.rubyonrails.org/classes/ActionController/RequestForgeryProtection/ClassMethods.html

  protect_from_forgery :except => [:preview, :create]

  authenticates_anonymous_user
  layout 'default'

  before_filter :set_comment, :only => [:show, :update, :destroy]
  before_filter :set_commentable, :only => [:show, :preview, :create]
  before_filter :set_comment_params, :only => [:preview, :create]

  cache_sweeper :comment_sweeper, :only => [:create, :update, :destroy]
  guards_permissions :comment, :except => :show, :create => :preview

  def show
  end

  def preview
    @comment = @commentable.comments.build params[:comment]
    @comment.send :process_filters
    render :layout => false
  end

  def create
    params[:comment].delete(:approved) # TODO use attr_protected api?
    @comment = @commentable.comments.build(params[:comment])
    if @comment.save
      trigger_events @comment
      @comment.check_approval :permalink => content_url(@comment.commentable), :authenticated => authenticated?
      flash[:notice] = t(:'adva.comments.flash.thank_you')
      redirect_to comment_path(@comment)
    else
      flash[:error] = @comment.errors.full_messages.to_sentence # TODO hu.
      render :action => :show
    end
  end

  def update
    params[:comment].delete(:approved) # TODO use attr_protected api?
    if @comment.update_attributes(params[:comment])
      trigger_events @comment
      flash[:notice] = t(:'adva.comments.flash.update.success')
      redirect_to comment_path(@comment)
    else
      set_commentable
      flash[:error] = @comment.errors.full_messages.to_sentence
      render :action => :show
    end
  end

  def destroy
    @comment.destroy
    trigger_events @comment
    flash[:notice] = t(:'adva.comments.flash.destroy.success')
    redirect_to "/"
  end

  protected

    def set_comment
      @comment = Comment.find params[:id]
    end

    def set_commentable
      @commentable = if @comment
        @comment.commentable
      else
        params[:comment][:commentable_type].constantize.find(params[:comment][:commentable_id])
      end
      raise ActiveRecord::RecordNotFound unless @commentable
    end

    def set_comment_params
      params[:comment].merge! :site_id => @commentable.site_id,
                              :section_id => @commentable.section_id,
                              :author => current_user
    end

    def current_role_context
      @comment || @commentable
    end
end