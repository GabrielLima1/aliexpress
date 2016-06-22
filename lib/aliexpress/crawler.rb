require "watir-webdriver"
require 'pry'

module Aliexpress
  class Crawler
    def initialize orders, links, woocommerce
      @orders = orders
      @links = links
      @b = Watir::Browser.new :firefox
      @woocommerce = woocommerce
      @tries = 0
    end

    #Efetua login no site da Aliexpresss usando user e password
    def login user,password
    p "Efetuando login"
      @b.goto "https://login.aliexpress.com/"
      frame = @b.iframe(id: 'alibaba-login-box')
      frame.text_field(name: 'loginId').set user
      frame.text_field(name: 'password').set password
      frame.button(name: 'submit-btn').click
      sleep 5
      #Levanta erro caso o login falhe (caso de captchas)
      raise unless @b.span(class: "account-name").present? || @b.div(id: "account-name").present?
      @b
    rescue
      @tries+=1
      if @tries >= 5 #número de tentativas em caso de erro
        p "Limite de tentativas ultrapassado, abortando!"
        @b.close
        exit
      else
        p "Falha no login, tentando novamente em 30 segundos"
        sleep 30 #tempo de espera
        retry
      end
    end

    #Adiciona item ao carrinho
    def add_to_cart browser
      browser.link(id: "j-add-cart-btn").click
      sleep 5
    end

    #Adiciona quantidade certa do item
    def add_quantity(browser,quantity)
      (quantity -1).times do
        browser.dl(id: "j-product-quantity-info").i(class: "p-quantity-increase").click
      end
      sleep 10
    end

    #Selecionar opções do produto na Aliexpress usando array de opções da planilha
    def set_options browser, user_option
      count = 0
      browser.div(id: "j-product-info-sku").dls.each do |option|
        selected = user_option[count]
        if selected.nil?
          option.a.click
        else
          option.as[selected].click
        end
        count +=1
      end
    end

    #finaliza pedido com informações do cliente
    def complete_order browser, customer
      browser.goto 'http://shoppingcart.aliexpress.com/shopcart/shopcartDetail.htm'
      browser.div(class: "bottom-info-right-wrapper").button.click #Botão Comprar
      browser.ul(class: "sa-address-list").a.click #Botão Editar Endereço
      #Preenche campos de endereço
      browser.text_field(name: "contactPerson").set customer["first_name"]+" "+customer["last_name"]
      browser.select_list(name: "country").select 'Brazil'
      browser.text_field(name: "address").set to_english(customer["address_1"])
      browser.text_field(name: "address2").set to_english(customer["address_2"])
      browser.text_field(name: "city").set to_english(customer["city"])
      arr = self.state.assoc(customer["state"])
      browser.div(class: "sa-province-group").select_list.select arr[1]
      browser.text_field(name: "zip").set customer["postcode"]

      browser.div(class: "sa-form").links[1].click #Botão Salvar
      sleep 5
      browser.button(id:"place-order-btn").click #Botão Finalizar pedido
      browser.spans(class:"order-no") #Retorna os números dos pedidos
    end

    #Tabela de conversão de Estados
    def state
      [
        ["AC","Acre"],
        ["AL","Alagoas"],
        ["AP","Amapa"],
        ["AM","Amazonas"],
        ["BA","Bahia"],
        ["CE","Ceara"],
        ["DF","Distrito Federal"],
        ["ES","Espirito Santo"],
        ["GO","Goias"],
        ["MA","Maranhao"],
        ["MT","Mato Grosso"],
        ["MS","Mato Grosso do Sul"],
        ["MG","Minas Gerais"],
        ["PA","Para"],
        ["PB","Paraiba"],
        ["PR","Parana"],
        ["PE","Pernambuco"],
        ["PI","Piaui"],
        ["RJ","Rio de Janeiro"],
        ["RN","Rio Grande do Norte"],
        ["RS","Rio Grande do Sul"],
        ["RO","Rondonia"],
        ["RR","Roraima"],
        ["SC","Santa Catarina"],
        ["SP","Sao Paulo"],
        ["SE","Sergipe"],
        ["TO","Tocantins"],
      ]
    end

    #Obtém dados da planilha usando o id do produto
    def get_item_data product_id
      product_link = @woocommerce.get_product_link(product_id)
      @links.find_item(product_link.downcase.strip.to_s)
    end

    #Retira acentos e caracteres especiais
    def to_english string
      string.tr("ÀÁÂÃÄÅàáâãäåĀāĂăĄąÇçĆćĈĉĊċČčÐðĎďĐđÈÉÊËèéêëĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħÌÍÎÏìíîïĨĩĪīĬĭĮįİıĴĵĶķĸĹĺĻļĽľĿŀŁłÑñŃńŅņŇňŉŊŋÒÓÔÕÖØòóôõöøŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšſŢţŤťŦŧÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųŴŵÝýÿŶŷŸŹźŻżŽž", "AAAAAAaaaaaaAaAaAaCcCcCcCcCcDdDdDdEEEEeeeeEeEeEeEeEeGgGgGgGgHhHhIIIIiiiiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnNnnNnOOOOOOooooooOoOoOoRrRrRrSsSsSsSssTtTtTtUUUUuuuuUuUuUuUuUuUuWwYyyYyYZzZzZz")
            .tr("^A-Za-z0-9 ", '')
    end

    #Esvazia carrinho
    def empty_cart browser
      browser.goto 'http://shoppingcart.aliexpress.com/shopcart/shopcartDetail.htm'
      empty = browser.link(class: "remove-all-product")
      empty.click if empty.present?
      ok = browser.div(class: "ui-window-btn").input
      ok.click if ok.present?
      sleep 5
    rescue
      p 'Falha ao esvaziar carrinho, verificar conexão. Abortando para evitar falhas'
      exit
    end

    #Método principal
    def run user, password
    @b = self.login user, password #Efetua Login
    self.empty_cart @b #Esvazia Carrinho
      @orders.each do |order| #Loop para todos os pedidos
        begin
          customer = order["shipping_address"] #Loop para todos os produtos
          order["line_items"].each do |item|
            begin
              quantity = item["quantity"]
              data = get_item_data item["product_id"]
              link = data["link"] #Pega link Aliexpress
              @b.goto link #Abre link do produto
              stock = @b.dl(id: "j-product-quantity-info").text.split[2].gsub("(","").to_i
              if quantity > stock #Verifica estoque
                p 'Erro de estoque, produto não disponível!'
                self.empty_cart
                break
              else
                #Ações dos produtos
                self.add_quantity @b, quantity
                user_options = [data["option_1"],data["option_3"],data["option_3"]]
                self.set_options @b, user_options
                # self.set_shipping @b, user_options
                self.add_to_cart @b
              end
            rescue
              p "Erro no produto #{data["product_name"]}, verificar link do produto na aliexpress, este pedido será pulado."
              self.empty_cart
              @b.close
              break
            end
          end
          #Finaliza pedido
          order_nos = self.complete_order(@b,customer)
          raise if order_nos.count == 0
          @woocommerce.update_order(order, order_nos)
        rescue
          p "Erro ao concluir pedido #{order["id"]}, verificar aliexpress e wordpress."
        end
      end
      @b.close
    end
  end
end