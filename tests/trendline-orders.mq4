string VERSION = "TL BO 1.0";

extern int EXT_ATR = 300; // ATR(x)
extern double EXT_ATR_INI_STOP = 0.1; // additional buffer to add beyond the initial stop
extern int EXT_LOOKBACK = 3; // number of bars to find highest high/lowest low
extern double EXT_RISK_MINAMT = 50; // dollar value of the minimum amount to risk per trade
extern double EXT_RISK_DIVISOR = 10; // AccountBalance/X = risk per trade
extern int EXT_MAX_SLIP = 10; // maximum points of slippage allowed for order 10 = 1 pip
extern double EXT_ATR_TRAILSTOP = 2; // multiple for trailing the market ATR(EXT_ATR) * X

// global variables
bool GATE_ACTIVE;

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
{
//----
	string sym = Symbol();
	// check if currency is active
	GATE_ACTIVE = isActive( sym, false );
//----
	return(0);
}
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
{
//----

//----
	return(0);
}
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
{
//----
	string sym = Symbol();
	int per = Period();
	if ( !GATE_ACTIVE ) {
	  if ( Bid > iHigh( sym, per, 1 ) + iATR( sym, per, EXT_ATR, 1 ) ) doBuy( sym, per );
	  if ( Ask < iLow( sym, per, 1 ) - iATR( sym, per, EXT_ATR, 1 ) ) doSell( sym, per );
	} else {
		// if the gate is active let's analyse whether it's stop loss needs amending
		GATE_ACTIVE = isActive( sym, true );
	}
//----
   return(0);
}
//+------------------------------------------------------------------+

// placing an at-market sell order
int doSell( string sym, int per ) {
	// check whether the system is allowed to place a trade
	int trade = checkIsTradeAllowed(), tkt = 0;
	if ( trade == 0 ) RefreshRates();
	if ( trade > 0 ) {
		// get entry price
		double entry = Bid;
		// get spread as SELL orders pay the spread on their exit
		double spread = MarketInfo( sym, MODE_SPREAD ) * MarketInfo( sym, MODE_POINT );
		// get initial stop loss - we will use the highest high over X periods plus a buffer
		double exit = N( iHigh( sym, per, iHighest( sym, per, MODE_HIGH, EXT_LOOKBACK, 0 ) ) + ( EXT_ATR_INI_STOP * iATR( sym, per, EXT_ATR, 1 ) ) );
		// add spread to initial stop loss value
		exit += spread;
		// check if stop loss is beyond the currency's stop level
		double stopPt = MarketInfo( sym, MODE_STOPLEVEL ) * MarketInfo( sym, MODE_POINT );
		// if not amend the exit to meet stop level requirements
		if ( MathAbs( entry - exit ) < stopPt ) exit = entry + stopPt;
		// get the amount to risk per trade
		double riskAmt = getRiskAmount();
		// now calculate what the amount risked per trade equates to in lot size
		double lots = MathMax( getLots( sym, entry, exit, riskAmt ), MarketInfo( sym, MODE_LOTSTEP ) );
		// as we have an at market ordering process we don't need an expiry value
		datetime expy = 0;
		// storing a value for the MagicNumber can be subjective, you can do whatever you want, I will just use
		// the active chart's Period() value
		int magic = per;
		// our last minute check to see that we DON'T have an active open order on this currency
		// if we do exit this function with 0
		if ( isActive( sym, false ) ) return( 0 );
		// submit AT MARKET sell order
		tkt = OrderSend( sym, OP_SELL, lots, entry, EXT_MAX_SLIP, exit, magic, VERSION, expy, 0 );
		if ( tkt > 0 ) {
			// change the active currency's GATE_ACTIVE flag to true
			GATE_ACTIVE = true;
			// our entry order has been placed let's now notify ourselves of the order
			SendMail( "NEW SELL Order " + sym, 
				"Entry = " + D( entry ) + "\n" +
				"StopLoss = " + D( exit ) + "\n" +
				"Initial Risk = " + D( riskAmt, 2 ) + "\n" +
				"Actual Risk = " + D( profitAtStop( sym, entry, exit, lots, OP_SELL ), 2 ) + "\n" +
				"Lots = " + D( lots, 2 ) + "\n" +
				"Expiry = " + TimeToStr( expy ) + "\n" +
				"MagicNum = " + magic + "\n" +
				"HHV = " + D( iHigh( sym, per, iHighest( sym, per, MODE_HIGH, EXT_LOOKBACK, 0 ) ) ) + "\n" +
				"Version = " + VERSION + "\n"
			);
		} else if ( tkt == -1 ) {
			// here's what we will do when something goes wrong - try to return as much details as possible
			if ( GetLastError() > 0 ) {
				SendMail( "ERR with NEW SELL Order " + sym,
					"Entry = " + D( entry ) + "\n" +
					"StopLoss = " + D( exit ) + "\n" +
					"Initial Risk = " + D( riskAmt, 2 ) + "\n" +
					"Actual Risk = " + D( profitAtStop( sym, entry, exit, lots, OP_SELL ), 2 ) + "\n" +
					"Lots = " + D( lots, 2 ) + "\n" +
					"Expiry = " + TimeToStr( expy ) + "\n" +
					"MagicNum = " + magic + "\n" + 					
					"HHV = " + D( iHigh( sym, per, iHighest( sym, per, MODE_HIGH, EXT_LOOKBACK, 0 ) ) ) + "\n" +
					"Version = " + VERSION + "\n"
				);
			}
		}
	}
	return ( tkt );
}

int doBuy( string sym, int per ) {
	int trade = checkIsTradeAllowed(), tkt = 0;
	if ( trade == 0 ) RefreshRates();
	if ( trade > 0 ) {		
		double entry = Ask; // spread paid at entry
		double exit = N( iLow( sym, per, iLowest( sym, per, MODE_LOW, EXT_LOOKBACK, 0 ) ) - ( EXT_ATR_INI_STOP * iATR( sym, per, EXT_ATR, 1 )) ); // bid price
		double stopPt = MarketInfo( sym, MODE_STOPLEVEL ) * MarketInfo( sym, MODE_POINT );
		if ( MathAbs( entry - exit ) < stopPt ) exit = entry - stopPt;
		double riskAmt = getRiskAmount();
		double lots = MathMax( getLots( sym, entry, exit, riskAmt ), MarketInfo( sym, MODE_LOTSTEP ) );
		datetime expy = 0;
		int magic = per;
		if ( isActive( sym, false ) ) return( 0 ); // last minute check!
		// submit AT MARKET entry order
		tkt = OrderSend( sym, OP_BUY, lots, entry, EXT_MAX_SLIP, exit, magic, VERSION, expy, 0 ); 
		if ( tkt > 0 ) {
			SendMail( "NEW BUY Order for " + sym, 
				"Entry = " + D( entry ) + "\n" +
				"StopLoss = " + D( exit ) + "\n" +
				"Initial Risk = " + D( riskAmt, 2 ) + "\n" +
				"Actual Risk = " + D( profitAtStop( sym, entry, exit, lots, OP_BUY ), 2 ) + "\n" +
				"Lots = " + D( lots, 2 ) + "\n" +
				"Expiry = " + TimeToStr( expy ) + "\n" +
				"MagicNum = " + magic + "\n" + 
				"LLV = " + D( iLow( sym, per, iLowest( sym, per, MODE_LOW, EXT_LOOKBACK, 0 ) ) ) + "\n" +
				"Version = " + VERSION
			);
			GATE_ACTIVE = true;
		} else if ( tkt == -1 ) {
			if ( GetLastError() > 0 ) {
				SendMail( "ERR with NEW BUY Order for " + sym,
					"Entry = " + D( entry ) + "\n" +
					"StopLoss = " + D( exit ) + "\n" +
					"Initial Risk = " + D( riskAmt, 2 ) + "\n" +
					"Actual Risk = " + D( profitAtStop( sym, entry, exit, lots, OP_BUY ), 2 ) + "\n" +
					"Lots = " + D( lots, 2 ) + "\n" +
					"Expiry = " + TimeToStr( expy ) + "\n" +
					"MagicNum = " + magic + "\n" + 
					"LLV = " + D( iLow( sym, per, iLowest( sym, per, MODE_LOW, EXT_LOOKBACK, 0 ) ) ) + "\n" +
					"Version = " + VERSION
				);
			}
		}
	}
	return( tkt );
}


// amended from http://articles.mql4.com/141
int checkIsTradeAllowed( uint MaxWaiting_sec = 30 ) {
	// check firstly whether it's the end of the forex day
	// Pepperstone will not allow us to trade between 17:00 - 17:05 NY EST
	if ( Hour() == 0 && Minute() < 5 ) {
			Print( "Cannot trade during this time, closing market" );
			return( -1 );
	}
	if ( !IsTradeAllowed() ) {
		uint StartWaitingTime = GetTickCount();
		while( true ) {
			if ( IsStopped() ) {
				Print("The expert was terminated by the user!");
				return( -1 );
			} 
			if ( GetTickCount() - StartWaitingTime > MaxWaiting_sec * 1000 ) {
				Print("Waiting limit exceeded");
				return( -2 );
			}
			if ( IsTradeAllowed() ) return( 0 );
			Sleep( 100 );
		}
	} else {
		return( 1 );
	}
	return( -1 );
}


// calculates the amount of money to risk per trade
double getRiskAmount() {
	return( MathMax( EXT_RISK_MINAMT, ( AccountBalance() + getStopPL() ) / EXT_RISK_DIVISOR ) );
}

// calculates the total profit/loss of all open positions as though every open trade were to 
// exit immediately at their current stop prices
double getStopPL() {
  int tot = OrdersTotal();
	double result = 0;
	for( int i = tot; i >= 0; i -= 1 ) {
		if ( OrderSelect( i, SELECT_BY_POS, MODE_TRADES) ) {
			result += profitAtStop( OrderSymbol(), OrderOpenPrice(), OrderStopLoss(), OrderLots(), OrderType() );		
		}
	}
	return( result );
}

// calculates the profit/loss of the trade if it's stop is hit
double profitAtStop( string sym, double open, double stop, double lots, int type ) {    
    double result = lots * MarketInfo( sym, MODE_TICKVALUE ) / MarketInfo( sym, MODE_TICKSIZE );
    if ( type == OP_BUY ) {
        return( N( ( stop - open ) * result, 2 ) );
    } else if ( type == OP_SELL ) {
        return( N( ( open - stop ) * result, 2 ) );
    }
    return ( 0 );
}

// shortcut function to NormalizeDouble
double N( double d, int dig = 0 ) {
	if ( dig == 0 ) dig = Digits;
	return( NormalizeDouble( d, dig ) );
}


// calculates the position size of the trade according to entry, initial stop loss and risk
double getLots( string sym, double entry, double stop, double risk ) {
	double dist = MathAbs( entry - stop ),
				result = ( risk * MarketInfo( sym, MODE_TICKSIZE ) ) / ( dist * MarketInfo( sym, MODE_TICKVALUE ) );
	return( N( result, 2 ) ); 
}
 
// shortcut function to convert double to string
string D( double d, int dig = 0 ) {
	if ( dig == 0 ) dig = Digits;
	return( DoubleToStr( d, dig ) );
}

// check if the symbol currently has an open position
bool isActive( string sym, bool checkStop ) {
	int tots = OrdersTotal();
	double stop;
	for ( int i = tots; i >= 0; i -= 1 ) {
		if ( OrderSelect( i, SELECT_BY_POS, MODE_TRADES ) ) {
			if ( OrderSymbol() == sym ) {
				// check if we are checking the trailing stop on an active order
				if ( checkStop && OrderType() < 2 ) { 
					// as we are checking stops let's check this one
					// notice here how when we stored the OrderMagicNumber we used it to store the Period
					// the purpose of this is to help us differentiate what time period was used in case we
					// use multiple time frames for this EA on the same currency
					stop = getTrailingStop( sym, OrderOpenPrice(), OrderStopLoss(), OrderOpenTime(), OrderMagicNumber(), OrderType() );
					// if the stop is different to the current orders' stop loss we will amend accordingly
					if ( stop != OrderStopLoss() ) amendStop( sym, OrderTicket(), OrderOpenPrice(), stop, OrderType(), OrderLots() );									
				}
				return ( true );
			}
		}
	}
	return ( false );
}

// this function requires the following parameters:
// sym = currency
// op = opening price of the current trade
// sl = stop loss price of the current trade
// ot = opening datetime of the current trade
// per = active chart's period - for calculating ATR distance properly
// type = order type of the current trade
double getTrailingStop( string sym, double op, double sl, datetime ot, int per, int type ) {
	double temp;	
	// make the result for this function initially equal the stop loss
	double result = sl;	
	// calculate the trailing stop distance
	double atr = iATR( sym, per, EXT_ATR, 1 ) * EXT_ATR_TRAILSTOP;
	// check if we are operating in the bar of entry, if so move to minute charts to find out
	// what the highest high or lowest low is since entry (rather than using the whole bar)
	// As Pepperstone timestamp their bars with the opening time of that bar we can frame
	// our logic by checking if the current bar is less than or equal to the current bar
	// if it is, then the current bar *IS* the bar of entry.
	if ( iTime( sym, per, 0 ) <= ot ) {
		temp = getMinutePrice( sym, ot, sl, type );
		if ( type == OP_BUY && temp > result ) result = temp - atr;
		if ( type == OP_SELL && temp < result ) result = temp + atr;
	}
	// get bars of current periods' chart	
	int b = iBars( sym, per );	
	// let's loop through the bars now, starting with the most recent bar
	for ( int i = 0; i < b; i += 1 ) {
		// if the time of the active chart is LESS than the time of when the trade opened, end
		if ( iTime( sym, per, i ) < ot ) break;
		// calculate the ATR trailing distance - using active chart's period
		// and always using the previous bar's ATR as the current bar is still
		// forming
		atr = iATR( sym, per, EXT_ATR, i+1 ) * EXT_ATR_TRAILSTOP;
		// for long trades
		if ( type == OP_BUY ) {
			// using the high of the minute chart subtract the ATR distance
			temp = iHigh( sym, per, i ) - atr;
			// compare against the current best result, and if it is better modify result
			if ( temp > result ) result = temp;
		// for short trades
		} else if ( type == OP_SELL ) {
			// using the low of the minute chart add the ATR distance
			temp = iLow( sym, per, i ) + atr;
			// compare against the current best result, and if it is better modify result
			if ( temp < result ) result = temp;
		}
	}
	// return the result, normalizing the double
	return ( N( result ) );
}

// this function will return the highest high or lowest low in the minute chart
// parameters of this function: 
// sym = currency's symbol
// ot = opening datetime of the trade
// type = order type of the trade
function getMinutePrice( string sym, datetime ot, int type ) {
	int per = PERIOD_M1;
	int b = iBars( sym, per );
	// better to start with a value, rather than 0
	double result = iClose( sym, per, 0 );
	for ( int i = 0; i < b; i += 1 ) {
		// once the active bar is less than the opening time then we are analysing
		// bars PRIOR to entry, therefore exit
		if ( iTime( sym, per, i ) < ot ) break;
		if ( type == OP_BUY && iHigh( sym, per, i ) > result ) result = iHigh( sym, per, i );
		if ( type == OP_SELL && iLow( sym, per, i ) < result ) result = iLow( sym, per, i );
	}
	return ( result );
}


// this function will amend the active order, but needs the following params:
// sym = currency symbol
// tkt = current orders' ticket number
// op = current orders' opening price
// sl = stop price to amend to
// type = order type
// lots = current orders' lot size
bool amendStop( string sym, int tkt, double op, double sl, int type, double lots ) {
	// check whether we can make an amendment
	int trade = checkIsTradeAllowed();
	if ( trade == 0 ) RefreshRates();
	if ( trade > 0 ) {
		// check if the amending of our long order is greater the bid price, if so exit at market
		if ( type == OP_BUY && sl > Bid ) {
			return( exitNow( sym, tkt, lots, type ) );
		// check if the amending of our short order is less than the ask price, if so exit at market
		} else if ( type == OP_SELL && sl < Ask ) {
			return( exitNow( sym, tkt, lots, type ) );
		// otherwise modify order accordingly
		} else {
			return( OrderModify( tkt, op, sl, 0, 0 ) );	
		}		
	}
	// if no modification has been made return false
	return( false );
}

// this function exits at market, but needs the following params:
// sym = currency symbol
// tkt = order's ticket number
// lots = order's lot size
// type = order's type (eg. OP_BUY, OP_SELL)
bool exitNow( string sym, int tkt, double lots, int type ) {
	// check if it's okay to exit trade
	int trade = checkIsTradeAllowed();
	double p;
	// get refreshed prices
	if ( type == OP_BUY ) p = MarketInfo( sym, MODE_ASK );
	if ( type == OP_SELL ) p = MarketInfo( sym, MODE_BID );
	// place trade if ok to place order
	if ( trade > 0 ) return( OrderClose( tkt, lots, p, EXT_MAX_SLIP ) );
	// if this has failed return false
	return( false );
}