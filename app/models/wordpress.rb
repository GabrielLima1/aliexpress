require 'woocommerce_api'

class Wordpress < ActiveRecord::Base
  validates :name, :url, :consumer_key, :consumer_secret, presence: true
  has_many :crawlers

  @error = nil

  def error
    @error
  end

  def woocommerce
    woocommerce = WooCommerce::API.new(
    self.url, #Url do site
    self.consumer_key, #Consumer Key
    self.consumer_secret, #Consumer Secret
      {
        version: "v2" #Versão da API
      }
    )
    woocommerce
  end

  def get_products
    products = self.woocommerce.get("products?filter[limit]=1000&fields=id,permalink,title,attributes").parsed_response
    products['products']
  end

  def update_order order, order_nos
    #Atualiza pedidos no wordpress com o numero dos pedidos da aliexpress
    data = {
      order_note: {
        note: order_nos.text
      }
    }
    #POST em order notes
    woocommerce.post("orders/#{order["id"]}/notes", data).parsed_response
    data = {
      order: {
        status: "completed"
      }
    }
    #PUT para mudar a ordem para concluída
    woocommerce.put("orders/#{order["id"]}", data).parsed_response
  rescue
    @error = "Erro ao atualizar pedido #{order["id"]} no wordpress, verificar ultimo pedido na aliexpress."
  end

  def get_orders
    #Pegar todos os pedidos com status Processado, limite 1000 e apenas dados
    #que serão usados: id,shipping_address,line_items
      all_orders = woocommerce.get("orders?filter[limit]=200&status=processing&fields=id,shipping_address,billing_address,line_items").parsed_response
    #Converção para array
    all_orders["orders"]
  rescue
    @error =  "Erro ao importar pedidos do Wordpress, favor verificar configurações."
  end
end
