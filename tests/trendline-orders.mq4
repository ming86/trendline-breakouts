string VERSION = "TL BO 1.0";

extern int EXT_ATR = 300; // ATR(x)
extern double EXT_ATR_INI_STOP = 0.1; // additional buffer to add beyond the initial stop
extern int EXT_LOOKBACK = 3; // number of bars to find highest high/lowest low
extern double EXT_RISK_MINAMT = 50; // dollar value of the minimum amount to risk per trade
extern double EXT_RISK_DIVISOR = 10; // AccountBalance/X = risk per trade
extern int EXT_MAX_SLIP = 10; // maximum points of slippage allowed for order 10 = 1 pip

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
 
// check if the symbol currently has an open position
bool isActive( string sym, bool checkStop ) {
	int tots = OrdersTotal();
	for ( int i = tots; i >= 0; i -= 1 ) {
		if ( OrderSelect( i, SELECT_BY_POS, MODE_TRADES ) ) {
			if ( OrderSymbol() == sym ) {
				// check if we are checking the trailing stop on an active order
				if ( checkStop && OrderType() < 2 ) { 
					// this will be done when we write up our details on exits
				}
				return ( true );
			}
		}
	}
	return ( false );
}


// shortcut function to convert double to string
string D( double d, int dig = 0 ) {
	if ( dig == 0 ) dig = Digits;
	return( DoubleToStr( d, dig ) );
}

