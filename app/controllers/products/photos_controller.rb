module Products
  class PhotosController < ApplicationController
    before_action :set_product
    before_action :authorize_product

    def show
      @photos = @product.photos
      @photos_data = @product.photos_meta_data
      @chosen_photo_id = params[:id].to_i
      @modal = "product-photos-#{@chosen_photo_id}"
      respond_to do |format|
        format.js { render "shared/show_modal_form" }
      end
    end

    def new
      render layout: false
    end

    def create
      existing_photos_count = @product.photos.size
      new_photos = photos_params[:photos]
      
      if existing_photos_count + new_photos.size <= Product::MAX_PHOTOS
        @product.photos += new_photos
        @product.photos_meta_data += create_meta_data(new_photos.size)
        if @product.save
          redirect_to product_url(@product)
        else
          flash[:alert] = "Ошибка при сохранении фотографий"
          redirect_back(fallback_location: product_url(@product))
        end
      elsif existing_photos_count == Product::MAX_PHOTOS
        flash[:alert] = "У данного товара уже #{Product::MAX_PHOTOS} фото."
        redirect_back(fallback_location: product_url(@product))
      else
        flash[:alert] = "У данного товара уже #{existing_photos_count} фото. Можно добавить еще #{Product::MAX_PHOTOS - existing_photos_count} фото."
        redirect_back(fallback_location: product_url(@product))
      end
    end

    def destroy
      deleted_photo = @product.photos.delete_at(params[:id].to_i)
      @product.photos_meta_data.delete_at(params[:id].to_i)
      @product.save!
      redirect_to product_url(@product)
    end

    private

    def create_meta_data(size)
      meta_data = []
      size.times do |i|
        meta_data << {user: current_user.short_name, date: DateTime.current.strftime("%d.%m.%Y %H:%M")}
      end
      meta_data
    end

    def set_product
      @product = Product.find(params[:product_id])
    end

    def authorize_product
      authorize @product, :edit?
    end

    def photos_params
      params.require(:product).permit(photos: [])
    end
  end
end