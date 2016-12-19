class TradesController < ApplicationController

#!!need to go back and decide on what to do if error
#!!!redirect?
#!! for the getters, do the returned objects have getters?
#everytime add a user, add they add 0 shares of everything?
#!add try and catch

    

    def allMarkets

        data = Market.all.map { |market|
           {id:market.id, price_long:calc_price(market.id,1,'l'),  price_short:-1*calc_price(market.id,-1,'s')}
        }
        render :json => data
    end

    def buyShares
        mid,type = params[:input].split('_');
        result = nil
        if type == "long" then
            result = buy_long(mid.to_i,session[:user_id],1)
        else
            result = buy_short(mid.to_i,session[:user_id],1)
        end

        render :json => {result: result.to_s}
    end

    #under construction
    def sellShares
        mid,type = params[:input].split('_');
        result = nil
        if type == "long" then
            result = sell_long(mid.to_i,session[:user_id],1)
        else
            result = sell_short(mid.to_i,session[:user_id],1)
        end

        render :json => {result: result.to_s}
    end

    def sell_long(market_id, num_shares, user_id)
        price = calc_price(market_id, -1*num_shares, 'l')
        #!!!!!!go back and handle error case
        user_longs = get_longs(user_id, market_id)
        if num_shares > user_longs
            puts "You don't own this."
        else
            # changing user data
            balance = get_balances(user_id)
            new_balance = balance - price
            set_balance(user_id, new_balance)
            trades = get_trades(user_id)
            set_trades(user_id, trades + num_shares)

            # changing shares data
            set_longs(user_id, market_id, user_longs - num_shares)

            # changing market data
            market_longs = get_longs(market_id)
            set_longs(market_id, market_longs - num_shares)

            #changing transactions data
            #!!!!add time
            add_transaction(market_id, user_id, num_shares, 0, cost, cost/num_shares, get_price(market_id))
        end
    end

    def sell_short(market, num_shares)
        price = calc_price(market_id, -1*num_shares, 's')
        #!!!!!!go back and handle error case
        user_shorts = get_shorts(user_id, market_id)
        if num_shares > user_shorts
            puts "You don't own this."
        else
            # changing user data
            balance = get_balances(user_id)
            new_balance = balance - price
            set_balance(user_id, new_balance)
            trades = get_trades(user_id)
            set_trades(user_id, trades + num_shares)

            # changing shares data
            set_shorts(user_id, market_id, user_shorts - num_shares)

            # changing market data
            market_shorts = get_shorts(market_id)
            set_shorts(market_id, market_shorts - num_shares)

            #changing transactions data
            #!!!!add time
            add_transaction(market_id, user_id, 0, num_shares, cost, cost/num_shares, get_price(market_id))
        end
    end

    def buy_long(market_id, user_id, num_shares)
        price = calc_price(market_id, num_shares, 'l')
        #!!!!!!go back and handle error case
        balance = get_balance(user_id)
        puts balance
        puts balance == nil
        puts price
        puts price == nil
        if price > balance
            puts "You don't have enough money."
            return false
        else
            # changing user data
            balance = get_balance(user_id)
            new_balance = balance - price
            set_balance(user_id, new_balance)
            # trades = get_trades(user_id)
            # set_trades(user_id, trades + num_shares)

            # changing shares data
            # set_longs(user_id, market_id, user_longs + num_shares)

            # changing market data
            market_longs = get_longs(market_id)
            set_longs(market_id, market_longs + num_shares)

            #changing transactions data
            #!!!!add time
            addTransaction(user_id,market_id,Time.zone.now,num_shares,price,'l')
            return true
        end
    end

    def buy_short(market_id, user_id, num_shares)
        price = -1*calc_price(market_id, -1*num_shares, 's')
        #!!!!!!go back and handle error case
        balance = get_balance(user_id)
        if price > balance
            puts "You don't have enough money."
            return false
        else
            # changing user data
            balance = get_balance(user_id)
            new_balance = balance - price
            set_balance(user_id, new_balance)
            # trades = get_trades(user_id)
            # set_trades(user_id, trades + num_shares)

            # changing shares data
            # set_longs(user_id, market_id, user_longs + num_shares)

            # changing market data
            market_shorts = get_shorts(market_id)
            set_longs(market_id, market_shorts + num_shares)

            #changing transactions data
            #!!!!add time
            addTransaction(user_id,market_id,Time.zone.now,num_shares,price,'s')
            return true
        end
    end

    def addTransaction(user_id,market_id,time,num_shares,price,flag)
        transaction = Transaction.new
        transaction.user_id = user_id
        transaction.market_id = market_id
        transaction.timestamp = time
        transaction.num_shares = num_shares
        transaction.price = price
        market = Market.where(:id => market_id).first
        market.num_shares = market.num_shares + 1
        if flag == 'l'
            market.longs = market.longs + 1
            market.last_price = price
        else
            market.shorts = market.shorts + 1
            market.last_price = 1 - price
        end

    end

    def calc_price(market_id, num_shares, flag)
        #get num shares bought for and against from table
        q1 = get_longs(market_id)
        q2 = get_shorts(market_id)
        b = get_b_val(market_id)
        if flag == 'l'
            c1= get_cost(b,q1+num_shares,q2)
        elsif flag == 's'
            c1= get_cost(b,q1,q2+num_shares)
        else
            print('error')
        end
        c2 = get_cost(b,q1,q2)
        #C(newnums) - C(old nums)

        #Round?
        return (c1 - c2).round(2)
    end

    def get_price(market_id)
      #e^q1/b/(e^q1/b + e^q2/b)
      q1 = get_price(market_id)
      q2 = get_price(market_id)
      b = get_b_val(market_id)
      return Math.exp(num_event/b)/(Math.exp(num_for/b) + Math.exp(num_against/b))
    end

    def get_cost(b,num_for,num_against)
        #b*log(e^q1/b + e^q2/b)
        b * Math.log(Math.exp(num_for/b) + Math.exp(num_against/b))
    end


    # def get_balance(id)
    #     ans = Users.first(:conditions => "user_id = ?", id)
    #     ans.balance
    # end

    # def get_trades(id)
    #     ans = Users.first(:conditions => "user_id = ?", id)
    #     ans.trades
    # end

    # def get_longs(u_id, m_id)
    #     ans = Users.first(:conditions => "user_id = ? AND market_id = ?", u_id, m_id)
    #     ans.longs
    # end

    # def get_shorts(u_id, m_id)
    #     ans = Users.first(:conditions => "user_id = ? AND market_id = ?", u_id, m_id)
    #     ans.shorts
    # end

    def get_b_val(id)
        ans = Market.where(:id => id).first
        ans.b_val
    end

    def get_balance(id)
        ans = User.where(:id => id).first
        if ans.balance == nil then
            ans.balance = 20 # OR WHATEVER THE BASE IS
        end
        ans.balance
    end

    def set_balance(id, new_balance)
        ans = User.where(:id => id).first
        ans.balance = new_balance
    end

    def get_trades(id)
        ans = User.where(:id => id).first
        ans.trades
    end

    # Do we need user id for these?
    def get_longs(id)
        ans = Market.where(:id => id).first
        ans.longs
    end

    def get_shorts(id)
        ans = Market.where(:id => id).first
        ans.shorts
    end

    def set_longs(id, new_longs)
        ans = Market.where(:id => id).first
        ans.longs = new_longs
    end

    def set_shorts(id, new_shorts)
        ans = Market.where(:id => id).first
        ans.shorts = new_shorts
    end

end
